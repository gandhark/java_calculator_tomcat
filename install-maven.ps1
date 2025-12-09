<#
install-maven.ps1

Downloads and installs Apache Maven on Windows and updates PATH so `mvn` is available.

Usage (run in an elevated PowerShell for machine-wide install):
  .\install-maven.ps1                 # installs default version to Program Files and updates machine PATH if admin
  .\install-maven.ps1 -Version 3.9.6 -InstallRoot "C:\Tools\Apache"  # custom install root

Notes:
- The script will try to detect Java; if Java is missing it will warn and exit.
- If run as Administrator it updates the Machine PATH; otherwise it updates the User PATH.
- You will need to open a new shell for PATH changes to take effect.
#>

param(
    [string]$Version = "3.9.11",
    [Alias("InstallationRoot")][string]$InstallRoot = "$env:ProgramFiles\Apache\maven"
)

function Is-Admin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Info($msg){ Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn($msg){ Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg){ Write-Host "[ERROR] $msg" -ForegroundColor Red }

# Check Java
try {
    $java = & java -version 2>&1
} catch {
    $java = $null
}
if (-not $java) {
    Write-Warn "Java not found in PATH. Maven requires a JDK/JRE. Please install Java first or run your repository's install-java.ps1 if available."
    exit 2
} else {
    Write-Info "Java detected: $($java -join '`n')"
}

$arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
# Build download URL (official apache downloads)
$baseUrl = "https://downloads.apache.org/maven/maven-3/$Version/binaries"
$zipName = "apache-maven-$Version-bin.zip"
$url = "$baseUrl/$zipName"

$destZip = Join-Path $env:TEMP $zipName
$tempExtract = Join-Path $env:TEMP "apache-maven-$Version-extract"

$finalDir = Join-Path $InstallRoot "apache-maven-$Version"
$mavenBin = Join-Path $finalDir "bin"

if (Test-Path (Join-Path $mavenBin 'mvn.bat')) {
    Write-Info "Maven $Version already installed at $finalDir. No action taken."
    Write-Info "Run `mvn -v` in a new shell to verify."
    exit 0
}

Write-Info "Downloading Apache Maven $Version from $url ..."
try {
    if (Test-Path $destZip) { Remove-Item $destZip -Force }
    Invoke-WebRequest -Uri $url -OutFile $destZip -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Err "Failed to download $url. Error: $_"
    exit 3
}

# Clean previous temp extract
if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }

Write-Info "Extracting to temporary folder..."
try {
    Expand-Archive -LiteralPath $destZip -DestinationPath $tempExtract -Force
} catch {
    Write-Err "Failed to extract $destZip. Error: $_"
    exit 4
}

# The zip contains a folder named apache-maven-$Version
$extractedFolder = Join-Path $tempExtract "apache-maven-$Version"
if (-not (Test-Path $extractedFolder)) {
    # try to find first child folder
    $child = Get-ChildItem -Path $tempExtract | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    if ($child) { $extractedFolder = $child.FullName } else {
        Write-Err "Could not find extracted Maven folder."
        exit 5
    }
}

# Ensure install root exists
if (-not (Test-Path $InstallRoot)) {
    try { New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null } catch { Write-Err "Failed to create install root ${InstallRoot}: $_"; exit 6 }
}

# If finalDir exists, back it up or remove
if (Test-Path $finalDir) {
    Write-Warn "Target installation folder $finalDir already exists. It will be overwritten."
    try { Remove-Item $finalDir -Recurse -Force } catch { Write-Err "Failed to remove existing folder: $_"; exit 7 }
}

Write-Info "Moving Maven files to $finalDir ..."
try {
    Move-Item -Path $extractedFolder -Destination $finalDir
} catch {
    # try copy then remove
    try { Copy-Item -Path $extractedFolder -Destination $finalDir -Recurse -Force; Remove-Item $extractedFolder -Recurse -Force } catch { Write-Err "Failed to move/copy files: $_"; exit 8 }
}

# Set environment variables
Write-Info "Setting environment variables (M2_HOME, MAVEN_HOME) and updating PATH ..."
$envVarsSet = @()
try {
    [Environment]::SetEnvironmentVariable('M2_HOME', $finalDir, 'Machine')
    [Environment]::SetEnvironmentVariable('MAVEN_HOME', $finalDir, 'Machine')
    $envVarsSet += 'Machine'
} catch {
    # fallback to User variables if machine-level failed (permission)
    Write-Warn "Could not set Machine-level environment variables (need Admin). Will set User-level variables instead."
    [Environment]::SetEnvironmentVariable('M2_HOME', $finalDir, 'User')
    [Environment]::SetEnvironmentVariable('MAVEN_HOME', $finalDir, 'User')
    $envVarsSet += 'User'
}

# Path update (prefer Machine if admin)
$binPath = $mavenBin
if (Is-Admin) {
    $scope = 'Machine'
} else {
    $scope = 'User'
}

$currentPath = [Environment]::GetEnvironmentVariable('Path', $scope)
if ($currentPath -notlike "*${binPath}*") {
    $newPath = $currentPath.TrimEnd(';') + ";" + $binPath
    try {
        [Environment]::SetEnvironmentVariable('Path', $newPath, $scope)
        Write-Info "Updated $scope PATH to include $binPath"
    } catch {
        Write-Warn "Failed to update $scope PATH: $_"
    }
} else {
    Write-Info "$binPath already present in $scope PATH"
}

# Cleanup
try { Remove-Item $destZip -Force -ErrorAction SilentlyContinue } catch {}
try { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue } catch {}

Write-Info "Apache Maven $Version installed to $finalDir"
if ($envVarsSet -contains 'Machine' -and (Is-Admin)) {
    Write-Info "Machine environment variables set. Open a new shell (or log off/on) to pick up changes."
} else {
    Write-Info "User environment variables set. Open a new shell to pick up changes."
}

Write-Info "Verify with: mvn -v (in a new shell)"

exit 0
