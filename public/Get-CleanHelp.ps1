function Get-CleanHelp {
    <#
    .SYNOPSIS
        Retrieves and processes help content for PowerShell commands.

    .DESCRIPTION
        The Get-CleanHelp function retrieves help content for specified PowerShell commands and processes it into a cleaner, more readable format. It supports importing help from a specified module and allows for the output to be formatted either as a string or as a PSObject.

    .PARAMETER Command
        One or more PowerShell commands to retrieve help for. Can be piped into the function.

    .PARAMETER Module
        The name of the module to import and retrieve commands from. If specified, the function will import the module and get all commands from it.

    .PARAMETER As
        Specifies the output format. Can be "PSObject" or "String". The default is "PSObject".

    .PARAMETER NoProgress
        Suppresses the progress bar.

    .EXAMPLE
        PS C:\> Get-CleanHelp -Command Get-Process

        Retrieves and processes help content for the Get-Process command.

    .EXAMPLE
        PS C:\> Get-Command -Module Microsoft.PowerShell.Management | Get-CleanHelp -As String

        Retrieves and processes help content for all commands in the Microsoft.PowerShell.Management module, outputting the result as a string.

    .EXAMPLE
        PS C:\> Get-CleanHelp -Module Microsoft.PowerShell.Management

        Imports the Microsoft.PowerShell.Management module and retrieves help content for all its commands.

#>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [psobject[]]$Command,
        [string]$Module,
        [ValidateSet("PSObject", "String")]
        [string]$As = "PSObject",
        [switch]$NoProgress
    )
    begin {
        $all = @()
        if ($NoProgress) {
            # shut it up
            function Write-Progress {}
        }
    }
    process {
        if ($Module) {
            Import-Module $Module -ErrorAction SilentlyContinue
            $Command = Get-Command -Module $Module | Where-Object CommandType -ne Alias
        }
        $all += $Command
    }
    end {
        $totalCommands = $all.Count
        $i = 0
        foreach ($cmd in $all) {
            if ($cmd.Name) {
                $cmd = $cmd.Name
            }

            $i++
            $percentComplete = ($i / $totalCommands) * 100
            Write-Verbose "$percentComplete percent complete"
            Write-Verbose "$i of $totalCommands total commands"

            # Display the progress
            if (-not $script:totalcost) {
                Write-Progress -Activity "Processing Commands" -Status "$cmd" -PercentComplete $percentComplete
            } else {
                $status = "$cmd ($i of $totalCommands) - cost so far: $" + [math]::Round($script:totalcost, 2)
                Write-Progress -Activity "Processing Commands" -Status $status -PercentComplete $percentComplete
            }

            # Retrieve help content
            $helpContent = Get-Help $cmd -Full

            if ((-not $helpContent.synopsis -or -not $helpContent.description.Text) -and -not $helpContent.examples.example.code) {
                Write-Verbose "No help content found for command: $cmd"
                continue
            }

            # Initialize the text collection
            $textCollection = @()
            $textCollection += "$cmd`: "

            # Add description if available
            if ($helpContent.description) {
                $description = ($helpContent.description.Text -replace '\r?\n', ' ' -replace '\s+', ' ').Trim()
                $description = $description -replace '\.', ''
                $textCollection += "$description "
            }

            # Process and add parameters if available
            if ($helpContent.parameters.parameter) {
                $parameters = $helpContent.parameters.parameter | ForEach-Object {
                    $paramDescription = ($_.description.Text -replace '\r?\n', ' ' -replace '\s+', ' ').Trim()
                    $paramDescription = $paramDescription -replace '\.', ''
                    "$($_.name) ($paramDescription)"
                }
                $textCollection += "Parameters: " + ($parameters -join ', ')
            }

            # Process and add one example if available
            if ($helpContent.examples.example) {
                $example = $helpContent.examples.example | Select-Object -First 1
                if ($example.remarks -match 'PS >') {
                    $example = $example.code + ' ' + (($example.remarks | Where-Object text -match 'PS >').text -replace 'PS >|\.', '')
                } else {
                    $example = $example.code
                }
                # clean it
                $example = $example -replace '\r?\n', ' ' -replace '\s+', ' '
                $textCollection += "Example: $example"
            }

            # Join all text into one single line
            $text = $textCollection -join ' '
            # Remove stuff the model doesn't need
            $text = Repair-Text -Text $text

            if ($As -eq "String") {
                $text
            } else {
                [PSCustomObject]@{
                    Command = $cmd
                    Text    = $text
                }
            }
        }
    }
}
