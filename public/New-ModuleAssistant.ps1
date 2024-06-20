function New-ModuleAssistant {
    <#
.SYNOPSIS
    Creates a new module assistant with specified configurations.

.DESCRIPTION
    This function creates a new module assistant using the provided module details. It allows setting a custom assistant name, model type, vector store, instructions, and description. The function can also force the recreation of the assistant and associated vector store if needed.

    The command also sets the default Module parameter values for Invoke-HelpChat and askhelp to the provided module name.

.PARAMETER Module
    The module(s) for which the assistant is created. Accepts an array of PSObject, which can include module names.

.PARAMETER AssistantName
    The name of the assistant to be created.

    Default: "--MODULENAME-- Copilot" (--MODULENAME-- is replaced with the actual module name)

.PARAMETER Description
    A description for the assistant.

    Default: "Chatbot assistant for the <ModuleName> PowerShell module v<ModuleVersion>"

.PARAMETER Model
    The model type to be used for the assistant.

    Default:
    - OpenAI API: "gpt-4o"
    - Azure API: The deployment name

.PARAMETER Instructions
    Custom instructions for the assistant.

    Default: Reads from instructions.md in the module root directory

.PARAMETER AdditionalInstructions
    Additional instructions to be appended to the default instructions.

.PARAMETER VectorStore
    The name of the vector store to be used.

    Default: "<ModuleName> v<ModuleVersion>"

    Note: If the specified vector store does not exist, the function runs Initialize-VectorStore to create it.

.PARAMETER Force
    A switch to force the recreation of the assistant and the associated vector store if they already exist.

    Note: If used, the function removes any existing assistant with the same name before creating a new one.

.NOTES
    - The function waits up to 10 seconds for the vector store to be created before throwing an error if it cannot be found.

.EXAMPLE
    PS C:\> New-ModuleAssistant -Module dbatools -AssistantName "dbatools Copilot" -Model gpt-4o

    Creates a new assistant named "dbatools Copilot" for the dbatools PowerShell module using the gpt-4o model.

.EXAMPLE
    PS C:\> New-ModuleAssistant -Module dbatools -VectorStore CustomVectorStore

    Creates a new assistant for the dbatools PowerShell module using a custom vector store named CustomVectorStore.

.EXAMPLE
    PS C:\> New-ModuleAssistant -Module PSOpenAI -Instructions "Use these custom instructions."

    Creates a new assistant for the PSOpenAI PowerShell module with custom instructions provided directly in the parameter.

.EXAMPLE
    PS C:\> $splat = @{
        Module               = "PSOpenAI"
        AssistantName        = "PSOpenAI Assistant"
        Description          = "Custom description for the assistant."
        AdditionalInstructions = "Please provide more detailed explanations when responding to questions."
        Force                = $true
    }
    PS C:\> New-ModuleAssistant @splat

    Forces the recreation of the assistant named "PSOpenAI Assistant" for the PSOpenAI PowerShell module with a custom description and additional instructions.

.EXAMPLE
   PS C:\> $splat = @{
       Module                = "dbatools"
       AssistantName         = "dbatools helper"
       Description           = "Chatbot assistant for the dbatools PowerShell module."
       AdditionalInstructions = "The proper name is dbatools NOT DBATools. Your data was last updated on April 12, 2024. You use Splats when commands get too long and only use single quotes as parameter values when required."
       Force                 = $true
   }
   PS C:\> New-ModuleAssistant @splat

   Creates a new assistant named "dbatools helper" for the dbatools PowerShell module with a custom description and additional instructions, forcing the recreation of the assistant and the associated vector store if they already exist.
#>
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [psobject[]]$Module,
        [string]$AssistantName = "--MODULENAME-- Copilot",
        [string]$Description,
        [string]$Instructions,
        [string]$AdditionalInstructions,
        [string]$Model,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$VectorStore,
        [switch]$Force
    )
    process {
        if (-not $PSBoundParameters.Model) {
            $provider = Get-OpenAIProvider
            if ($provider.ApiType -ne "Azure") {
                $Model = "gpt-4o"
            } else {
                if (-not $provider.Deployment) {
                    throw "Model (deployment) is required for Azure API type. Use Set-OpenAIProvider to get going."
                }
                $Model = $provider.Deployment
            }
        }

        if ($Force) {
            $PSDefaultParameterValues['*:Force'] = $true
        }
        if ($Module.ModuleName) {
            $Module = $Module.ModuleName
        }

        foreach ($moduleName in $Module) {
            Write-Verbose "Creating assistant for module: $moduleName"
            $null = Import-Module $moduleName -Force -ErrorAction Stop
            $moduleversion = (Get-Module $moduleName | Select-Object -First 1).Version.ToString()
            $assistant = $AssistantName -replace '--MODULENAME--', $moduleName

            if ($Force) {
                $rmassistant = Get-ModuleAssistant -WarningAction SilentlyContinue | Where-Object Name -eq $assistant
                if ($rmassistant) {
                    Write-Warning "Removing existing assistant: $assistant"
                    $null = $rmassistant | Remove-ModuleAssistant -Confirm:$false
                }
            }
            if (-not $PSBoundParameters.VectorStore) {
                $VectorStore = $moduleName + " v" + $moduleversion
            }

            $vectorinfo = Get-VectorStore -All | Where-Object Name -eq $VectorStore

            # check if vector store exists
            if (-not $vectorinfo.id) {
                Write-Warning "Vector store not found: $VectorStore. Running Initialize-VectorStore..."
                $vectorinfo = $moduleName | Initialize-VectorStore
            }

            if ($script:nohelp) {
                Write-Warning "Something went wrong :/ It's probably a module without any help."
                continue
            }
            # if still no vectorinfo.id, loop until it is found or 10 seconds pass
            $count = 0
            while (-not $vectorinfo.id -and $count -lt 10) {
                Start-Sleep -Seconds 1
                $vectorinfo = Get-VectorStore -All | Where-Object Name -eq $VectorStore
                $count++
            }

            # if still no vectorinfo.id, throw an error
            if (-not $vectorinfo.id) {
                throw "Vector store could not be found or created: $VectorStore"
            }

            $splat = @{
                Name                      = $assistant
                Model                     = $Model
                UseFileSearch             = $true
                VectorStoresForFileSearch = $vectorinfo.Id
                Metadata                  = @{ tag = "PSHelp.Copilot" }
            }

            if ($PSBoundParameters.Instructions) {
                $splat['Instructions'] = $Instructions
            } else {
                $instructionsfile = Join-Path -Path $script:ModuleRoot -Childpath instructions.md
                $Instructions = Get-Content $instructionsfile -Raw
                $Instructions = $Instructions -replace '--MODULENAME--', $moduleName
                $Instructions = $Instructions -replace '--MODULEVERSION--', $moduleversion
                $Instructions = $Instructions -replace '--TODAYSDATE--', (Get-Date -Format "dd MMM yyyy")

                if ($AdditionalInstructions) {
                    $Instructions += "`n`n$AdditionalInstructions"
                }

                $splat['Instructions'] = $Instructions
            }

            if ($Description) {
                $splat['Description'] = $Description
            } else {
                $splat['Description'] = "Chatbot assistant for the $moduleName PowerShell module v$moduleVersion."
            }

            New-Assistant @splat

            Write-Verbose "Adding default Module parameter values for Invoke-HelpChat and askhelp"
            $global:PSDefaultParameterValues['Invoke-HelpChat:Module'] = $moduleName
            $global:PSDefaultParameterValues['askhelp:Module'] = $moduleName
        }
    }
}