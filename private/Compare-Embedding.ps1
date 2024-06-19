function Compare-Embedding {
    [CmdletBinding()]
    param(
        [string]$Query,
        [double[]]$QueryEmbedding,
        [Parameter(Mandatory)]
        [hashtable]$Embeddings,
        [int]$Top = 25
    )
    process {
        if (-not $Query -and -not $QueryEmbedding) {
            throw "You must specify either Query or QueryEmbedding"
        }

        if ($Query) {
            $QueryEmbedding = Get-Embedding -Text $Query
        }

        $similarities = New-Object System.Collections.ArrayList

        foreach ($key in $Embeddings.Keys) {
            try {
                $embeddingVector = $Embeddings[$key]
            } catch {
                Write-Verbose "Error with $key"
                continue
            }

            # Local implementation of Cosine similarity calculation
            $dotProduct = 0
            $queryMagnitude = 0
            $embeddingMagnitude = 0

            for ($i = 0; $i -lt $QueryEmbedding.Count; $i++) {
                $dotProduct += $QueryEmbedding[$i] * $embeddingVector[$i]
                $queryMagnitude += $QueryEmbedding[$i] * $QueryEmbedding[$i]
                $embeddingMagnitude += $embeddingVector[$i] * $embeddingVector[$i]
            }

            $queryMagnitude = [Math]::Sqrt($queryMagnitude)
            $embeddingMagnitude = [Math]::Sqrt($embeddingMagnitude)

            if ($queryMagnitude -ne 0 -and $embeddingMagnitude -ne 0) {
                $similarity = $dotProduct / ($queryMagnitude * $embeddingMagnitude)
            } else {
                $similarity = 0
            }

            $null = $similarities.Add([PSCustomObject]@{ Command = $key; Similarity = $similarity })
        }

        $similarities | Sort-Object -Property Similarity -Descending | Select-Object -First $Top
    }
}