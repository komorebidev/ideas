# C:\temp\requirements.ps1

$tempDir = "C:\temp"

# ------------------------------------------------------------
# Create temp directory
# ------------------------------------------------------------

if (-not (Test-Path -Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

Write-Host "========================================"
Write-Host " Installing requirements"
Write-Host "========================================"

# ------------------------------------------------------------
# Require Administrator privileges
# ------------------------------------------------------------

$currentIdentity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)

if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

Write-Host "Running with Administrator privileges."

# ------------------------------------------------------------
# Ensure WinGet is available
# ------------------------------------------------------------

$wingetCommand = Get-Command -Name "winget" -ErrorAction SilentlyContinue

if (-not $wingetCommand) {
    Write-Host "WinGet not found. Installing WinGet..."

    $ProgressPreference = "SilentlyContinue"

    try {
        # Install NuGet provider
        Write-Host "Installing NuGet provider..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null

        # Install WinGet PowerShell module
        Write-Host "Installing Microsoft.WinGet.Client..."
        Install-Module -Name Microsoft.WinGet.Client -Repository PSGallery -Force -ErrorAction Stop | Out-Null

        # Install/repair WinGet for all users
        Write-Host "Repairing WinGet package manager..."
        Repair-WinGetPackageManager -AllUsers -ErrorAction Stop

        Write-Host "WinGet installation completed."
    }
    catch {
        Write-Error "Failed to install WinGet."
        Write-Error $_.Exception.Message
        exit 1
    }
}

# ------------------------------------------------------------
# Locate WinGet again
# ------------------------------------------------------------

$wingetCommand = Get-Command -Name "winget" -ErrorAction SilentlyContinue
$wingetPath    = $null

if (-not $wingetCommand) {
    $wingetCandidates = @(
        "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    )

    foreach ($candidate in $wingetCandidates) {
        $found = Get-ChildItem -Path $candidate -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($found) {
            $wingetPath = $found.FullName
            break
        }
    }

    if (-not $wingetPath) {
        Write-Error "WinGet is not available after installation."
        exit 1
    }
}
else {
    $wingetPath = $wingetCommand.Source
}

Write-Host "WinGet path: $wingetPath"

# ------------------------------------------------------------
# Verify WinGet
# ------------------------------------------------------------

& $wingetPath --version

if ($LASTEXITCODE -ne 0) {
    Write-Error "WinGet could not be executed."
    exit 1
}

# ------------------------------------------------------------
# Update only the winget source
# ------------------------------------------------------------

Write-Host ""
Write-Host "Updating WinGet source..."

& $wingetPath source update --source winget --disable-interactivity

if ($LASTEXITCODE -ne 0) {
    Write-Warning "WinGet source update returned exit code $LASTEXITCODE."
    Write-Warning "Continuing with installation..."
}

# ------------------------------------------------------------
# Applications to install
# ------------------------------------------------------------

$apps = @(
    [PSCustomObject]@{
        Name = "Visual Studio Code"
        Id   = "Microsoft.VisualStudioCode"
    },
    [PSCustomObject]@{
        Name = "Python 3.11"
        Id   = "Python.Python.3.11"
    },
    [PSCustomObject]@{
        Name = "Mozilla Firefox"
        Id   = "Mozilla.Firefox"
    },
    [PSCustomObject]@{
        Name = "Git"
        Id   = "Git.Git"
    },
    [PSCustomObject]@{
        Name = "Microsoft Azure CLI"
        Id   = "Microsoft.AzureCLI"
    },
    [PSCustomObject]@{
        Name = "Windows App"
        Id   = "Microsoft.WindowsApp"
    }
)

# ------------------------------------------------------------
# Install applications machine-wide
# ------------------------------------------------------------

foreach ($app in$apps) {
    Write-Host ""
    Write-Host "========================================"
    Write-Host "Checking $($app.Name)"
    Write-Host "Package ID: $($app.Id)"
    Write-Host "========================================"

    Write-Host "Checking machine-wide installation..."

    $installed = &$wingetPath list `
        --id $app.Id `
        --exact `
        --source winget `
        --scope machine `
        --disable-interactivity `
        2>&1

    if ($LASTEXITCODE -eq 0 -and ($installed -match [regex]::Escape($app.Id))) {
        Write-Host "$($app.Name) is already installed machine-wide."
        Write-Host "Skipping installation."
        continue
    }

    Write-Host "$($app.Name) is not installed machine-wide."
    Write-Host "Installing for all users..."

    & $wingetPath install `
        --id $app.Id `
        --exact `
        --source winget `
        --scope machine `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements `
        --disable-interactivity

    $installExitCode =$LASTEXITCODE

    if ($installExitCode -eq 0) {
        Write-Host "$($app.Name) installed successfully."
    }
    else {
        Write-Error "Failed to install $($app.Name). Exit code: $installExitCode"
    }
}

# ------------------------------------------------------------
# Final verification
# ------------------------------------------------------------

Write-Host ""
Write-Host "========================================"
Write-Host " Installation Verification"
Write-Host "========================================"

foreach ($app in $apps) {
    Write-Host ""
    Write-Host "Checking $($app.Name)..."

    $result = & $wingetPath list `
        --id $app.Id `
        --exact `
        --source winget `
        --scope machine `
        --disable-interactivity `
        2>&1

    if ($LASTEXITCODE -eq 0 -and ($result -match [regex]::Escape($app.Id))) {
        Write-Host "[OK] $($app.Name) is installed."
    }
    else {
        Write-Warning "[NOT FOUND] $($app.Name) was not detected."
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host " Installation process completed"
Write-Host "========================================"