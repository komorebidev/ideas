# Test Lab

* Spins up Azure VM with web page that shows the IP and login info
* When using Azure VPN client on test lab sometimes needs certificate install

# First-time setup

```powershell
& {
    # 0. Check administrator privileges
    $IsAdmin = ([Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $IsAdmin) {
        Write-Error "Please run this script as Administrator."
        return
    }

    # 1. Fix winget
    Write-Host "`n=== Fixing winget ===" -ForegroundColor Cyan

    $NuGetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
    if (-not $NuGetProvider) {
        Write-Host "Installing NuGet package provider..."
        Install-PackageProvider -Name NuGet -Force
    } else {
        Write-Host "NuGet provider is already installed."
    }

    $WinGetModule = Get-InstalledModule -Name Microsoft.WinGet.Client -ErrorAction SilentlyContinue
    if (-not $WinGetModule) {
        Write-Host "Installing Microsoft.WinGet.Client module..."
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope AllUsers
    } else {
        Write-Host "Microsoft.WinGet.Client module is already installed."
    }

    Write-Host "Repairing WinGet Package Manager..."
    Repair-WinGetPackageManager -Force -Latest

    # 2. Install applications
    Write-Host "`n=== Installing applications ===" -ForegroundColor Cyan

    function Test-WinGetPackageInstalled {
        param ([Parameter(Mandatory)][string]$PackageId)
        $Result = winget list --id $PackageId --exact --accept-source-agreements 2>&1
        foreach ($Line in $Result) {
            if ($Line -match "(?i)\b$([regex]::Escape($PackageId))\b") {
                return $true
            }
        }
        return $false
    }

    function Install-WinGetPackage {
        param (
            [Parameter(Mandatory)][string]$PackageId,
            [Parameter(Mandatory)][string]$PackageName,
            [string]$Source
        )
        Write-Host "`nChecking $PackageName..."
        if (Test-WinGetPackageInstalled -PackageId $PackageId) {
            Write-Host "$PackageName is already installed. Skipping." -ForegroundColor Green
        } else {
            Write-Host "Installing $PackageName..."
            $Arguments = @("install", "--id", $PackageId, "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements")
            if ($Source) { $Arguments += @("--source", $Source) }
            & winget @Arguments
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to install $PackageName. Exit code: $LASTEXITCODE"
            }
            Write-Host "$PackageName installed successfully." -ForegroundColor Green
        }
    }

    # 2.1 Azure VPN Client
    Install-WinGetPackage -PackageId "9NP355QT2SQB" -PackageName "Azure VPN Client" -Source "msstore"

    # 2.2 App Installer
    Install-WinGetPackage -PackageId "Microsoft.AppInstaller" -PackageName "App Installer"

    # 2.3 Windows App
    Install-WinGetPackage -PackageId "Microsoft.WindowsApp" -PackageName "Windows App"

    # 2.4 WinSCP
    Install-WinGetPackage -PackageId "WinSCP.WinSCP" -PackageName "WinSCP"

    # 2.5 Prevent Computer Sleep
    Install-WinGetPackage -PackageId "VovSoft.PreventComputerSleep" -PackageName "Prevent Computer Sleep"

    # 3. Install DigiCert trusted root certificates
    Write-Host "`n=== Installing DigiCert certificates ===" -ForegroundColor Cyan

    $Folder = "C:\tmp\DigiCertRoots"
    if (-not (Test-Path -Path $Folder)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
        Write-Host "Created certificate download folder."
    } else {
        Write-Host "Certificate download folder already exists."
    }

    $Page = "https://knowledge.digicert.com/general-information/digicert-trusted-root-authority-certificates"
    Write-Host "Downloading DigiCert certificate links..."
    $Response = Invoke-WebRequest -Uri $Page -UseBasicParsing -ErrorAction Stop

    $Links = [regex]::Matches(
        $Response.Content,
        'href=["'']([^"'']+\.(?:crt|cer|pem))["'']',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    ) | ForEach-Object {
        [System.Net.WebUtility]::HtmlDecode($_.Groups[1].Value)
    } | Select-Object -Unique

    $Installed = 0
    foreach ($Link in $Links) {
        try {
            if ($Link -notmatch '^https?://') {
                $Link = [uri]::new([uri]$Page, $Link).AbsoluteUri
            }
            $FileName = [System.IO.Path]::GetFileName(([uri]$Link).AbsolutePath)
            if (-not $FileName) { continue }
            $FilePath = Join-Path $Folder $FileName
            Invoke-WebRequest -Uri $Link -OutFile $FilePath -UseBasicParsing -ErrorAction Stop
            $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($FilePath)
            if ($Cert.Subject -eq $Cert.Issuer) {
                $ExistingCert = Get-ChildItem -Path "Cert:\LocalMachine\Root" | Where-Object { $_.Thumbprint -eq $Cert.Thumbprint }
                if ($ExistingCert) {
                    Write-Host "Already installed: $($Cert.Subject)" -ForegroundColor Yellow
                } else {
                    Import-Certificate -FilePath $FilePath -CertStoreLocation "Cert:\LocalMachine\Root" -ErrorAction Stop | Out-Null
                    Write-Host "Installed: $($Cert.Subject)" -ForegroundColor Green
                    $Installed++
                }
            }
        } catch {
            Write-Warning "Skipped $Link : $_"
        }
    }

    # 4. Verify DigiCert certificates
    Write-Host "`n=== DigiCert certificate verification ===" -ForegroundColor Cyan
    Get-ChildItem -Path "Cert:\LocalMachine\Root" | Where-Object {
        $_.Issuer -like "*DigiCert*" -or $_.Subject -like "*DigiCert*"
    } | Format-Table Subject, Thumbprint, NotAfter -AutoSize

    # 5. Summary
    Write-Host "`n=== Setup completed ===" -ForegroundColor Cyan
    Write-Host "New DigiCert root certificates installed: $Installed" -ForegroundColor Green
    Write-Host "Windows setup script finished." -ForegroundColor Green
}
```

## Fix winget manually if script fails

```text
Missing or outdated base images. Many Windows Server images on Azure do not include the App Installer (Microsoft.DesktopAppInstaller) by default. On images that do include it, the pre-installed version and its SSL certificate chain are often outdated by the time the VM is provisioned.
```

```powershell
Install-PackageProvider -Name NuGet -Force
Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery
Repair-WinGetPackageManager -Force -Latest
```

## Certificate install for Digicert

```powershell

