function Set-ModuleAssistant {
    <#
    .SYNOPSIS
        Sets the default module assistant for a specified module.

    .DESCRIPTION
        This function sets the default module assistant for a specified module by setting the default parameter values for Invoke-HelpChat and askhelp functions. It checks if the specified module exists and if an assistant for that module is available before setting the defaults.

    .PARAMETER Module
        The module for which the default assistant is set.

    .PARAMETER AssistantName
        The name of the assistant to be set as default. If not provided, the function tries to find an assistant with the naming convention "<ModuleName> Copilot".

    .EXAMPLE
        PS C:\> Set-ModuleAssistant -Module dbatools

        Sets the default assistant for the dbatools module, using the assistant named "dbatools Copilot" if available.

    .EXAMPLE
        PS C:\> Set-ModuleAssistant -Module PSOpenAI -AssistantName "PSOpenAI Assistant"

        Sets the default assistant for the PSOpenAI module to "PSOpenAI Assistant".

    .NOTES
        - If the specified module is not found, the function throws an error.
        - If no assistant is found for the specified module, the function throws a warning and does not set the defaults.
        - The function sets the default Module parameter values for Invoke-HelpChat and askhelp functions.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Module,

        [string]$AssistantName
    )

    process {
        # Check if the module exists
        if (-not (Get-Module -Name $Module -ListAvailable)) {
            throw "Module '$Module' not found. Please specify a valid module name."
        }

        # If AssistantName is not provided, try to find the default assistant
        if (-not $AssistantName) {
            $AssistantName = "$Module Copilot"
        }

        # Check if the assistant exists
        $assistant = Get-ModuleAssistant -Name $AssistantName -WarningAction SilentlyContinue
        if (-not $assistant) {
            Write-Warning "Assistant '$AssistantName' not found for module '$Module'. Default assistant not set."
            return
        }

        # Set the default parameter values for Invoke-HelpChat and askhelp
        $global:PSDefaultParameterValues['Invoke-HelpChat:Module'] = $Module
        $global:PSDefaultParameterValues['askhelp:Module'] = $Module

        Write-Verbose "Default assistant for module '$Module' set to '$AssistantName'."
    }
}