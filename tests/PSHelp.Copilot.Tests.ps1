Describe "PSHelp.Copilot Module" {
    BeforeAll {
        $modulePath = Join-Path -Parent ($PSScriptRoot | Split-Path) -Child PSHelp.Copilot.psd1
        Import-Module $modulePath
    }

    Context "New-ModuleAssistant" {
        It "Should create a new module assistant" {
            # Create a module assistant for a test module
            $assistantName = "TestModuleAssistant"
            New-ModuleAssistant -Module PSHelp.Copilot -AssistantName $assistantName

            # Check if the assistant was created successfully
            $assistant = Get-Assistant | Where-Object { $_.Name -eq $assistantName }
            $assistant | Should -Not -BeNullOrEmpty
        }
    }

    Context "Invoke-HelpChat" {
        BeforeAll {
            # Create a module assistant for a test module
            New-ModuleAssistant -Module PSHelp.Copilot
        }

        It "Should return a response from the module assistant" {
            # Set the default module for Invoke-HelpChat
            $PSDefaultParameterValues['Invoke-HelpChat:Module'] = 'PSHelp.Copilot'

            # Invoke a chat with the module assistant
            $response = Invoke-HelpChat "What does the Initialize-VectorStore do?"

            # Check if the response is not empty
            $response | Should -Not -BeNullOrEmpty

            # Invoke a chat with the module assistant
            $response = Invoke-HelpChat What does the Initialize-VectorStore do?

            # Check if the response is not empty
            $response | Should -Not -BeNullOrEmpty
        }
    }

    AfterAll {
        # Clean up the created module assistant
        Get-Assistant | Where-Object Name -match "TestModuleAssistant" | Remove-Assistant
        Get-Assistant | Where-Object Name -match "PSHelp.Copilot" | Remove-Assistant
    }
}