# Create download folder
$Folder = "C:\tmp\DigiCertRoots"
New-Item -ItemType Directory -Path $Folder -Force | Out-Null

# DigiCert official trusted root certificate page
$Page = "https://knowledge.digicert.com/general-information/digicert-trusted-root-authority-certificates"

# Download official root certificate files
$Response = Invoke-WebRequest -Uri $Page -UseBasicParsing

# Extract DigiCert certificate download links
$Links = [regex]::Matches(
    $Response.Content,
    'href=["'']([^"'']+\.(?:crt|cer|pem))["'']',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
) | ForEach-Object {
    [System.Net.WebUtility]::HtmlDecode($_.Groups[1].Value)
} | Select-Object -Unique

$Installed = 0

foreach ($Link in $Links) {
    try {
        if ($Link -notmatch '^https?://') {
            $Link = [uri]::new([uri]$Page, $Link).AbsoluteUri
        }

        $FileName = [System.IO.Path]::GetFileName(
            ([uri]$Link).AbsolutePath
        )

        if (-not $FileName) { continue }

        $FilePath = Join-Path $Folder $FileName

        Invoke-WebRequest -Uri $Link -OutFile $FilePath -UseBasicParsing

        $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($FilePath)

        # Install only self-signed root certificates
        if ($Cert.Subject -eq $Cert.Issuer) {
            Import-Certificate -FilePath $FilePath `
                -CertStoreLocation "Cert:\LocalMachine\Root" `
                -ErrorAction Stop | Out-Null

            Write-Host "Installed: $($Cert.Subject)" -ForegroundColor Green
            $Installed++
        }
    }
    catch {
        Write-Warning "Skipped $Link : $_"
    }
}

Write-Host "`nTotal root certificates installed: $Installed" -ForegroundColor Cyan

# Verify DigiCert certificates
Get-ChildItem Cert:\LocalMachine\Root |
    Where-Object { $_.Issuer -like "*DigiCert*" -or $_.Subject -like "*DigiCert*" } |
    Format-Table Subject, Thumbprint, NotAfter -AutoSize
```

# Build the deployment zip

Run from the `app` folder. It packages the app into `Test Lab/app.zip` (skips `.venv`, `__pycache__` and the script itself). Same script as the Tango repo.

```powershell
cd app
python zip.py
```

# Deploy

Run from the `Test Lab` folder (where `app.zip` is), after building the zip. Deploys to `labapp-<suffix>` in `testlabapp-<suffix>`, where `<suffix>` is the last 4 characters of the current subscription ID. Same script as the Tango repo.

```powershell
cd ..
./deploy.ps1
```
