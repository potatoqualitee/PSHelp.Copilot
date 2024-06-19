function Split-ModuleHelp {
    <#
    .SYNOPSIS
        Splits module help content into multiple files for use with ChatGPT Custom GPTs.

    .DESCRIPTION
        The Split-ModuleHelp function retrieves clean help content for a specified module using Get-CleanHelp and combines it with files from an optional path.
        It then splits the content into a specified number of files (up to a maximum of 20, which is the limit for ChatGPT Custom GPTs) and exports them to an output directory.

    .PARAMETER Module
        The name of the module to retrieve help content from.

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
        PS C:\> Split-ModuleHelp -Module dbatools -IncludePath C:\AdditionalFiles -OutputPath C:\SplitFiles -FileCount 18

        Splits clean help content from the dbatools module, along with files from "C:\AdditionalFiles", into 18 files in the "C:\SplitFiles" directory.

    .EXAMPLE
        PS C:\> Split-ModuleHelp -Module PSOpenAI

        Splits clean help content from the PSOpenAI module into 20 files (default) in the current directory plus the module name.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Module,
        [string]$IncludePath,
        [string]$OutputPath,
        [ValidateRange(1, 20)]
        [int]$FileCount = 20,
        [scriptblock]$Filter,
        [int]$MaxFileSizeKB
    )

    try {
        # Import the module
        Import-Module $Module -ErrorAction Stop
    } catch {
        Write-Error "Failed to import module $Module`: $_"
        return
    }

    try {
        # Get clean help content
        $helpContent = Get-Command -Module $Module | Get-CleanHelp -As String
        if ($Filter) {
            $helpContent = $helpContent | Where-Object $Filter
        }
    } catch {
        Write-Error "Failed to retrieve help content for module $Module`: $_"
        return
    }

    # Collect additional files if IncludePath is specified
    $additionalFiles = @()
    if ($IncludePath -and (Test-Path -Path $IncludePath)) {
        try {
            $additionalFiles = Get-ChildItem -Path $IncludePath -File | ForEach-Object { Get-Content -Path $_.FullName -Raw }
        } catch {
            Write-Warning "Failed to retrieve files from path $IncludePath`: $_"
        }
    }

    # Combine help content and additional files
    $combinedContent = @($helpContent) + @($additionalFiles)

    # Calculate the number of items per file
    $itemsPerFile = [math]::Ceiling($combinedContent.Count / $FileCount)

    # Create the output directory if not specified
    if (-not $OutputPath) {
        $OutputPath = Join-Path -Path (Get-Location) -ChildPath $Module
    }
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

    # Initialize progress
    $progressActivity = "Splitting Help Content"
    $totalSteps = $FileCount

    # Split the combined content and export to files
    for ($i = 0; $i -lt $FileCount; $i++) {
        $percentComplete = [math]::Round(($i / $totalSteps) * 100)
        Write-Progress -Activity $progressActivity -Status "Processing file $($i + 1) of $FileCount" -PercentComplete $percentComplete

        $startIndex = $i * $itemsPerFile
        $endIndex = [math]::Min(($i + 1) * $itemsPerFile - 1, $combinedContent.Count - 1)
        $split = $combinedContent[$startIndex..$endIndex]

        # Check file size if MaxFileSizeKB is specified
        if ($MaxFileSizeKB) {
            $split = $split -join "`n"
            while ([System.Text.Encoding]::UTF8.GetByteCount($split) / 1KB -gt $MaxFileSizeKB) {
                $endIndex--
                $split = $combinedContent[$startIndex..$endIndex] -join "`n"
            }
        }

        $outputFile = Join-Path -Path $OutputPath -ChildPath "split-$($i + 1).txt"
        $split | Out-File -FilePath $outputFile -Encoding UTF8 -Force
    }

    Write-Progress -Activity $progressActivity -Completed
    Write-Verbose "Exported $FileCount split files to $OutputPath"
}
