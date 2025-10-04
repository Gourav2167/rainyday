<#
Checks if Gradle is installed locally and if so, generates the Gradle wrapper inside the Android project.
Usage (PowerShell):
  cd <repo root>
  .\scripts\setup-gradle-wrapper.ps1
#>
$androidDir = "$(Resolve-Path .)\rainn_\android"
Write-Host "Checking for system 'gradle' on PATH..."
$gradle = Get-Command gradle -ErrorAction SilentlyContinue
if (-not $gradle) {
    Write-Host "Gradle not found on PATH. Please install Gradle or use SDKMAN / choco / winget to install it."
    Write-Host "If you prefer not to install Gradle globally, you can generate the wrapper on another machine that has Gradle and commit the 'gradlew' files."
    exit 1
}
Write-Host "Found Gradle at: $($gradle.Source)"
Write-Host "Generating Gradle wrapper in $androidDir (this will create gradlew, gradlew.bat and wrapper files)..."
Push-Location $androidDir
try {
    gradle wrapper
    Write-Host "Gradle wrapper generated. You can now run: .\gradlew.bat --version"
} catch {
    Write-Host "Failed to generate Gradle wrapper: $_"
} finally {
    Pop-Location
}
