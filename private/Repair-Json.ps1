function Repair-Json {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [string]$Json
    )

    $Json = "$Json".Replace('```jsonl', '')
    $Json = $Json.Replace('```json', '')
    $Json = $Json.Replace('```', '')
    $Json = $Json -replace '[\r\n]+', ''
    $Json = $Json.Replace('json{"', '{"')
    $Json = $Json.Replace('\$', '$')
    $Json = $Json -replace '\{\s+"messages"', '{"messages"'
    $Json = $Json -replace '\{\s+"content"', '{"content"'
    $Json = $Json -replace '\{\s+"roles"', '{"roles"'
    $Json = $Json -replace '\[\s+\{', '[{'
    $Json = $Json -replace ':\s+\[', ':['

    $array = $Json -split '{"messages"'
    $Json = $array -join '{"messages"'

    return $Json
}