function Set-OpenAIProvider {
    <#
    .SYNOPSIS
        Configures the OpenAI or Azure OpenAI service context for subsequent commands.

    .DESCRIPTION
        This command sets the necessary context for interacting with either the OpenAI or Azure OpenAI service.
        It sets the API key, API base, deployment, authentication type, and other parameters required for the service.

        The configuration can be persisted to a file for future use.

    .PARAMETER ApiKey
        The API key for accessing the OpenAI or Azure OpenAI service.

    .PARAMETER ApiBase
        The base URL for the API. Required for Azure OpenAI service.

    .PARAMETER Deployment
        The deployment or model name used for the Azure OpenAI service.

    .PARAMETER ApiType
        Specifies the type of API to be used. Valid values are 'OpenAI' and 'Azure'.

    .PARAMETER ApiVersion
        Specifies the version of the API to be used. Required for Azure OpenAI service.

    .PARAMETER AuthType
        Specifies the type of authentication to be used. Valid values are 'openai', 'azure', 'azure_ad'.

    .PARAMETER Organization
        The organization name for the OpenAI service.

    .PARAMETER NoPersist
        When specified, the configuration is not persisted to a file.

    .EXAMPLE
    $config = @{
        ApiKey = "your-api-key"
        ApiBase = "https://your-resource-name.openai.azure.com"
        Deployment = "your-deployment-name"
        ApiType = "Azure"
        ApiVersion = "2024-04-01-preview"
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
        [string]$ApiVersion,
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

        if (-not $ApiKey) {
            $ApiKey = Get-ApiKey -PlainText
        }
        $null = Clear-OpenAIProvider

        if ($ApiType -eq 'Azure') {
            # Set context for Azure
            $splat = @{
                ApiType  = 'Azure'
                AuthType = $AuthType
                ApiKey   = $ApiKey
                ApiBase  = $ApiBase
            }
            if ($Organization) {
                $splat.Organization = $Organization
            }
            if ($ApiVersion) {
                $splat.ApiVersion = $ApiVersion
            }
            if ($Deployment) {
                Set-Variable -Scope 1 -Name PSDefaultParameterValues -Force -ErrorAction SilentlyContinue -Value @{
                    '*:Deployment' = $Deployment
                    '*:Model'      = $Deployment
                }
            }
        } else {
            # Set context for OpenAI
            $splat = @{
                ApiType  = 'OpenAI'
                AuthType = 'OpenAI'
                ApiKey   = $ApiKey
            }
        }
        $null = Set-OpenAIContext @splat

        if (-not $NoPersist) {
            $configFile = Join-Path -Path $script:configdir -ChildPath config.json
            try {
                [pscustomobject]@{
                    ApiKey       = $ApiKey
                    AuthType     = $AuthType
                    ApiType      = $ApiType
                    Deployment   = $Deployment
                    ApiBase      = $ApiBase
                    ApiVersion   = $ApiVersion
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