<#
install-java.ps1
# Downloads Eclipse Temurin OpenJDK zip for Windows x64 and unpacks to %USERPROFILE%\.java\temurin-{version}
# Sets user environment variables JAVA_HOME and updates PATH to include the bin dir.
#
# This script installs the JDK by default (Maven requires a JDK to provide the Java compiler).
# Usage:
#   .\install-java.ps1 -Version 17 -SetAsDefault           # installs JDK 17 and sets JAVA_HOME
#   .\install-java.ps1 -Version 11 -PackageType jre        # installs JRE 11 (if you prefer)
#
# Notes:
# - This script modifies user environment variables (not machine). You must open a new PowerShell / cmd for changes to take effect.
# - If you prefer a different build or architecture, modify the download URL.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$false)]
  [ValidateSet('8','11','17','21')]
  [string]$Version = '17',

  [Parameter(Mandatory=$false)]
  [ValidateSet('jre','jdk')]
  [string]$PackageType = 'jdk',

  [switch]$SetAsDefault,

  [switch]$AcceptEULA
)

function Write-ErrAndExit($msg) {
  Write-Error $msg
  exit 1
}

# Map version to Temurin download URL (Windows x64 ZIP) - using Adoptium's binaries
$arch = 'x64'

# install directory (keep package type in path)
$installDir = Join-Path $env:USERPROFILE ".java\temurin-$Version-$PackageType"
if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir | Out-Null }

# Try to download using Adoptium API. Choose jre/jdk based on $PackageType
$apiUrl = "https://api.adoptium.net/v3/binary/latest/$Version/ga/windows/$arch/$PackageType/hotspot/normal/eclipse"
Write-Host "Querying Adoptium API for download (version $Version)..."
try {
  $resp = Invoke-RestMethod -Uri $apiUrl -Method Head -ErrorAction Stop
} catch {
  Write-Warning "Could not fetch metadata from Adoptium API. Attempting fallback download."
}

# Download binary using the api endpoint which may redirect to the asset
$zipPath = Join-Path $env:TEMP ("temurin-$Version-$PackageType.zip")
Write-Host "Downloading $PackageType to $zipPath. This may take a minute..."
try {
  Invoke-WebRequest -Uri $apiUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
} catch {
  Write-ErrAndExit "Download failed: $_"
}

Write-Host "Extracting to $installDir..."
try {
  Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
} catch {
  Write-ErrAndExit "Extraction failed: $_"
}

# After extraction, the JRE is inside a folder like 'jdk-17.0.x+10' or 'jre-17.0.x'
$children = Get-ChildItem -Path $installDir -Directory | Select-Object -First 1
if ($children) {
  $jdkRoot = $children.FullName
} else {
  $jdkRoot = $installDir
}

 $javaBin = Join-Path $jdkRoot 'bin'
if (-not (Test-Path $javaBin)) {
  Write-ErrAndExit "Unexpected layout: bin directory not found under $jdkRoot"
}

# Set user environment variables
if ($SetAsDefault) {
  Write-Host "Setting JAVA_HOME (user) to $jdkRoot and adding to PATH"
  setx JAVA_HOME $jdkRoot | Out-Null
  # Prepend to PATH in the user environment
  $currentUserPath = [Environment]::GetEnvironmentVariable('PATH',[EnvironmentVariableTarget]::User)
  if ($currentUserPath -notlike "*$javaBin*") {
    $newPath = "$javaBin;$currentUserPath"
    setx PATH $newPath | Out-Null
  }
  Write-Host "JAVA_HOME and PATH updated for current user. Open a new shell to pick up changes."
} else {
  # Build a command string showing how to use the installed JDK/JRE in the current session.
  $cmd = '$env:JAVA_HOME="' + $jdkRoot + '"; $env:PATH="' + $javaBin + ';$env:PATH"'
  Write-Host "Installation finished. To use this Java for this session, run:`n  $cmd"
}

Write-Host "Done."