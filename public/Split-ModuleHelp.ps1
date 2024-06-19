function Split-ModuleHelp {
    <#
    .SYNOPSIS
        Splits module help content into multiple files for use with ChatGPT Custom GPTs.

    .DESCRIPTION
        The Split-ModuleHelp function retrieves clean help content for specified modules using Get-CleanHelp and combines it with files from an optional path.

        It then splits the content into a specified number of files (up to a maximum of 20, which is the limit for ChatGPT Custom GPTs) and exports them to an output directory.

        The function can process multiple modules and returns the list of output files and module files for each module.

        If the number of commands in the module plus the count of additional files is less than or equal to the specified FileCount, it outputs one file per command.

    .PARAMETER Module
        The name(s) of the module(s) to retrieve help content from. Accepts an array of strings or PSCustomObjects with a Name or ModuleName property.

    .PARAMETER IncludePath
        An optional path to include additional files for splitting.

    .PARAMETER OutputPath
        The directory where the split files will be saved. If not specified, it defaults to the current directory plus the module name.

    .PARAMETER FileCount
        The desired number of output files. Defaults to 20, with a maximum of 20.

    .PARAMETER Filter
        A script block to filter the help content before splitting.

    .PARAMETER MaxFileSizeKB
        Maximum size in KB for each split file to ensure manageability.

    .EXAMPLE
        PS C:\> Split-ModuleHelp -Module dbatools, PSOpenAI -IncludePath C:\AdditionalFiles -OutputPath C:\SplitFiles -FileCount 18

        Splits clean help content from the dbatools and PSOpenAI modules, along with files from "C:\AdditionalFiles", into 18 files each in the "C:\SplitFiles\dbatools" and "C:\SplitFiles\PSOpenAI" directories.

    .EXAMPLE
        PS C:\> Split-ModuleHelp -Module @{ModuleName = 'PSOpenAI'}, @{Name = 'dbatools'}

        Splits clean help content from the PSOpenAI and dbatools modules into 20 files (default) in the current directory plus the respective module names.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]$Module,
        [string]$IncludePath,
        [string]$OutputPath,
        [ValidateRange(1, 20)]
        [int]$FileCount = 20,
        [scriptblock]$Filter,
        [int]$MaxFileSizeKB
    )
    $PSDefaultParameterValues['Get-CleanHelp:NoProgress'] = $true

    foreach ($moduleName in $Module) {
        if ($moduleName -is [PSCustomObject]) {
            if ($moduleName.Name) {
                $moduleName = $moduleName.Name
            } elseif ($moduleName.ModuleName) {
                $moduleName = $moduleName.ModuleName
            }
        }

        try {
            # Import the module
            Import-Module $moduleName -ErrorAction Stop -Verbose:$false
        } catch {
            Write-Error "Failed to import module $moduleName - $PSItem"
            continue
        }

        # Get the commands in the module
        $commands = Get-Command -Module $moduleName -Type Cmdlet, Function

        # Collect additional files if IncludePath is specified
        $additionalFiles = @()
        if ($IncludePath -and (Test-Path -Path $IncludePath)) {
            try {
                $additionalFiles = Get-ChildItem -Path $IncludePath -File
            } catch {
                Write-Warning "Failed to retrieve files from path $IncludePath - $PSItem"
            }
        }

        # Calculate the total count of commands and additional files
        $totalCount = $commands.Count + $additionalFiles.Count

        # Create the output directory if not specified
        if (-not $OutputPath) {
            $OutputPath = Join-Path -Path (Get-Location) -ChildPath $moduleName
        }

        $null = New-Item -ItemType Directory -Path $OutputPath -Force

        # Replace placeholders in the instructions file
        $moduleVersion = (Get-Module $moduleName | Select-Object -First 1).Version.ToString()
        $instructionsFile = Join-Path -Path $script:ModuleRoot -ChildPath instructions.md
        $outfile = Join-Path -Path $OutputPath -ChildPath "instructions.txt"
        if (Test-Path -Path $instructionsFile) {
            $instructions = Get-Content -Path $instructionsFile -Raw
            $instructions = $instructions -replace '--MODULENAME--', $moduleName
            $instructions = $instructions -replace '--MODULEVERSION--', $moduleVersion
            $instructions = $instructions -replace '--TODAYSDATE--', (Get-Date -Format "dd MMM yyyy")
            $instructions | Out-File -FilePath $outfile -Encoding UTF8 -Force
            Get-ChildItem $outfile
        }

        # Initialize progress
        $progressActivity = "Splitting Help Content for $moduleName"
        $progressParams = @{
            Activity = $progressActivity
            Status = "Processing file 0 of $FileCount"
            PercentComplete = 0
        }
        Write-Progress @progressParams

        if ($totalCount -le $FileCount -or $moduleName -eq 'PSHelp.Copilot') {
            # Output one file per command if the total count is less than or equal to FileCount
            foreach ($command in $commands) {
                $outputFile = Join-Path -Path $OutputPath -ChildPath "$($command.Name).txt"
                try {
                    $helpContent = Get-CleanHelp -Command $command -As String
                    if (-not $helpContent) {
                        Write-Verbose "No help content found for command: $($command.Name)"
                        continue
                    }
                    if ($Filter) {
                        $helpContent = $helpContent | Where-Object $Filter
                    }
                    $helpContent | Out-File -FilePath $outputFile -Encoding UTF8 -Force
                    Get-ChildItem $outputFile
                    Write-Verbose "Processed command: $($command.Name)"
                } catch {
                    Write-Warning "Failed to retrieve help content for command $($command.Name) in module $moduleName - $PSItem"
                }

                # Update progress
                $progressParams.PercentComplete = (($commands.IndexOf($command) + 1) / $totalCount) * 100
                $progressParams.Status = "Processing file $($commands.IndexOf($command) + 1) of $totalCount"
                Write-Progress @progressParams
            }

            # Output additional files
            foreach ($file in $additionalFiles) {
                $outputFile = Join-Path -Path $OutputPath -ChildPath $file.Name
                try {
                    $content = Get-Content -Path $file.FullName -Raw
                    $content | Out-File -FilePath $outputFile -Encoding UTF8 -Force
                    Get-ChildItem $outputFile
                    Write-Verbose "Processed additional file: $($file.Name)"
                } catch {
                    Write-Warning "Failed to retrieve content from file $($file.FullName) - $PSItem"
                }

                # Update progress
                $progressParams.PercentComplete = (($commands.Count + $additionalFiles.IndexOf($file) + 1) / $totalCount) * 100
                $progressParams.Status = "Processing file $($commands.Count + $additionalFiles.IndexOf($file) + 1) of $totalCount"
                Write-Progress @progressParams
            }
        } else {
            # Calculate the number of items per file
            $itemsPerFile = [math]::Ceiling($totalCount / $FileCount)

            # Process commands and additional files in batches
            for ($i = 0; $i -lt $FileCount; $i++) {
                $startIndex = $i * $itemsPerFile
                $endIndex = [math]::Min(($i + 1) * $itemsPerFile - 1, $totalCount - 1)

                $outputFile = Join-Path -Path $OutputPath -ChildPath "$moduleName-$($i + 1).txt"

                # Get clean help content for the batch of commands
                $helpContent = $commands[$startIndex..$endIndex] | ForEach-Object {
                    try {
                        Get-CleanHelp -Command $PSItem -As String
                    } catch {
                        Write-Warning "Failed to retrieve help content for command $($PSItem.Name) in module $moduleName - $PSItem"
                        return
                    }
                }

                if ($Filter) {
                    $helpContent = $helpContent | Where-Object $Filter
                }

                # Get content from the batch of additional files
                $additionalContent = $additionalFiles[$startIndex..$endIndex] | ForEach-Object {
                    try {
                        Get-Content -Path $PSItem.FullName -Raw
                    } catch {
                        Write-Warning "Failed to retrieve content from file $($PSItem.FullName) - $PSItem"
                        return
                    }
                }

                # Combine help content and additional file content
                $combinedContent = @($helpContent) + @($additionalContent)

                # Check file size if MaxFileSizeKB is specified
                if ($MaxFileSizeKB) {
                    $combinedContent = $combinedContent -join "`n"
                    while ([System.Text.Encoding]::UTF8.GetByteCount($combinedContent) / 1KB -gt $MaxFileSizeKB) {
                        $combinedContent = $combinedContent.Substring(0, $combinedContent.LastIndexOf("`n"))
                    }
                }

                # Output the file to the pipeline
                $combinedContent | Out-File -FilePath $outputFile -Encoding UTF8 -Force
                Get-ChildItem $outputFile

                $batchCommands = $commands[$startIndex..$endIndex]
                $batchAdditionalFiles = $additionalFiles[$startIndex..$endIndex]
                $batchCount = $batchCommands.Count + $batchAdditionalFiles.Count
                $batchPercentage = [math]::Round(($batchCount / $totalCount) * 100)

                Write-Verbose "Processed batch $($i + 1) of $FileCount - Commands: $($batchCommands.Count), Additional Files: $($batchAdditionalFiles.Count), Total: $batchCount ($batchPercentage%)"

                # Update progress
                $progressParams.PercentComplete = (($i + 1) / $FileCount) * 100
                $progressParams.Status = "Processing file $($i + 1) of $FileCount"
                Write-Progress @progressParams
            }
        }

        # Complete progress
        $progressParams.Completed = $true
        Write-Progress @progressParams
    }
}