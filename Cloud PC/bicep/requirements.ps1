param(
    [Parameter(Mandatory = $true)]
    [string]$PostgresHostname,

    [Parameter(Mandatory = $true)]
    [string]$PostgresAdministratorLogin,

    [Parameter(Mandatory = $true)]
    [string]$PostgresAdministratorPassword,

    [Parameter(Mandatory = $true)]
    [string]$GuacamolePostgresUsername,

    [Parameter(Mandatory = $true)]
    [string]$GuacamolePostgresPassword
)

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
        Write-Host "Installing NuGet provider..."
        Install-PackageProvider `
            -Name NuGet `
            -MinimumVersion 2.8.5.201 `
            -Force `
            -ErrorAction Stop | Out-Null

        Write-Host "Installing Microsoft.WinGet.Client..."
        Install-Module `
            -Name Microsoft.WinGet.Client `
            -Repository PSGallery `
            -Force `
            -ErrorAction Stop | Out-Null

        Write-Host "Repairing WinGet package manager..."
        Repair-WinGetPackageManager `
            -AllUsers `
            -ErrorAction Stop

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
$wingetPath    =$null

if (-not $wingetCommand) {$wingetCandidates = @(
        "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    )

    foreach ($candidate in $wingetCandidates) {$found = Get-ChildItem `
            -Path $candidate `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($found) {
            $wingetPath =$found.FullName
            break
        }
    }

    if (-not $wingetPath) {
        Write-Error "WinGet is not available after installation."
        exit 1
    }
}
else {
    $wingetPath =$wingetCommand.Source
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
# Update WinGet source
# ------------------------------------------------------------

Write-Host ""
Write-Host "Updating WinGet source..."

& $wingetPath source update `
    --source winget `
    --disable-interactivity

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
    },
    [PSCustomObject]@{
        Name = "PostgreSQL 16"
        Id   = "PostgreSQL.PostgreSQL.16"
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
        exit $installExitCode
    }
}

# ------------------------------------------------------------
# Locate PostgreSQL client
# ------------------------------------------------------------

Write-Host ""
Write-Host "========================================"
Write-Host "Locating PostgreSQL client"
Write-Host "========================================"

$psqlCommand = Get-Command -Name "psql.exe" -ErrorAction SilentlyContinue

if ($psqlCommand) {
    $psqlPath =$psqlCommand.Source
}
else {
    $postgresCandidates = @(
        "C:\Program Files\PostgreSQL\16\bin\psql.exe",
        "C:\Program Files\PostgreSQL\*\bin\psql.exe"
    )

    $psqlPath =$null

    foreach ($candidate in $postgresCandidates) {$found = Get-ChildItem `
            -Path $candidate `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($found) {
            $psqlPath =$found.FullName
            break
        }
    }
}

if (-not $psqlPath) {
    Write-Error "PostgreSQL psql.exe was not found."
    exit 1
}

Write-Host "PostgreSQL client: $psqlPath"

# ------------------------------------------------------------
# Wait for PostgreSQL private endpoint
# ------------------------------------------------------------

Write-Host ""
Write-Host "========================================"
Write-Host "Waiting for PostgreSQL"
Write-Host "========================================"

$maxAttempts = 60$attempt = 0

while ($attempt -lt $maxAttempts) {$attempt++

    Write-Host "PostgreSQL connection attempt $attempt of$maxAttempts..."

    $env:PGPASSWORD =$PostgresAdministratorPassword

    & $psqlPath `
        -h $PostgresHostname `
        -p 5432 `
        -U $PostgresAdministratorLogin `
        -d "guacamole_db" `
        -c "SELECT 1;" `
        --no-password `
        --quiet `
        2>$null

    $exitCode =$LASTEXITCODE

    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

    if ($exitCode -eq 0) {
        Write-Host "PostgreSQL is reachable."
        break
    }

    if ($attempt -eq$maxAttempts) {
        Write-Error "PostgreSQL did not become reachable."
        exit 1
    }

    Start-Sleep -Seconds 10
}

# ------------------------------------------------------------
# Create Guacamole PostgreSQL user
# ------------------------------------------------------------

Write-Host ""
Write-Host "========================================"
Write-Host "Configuring Guacamole PostgreSQL user"
Write-Host "========================================"

$env:PGPASSWORD =$PostgresAdministratorPassword

$createUserSql = @"
DO `$`$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_catalog.pg_roles
        WHERE rolname = :'guacamole_user'
    ) THEN
        CREATE ROLE :"guacamole_user" LOGIN PASSWORD :'guacamole_password';
    ELSE
        ALTER ROLE :"guacamole_user" WITH LOGIN PASSWORD :'guacamole_password';
    END IF;
END
`$`$;
"@

& $psqlPath `
    -h $PostgresHostname `
    -p 5432 `
    -U $PostgresAdministratorLogin `
    -d "guacamole_db" `
    -v "guacamole_user=$GuacamolePostgresUsername" `
    -v "guacamole_password=$GuacamolePostgresPassword" `
    -v "ON_ERROR_STOP=1" `
    -c $createUserSql

$exitCode =$LASTEXITCODE

Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

if ($exitCode -ne 0) {
    Write-Error "Failed to create Guacamole PostgreSQL user."
    exit $exitCode
}

Write-Host "Guacamole PostgreSQL user configured."

# ------------------------------------------------------------
# Download Guacamole JDBC schema
# ------------------------------------------------------------

Write-Host ""
Write-Host "========================================"
Write-Host "Downloading Guacamole database schema"
Write-Host "========================================"

$guacamoleVersion = "1.6.0"
$guacamoleArchive = "$tempDir\guacamole-auth-jdbc-$guacamoleVersion.tar.gz"
$guacamoleUrl = "https://dlcdn.apache.org/guacamole/$guacamoleVersion/binary/guacamole-auth-jdbc-$guacamoleVersion.tar.gz"

if (-not (Test-Path $guacamoleArchive)) {
    Write-Host "Downloading Guacamole JDBC archive..."

    Invoke-WebRequest `
        -Uri $guacamoleUrl `
        -OutFile $guacamoleArchive `
        -UseBasicParsing `
        -ErrorAction Stop
}

# ------------------------------------------------------------
# Extract Guacamole schema
# ------------------------------------------------------------

Write-Host ""
Write-Host "========================================"
Write-Host "Extracting Guacamole schema"
Write-Host "========================================"

$guacamoleExtractDir = "$tempDir\guacamole-auth-jdbc-$guacamoleVersion"

if (Test-Path $guacamoleExtractDir) {
    Remove-Item `
        -Path $guacamoleExtractDir `
        -Recurse `
        -Force
}

New-Item `
    -ItemType Directory `
    -Path $guacamoleExtractDir `
    -Force | Out-Null

tar.exe `
    -xzf $guacamoleArchive `
    -C $guacamoleExtractDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to extract Guacamole JDBC archive."
    exit 1
}

$schemaDirectory = Join