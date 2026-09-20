$ErrorActionPreference = "Stop"

$data = Get-Content -Raw "D:\git\android-projects\flutter_fitness\tools\exercises.json" | ConvertFrom-Json
Write-Output "Total exercises in dataset: $($data.exercises.Count)"

# Build lookup by ID
$exerciseIds = @{}
foreach ($ex in $data.exercises) {
    $exerciseIds[$ex.id] = $ex
}

# Mapping: our exercise name -> candidate RepDB IDs
$candidates = @{
    "hack-squat" = @("hack-squat", "barbell-squat", "front-squat")
    "hip-thrust" = @("hip-thrust", "barbell-hip-thrust", "machine-hip-thrust")
    "leg-press" = @("leg-press", "horizontal-leg-press", "45-degree-leg-press")
    "calf-raise" = @("seated-calf-raise", "standing-calf-raise", "calf-raise")
    "leg-extension" = @("leg-extension")
    "leg-curl" = @("leg-curl", "lying-leg-curl", "seated-leg-curl")
    "chest-press" = @("chest-press-machine", "machine-chest-press", "bench-press")
    "chest-fly" = @("chest-fly", "machine-chest-fly", "pec-deck")
    "shoulder-press" = @("overhead-press", "machine-shoulder-press", "arnold-press")
    "lateral-raise" = @("lateral-raise", "dumbbell-lateral-raise")
    "skull-crusher" = @("skull-crusher", "lying-triceps-extension", "ez-bar-skull-crusher")
    "triceps-pushdown" = @("triceps-pushdown", "cable-pushdown")
    "lat-pulldown" = @("lat-pulldown", "wide-grip-lat-pulldown")
    "seated-row" = @("seated-cable-row", "cable-row", "machine-row")
    "chest-supported-row" = @("chest-supported-row", "chest-supported-dumbbell-row")
    "face-pull" = @("face-pull")
    "hammer-curl" = @("hammer-curl", "dumbbell-hammer-curl")
    "cable-curl" = @("cable-curl", "standing-cable-curl")
    "back-extension" = @("back-extension", "hyperextension")
    "crunch" = @("crunch", "cable-crunch")
    "machine-crunch" = @("machine-crunch", "crunch-machine")
    "wrist-curl" = @("wrist-curl", "barbell-wrist-curl")
    "reverse-wrist-curl" = @("reverse-wrist-curl", "wrist-extensor-curl")
    "squat" = @("barbell-squat", "goblet-squat")
    "deadlift" = @("barbell-deadlift", "conventional-deadlift")
    "bench-press" = @("barbell-bench-press", "bench-press")
    "dumbbell-bench-press" = @("dumbbell-bench-press")
    "incline-bench-press" = @("incline-barbell-bench-press", "incline-bench-press")
    "pull-up" = @("pull-up", "chin-up")
    "dip" = @("dip", "parallel-bar-dip")
    "barbell-row" = @("barbell-row", "bent-over-barbell-row")
    "dumbbell-row" = @("one-arm-dumbbell-row", "dumbbell-row")
    "romanian-deadlift" = @("romanian-deadlift", "barbell-romanian-deadlift")
    "bulgarian-split-squat" = @("bulgarian-split-squat")
    "lunge" = @("barbell-lunge", "walking-lunge")
    "front-raise" = @("dumbbell-front-raise", "front-raise")
    "shrug" = @("barbell-shrug", "dumbbell-shrug")
    "preacher-curl" = @("preacher-curl", "ez-bar-preacher-curl")
    "bench-dip" = @("bench-dip", "tricep-dip")
    "cable-crossover" = @("cable-crossover", "cable-fly")
    "plank" = @("plank")
    "hanging-leg-raise" = @("hanging-leg-raise")
    "russian-twist" = @("russian-twist")
    "ab-wheel-rollout" = @("ab-wheel-rollout")
    "dumbbell-curl" = @("dumbbell-bicep-curl", "standing-dumbbell-curl")
    "stationary-bike" = @("stationary-bike", "air-bike")
    "running" = @("running", "treadmill-walk")
}

# Find matches
$matched = @{}
foreach ($name in $candidates.Keys) {
    foreach ($candidate in $candidates[$name]) {
        if ($exerciseIds.ContainsKey($candidate)) {
            $ex = $exerciseIds[$candidate]
            $img = $null
            if ($ex.images.flat.PSObject.Properties['peak']) { $img = $ex.images.flat.peak }
            elseif ($ex.images.flat.PSObject.Properties['start']) { $img = $ex.images.flat.start }
            elseif ($ex.images.flat.PSObject.Properties['main']) { $img = $ex.images.flat.main }
            if ($img) {
                $matched[$name] = @{ id = $ex.id; name_de = $ex.name_de; image = $img }
                break
            }
        }
    }
}

Write-Output "Matched: $($matched.Count) exercises"

# Download images
$outDir = "D:\git\android-projects\flutter_fitness\assets\exercises"
$baseUrl = "https://exercise-dataset.com/"

$downloadCount = 0
$failed = 0
foreach ($name in $matched.Keys) {
    $info = $matched[$name]
    $fileName = "$name.webp"
    $url = "$baseUrl$($info.image)"
    $outFile = Join-Path $outDir $fileName
    
    if (-not (Test-Path $outFile)) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $outFile -TimeoutSec 10
            $downloadCount++
            Write-Output "Downloaded: $fileName"
        } catch {
            $failed++
            Write-Output "FAILED: $fileName ($url)"
        }
    } else {
        Write-Output "Exists: $fileName"
    }
}
Write-Output "`nDownloaded: $downloadCount, Failed: $failed, Total: $($matched.Count)"

# Output mapping
Write-Output "`n--- DART MAPPING ---"
foreach ($name in ($matched.Keys | Sort-Object)) {
    $fileName = "$name.webp"
    Write-Output "  '$name': 'assets/exercises/$fileName',"
}
