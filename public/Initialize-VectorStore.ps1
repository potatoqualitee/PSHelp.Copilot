function Initialize-VectorStore {
    <#
        .SYNOPSIS
            Initializes a vector store for specified modules.

        .DESCRIPTION
            Initializes a vector store by processing the given modules and uploading their data to a specified vector store.
            The function checks if a local vector store file exists for the module. If it does, it uses the text from the local store file.
            If a local vector store file doesn't exist or if the -Force parameter is specified, it retrieves the help content using Get-CleanHelp
            and uploads it to the vector store in batches. The files are named based on the command name.

        .PARAMETER Module
            The modules to initialize in the vector store. Accepts input from the pipeline.

        .PARAMETER Force
            If specified, forces the recreation of the vector store even if a local vector store file exists.

        .EXAMPLE
            PS C:\> Initialize-VectorStore -Module dbatools

            Initializes the vector store for the module dbatools. If a local vector store file exists, it uses the text from there.

        .EXAMPLE
            PS C:\> $modules = Get-MyModules
            PS C:\> $modules | Initialize-VectorStore -Force

            Initializes the vector store for each module in the $modules array, forcing the recreation of the vector store.
    #>
    param (
        [Parameter(ValueFromPipeline, Mandatory)]
        [psobject[]]$Module,
        [switch]$Force
    )
    begin {
        $count = 0
        $MaxFiles = 10000
        $temp = [System.IO.Path]::GetTempPath()
    }
    process {
        foreach ($object in $Module) {
            if ($object.ModuleName) {
                $moduleName = $object.ModuleName
                $moduleVersion = $object.Version.ToString()
            } else {
                $moduleName = $object
                $moduleVersion = (Get-Module -Name $moduleName | Select-Object -First 1).Version.ToString()
            }

            $localVectorStoreFiles = Get-LocalVectorStoreFile -Module $moduleName -ErrorAction SilentlyContinue

            $storename = $moduleName + " v" + $moduleversion
            $vectorStore = Get-VectorStore -All | Where-Object Name -eq $storename

            if (-not $vectorStore) {
                Write-Verbose "Creating new vector store: $storename"
                $vectorStore = PSOpenAI\New-VectorStore -Name $storename
                Write-Verbose "Created new vector store: $storename"
            }

            while ($vectorstore.status -ne 'completed') {
                Start-Sleep -Seconds 1
                $vectorStore = Get-VectorStore -VectorStoreId $vectorStore.id
                Write-Verbose "Waiting for vector store to be ready...(file_counts are completed). Current status: $($vectorstore.status)"
            }

            if ($localVectorStoreFiles -and -not $Force) {
                $totalFiles = $localVectorStoreFiles.Count
                Write-Verbose "Using text from local vector store files: $totalFiles files found"
            } else {
                Write-Verbose "Retrieving help content using Get-CleanHelp"
                $commands = Get-Command -Module $moduleName
                $helpContents = foreach ($command in $commands) {
                    @{
                        CommandName = $command.Name
                        HelpContent = Get-Help $command.Name -Full | Get-CleanHelp
                    }
                }
                $totalFiles = $helpContents.Count
                Write-Verbose "Retrieved $totalFiles help contents"
            }

            $batches = [Math]::Ceiling($totalFiles / 100)

            for ($i = 0; $i -lt $batches -and $count -lt $MaxFiles; $i++) {
                $startIndex = $i * 100
                $endIndex = [Math]::Min(($i + 1) * 100 - 1, $totalFiles - 1)

                if ($localVectorStoreFiles -and -not $Force) {
                    $batch = $localVectorStoreFiles[$startIndex..$endIndex]
                    $batchobjects = $batch
                } else {
                    $batchobjects = $helpContents[$startIndex..$endIndex]
                }

                $commandfiles = @()

                $fileIndex = 0
                foreach ($object in $batchobjects) {
                    if ($localVectorStoreFiles -and -not $Force) {
                        $commandName = $object.Command
                        $text = $object.Text
                    } else {
                        $commandName = $object.CommandName
                        $text = $object.HelpContent.Text
                    }

                    if (-not $text) {
                        Write-Verbose "No help content found for command: $commandName"
                        continue
                    }

                    $commandfile = Join-Path -Path $temp -ChildPath "$commandName.txt"
                    Write-Verbose "Writing to temporary file: $commandfile"
                    $null = $text | Out-File -FilePath $commandfile -Encoding utf8
                    $null = $commandfiles += $commandfile

                    # Write-Progress for each file
                    $fileIndex++
                    Write-Progress -Activity "Processing Files" -Status "Processing file $fileIndex of $($batchobjects.Count) for batch $($i + 1) of $batches" -PercentComplete (($fileIndex / $batchobjects.Count) * 100)
                }

                Write-Verbose "Uploading $($commandfiles.Count) files"

                $uploads = Get-ChildItem $commandfiles | PSOpenAI\Add-OpenAIFile -Purpose "assistants"
                $filebatch = PSOpenAI\Start-VectorStoreFileBatch -VectorStore $vectorStore -FileId $uploads.id
                # Define the parameters for splatting
                $splats = @{
                    VectorStoreId = $vectorStore.id
                    BatchId       = $filebatch.id
                    ErrorAction   = 'SilentlyContinue'
                }

                # Check if $filebatch.id is not null or empty
                if ($filebatch.id) {
                    $null = PSOpenAI\Wait-VectorStoreFileBatch @splats
                }
                Write-Verbose "Uploaded batch $($i + 1) of $batches to vector store: $storename"

                $count += $batchobjects.Count

                # Write-Progress for each batch
                Write-Progress -Activity "Initializing Vector Store" -Status "Processing batch $($i + 1) of $batches for $storename" -PercentComplete (($i + 1) / $batches * 100)
            }

            [PSCustomObject]@{
                Id          = $vectorStore.id
                Module      = $moduleName
                Version     = $moduleVersion
                VectorStore = $vectorStore
            }
        }
    }
}