function Export-PowerShellHelpToJson {
    <#
    This did not produce a good finely tuned model at all.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]$Module,
        [Parameter()]
        [double]$ValidationSplit = 0.2
    )

    $commonParameters = [System.Management.Automation.PSCmdlet]::CommonParameters

    foreach ($moduleName in $Module) {
        Import-Module $moduleName -ErrorAction SilentlyContinue

        $commands = Get-Command -Module $moduleName | Where-Object CommandType -ne Alias

        $trainingData = @()
        $validationData = @()

        foreach ($command in $commands) {
            $help = Get-Help $command.Name -Full

            if ((-not $helpContent.synopsis -or -not $helpContent.description.Text) -and -not $helpContent.examples.example.code) {
                Write-Verbose "No help content found for command: $cmd"
                continue
            }
            $questionAnswer = @{
                "question" = "What does the command {0} do?" -f $command.Name
                "answer"   = "$($help.Synopsis)".Trim()
            }
            $trainingData += $questionAnswer

            if ($help.Description) {
                $questionAnswer = @{
                    "question" = "Can you provide more details about the {0} command?" -f $command.Name
                    "answer"   = "$($help.Description.Text)".Trim()
                }
                $trainingData += $questionAnswer
            }

            $parameters = $command.Parameters.Keys | Where-Object { $_ -notin $commonParameters }
            foreach ($parameter in $parameters) {
                $paramHelp = Get-Help $command.Name -Parameter $parameter

                $questionAnswer = @{
                    "question" = "What is the purpose of the -{0} parameter in the {1} command?" -f $parameter, $command.Name
                    "answer"   = "$($paramHelp.Description.Text)".Trim()
                }
                $trainingData += $questionAnswer
            }

            $examples = $help.Examples.Example
            foreach ($example in $examples) {
                $questionAnswer = @{
                    "question" = "Can you provide an example of how to use the {0} command?" -f $command.Name
                    "answer"   = "$($example.Code)".Trim().Replace("'", "").Replace('"', '')
                }
                $validationData += $questionAnswer

                if ($example.Remarks) {
                    $questionAnswer = @{
                        "question" = "What does the example for the {0} command demonstrate?" -f $command.Name
                        "answer"   = "$($example.Remarks.Text)".Trim()
                    }
                    $validationData += $questionAnswer
                }
            }
        }

        $totalCount = $trainingData.Count + $validationData.Count
        $validationCount = [int]($totalCount * $ValidationSplit)

        $selectedValidationData = $validationData | Get-Random -Count $validationCount
        $trainingData += $validationData | Where-Object { $_ -notin $selectedValidationData }

        $trainingOutputFile = "{0}_TrainingData.jsonl" -f $moduleName
        $validationOutputFile = "{0}_ValidationData.jsonl" -f $moduleName

        $trainingData | ConvertTo-Json -Depth 100 -Compress | Out-File $trainingOutputFile -Encoding utf8
        $selectedValidationData | ConvertTo-Json -Depth 100 -Compress | Out-File $validationOutputFile -Encoding utf8

        Get-ChildItem $trainingOutputFile, $validationOutputFile
    }
}