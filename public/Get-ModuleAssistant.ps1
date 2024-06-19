function Get-ModuleAssistant {
    <#
    .SYNOPSIS
        Retrieves module assistants based on metadata.

    .DESCRIPTION
        This function retrieves assistants that have been tagged with the metadata "PSHelp.Copilot".
        It uses the Get-Assistant command from the PSOpenAI module to retrieve the assistants.

    .PARAMETER Name
        The name of the assistant to retrieve. Supports wildcards.

    .PARAMETER Metadata
        The metadata tag to filter assistants. Defaults to "PSHelp.Copilot".

    .EXAMPLE
        Get-ModuleAssistant

        Retrieves all assistants tagged with "PSHelp.Copilot". This tag is added when New-ModuleAssistant is used.

    .EXAMPLE
        Get-ModuleAssistant -Name "dbatools*"

        Retrieves all assistants with names starting with "dbatools" tagged with "PSHelp.Copilot".
    #>
    [CmdletBinding()]
    param (
        [string]$Name = "*",
        [string]$Metadata = "PSHelp.Copilot"
    )
    process {
        Get-Assistant -All | Where-Object {
            $PSItem.Name -like $Name -and $PSItem.Metadata.tag -eq $Metadata
        }
    }
}