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

$configFile = Join-Path -Path $script:configdir -ChildPath "config.json"

if (Test-Path -Path $configFile) {
    $persisted = Get-Content -Path $configFile -Raw | ConvertFrom-Json
    $splat = @{}
    if ($persisted.ApiKey) {
        $splat.ApiKey = $persisted.ApiKey
    }
    if ($persisted.ApiBase) {
        $splat.ApiBase = $persisted.ApiBase
    }
    if ($persisted.Deployment) {
        $splat.Deployment = $persisted.Deployment
    }
    if ($persisted.ApiType) {
        $splat.ApiType = $persisted.ApiType
    }
    if ($persisted.ApiVersion) {
        $splat.ApiVersion = $persisted.ApiVersion
    }
    if ($persisted.AuthType) {
        $splat.AuthType = $persisted.AuthType
    }
    if ($persisted.Organization) {
        $splat.Organization = $persisted.Organization
    }
    $null = Set-OpenAIProvider @splat
}

$PSDefaultParameterValues['Import-Module:Verbose'] = $false
$PSDefaultParameterValues['Add-Type:Verbose'] = $false