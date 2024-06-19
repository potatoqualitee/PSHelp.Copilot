@{
    # Script module or binary module file associated with this manifest.
    RootModule           = 'PSHelp.Copilot.psm1'

    # Version number of this module.
    ModuleVersion        = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core', 'Desktop')

    # ID used to uniquely identify this module
    GUID                 = '7d465a04-cf1d-4b57-a4b1-7d00637889d9'

    # Author of this module
    Author               = 'Chrissy LeMaire'

    # Copyright statement for this module
    Copyright            = '(c) 2024. All rights reserved.'

    # Description of the functionality provided by this module
    Description          = 'Get AI-powered help for documented PowerShell modules.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion    = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules      = @('PSOpenAI')

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies   = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module
    ScriptsToProcess     = @()

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess       = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess     = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules        = @()

    # Functions to export from this module
    FunctionsToExport    = @(
        'ConvertTo-Embedding',
        'ConvertTo-FineTuning',
        'Get-CleanHelp',
        'Get-LocalVectorStore',
        'Get-LocalVectorStoreFile',
        'Get-ModuleAssistant',
        'Get-OpenAIProvider',
        'Initialize-LocalVectorStore',
        'Initialize-VectorStore',
        'Invoke-HelpChat',
        'New-ModuleAssistant',
        'Remove-ModuleAssistant',
        'Reset-OpenAIProvider',
        'Save-LocalVectorStore',
        'Set-OpenAIProvider',
        'Split-ModuleHelp'
    )

    # Cmdlets to export from this module
    CmdletsToExport      = @()

    # Variables to export from this module
    VariablesToExport    = @()

    # Aliases to export from this module
    AliasesToExport      = @('askhelp')

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @("openai", "chatgpt", "genai", "copilot", "potato")

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/potatoqualitee/PSHelp.Copilot/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/potatoqualitee/PSHelp.Copilot'

            # A URL to an icon representing this module.
            IconUri    = 'https://github.com/potatoqualitee/finetuna/assets/8278033/b6e12c36-afd2-46a1-8024-a9fd12c9b773'

        }
    }
}
