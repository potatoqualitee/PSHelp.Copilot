function Remove-ModuleAssistant {
    <#
    .SYNOPSIS
        Removes a module assistant.

    .DESCRIPTION
        This function removes a module assistant based on its unique ID, supporting piping and confirmation prompts.

        Removes associated vector stores and their files by default.

    .PARAMETER Id
        The unique ID(s) of the assistant(s) to remove.

    .PARAMETER KeepVectorStore
        A switch to keep the vector store associated with the assistant(s) when removing them.

    .EXAMPLE
        Get-ModuleAssistant | Out-GridView -Passthru | Remove-ModuleAssistant

        Removes the selected assistant from the grid view without confirmation.

    .EXAMPLE
        Remove-ModuleAssistant -Id asst_LDBDlXhNhXfWcTFIWCovjSee -Confirm

        Removes multiple assistants by their unique IDs with confirmation.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param (
        [Parameter(ValueFromPipelineByPropertyName, Mandatory)]
        [string[]]$Id,
        [switch]$KeepVectorStore
    )

    process {
        foreach ($assistantId in $Id) {
            if (-not $KeepVectorStore) {
                $current = Get-Assistant -AssistantId $assistantId
                foreach ($vid in $current.tool_resources.file_search.vector_store_ids) {
                    if ($PSCmdlet.ShouldProcess($vid, "Remove vector store files")) {
                        Get-VectorStoreFile -VectorStoreId $vid | Remove-OpenAIFile
                        Write-Verbose "Vector store files for ID '$vid' removed."
                    }

                    if ($PSCmdlet.ShouldProcess($vid, "Remove vector store")) {
                        $null = Remove-VectorStore -VectorStoreId $vid
                        Write-Verbose "Vector store with ID '$vid' removed."
                    }
                }
                if ($PSCmdlet.ShouldProcess($assistantId, "Remove assistant")) {
                    Remove-Assistant -AssistantId $assistantId
                    Write-Verbose "Assistant with ID '$assistantId' removed."
                    [pscustomobject]@{
                        AssistantId    = $assistantId
                        VectorStoreIds = $current.tool_resources.file_search.vector_store_ids
                        Removed        = $true
                    }
                }
            } else {
                if ($PSCmdlet.ShouldProcess($assistantId, "Remove assistant")) {
                    Remove-Assistant -AssistantId $assistantId
                    Write-Verbose "Assistant with ID '$assistantId' removed."

                    [pscustomobject]@{
                        AssistantId    = $assistantId
                        VectorStoreIds = $null
                        Removed        = $true
                    }
                }
            }
        }
    }
}