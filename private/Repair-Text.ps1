function Repair-Text {
    [CmdletBinding()]
    param (
        [string]$Text
    )
    # Define a list of stop words. You might need to expand this list based on your context.
    $stopWords = @("the", "is", "at", "which", "on", "and", "a", "to")

    # Remove stop words
    $Text = $Text.Split(' ').Where({ $PSItem -notin $stopWords })
    $Text = $Text -join ' '

    $Text = $Text.Replace("`t", " ")
    $Text = $Text.Replace("  ", " ")
    # Remove special characters, preserving PowerShell-specific ones like '-', '_'
    # Adjust the regex to keep hyphens and underscores
    $output = $Text -replace '[^\w\s\-_;:\\\$\=]', ''
    $output = $Text -replace '�', 'ó'
    $output = $Text -replace '[^\x00-\x7F]', 'ó'
    $output -creplace '-UA', '-PSU'
}