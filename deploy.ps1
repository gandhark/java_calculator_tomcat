param(
  [string]$TomcatHome = $env:TOMCAT_HOME,
  [switch]$RestartTomcat
)

if (-not $TomcatHome -or $TomcatHome -eq "") {
  $TomcatHome = Read-Host "Enter Tomcat installation path (e.g., C:\\apache-tomcat-9.0.xx)"
}

if (-not (Test-Path $TomcatHome)) {
  Write-Error "Tomcat path '$TomcatHome' not found. Set TOMCAT_HOME env var or pass -TomcatHome."
  exit 1
}

# Ensure WAR exists
$war = Get-ChildItem -Path ".\target\*.war" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $war) {
  Write-Host "No WAR found in target/. Building project..."
  & .\build.ps1
  if ($LASTEXITCODE -ne 0) { Write-Error "Build failed; aborting."; exit $LASTEXITCODE }
  $war = Get-ChildItem -Path ".\target\*.war" | Select-Object -First 1
}

if (-not $war) { Write-Error "WAR not found after build; aborting."; exit 1 }

$dest = Join-Path $TomcatHome ("webapps\" + $war.Name)
Copy-Item $war.FullName $dest -Force
Write-Host "Copied $($war.Name) to $dest"

if ($RestartTomcat) {
  $catalina = Join-Path $TomcatHome "bin\catalina.bat"
  if (-not (Test-Path $catalina)) { Write-Warning "Tomcat control script not found at $catalina; cannot restart."; exit 0 }
  Write-Host "Stopping Tomcat..."
  & "$TomcatHome\bin\catalina.bat" stop
  Start-Sleep -Seconds 2
  Write-Host "Starting Tomcat..."
  & "$TomcatHome\bin\catalina.bat" start
  Write-Host "Tomcat restart attempted. Check Tomcat logs if needed."
}

Write-Host "Deployment finished. Access the app at: http://localhost:8080/$($war.BaseName)/"