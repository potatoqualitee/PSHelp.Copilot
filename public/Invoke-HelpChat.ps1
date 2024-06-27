function Invoke-HelpChat {
    <#
    .SYNOPSIS
        Initiates a chat interaction with an AI assistant for PowerShell module help.

    .DESCRIPTION
        Invoke-HelpChat sends a message to an AI assistant specialized in a specific PowerShell module and retrieves the response. It supports various options such as embedding hints and returning the response in different formats. This function leverages OpenAI's language models to provide intelligent, context-aware help for PowerShell modules.

    .PARAMETER Message
        The message or question to send to the assistant. Accepts input from the pipeline and can be provided without quotes.

    .PARAMETER Module
        The name of the PowerShell module to get help for. If provided, the assistant name will be automatically generated as "<Module> Copilot".

    .PARAMETER AssistantName
        The specific name of the assistant to interact with. If not provided, the Module parameter must be specified.

    .PARAMETER As
        Specifies the format of the response. Valid values are 'String' and 'PSObject'. Defaults to 'String'.
        - String: Returns the assistant's response as a simple string.
        - PSObject: Returns a detailed object including the question, answer, and token usage information.

    .PARAMETER AddHint
        Adds embedding hints to the interaction, which can enhance the response quality by providing more context to the AI model.

    .PARAMETER NoYell
        Suppresses the "USE YOUR RETRIEVAL DOCUMENTS!!!" message that is normally appended to the user message.

    .EXAMPLE
        PS C:\> Set-ModuleAssistant -Module dbatools
        PS C:\> askhelp how do I backup a database?

        Sets dbatools as the default module and uses the askhelp alias to ask about database backups.

    .EXAMPLE
        PS C:\> Invoke-HelpChat "How can I copy files recursively?" -Module Microsoft.PowerShell.Management -As PSObject

        Asks about copying files recursively in the Microsoft.PowerShell.Management module and returns a detailed PSObject response.

    .EXAMPLE
        PS C:\> "Generate an AI summary of this text" | Invoke-HelpChat -AssistantName "PSOpenAI Assistant"

        Uses pipeline input to send a request to a specific assistant named "PSOpenAI Assistant".

    .EXAMPLE
        PS C:\> Invoke-HelpChat List all SQL Server instances -Module dbatools -AddHint

        Demonstrates using the function without quotes around the message and with the AddHint parameter for enhanced context.
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
        if ($script:threadcache[$hashkey].assistant.model) {
            Write-Verbose "Using model $($script:threadcache[$hashkey].assistant.model)"
            $PSDefaultParameterValues['*:Model'] = $script:threadcache[$hashkey].assistant.model
            $PSDefaultParameterValues['*:Deployment'] = $script:threadcache[$hashkey].assistant.model
        }
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
                $msg = $msg + "`r`nOutput in plain-text. Markdown is forbidden."
                # lol look, i'm desperate
                $msg = $msg + "`r`nUSE YOUR RETRIEVAL DOCUMENTS!!!"
            }

            $null = Add-ThreadMessage -ThreadId $thread.id -Role user -Message $msg

            if ($agent.tool_resources.file_search.vector_store_ids.count -ne 0) {
                $vfsid = $agent.tool_resources.file_search.vector_store_ids | Select-Object -First 1
            }

            $params = @{
                Stream                    = $false
                Message                   = $msg
                VectorStoresForFileSearch = ($vfsid | Select-Object -First 1)
                MaxCompletionTokens       = 2048
                Assistant                 = $agent.id
            }

            $response = Start-ThreadRun @params -Outvariable run | Receive-ThreadRun -Wait

            while ($msg -eq $response.Messages[-1].SimpleContent.Content) {
                # azure FAQ - up quota, pick module
                Write-Warning "Ran into an issue, retrying..."

                $response = Get-ThreadRun -ThreadId $thread.id
                if ($response.last_error.code -eq "rate_limit_exceeded") {
                    $sleep = $response.last_error.message -replace '\D'
                    Write-Warning "Rate limit exceeded, sleeping for $sleep seconds..."
                    Write-Warning "If using Azure, consider increasing your quota"
                    Start-Sleep -Seconds ($sleep + 1)
                } else {
                    # extract error and throw
                    throw $response.last_error.message
                }
            }
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
