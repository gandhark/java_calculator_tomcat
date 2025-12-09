param(
  [switch]$SkipTests
)

Write-Host "Running Maven build (skip tests: $SkipTests)"
$mvnCmd = "mvn"
if ($SkipTests) { & $mvnCmd clean package -DskipTests } else { & $mvnCmd clean package }
if ($LASTEXITCODE -ne 0) {
  Write-Error "Maven build failed (exit code $LASTEXITCODE). Ensure Maven and Java are installed and on PATH."
  exit $LASTEXITCODE
}
Write-Host "Build successful. WAR produced in target\"