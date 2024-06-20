function Get-OpenAIProvider {
    <#
    .SYNOPSIS
        Retrieves the current OpenAI provider configuration.

    .DESCRIPTION
        The Get-OpenAIProvider function retrieves the current OpenAI provider configuration.

        It retrieves the configuration from the persisted configuration file if the -Persisted switch is used.

    .PARAMETER Persisted
        A switch parameter that determines whether to retrieve only the persisted configuration. By default, the function retrieves the session configuration.

    .PARAMETER PlainText
        A switch parameter that determines whether to return the API key in plain text. By default, the function masks the API key.

    .EXAMPLE
        Get-OpenAIProvider

        This example retrieves the current session's OpenAI provider configuration.

    .EXAMPLE
        Get-OpenAIProvider -Persisted

        This example retrieves the persisted OpenAI provider configuration.
    #>
    [CmdletBinding()]
    param(
        [switch]$Persisted,
        [switch]$PlainText
    )

    $configFile = Join-Path -Path $script:configdir -ChildPath config.json

    if ($Persisted) {
        if (Test-Path -Path $configFile) {
            Get-Content -Path $configFile -Raw | ConvertFrom-Json
        } else {
            Write-Warning "No persisted configuration found."
        }
    } else {
        $context = Get-OpenAIContext
        if ($context.ApiBase) {
            if ($context.ApiKey) {
                $decryptedkey = Get-DecryptedString -SecureString $context.ApiKey
                if ($decryptedkey) {
                    $splat = @{
                        Source               = $decryptedkey
                        First                = $first
                        Last                 = 2
                        MaxNumberOfAsterisks = 45
                    }
                    $maskedkey = Get-MaskedString @splat
                } else {
                    $maskedkey = $null
                }
            }

            if ($PlainText) {
                $maskedkey = $decryptedkey
            }

            [pscustomobject]@{
                ApiKey       = $maskedkey
                AuthType     = $context.AuthType
                ApiType      = $context.ApiType
                Deployment   = $PSDefaultParameterValues['*:Deployment']
                ApiBase      = $context.ApiBase
                ApiVersion   = $context.ApiVersion
                Organization = $context.Organization
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