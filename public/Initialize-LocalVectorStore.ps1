function Initialize-LocalVectorStore {
    <#
        .SYNOPSIS
            Initializes a local vector store for specified modules.

        .DESCRIPTION
            Initializes a local vector store by processing the given modules and storing their data in a specified path.
            If the vector store for a module does not exist, it creates a new one. The function handles JSON files
            associated with the modules, processes them, and saves them in the local vector store.

        .PARAMETER Module
            The modules to initialize in the local vector store. Accepts input from the pipeline.

        .PARAMETER Path
            The directory where the local vector store files are located. Defaults to the script's configuration directory.

        .EXAMPLE
            PS C:\> Initialize-LocalVectorStore -Module dbatools

            Initializes the local vector store for the module stored in dbatools using the default path.

        .EXAMPLE
            PS C:\> $modules = Get-MyModules
            PS C:\> $modules | Initialize-LocalVectorStore -Path C:\LocalVectorStore

            Initializes the local vector store for each module in the $modules array and saves the data in "C:\LocalVectorStore".
    #>
    param (
        [Parameter(ValueFromPipeline, Mandatory)]
        [psobject[]]$Module,
        [string]$Path = $script:configdir
    )
    process {
        foreach ($object in $Module) {
            if ($object.ModuleName) {
                $moduleName = $object.ModuleName
                $moduleVersion = $object.Version.ToString()
            } else {
                $moduleName = $object
                $moduleVersion = (Get-Module -Name $moduleName).Version.ToString()
            }

            $moduleDir = Join-Path -Path $Path -ChildPath "$moduleName\$moduleVersion"

            if (-not (Test-Path -Path $moduleDir)) {
                $null = New-Item -ItemType Directory -Path $moduleDir -Force
            }

            $commands = Get-Command -Module $moduleName
            foreach ($command in $commands) {
                $commandFile = Join-Path -Path $moduleDir -ChildPath "$($command.Name).json"
                if (-not (Test-Path -Path $commandFile)) {
                    Write-Verbose "Command file not found: $commandFile. Creating it..."
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
                    } | ConvertTo-Json -Depth 3 | Out-File -FilePath $commandFile -Encoding utf8
                }
            }
        }
    }
}