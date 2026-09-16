Set-StrictMode -Version 3.0

function Get-JobAgentSupertestPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $matrixPath = Join-Path $root 'docs\test-matrix.json'
    if (-not (Test-Path -LiteralPath $matrixPath -PathType Leaf)) { throw "Supertest-Matrix fehlt: $matrixPath" }

    $matrix = Get-Content -LiteralPath $matrixPath -Raw | ConvertFrom-Json -Depth 100
    $selected = @($matrix.items | Where-Object {
            $_.include_in_supertest -eq $true -and [string]$_.status -eq 'done'
        } | Sort-Object @{ Expression = { [int]$_.supertest_order } }, roadmap_id)
    if ($selected.Count -eq 0) { throw 'Supertest-Matrix enthält keine freigegebenen abgeschlossenen Tests.' }

    $seenFiles = @{}
    foreach ($entry in $selected) {
        foreach ($property in @('roadmap_id', 'test_file', 'command', 'status', 'include_in_supertest', 'lane', 'supertest_order')) {
            if (-not ($entry.PSObject.Properties.Name -contains $property)) { throw "Supertest-Matrixeintrag $($entry.roadmap_id) fehlt $property." }
        }
        if ([int]$entry.supertest_order -lt 1) { throw "Supertest-Matrixeintrag $($entry.roadmap_id) hat keine positive supertest_order." }
        $relativePath = [string]$entry.test_file
        $fileName = Split-Path -Leaf $relativePath
        if ($fileName -eq 'Test-JobAgentSupertest.ps1') { throw 'Supertest darf sich nicht selbst aufnehmen.' }
        if ($seenFiles.ContainsKey($fileName)) { throw "Supertest-Matrix enthält den Test doppelt: $fileName" }
        if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath) -PathType Leaf)) { throw "Supertest-Matrix referenziert fehlende Testdatei: $relativePath" }
        $seenFiles[$fileName] = $true
    }
    $orders = @($selected | ForEach-Object { [int]$_.supertest_order })
    if (@($orders | Select-Object -Unique).Count -ne $orders.Count) { throw 'Supertest-Matrix enthält doppelte supertest_order-Werte.' }
    return @($selected)
}

Export-ModuleMember -Function Get-JobAgentSupertestPlan
