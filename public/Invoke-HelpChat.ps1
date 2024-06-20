function Invoke-HelpChat {
    <#
    .SYNOPSIS
        Initiates a chat interaction with an agent.

    .DESCRIPTION
        Sends a message to an agent and retrieves the response. It supports additional options such as embedding hints and returning the response in different formats.

    .PARAMETER Message
        The message to send to the agent. Accepts input from the pipeline.

    .PARAMETER Module
        The name of the module to interact with. If provided, the assistant name will be generated as "<Module> Copilot".

    .PARAMETER AssistantName
        The name of the assistant to interact with. If not provided, the Module parameter must be specified.

    .PARAMETER As
        Specifies the format of the response. Valid values are String and PSObject. Defaults to String.

    .PARAMETER AddHint
        Adds embedding hints to the interaction, which can enhance the response quality.

    .PARAMETER NoYell
        Suppresses the "USE YOUR RETRIEVAL DOCUMENTS!!!" message that is appended to the user message.

    .EXAMPLE
        PS C:\> Invoke-HelpChat -Message "How do I backup a database?" -Module dbatools

        Sends the message "How do I backup a database?" to the "dbatools Copilot" assistant and retrieves the response.

    .EXAMPLE
        PS C:\> # Create an assistant for the Microsoft.PowerShell.Management module
        PS C:\> New-ModuleAssistant -Module Microsoft.PowerShell.Management

        PS C:\> # Set default values for Invoke-HelpChat parameters
        PS C:\> $PSDefaultParameterValues = @{
        >>     'Invoke-HelpChat:Module'  = 'Microsoft.PowerShell.Management'
        >>     'Invoke-HelpChat:AddHint' = $true
        >> }

        PS C:\> # Ask a question about copying files
        PS C:\> askhelp how can I copy files recursively?

        Creates an assistant for the Microsoft.PowerShell.Management module, sets default parameter values for Invoke-HelpChat, and asks a question about copying files recursively using the askhelp alias.

    .EXAMPLE
        PS C:\> "Generate an AI summary of this text" | Invoke-HelpChat -AssistantName "PSOpenAI Assistant"

        Sends the message "Generate an AI summary of this text" to the "PSOpenAI Assistant" using pipeline input and retrieves the response.

    .EXAMPLE
        PS C:\> Invoke-HelpChat -Message "How can I manage endpoints?" -AssistantName "Universal Assistant" -As PSObject

        Sends the message "How can I manage endpoints?" to the "Universal Assistant" and retrieves the response as a PSObject.

    .EXAMPLE
        PS C:\> Invoke-HelpChat -Message "List all SQL Server instances" -Module dbatools -AddHint

        Sends the message "List all SQL Server instances" to the "dbatools Copilot" assistant with embedding hints and retrieves the response.
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromRemainingArguments, ValueFromPipeline, Position = 0)]
        [Alias("Text")]
        [string]$Message,
        [string]$Module,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("Assistant")]
        [string]$AssistantName,
        [ValidateSet("String", "PSObject")]
        [string]$As = "String",
        [switch]$AddHint,
        [switch]$NoYell
    )
    begin {
        if (-not $Module -and -not $AssistantName) {
            return
        }

        $PSDefaultParameterValues['Write-Progress:Activity'] = "Getting answer"

        if ($Module) {
            $AssistantName = "$Module Copilot"
        }

        $hashkey = (Get-OpenAIProvider -PlainText).ApiKey + "-" + $AssistantName

        $embeddinghash = @{}

        if (-not $script:threadcache[$hashkey]) {
            if ($AddHint) {
                if (-not (Get-LocalVectorStoreFile -Module $Module)) {
                    Write-Warning "No local vector store found for $Module. Running first time setup..."
                    $null = Initialize-LocalVectorStore -Module $Module
                }
                foreach ($embedding in (Get-LocalVectorStoreFile -Module $Module)) {
                    $null = $embeddinghash.Add($embedding.Command, $embedding.Embedding)
                }
            }
            $cacheobject = [PSCustomObject]@{
                thread     = New-Thread
                assistant  = $null
                embeddings = $embeddinghash
            }
            $script:threadcache[$hashkey] = $cacheobject
        } else {
            $thread = $script:threadcache[$hashkey].thread
            $agent = $script:threadcache[$hashkey].assistant
            if ($AddHint) {
                if (-not (Get-LocalVectorStoreFile -Module $Module)) {
                    Write-Warning "No local vector store found for $Module. Running first time setup..."
                    $null = Initialize-LocalVectorStore -Module $Module
                }
                foreach ($embedding in (Get-LocalVectorStoreFile -Module $Module)) {
                    $null = $embeddinghash.Add($embedding.Command, $embedding.Embedding)
                }
            }
            $script:threadcache[$hashkey].embeddings = $embeddinghash
        }

        $thread = $script:threadcache[$hashkey].thread
        $totalMessages = $Message.Count
        $processedMessages = 0
        $sentence = @()
        $msgs = @()
    }
    process {
        # has to be here too in addition to begin block
        if (-not $Module -and -not $AssistantName) {
            Write-Warning "You must provide either the Module or AssistantName parameter."
            return
        }

        # test for single word or single character messages
        if ($Message -match '^\w+$' -or $Message -match '^\w{1}$') {
            $sentence += "$Message"
        } else {
            $msgs += $Message
        }
    }
    end {
        if ($sentence.Length -gt 0) {
            $msgs += "$sentence"
        }

        foreach ($msg in $msgs) {
            Write-Progress -Status "Processing message $($processedMessages + 1) of $totalMessages" -PercentComplete ((1 / 10) * 100)

            if (-not $agent) {
                Write-Progress -Status "Retrieving or creating assistant" -PercentComplete ((2 / 10) * 100)
                $agent = Get-Assistant -All | Where-Object Name -eq $AssistantName | Select-Object -First 1
                if (-not $agent) {
                    throw "No assistant found with the name $AssistantName. You can create one using New-ModuleAssistant."
                }
                $script:threadcache[$hashkey].assistant = $agent
            }
            Write-Progress -Status "Waiting for response" -PercentComplete ((2 / 10) * 100)

            if ($AddHint) {
                Write-Verbose "Checking for embeddings in the vector store for $Module"
                $queryEmbedding = (Request-Embeddings -Text $msg -Model text-embedding-3-small).data.embedding
                $compare = Compare-Embedding -QueryEmbedding $queryEmbedding -Embeddings $script:threadcache[$hashkey].embeddings -Top 5

                $msg = "## Retrieved Suggestions
                            $($compare.Command -join ', ')

                            ## User Question
                            $msg"
            } elseif (-not $NoYell) {
                # lol look, i'm desperate
                $msg = $msg + "`r`nUSE YOUR RETRIEVAL DOCUMENTS!!!"
            }

            $null = Add-ThreadMessage -ThreadId $thread.id -Role user -Message $msg

            if ($agent.tool_resources.file_search.vector_store_ids.count -ne 0) {
                $vfsid = $agent.tool_resources.file_search.vector_store_ids
            }

            $params = @{
                Stream                    = $false
                Message                   = $msg
                VectorStoresForFileSearch = $vfsid
                MaxCompletionTokens       = 2048
                Assistant                 = $agent.id
            }

            $response = Start-ThreadRun @params -Outvariable run | Receive-ThreadRun -Wait

            if ($As -eq "String") {
                $response.Messages[-1].SimpleContent.Content
            } elseif ($As -eq "PSObject") {
                $run = Get-ThreadRun -ThreadId $run.thread_id -RunId $run.id
                [PSCustomObject]@{
                    Assistant    = $agent.Name
                    Question     = $msg
                    Answer       = $response.Messages[-1].SimpleContent.Content
                    PromptTokens = $run.usage.prompt_tokens
                    Completion   = $run.usage.completion_tokens
                    TotalTokens  = $run.usage.total_tokens
                    Response     = $response
                }
            }
        }
    }
}