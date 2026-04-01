param(
  [string]$ExclusionFile = "$PSScriptRoot\..\config\artifact-exclusions.txt"
)

# Create artifact staging directory
$stagingDir = "artifact-staging"
New-Item -ItemType Directory -Force -Path $stagingDir
New-Item -ItemType Directory -Force -Path "$stagingDir\vi.lib\ActorFramework"
New-Item -ItemType Directory -Force -Path "$stagingDir\resource\AFDebug"
New-Item -ItemType Directory -Force -Path "$stagingDir\resource\Framework\Providers"
New-Item -ItemType Directory -Force -Path "$stagingDir\menus"

# Define exclusion patterns
$excludeExtensions = @('*.lvproj', '*.vipb', '*.aliases', '*.lvlps')

# Parse path exclusions from file
$excludePathsList = @()
if (Test-Path $ExclusionFile) {
  Write-Host "Reading exclusions from: $ExclusionFile"
  $excludePathsList = Get-Content $ExclusionFile | 
    Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$' } |
    ForEach-Object { $_.Trim() }
  
  Write-Host "Loaded $($excludePathsList.Count) exclusion path(s)"
} else {
  Write-Warning "Exclusion file not found: $ExclusionFile"
}

# Helper function to check if path should be excluded
function Test-PathExcluded {
  param($FilePath)
  
  foreach ($excludePath in $excludePathsList) {
    $normalizedExclude = $excludePath -replace '/', '\'
    if ($FilePath -like "*$normalizedExclude*") {
      return $true
    }
  }
  return $false
}

# Helper function to copy files with exclusions
function Copy-WithExclusions {
  param($SourcePath, $DestPath, $Label)
  
  Write-Host "Copying $Label"
  Get-ChildItem -Path $SourcePath -Recurse -File | ForEach-Object {
    $excluded = $false
    
    # Check file extension exclusions
    foreach ($pattern in $excludeExtensions) {
      if ($_.Name -like $pattern) {
        Write-Warning "Excluding file: $($_.FullName)"
        $excluded = $true
        break
      }
    }
    
    # Check path exclusions
    if (-not $excluded -and (Test-PathExcluded -FilePath $_.FullName)) {
      Write-Warning "Excluding path: $($_.FullName)"
      $excluded = $true
    }
    
    if (-not $excluded) {
      $relativePath = $_.FullName.Substring((Resolve-Path $SourcePath).Path.Length + 1)
      $destFilePath = Join-Path $DestPath $relativePath
      $destDir = Split-Path -Parent $destFilePath
      
      if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
      }
      
      Copy-Item -Path $_.FullName -Destination $destFilePath -Force
      Write-Host "Copied: $relativePath"
    }
  }
}

# Copy Core\ActorFramework\ to vi.lib\ActorFramework\
Copy-WithExclusions -SourcePath "Core\ActorFramework" -DestPath "$stagingDir\vi.lib\ActorFramework" -Label "Core\ActorFramework\ to vi.lib\ActorFramework\"

# Copy Core\AFDebug\ to resource\AFDebug\
Write-Host "`n"
Copy-WithExclusions -SourcePath "Core\AFDebug" -DestPath "$stagingDir\resource\AFDebug" -Label "Core\AFDebug\ to resource\AFDebug\"

# Copy Core\Menus\ to menus\
Write-Host "`n"
Copy-WithExclusions -SourcePath "Core\Menus" -DestPath "$stagingDir\menus" -Label "Core\Menus\ to menus\"

# Copy Providers\ to resource\Framework\Providers\
Write-Host "`n"
Copy-WithExclusions -SourcePath "Providers" -DestPath "$stagingDir\resource\Framework\Providers" -Label "Providers\ to resource\Framework\Providers\"

Write-Host "`nArtifact preparation complete"