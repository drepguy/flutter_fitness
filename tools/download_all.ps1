$ErrorActionPreference = "Stop"

$data = Get-Content -Raw "D:\git\android-projects\flutter_fitness\tools\exercises.json" | ConvertFrom-Json
$outDir = "D:\git\android-projects\flutter_fitness\assets\exercises"
$baseUrl = "https://exercise-dataset.com/"

# Metadata for search
$metadata = @()

$downloadCount = 0
$skipCount = 0
$failCount = 0

foreach ($ex in $data.exercises) {
    $id = $ex.id
    $img = $null
    if ($ex.images.flat.PSObject.Properties['peak']) { $img = $ex.images.flat.peak }
    elseif ($ex.images.flat.PSObject.Properties['start']) { $img = $ex.images.flat.start }
    elseif ($ex.images.flat.PSObject.Properties['main']) { $img = $ex.images.flat.main }
    
    if (-not $img) { $skipCount++; continue }
    
    $fileName = "$id.webp"
    $outFile = Join-Path $outDir $fileName
    
    if (-not (Test-Path $outFile)) {
        try {
            Invoke-WebRequest -Uri "$baseUrl$img" -OutFile $outFile -TimeoutSec 10
            $downloadCount++
        } catch {
            $failCount++
            Write-Output "FAILED: $id"
            continue
        }
    }
    
    $metadata += @{
        id = $id
        name_en = $ex.name_en
        name_de = $ex.name_de
        category = $ex.category
        equipment = $ex.equipment
        body_part = $ex.body_part
        primary_muscles = $ex.primary_muscles
    }
    
    if (($downloadCount + $skipCount + $failCount) % 50 -eq 0) {
        Write-Output "Progress: $($downloadCount + $skipCount + $failCount) / $($data.exercises.Count)"
    }
}

Write-Output "`nDone: Downloaded=$downloadCount, Skipped=$skipCount, Failed=$failCount"

# Write metadata JSON
$metadataJson = $metadata | ConvertTo-Json -Depth 3 -Compress
$metadataFile = Join-Path $outDir "exercises_meta.json"
Set-Content -Path $metadataFile -Value $metadataJson -Encoding UTF8
Write-Output "Metadata written to $metadataFile"
Write-Output "Metadata entries: $($metadata.Count)"
