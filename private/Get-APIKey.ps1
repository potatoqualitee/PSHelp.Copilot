using namespace System.Runtime.InteropServices

function Get-MaskedString {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [int]$First,

        [Parameter(Mandatory = $true)]
        [int]$Last,

        [Parameter(Mandatory = $true)]
        [int]$MaxNumberOfAsterisks
    )

    if ($Source.Length -le ($First + $Last)) {
        return $Source
    }

    $numberOfAsterisks = $Source.Length - $First - $Last
    if ($numberOfAsterisks -gt $MaxNumberOfAsterisks) {
        $numberOfAsterisks = $MaxNumberOfAsterisks
    }

    $maskedString = $Source.Substring(0, $First) + ('*' * $numberOfAsterisks) + $Source.Substring($Source.Length - $Last, $Last)
    return $maskedString
}


function DecryptSecureString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [securestring]$SecureString
    )
    try {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        $PlainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        $PlainToken
    } catch {
        Write-Error -Exception $_.Exception
    } finally {
        $bstr = $PlainToken = $null
    }
}

# this is a modified function that surfaces the API key that PSOpenAI will use
function Get-APIKey {
    [CmdletBinding()]
    [OutputType([securestring])]
    Param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [System.Management.Automation.PSObjectPropertyDescriptor]$ApiKey
    )

    # Search API key below priorities.

    if ($PSDefaultParameterValues.ApiKey) {
        $key = [string]$PSDefaultParameterValues.ApiKey
        Write-Verbose -Message 'API Key found in $PSDefaultParameterValues'
    }
    #   2. Global variable "OPENAI_API_KEY"
    elseif ($null -ne $global:OPENAI_API_KEY -and $global:OPENAI_API_KEY -is [string]) {
        $key = [string]$global:OPENAI_API_KEY
        Write-Verbose -Message 'API Key found in global variable "OPENAI_API_KEY".'
    }
    #   3. Environment variable "OPENAI_API_KEY"
    elseif ($null -ne $env:OPENAI_API_KEY -and $env:OPENAI_API_KEY -is [string]) {
        $key = [string]$env:OPENAI_API_KEY
        Write-Verbose -Message 'API Key found in environment variable "OPENAI_API_KEY".'
    }

    if ($key -is [securestring]) {
        $key = DecryptSecureString $key
    }

    if ($key) {
        if ($key.StartsWith('sk-', [StringComparison]::Ordinal)) {
            $first = 6
        }else {
            $first = 3
        }
        Get-MaskedString -Source $key -First $first -Last 2 -MaxNumberOfAsterisks 45
    } else {
        $null
    }
}
