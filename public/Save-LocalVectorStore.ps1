function Save-LocalVectorStore {
    <#
    .SYNOPSIS
        Saves the local vector store for specified modules.

    .DESCRIPTION
        This function saves the local vector store for the provided modules. It generates JSON files containing
        command information and embeddings for each command in the specified modules. The function can also
        force the creation of new files, overwriting existing ones if necessary.

    .PARAMETER Module
        The module(s) for which the local vector store is saved. Accepts an array of PSObject,
        which can include module names.

    .PARAMETER Path
        The path where the local vector store will be saved. Defaults to the configuration directory.

    .PARAMETER Force
        A switch to force the creation of new files, overwriting existing ones if they already exist.

    .EXAMPLE
        PS C:\> Save-LocalVectorStore -Module dbatools -Path C:\VectorStore

        Saves the local vector store for the dbatools PowerShell module in the specified path.

    .EXAMPLE
        PS C:\> Save-LocalVectorStore -Module PSOpenAI

        Saves the local vector store for the PSOpenAI PowerShell module in the default configuration directory.

    .EXAMPLE
        PS C:\> Save-LocalVectorStore -Module dbatools -Force

        Forces the creation of new vector store files for the dbatools PowerShell module, overwriting any existing files.

    .EXAMPLE
        PS C:\> $splat = @{
            Module = "PSOpenAI"
            Path   = "D:\CustomPath"
            Force  = $true
        }
        PS C:\> Save-LocalVectorStore @splat

        Saves the local vector store for the PSOpenAI PowerShell module in the specified custom path,
        forcing the creation of new files.
#>
    param (
        [Parameter(ValueFromPipeline, Mandatory)]
        [psobject[]]$Module,
        [string]$Path = $script:configdir,
        [switch]$Force
    )
    process {
        foreach ($object in $Module) {
            if ($object.Name) {
                $moduleName = $object.Name
                $moduleVersion = $object.Version.ToString()
            } elseif ($object.ModuleName) {
                $moduleName = $object.ModuleName
                $moduleVersion = $object.Version.ToString()
            } else {
                $moduleName = $object
                $moduleVersion = (Get-Module -Name $moduleName).Version.ToString()
            }
            if (-not (Get-Module $moduleName)) {
                $null = Import-Module $moduleName -ErrorAction SilentlyContinue
            }
            # create a directory for module
            $ModuleDir = Join-Path -Path $Path -ChildPath "$moduleName\$moduleVersion"
            if (-not (Test-Path -Path $ModuleDir)) {
                $null = New-Item -Path $ModuleDir -ItemType Directory -Force
            }

            $commands = Get-Command -Module $moduleName | Where-Object CommandType -ne Alias

            foreach ($command in $commands) {
                $commandfile = Join-Path -Path $ModuleDir -ChildPath "$($command.Name).json"
                if (-not (Test-Path -Path $commandfile) -or $Force) {
                    Write-Verbose "Creating local vector store file: $commandfile"
                    $helpContent = Get-Help $command.Name -Full | Get-CleanHelp
                    if (-not $helpContent) {
                        Write-Verbose "No help content found for command: $($command.Name)"
                        continue
                    }
                    $embedding = $helpContent | ConvertTo-Embedding
                    [PSCustomObject]@{
                        Command   = $command.Name
                        Text      = $helpContent.Text
                        Embedding = $embedding.Embedding
                    } | ConvertTo-Json -Depth 3 | Out-File -FilePath $commandfile -Encoding utf8
                    Get-ChildItem -Path $commandfile
                }
            }
        }
    }
}