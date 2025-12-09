<#
install-tomcat.ps1

Downloads and installs Apache Tomcat on Windows, sets TOMCAT_HOME and updates PATH to include the Tomcat `bin` folder.

Usage (run in an elevated PowerShell for machine-wide install):
  .\install-tomcat.ps1                         # installs default version to Program Files and updates machine PATH if admin
  .\install-tomcat.ps1 -Major 9 -Version 9.0.88 -InstallRoot "C:\Tools\Apache"  # custom install root and version

Notes:
- The script will install to the specified InstallRoot under a directory named `apache-tomcat-<version>`.
- If run as Administrator it updates Machine environment variables; otherwise it updates User environment variables.
- To run Tomcat as a Windows service, you'll need to run the service installer scripts that come with Tomcat (requires admin).
- You will need to open a new shell for PATH changes to take effect.
#>

param(
    [int]$Major = 9,
    [string]$Version = "9.0.113",
    [Alias("InstallationRoot")][string]$InstallRoot = "$env:ProgramFiles\Apache\tomcat"
)

function Is-Admin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Info($msg){ Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn($msg){ Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg){ Write-Host "[ERROR] $msg" -ForegroundColor Red }

# Compose download URL
$baseUrl = "https://downloads.apache.org/tomcat/tomcat-$Major"
$zipName = "apache-tomcat-$Version-windows-x64.zip"
$url = "$baseUrl/v$Version/bin/$zipName"

$destZip = Join-Path $env:TEMP $zipName
$tempExtract = Join-Path $env:TEMP "apache-tomcat-$Version-extract"

$finalDir = Join-Path $InstallRoot "apache-tomcat-$Version"
$tomcatBin = Join-Path $finalDir "bin"

if (Test-Path (Join-Path $tomcatBin 'startup.bat')) {
    Write-Info "Tomcat $Version already installed at $finalDir. No action taken."
    Write-Info "Run `startup.bat` from the Tomcat bin folder or `TOMCAT_HOME` in a new shell to verify."
    exit 0
}

Write-Info "Downloading Apache Tomcat $Version from $url ..."
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

# The zip contains a folder named apache-tomcat-$Version
$extractedFolder = Join-Path $tempExtract "apache-tomcat-$Version"
if (-not (Test-Path $extractedFolder)) {
    # try to find first child folder
    $child = Get-ChildItem -Path $tempExtract | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    if ($child) { $extractedFolder = $child.FullName } else {
        Write-Err "Could not find extracted Tomcat folder."
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

Write-Info "Moving Tomcat files to $finalDir ..."
try {
    Move-Item -Path $extractedFolder -Destination $finalDir
} catch {
    # try copy then remove
    try { Copy-Item -Path $extractedFolder -Destination $finalDir -Recurse -Force; Remove-Item $extractedFolder -Recurse -Force } catch { Write-Err "Failed to move/copy files: $_"; exit 8 }
}

# Set environment variables
Write-Info "Setting environment variable (TOMCAT_HOME) and updating PATH ..."
try {
    if (Is-Admin) {
        $scope = 'Machine'
    } else {
        $scope = 'User'
    }

    [Environment]::SetEnvironmentVariable('TOMCAT_HOME', $finalDir, $scope)

    $currentPath = [Environment]::GetEnvironmentVariable('Path', $scope)
    if ($currentPath -notlike "*${tomcatBin}*") {
        $newPath = $currentPath.TrimEnd(';') + ";" + $tomcatBin
        try {
            [Environment]::SetEnvironmentVariable('Path', $newPath, $scope)
            Write-Info "Updated $scope PATH to include $tomcatBin"
        } catch {
            Write-Warn "Failed to update $scope PATH: $_"
        }
    } else {
        Write-Info "$tomcatBin already present in $scope PATH"
    }
} catch {
    Write-Warn "Could not set environment variables at machine-level. You may need to run as Administrator. Error: $_"
}

# Cleanup
try { Remove-Item $destZip -Force -ErrorAction SilentlyContinue } catch {}
try { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue } catch {}

Write-Info "Apache Tomcat $Version installed to $finalDir"
Write-Info "Open a new shell to pick up PATH/TOMCAT_HOME changes. Start Tomcat with: `startup.bat` (or run service scripts in the Tomcat bin folder as Administrator)."

exit 0
