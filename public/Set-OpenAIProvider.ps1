function Set-OpenAIProvider {
    <#
    .SYNOPSIS
    Sets the OpenAI provider configuration.

    .DESCRIPTION
    The Set-OpenAIProvider function sets the OpenAI provider configuration and optionally persists it to a configuration file.

    .PARAMETER ApiKey
    The API key for the OpenAI provider.

    .PARAMETER ApiBase
    The base URL for the Azure OpenAI resource.

    .PARAMETER Deployment
    The deployment name for the Azure OpenAI resource.

    .PARAMETER ApiType
    The provider type (either "OpenAI" or "Azure").

    .PARAMETER ApiVersion
    The API version for the Azure OpenAI resource.

    .PARAMETER AuthType
    The authentication type (either "openai" or "azure").

    .PARAMETER Organization
    The organization associated with the OpenAI provider.

    .PARAMETER NoPersist
    A switch parameter that determines whether to skip persisting the configuration to a file.

    .EXAMPLE
    $config = @{
        ApiKey = "your-api-key"
        ApiBase = "https://your-resource-name.openai.azure.com"
        Deployment = "your-deployment-name"
        ApiType = "Azure"
        ApiVersion = "2024-05-01-preview"
        AuthType = "azure"
    }
    Set-OpenAIProvider @config

    This example sets the OpenAI provider configuration for Azure and persists it.

    .EXAMPLE
    Set-OpenAIProvider -ApiKey "your-api-key" -Provider "OpenAI"

    This example sets the OpenAI provider configuration for OpenAI and persists it.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$ApiKey,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$ApiBase,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Deployment,
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateSet("OpenAI", "Azure")]
        [string]$ApiType,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$ApiVersion = "2024-05-01-preview",
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateSet("openai", "azure", "azure_ad")]
        [string]$AuthType,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Organization,
        [switch]$NoPersist
    )
    process {
        if (-not $AuthType) {
            $AuthType = if ($ApiType -eq 'Azure') { 'Azure' } else { 'OpenAI' }
        }

        Set-Variable -Scope 1 -Name PSDefaultParameterValues -Force -ErrorAction SilentlyContinue -Value @{
            '*:ApiKey'       = $ApiKey
            '*:ApiBase'      = $ApiBase
            '*:ApiVersion'   = $ApiVersion
            '*:AuthType'     = $AuthType
            '*:ApiType'      = $ApiType
            '*:Organization' = $Organization
        }

        if (-not $NoPersist) {
            $configFile = Join-Path -Path $script:configdir -ChildPath "config.json"
            try {
                [pscustomobject]@{
                    ApiKey       = $ApiKey
                    ApiBase      = $ApiBase
                    Deployment   = $Deployment
                    ApiType      = $ApiType
                    ApiVersion   = $ApiVersion
                    AuthType     = $AuthType
                    Organization = $Organization
                } | ConvertTo-Json | Set-Content -Path $configFile -Force
                Write-Verbose "OpenAI provider configuration persisted."
            } catch {
                Write-Error "Error persisting configuration file: $_"
            }
        }
        Get-OpenAIProvider
    }
}