function Get-LocalVectorStoreFile {
    <#
    .SYNOPSIS
        Retrieves local vector store data from specified modules or directories.

    .DESCRIPTION
        The Get-LocalVectorStoreFile function retrieves local vector store data stored in JSON files from specified modules or directories. It reads the JSON files and converts their content to PowerShell objects.

        The function handles versioned module directories (e.g., dbatools/2.1.3, dbatools/2.1.8) and selects the most recent version for each module.

    .PARAMETER Module
        One or more modules to retrieve vector store data from. Can be piped into the function. If specified, the function will look for a directory named after each module under the given Path.

    .PARAMETER Path
        The base directory where module directories are located. Defaults to the script's configuration directory.

    .EXAMPLE
        PS C:\> Get-LocalVectorStoreFile -Module dbatools

        Retrieves vector store data from the most recent version of the dbatools directory under the default configuration path.

    .EXAMPLE
        PS C:\> Get-LocalVectorStore -Module dbatools | Get-LocalVectorStoreFile

        Retrieves vector store data from the most recent version of the dbatools directory by piping the output of Get-LocalVectorStore.

#>
    param (
        [Parameter(ValueFromPipelineByPropertyName, Mandatory)]
        [Alias("Assistant")]
        [string[]]$Module,
        [string]$Path = $script:configdir
    )
    process {
        foreach ($moduleName in $Module) {
            $ModuleBaseDir = Join-Path -Path $Path -ChildPath $moduleName
            if (Test-Path -Path $ModuleBaseDir) {
                $ModuleVersionDirs = Get-ChildItem -Path $ModuleBaseDir -Directory
                if ($ModuleVersionDirs) {
                    $LatestModuleDir = $ModuleVersionDirs | Sort-Object -Property Name -Descending | Select-Object -First 1
                    $ModuleDir = Join-Path -Path $ModuleBaseDir -ChildPath $LatestModuleDir.Name
                    Get-ChildItem -Path $ModuleDir -Filter "*.json" | ForEach-Object {
                        $jsonData = Get-Content $_.FullName | ConvertFrom-Json
                        [pscustomobject]@{
                            Module    = $moduleName
                            Command   = $jsonData.Command
                            Embedding = $jsonData.Embedding
                            Text      = $jsonData.Text
                        }
                    }
                }
            }
        }
    }
}