$script:PSModuleRoot = $script:ModuleRoot = $PSScriptRoot
$script:totalcost = 0.0
$script:threadcache = @{}

switch ($PSVersionTable.Platform) {
    "Unix" {
        $script:configdir = "$home/.config/PSHelp.Copilot"
        if (-not (Test-Path -Path $script:configdir)) {
            $null = New-Item -Path $script:configdir -ItemType Directory -Force
        }
    }
    default {
        $script:configdir = "$env:APPDATA\PSHelp.Copilot"
        if (-not (Test-Path -Path $script:configdir)) {
            $null = New-Item -Path $script:configdir -ItemType Directory -Force
        }
    }
}

function Import-ModuleFile {
    [CmdletBinding()]
    Param (
        [string]
        $Path
    )
    if ($doDotSource) { . $Path }
    else { $ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create([io.file]::ReadAllText($Path))), $null, $null) }
}

foreach ($function in (Get-ChildItem "$ModuleRoot\private\" -Filter "*.ps1" -Recurse -ErrorAction Ignore)) {
    . Import-ModuleFile -Path $function.FullName
}

# Import all public functions
foreach ($function in (Get-ChildItem "$ModuleRoot\public" -Filter "*.ps1" -Recurse -ErrorAction Ignore)) {
    . Import-ModuleFile -Path $function.FullName
}

Set-Alias -Name askhelp -Value Invoke-HelpChat

Set-Variable -Scope 0 -Name PSDefaultParameterValues -Force -ErrorAction SilentlyContinue -Value @{
    '*:ApiKey'       = $null
    '*:ApiBase'      = $null
    '*:ApiVersion'   = $null
    '*:AuthType'     = 'openai'
    '*:ApiType'      = 'openai'
    '*:Organization' = $null
}

$configFile = Join-Path -Path $script:configdir -ChildPath "config.json"

if (Test-Path -Path $configFile) {
    $persisted = Get-Content -Path $configFile -Raw | ConvertFrom-Json
    $splat = @{
        ApiKey       = $persisted.ApiKey
        ApiBase      = $persisted.ApiBase
        Deployment   = $persisted.Deployment
        ApiType      = $persisted.ApiType
        ApiVersion   = $persisted.ApiVersion
        AuthType     = $persisted.AuthType
        Organization = $persisted.Organization
    }
} elseif ($env:OPENAI_API_TYPE) {
    $splat = @{
        ApiKey       = $env:OPENAI_API_KEY
        ApiBase      = $env:OPENAI_API_BASE
        Deployment   = $env:OPENAI_AZURE_DEPLOYMENT
        ApiType      = $env:OPENAI_API_TYPE
        ApiVersion   = $env:OPENAI_API_VERSION
        AuthType     = if ($env:OPENAI_API_TYPE -match 'azure') { 'azure' } else { 'openai' }
        Organization = $env:OPENAI_AZURE_ORGANIZATION
    }
}
$null = Set-OpenAIProvider @splat