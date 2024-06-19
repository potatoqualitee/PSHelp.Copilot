function Export-TokenChunk {
    <#
    .SYNOPSIS
        Splits files into smaller chunks based on a token limit.

    .DESCRIPTION
        The Export-TokenChunk function reads files from a specified path and splits them into smaller chunks based on a specified token limit.
        It processes the files in chunks and exports the content to new files with specified prefixes.

    .PARAMETER Path
        The path to the files to be processed. Can be piped or provided directly.

    .PARAMETER TokenLimit
        The maximum number of tokens per chunk. Defaults to 8000.

    .PARAMETER OutputPath
        The directory where the chunk files will be saved. Defaults to the current directory.

    .PARAMETER OutputPrefix
        The prefix for the output chunk files. Defaults to "chunk-".

    .PARAMETER Recurse
        Switch to indicate if the command should process files in subdirectories recursively.

    .EXAMPLE
        PS C:\> Export-TokenChunk -Path "C:\Documents" -TokenLimit 5000 -OutputPath "C:\Chunks" -OutputPrefix "doc-"

        Processes files in "C:\Documents" and splits them into chunks of 5000 tokens each, saving the chunks in "C:\Chunks" with the prefix "doc-".

    .EXAMPLE
        PS C:\> Get-ChildItem -Path "C:\Logs" -File | Export-TokenChunk -TokenLimit 10000

        Processes all files in "C:\Logs" and splits them into chunks of 10000 tokens each, saving the chunks in the current directory.

    .EXAMPLE
        PS C:\> $splat = @{
                Path        = "C:\Data"
                TokenLimit  = 8000
                OutputPath  = "C:\Output"
                OutputPrefix= "data-chunk-"
                Recurse     = $true
            }
        PS C:\> Export-TokenChunk @splat

        Processes files in "C:\Data" and its subdirectories, splitting them into chunks of 8000 tokens each, saving the chunks in "C:\Output" with the prefix "data-chunk-".

#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject[]]$Path,
        [int]$TokenLimit = 8000,
        [string]$OutputPath = ".",
        [string]$OutputPrefix = "chunk-",
        [switch]$Recurse
    )
    begin {
        $files = New-Object System.Collections.ArrayList
    }
    process {
        if (-not $Path.FullName) {
            $Path = Get-ChildItem -Path $Path -File -Recurse:$Recurse
        }

        foreach ($file in $Path) {
            $null = $files.Add($file)
        }
    }
    end {
        $chunkNumber = 1
        $startIndex = 0
        $endIndex = 0

        $totalFiles = $files.Count
        $currentFile = 1

        while ($currentFile -le $totalFiles) {
            # progress bar
            Write-Progress -Activity "Exporting token chunks" -Status "Processing chunk $chunkNumber" -PercentComplete (($currentFile / $totalFiles) * 100)
            $tokenCount = 0
            $chunk = @()

            while ($tokenCount -lt $TokenLimit -and $currentFile -le $totalFiles) {
                $content = Get-Content $files[$currentFile - 1].FullName -Raw
                if ($content) {
                    $tokenInfo = Measure-TuneToken -InputObject $content
                    $tokenCount += $tokenInfo.TokenCount
                }
                $chunk += $files[$currentFile - 1]
                $currentFile++
            }

            $endIndex = $currentFile - 1
            $chunkFileName = Join-Path -Path $OutputPath -ChildPath "$OutputPrefix$($startIndex + 1)-$($endIndex).txt"
            $chunk | Get-Content | Set-Content $chunkFileName
            $startIndex = $endIndex
            $chunkNumber++
            Get-ChildItem $chunkFileName
        }
    }
}