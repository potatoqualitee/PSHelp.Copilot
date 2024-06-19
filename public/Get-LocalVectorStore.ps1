function Get-LocalVectorStore {
    <#
    .SYNOPSIS
        Retrieves local vector store paths for specified modules.

    .DESCRIPTION
        This function retrieves the paths to local vector stores for specified modules or lists all available module paths in the specified directory.

        If modules are provided through the pipeline or as parameters, their paths are retrieved.

        If no modules are specified, all module paths in the given directory are listed.

    .PARAMETER Module
        Specifies the module(s) for which to retrieve the local vector store paths.

    .PARAMETER Path
        Specifies the directory path to search for the module directories.

        Defaults to the module's configuration directory.

    .EXAMPLE
        PS C:\> Get-LocalVectorStore -Module dbatools

        Retrieves the local vector store path for dbatools.

    .EXAMPLE
        PS C:\> Get-LocalVectorStore

        Lists all available local vector stores.
#>
    param (
        [Parameter(ValueFromPipeline)]
        [Alias("Assistant")]
        [psobject[]]$Module,
        [string]$Path = $script:configdir
    )
    process {
        if ($Module) {
            if ($Module.ModuleName) {
                $Module = $Module.ModuleName
            }
            foreach ($moduleName in $Module) {
                $ModuleDir = Join-Path -Path $Path -ChildPath $moduleName
                if (Test-Path -Path $ModuleDir) {
                    [pscustomobject]@{
                        Module  = $moduleName
                        Path    = $ModuleDir
                    }
                }
            }
        } else {
            if (Test-Path -Path $Path) {
                Get-ChildItem -Path $Path -Directory | ForEach-Object {
                    [pscustomobject]@{
                        Module = $PSItem.BaseName
                        Path   = $PSItem.FullName
                    }
                }
            }
        }
    }
}