function ConvertTo-FineTuning {
    <#
    .SYNOPSIS
        Converts help text of commands into fine-tuning data for a chatbot using an external service.

    .DESCRIPTION
        The ConvertTo-FineTuning function processes command help text to create fine-tuning data for a chatbot. It can take input directly from a pipeline of objects or specify a module to retrieve commands from. The function prepares the data by sending it to an external API and handles the responses to generate the fine-tuning data.

    .PARAMETER InputObject
        Objects containing commands to process. These can be piped into the function.

    .PARAMETER SystemRole
        A description of the chatbot's system role. If not provided, a default role based on the specified module will be used.

    .PARAMETER RoundOneInstructions
        The instructions for the first round of processing. If not provided, default instructions will be used.

    .PARAMETER RoundTwoInstructions
        The instructions for the second round of processing. If not provided, default instructions will be used.

    .PARAMETER Module
        The name of a module from which to retrieve commands. If specified, the module will be imported if not already present.

    .PARAMETER As
        This parameter is currently not used in the function.

    .EXAMPLE
        PS C:\> Get-Command -Module Microsoft.PowerShell.Management | ConvertTo-FineTuning

        Retrieves commands from the specified module and converts their help text into fine-tuning data.

    .EXAMPLE
        PS C:\> ConvertTo-FineTuning -Module Microsoft.PowerShell.Management

        Imports the specified module, retrieves its commands, and converts their help text into fine-tuning data.

    .EXAMPLE
        PS C:\> $commands = Get-Command -Module Microsoft.PowerShell.Management
        PS C:\> ConvertTo-FineTuning -InputObject $commands

        Uses a variable containing commands from the specified module and converts their help text into fine-tuning data.
#>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [psobject[]]$InputObject,
        [string]$SystemRole,
        [string]$RoundOneInstructions,
        [string]$RoundTwoInstructions,
        [string]$Module,
        [string]$As
    )
    process {
        if (-not $InputObject -and -not $Module) {
            Write-Error "You must provide either provide InputObject or Module"
            return
        }

        if ($Module) {
            Import-Module $Module -ErrorAction Stop
            $InputObject = Get-Command -Module $Module | Where-Object CommandType -ne Alias | Get-CleanHelp
        }

        if ($InputObject.ModuleName) {
            $Module = $InputObject.ModuleName
        }

        if (-not $SystemRole) {
            if ($Module) {
                $SystemRole = "You are a friendly support chatbot and PowerShell expert who helps people find the commands and write the code they need for the $Module module"
            } else {
                $SystemRole = "You are a friendly support chatbot and PowerShell expert who helps people find the commands and write the code they need"
            }
        }
        if (-not $RoundOneInstructions) {
            $RoundOneInstructions = (Get-Content -Path "$script:PSModuleRoot\instructions1.txt" -Raw).Replace('--replaceme--', $SystemRole)
        }
        if (-not $RoundTwoInstructions) {
            $RoundTwoInstructions = (Get-Content -Path "$script:PSModuleRoot\instructions2.txt" -Raw).Replace('--replaceme--', $SystemRole)
        }

        foreach ($object in $InputObject) {

            if ($object.Text) {
                $msg = $object.Text
                $cmdname = $object.Command
            } else {
                $msg = $object
            }

            $body = @{
                max_tokens = 3000
                messages   = @(
                    @{
                        "role"    = "system"
                        "content" = $RoundOneInstructions
                    },
                    @{
                        "role"    = "user"
                        "content" = "$msg"
                    }
                )
            } | ConvertTo-Json -Compress -Depth 10

            $splat = @{
                Uri         = $env:azureaiurl
                Method      = "POST"
                Headers     = @{
                    "Content-Type" = "application/json"
                    "api-key"      = $env:copAIkey
                }
                ErrorAction = 'Stop'
            }

            try {
                $results = Invoke-RestMethod @splat -Body $body
            } catch {
                Start-Sleep -Seconds 60
                try {
                    $results = Invoke-RestMethod @splat -Body $body
                } catch {
                    Write-Warning "Failed to process the following: $Message"
                    continue
                }
            }

            $inputTokens = $results.usage.prompt_tokens
            $outputTokens = $results.usage.completion_tokens

            Write-Verbose "Prompt tokens: $($results.usage.prompt_tokens)"
            Write-Verbose "Completion: $($results.usage.completion_tokens)"
            Write-Debug "First result: $($results.choices.message.content)"

            $body = @{
                max_tokens = 3000
                messages   = @(
                    @{
                        "role"    = "system"
                        "content" = $RoundTwoInstructions
                    },
                    @{
                        "role"    = "user"
                        "content" = "$script:result1".Replace('```jsonl', '').Replace('```', '')
                    }
                )
            } | ConvertTo-Json -Compress -Depth 10


            try {
                $results = Invoke-RestMethod @splat -Body $body
            } catch {
                Start-Sleep -Seconds 60
                try {
                    $results = Invoke-RestMethod @splat -Body $body
                } catch {
                    Write-Warning "Failed to process the following: $Message"
                    continue
                }
            }

            Write-Verbose "Prompt tokens: $($results.usage.prompt_tokens)"
            Write-Verbose "Completion: $($results.usage.completion_tokens)"

            $inputtokencost = "0.01"
            $outputtokencost = "0.03"

            $allinputtokencost = (($inputTokens + $results.usage.prompt_tokens) / 1000) * $inputtokencost
            $alloutputtokencost = (($outputTokens + $results.usage.completion_tokens) / 1000) * $outputtokencost

            Write-Verbose "Input token cost: $allinputtokencost"
            Write-Verbose "Output token cost: $alloutputtokencost"

            $script:result2 = $results.choices.message.content
            $script:result2 = Repair-Json -Json $script:result2

            if ($As -eq "String") {
                $script:result2
            } else {
                [PSCustomObject]@{
                    Command = $cmdname
                    Text    = $script:result2
                }
            }

            Write-Debug "Second result: $script:result2"

            $commandcost = $allinputtokencost + $alloutputtokencost
            $script:totalcost = $script:totalcost + $commandcost
            Write-Verbose "Command token cost: $commandcost"
            Write-Verbose "Grand total token cost: $script:totalcost"

        }
    }
}