function Get-OpenAIProvider {
    <#
    .SYNOPSIS
        Retrieves the current OpenAI provider configuration.

    .DESCRIPTION
        The Get-OpenAIProvider function retrieves the current OpenAI provider configuration.

        It retrieves the configuration from the persisted configuration file if the -Persisted switch is used.

    .PARAMETER Persisted
        A switch parameter that determines whether to retrieve only the persisted configuration. By default, the function retrieves the session configuration.

    .EXAMPLE
        Get-OpenAIProvider

        This example retrieves the current session's OpenAI provider configuration.

    .EXAMPLE
        Get-OpenAIProvider -Persisted

        This example retrieves the persisted OpenAI provider configuration.
    #>
    [CmdletBinding()]
    param(
        [switch]$Persisted
    )

    $configFile = Join-Path -Path $script:configdir -ChildPath "config.json"

    if ($Persisted) {
        if (Test-Path -Path $configFile) {
            Get-Content -Path $configFile -Raw | ConvertFrom-Json
        } else {
            Write-Warning "No persisted configuration found."
        }
    } else {
        if ($PSDefaultParameterValues["*:ApiBase"]) {
            if ($PSDefaultParameterValues["*:ApiKey"]) {
                $maskedkey = Get-MaskedString -Source $PSDefaultParameterValues["*:ApiKey"] -First $first -Last 2 -MaxNumberOfAsterisks 45
            } else {
                $maskedkey = $null
            }

            [pscustomobject]@{
                ApiKey       = $maskedkey
                AuthType     = $PSDefaultParameterValues["*:AuthType"]
                ApiType      = $PSDefaultParameterValues["*:ApiType"]
                Deployment   = $PSDefaultParameterValues["*:Deployment"]
                ApiBase      = $PSDefaultParameterValues["*:ApiBase"]
                ApiVersion   = $PSDefaultParameterValues["*:ApiVersion"]
                Organization = $PSDefaultParameterValues["*:Organization"]
            }
        } else {
            $maskedkey = Get-ApiKey
            if ($maskedkey) {
                $auth = "openai"
            } else {
                $auth = $null
            }
            [pscustomobject]@{
                ApiKey       = $maskedkey
                AuthType     = $auth
                ApiType      = $auth
                Deployment   = $null
                ApiBase      = $null
                ApiVersion   = $null
                Organization = $null
            }
        }
    }
}