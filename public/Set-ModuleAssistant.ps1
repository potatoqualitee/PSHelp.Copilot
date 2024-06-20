function Set-ModuleAssistant {
<#
    .SYNOPSIS
        Sets the default module assistant for a specified module or assistant name.

    .DESCRIPTION
        This function sets the default module assistant for a specified module or assistant name by setting the default parameter values for Invoke-HelpChat and askhelp functions. It checks if the specified assistant exists before setting the defaults.

    .PARAMETER Module
        The module for which the default assistant is set.

    .PARAMETER AssistantName
        The name of the assistant to be set as default. If not provided and the Module parameter is specified, the function tries to find an assistant with the naming convention "<ModuleName> Copilot".

    .EXAMPLE
        PS C:\> Set-ModuleAssistant -Module dbatools

        Sets the default assistant for the dbatools module, using the assistant named "dbatools Copilot" if available.

    .EXAMPLE
        PS C:\> Set-ModuleAssistant -AssistantName "PSOpenAI Assistant"

        Sets the default assistant to "PSOpenAI Assistant".
#>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [string]$Module,
        [string]$AssistantName
    )
    process {
        if (-not $Module -and -not $AssistantName) {
            throw "Module or AssistantName must be provided."
        }

        # If AssistantName is not provided, try to find the default assistant
        if (-not $AssistantName) {
            $AssistantName = "$Module Copilot"
        }

        # Check if the assistant exists
        $assistant = Get-ModuleAssistant -Name $AssistantName -WarningAction SilentlyContinue
        if (-not $assistant) {
            Write-Warning "Assistant '$AssistantName' not found. Default assistant not set."
            return
        }

        # Set the default parameter values for Invoke-HelpChat and askhelp
        $global:PSDefaultParameterValues['Invoke-HelpChat:Module'] = $Module
        $global:PSDefaultParameterValues['askhelp:Module'] = $Module

        Write-Output "Default assistant set to '$AssistantName'."
    }
}