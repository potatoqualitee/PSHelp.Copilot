# Configuring Providers for PSOpenAI

PSOpenAI is a powerful PowerShell module that allows you to interact with OpenAI's API and Azure OpenAI Service. This guide will walk you through the process of setting up and using PSOpenAI with both OpenAI and Azure OpenAI Service providers.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Setting Up OpenAI Provider](#setting-up-openai-provider)
3. [Setting Up Azure OpenAI Service Provider](#setting-up-azure-openai-service-provider)
4. [Using PSOpenAI with OpenAI](#using-psopenai-with-openai)
5. [Using PSOpenAI with Azure OpenAI Service](#using-psopenai-with-azure-openai-service)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)
8. [Additional Resources](#additional-resources)

## Prerequisites

Before you begin, ensure that you have the following:

- PowerShell 5.1 or later installed on your machine. You can download the latest version of PowerShell from the [official Microsoft website](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell).
- An OpenAI API key. If you don't have one, sign up for an account at [OpenAI](https://beta.openai.com/signup/) and generate an API key.
- An Azure subscription. If you don't have one, you can create a [free account](https://azure.microsoft.com/en-us/free/).

## Setting Up OpenAI Provider

To use PSOpenAI with OpenAI, you need to set your OpenAI API key. You can do this using the `Set-OpenAIProvider` command or by setting the `OPENAI_API_KEY` environment variable.

### Using Set-OpenAIProvider

1. Open a PowerShell console.
2. Run the following command, replacing `your-openai-api-key` with your actual OpenAI API key:

   ```powershell
   Set-OpenAIProvider -Provider OpenAI -ApiKey "your-openai-api-key"
   ```

### Using Environment Variable

1. Open a PowerShell console.
2. Run the following command, replacing `your-openai-api-key` with your actual OpenAI API key:

   ```powershell
   $env:OPENAI_API_KEY = "your-openai-api-key"
   ```

   Note that this method sets the environment variable for the current PowerShell session only. To persist the environment variable across sessions, you can set it using the System Properties dialog or by modifying your PowerShell profile.

## Setting Up Azure OpenAI Service Provider

To use PSOpenAI with Azure OpenAI Service, you need to set up an Azure OpenAI resource and obtain the API key, endpoint URL, and deployment name.

1. Follow the steps in the [Azure OpenAI Service documentation](https://docs.microsoft.com/en-us/azure/cognitive-services/openai/how-to/create-resource) to create an Azure OpenAI resource.
2. Once your resource is created, navigate to the "Keys and Endpoint" section in the Azure portal to find your API key and endpoint URL.
3. Note down the deployment name you used while creating the Azure OpenAI resource.

You can set the Azure OpenAI Service configuration using the `Set-OpenAIProvider` command or by setting the relevant environment variables.

### Using Set-OpenAIProvider

1. Open a PowerShell console.
2. Run the following command, replacing `your-azure-api-key`, `your-azure-endpoint`, and `your-deployment-name` with your actual values:

   ```powershell
   Set-OpenAIProvider -Provider Azure -ApiKey "your-azure-api-key" -ApiBase "your-azure-endpoint" -Deployment "your-deployment-name"
   ```

### Using Environment Variables

1. Open a PowerShell console.
2. Run the following commands, replacing `your-azure-api-key`, `your-azure-endpoint`, and `your-deployment-name` with your actual values:

   ```powershell
   $env:OPENAI_API_KEY = "your-azure-api-key"
   $env:OPENAI_API_BASE = "your-azure-endpoint"
   $env:OPENAI_API_TYPE = "azure"
   $env:OPENAI_API_VERSION = "2023-03-15-preview"
   $env:OPENAI_AZURE_DEPLOYMENT = "your-deployment-name"
   ```

   Note that these environment variables are set for the current PowerShell session only. To persist them across sessions, you can set them using the System Properties dialog or by modifying your PowerShell profile.

## Using PSOpenAI with OpenAI

Once you have set up the OpenAI provider, you can start using PSOpenAI to interact with OpenAI's API. Here are a few examples:

### Text Completion

To generate text completions using OpenAI's API, use the `Request-TextCompletion` command:

```powershell
$result = Request-TextCompletion -Prompt "Once upon a time"
Write-Output $result.Answer
```

This will generate a text completion based on the provided prompt and display the generated text.

### Chat Completion

To generate chat completions using OpenAI's API, use the `Request-ChatCompletion` command:

```powershell
$result = Request-ChatCompletion -Message "Hello, how are you?"
Write-Output $result.Answer
```

This will generate a chat completion based on the provided message and display the generated response.

For more examples and detailed usage instructions, refer to the [PSOpenAI README](https://github.com/mkht/PSOpenAI/blob/main/README.md) and the [OpenAI API documentation](https://beta.openai.com/docs/api-reference/).

## Using PSOpenAI with Azure OpenAI Service

Using PSOpenAI with Azure OpenAI Service is similar to using it with OpenAI, but you need to specify the deployment name when making API requests. Here are a few examples:

### Text Completion

To generate text completions using Azure OpenAI Service, use the `Request-TextCompletion` command with the `-Deployment` parameter:

```powershell
$result = Request-TextCompletion -Prompt "Once upon a time" -Deployment "your-deployment-name"
Write-Output $result.Answer
```

### Chat Completion

To generate chat completions using Azure OpenAI Service, use the `Request-ChatCompletion` command with the `-Deployment` parameter:

```powershell
$result = Request-ChatCompletion -Message "Hello, how are you?" -Deployment "your-deployment-name"
Write-Output $result.Answer
```

For more examples and detailed usage instructions, refer to the [PSOpenAI README](https://github.com/mkht/PSOpenAI/blob/main/README.md) and the [Azure OpenAI Service documentation](https://docs.microsoft.com/en-us/azure/cognitive-services/openai/).

## Best Practices

- Keep your API keys secure. Avoid storing them in plain text or sharing them with others.
- Use environment variables or secure storage mechanisms to store your API keys.
- Be mindful of the costs associated with using OpenAI's API and Azure OpenAI Service. Monitor your usage and set up alerts to avoid unexpected charges.
- Refer to the [OpenAI API usage guidelines](https://beta.openai.com/docs/usage-guidelines) and the [Azure OpenAI Service responsible AI guidelines](https://docs.microsoft.com/en-us/azure/cognitive-services/openai/concepts/responsible-ai) to ensure responsible and ethical use of the APIs.

## Troubleshooting

If you encounter issues while using PSOpenAI, consider the following troubleshooting steps:

- Verify that you have set the correct API key and endpoint URL for your provider.
- Check the PowerShell version you are using. PSOpenAI requires PowerShell 5.1 or later.
- Ensure that you have a stable internet connection.
- If you encounter rate limiting or quota exceeded errors, wait for a while before making further requests or consider upgrading your subscription.
- Consult the [PSOpenAI GitHub Issues](https://github.com/mkht/PSOpenAI/issues) page to see if someone has reported a similar issue and find possible solutions.

## Additional Resources

- [PSOpenAI GitHub Repository](https://github.com/mkht/PSOpenAI)
- [OpenAI API Documentation](https://beta.openai.com/docs/api-reference/)
- [Azure OpenAI Service Documentation](https://docs.microsoft.com/en-us/azure/cognitive-services/openai/)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)

I hope this guide helps you get started with using PSOpenAI with both OpenAI and Azure OpenAI Service providers. If you have any further questions or feedback, feel free to reach out to the PSOpenAI community on GitHub.