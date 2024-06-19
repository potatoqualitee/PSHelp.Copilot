function Reset-OpenAIProvider {
    <#
    .SYNOPSIS
        Resets the OpenAI provider configuration.

    .DESCRIPTION
        The Reset-OpenAIProvider function resets the OpenAI provider configuration by removing the persisted configuration file and resetting the module-scoped configuration object.
        It removes the persisted configuration file, if it exists, and resets the PSDefaultParameterValues object to its default values.

    .EXAMPLE
        Reset-OpenAIProvider

        This example resets the OpenAI provider configuration.
    #>
    [CmdletBinding()]
    param ()

    <#
        Set-Variable -Scope 1 -Name PSDefaultParameterValues -Force -ErrorAction SilentlyContinue -Value @{
            '*:ApiKey'       = $null
            '*:ApiBase'      = $null
            '*:ApiVersion'   = $null
            '*:AuthType'     = 'openai'
            '*:ApiType'      = 'openai'
            '*:Organization' = $null
        }
    #>

    Remove-Variable -Scope 1 -Name PSDefaultParameterValues -ErrorAction SilentlyContinue

    $configFile = Join-Path -Path $script:configdir -ChildPath "config.json"

    if (Test-Path -Path $configFile) {
        Remove-Item -Path $configFile -Force
    }

    Write-Verbose "OpenAI provider configuration reset to default."
    Get-OpenAIProvider
}