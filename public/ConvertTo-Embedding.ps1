function ConvertTo-Embedding {
    <#
    .SYNOPSIS
        Converts command help text into embeddings using an external embedding service.

    .DESCRIPTION
        The ConvertTo-Embedding function processes commands to generate embeddings from their help text. It can take input directly from a pipeline of objects or specify a module to retrieve commands from. The function uses Get-CleanHelp to fetch cleaned help text and Request-Embeddings to convert this text into embeddings.

    .PARAMETER InputObject
        Objects containing commands to process. These can be piped into the function.

    .PARAMETER Module
        The name of a module from which to retrieve commands. If specified, the module will be imported if not already present.

    .PARAMETER As
        This parameter is currently not used in the function.

    .EXAMPLE
        PS C:\> Get-Command -Module Microsoft.PowerShell.Management | ConvertTo-Embedding

        Retrieves commands from the specified module and converts their help text into embeddings.

    .EXAMPLE
        PS C:\> ConvertTo-Embedding -Module Microsoft.PowerShell.Management

        Imports the specified module, retrieves its commands, and converts their help text into embeddings.

    .EXAMPLE
        PS C:\> $commands = Get-Command -Module Microsoft.PowerShell.Management
        PS C:\> ConvertTo-Embedding -InputObject $commands

        Uses a variable containing commands from the specified module and converts their help text into embeddings.
#>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [psobject[]]$InputObject,
        [string]$Module,
        [string]$As
    )
    begin {
        if ($Module) {
            if (-not (Get-Module $Module)) {
                $null = Import-Module $Module -ErrorAction Stop
                $InputObject = Get-Command -Module $Module | Where-Object CommandType -ne Alias
            }
        }
    }
    process {
        if (-not $InputObject -and -not $Module) {
            Write-Error "You must provide either provide InputObject or Module"
            return
        }

        if ($InputObject.ModuleName) {
            $Module = $InputObject.ModuleName
        }

        foreach ($object in $InputObject) {
            if ($object.Command) {
                $cmdname = $object.Command
            } elseif ($object.Name) {
                $cmdname = $object.Name
            } else {
                $cmdname = "$object"
            }
            Write-Verbose "Processing: $cmdname"

            try {
                Write-Verbose "Running Get-CleanHelp for $cmdname and converting to embedding..."
                $help = Get-CleanHelp -Command $cmdname
                $emb = (Request-Embeddings -Text $help.Text -Model text-embedding-3-small).data.embedding

            } catch {
                Write-Verbose "Failure: $PSItem"
                Write-Verbose "Pausing for (presumably) the API quota then running Get-CleanHelp for $cmdname and converting to embedding..."
                Start-Sleep -Seconds 60
                try {
                    $help = Get-CleanHelp -Command $cmdname
                    $emb = (Request-Embeddings -Text $help.Text -Model text-embedding-3-small).data.embedding
                } catch {
                    Write-Warning "Failed to process the following: $cmdname"
                    continue
                }
            }
            [PSCustomObject]@{
                Command   = $cmdname
                Embedding = $emb
                CleanHelp = $cleanhelp
            }
        }
    }
}