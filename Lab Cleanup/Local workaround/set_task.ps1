# Register nightly Azure cleanup task

$vbsPath = Join-Path $PSScriptRoot 'run_cleanup.vbs'

if (-not (Test-Path $vbsPath)) {
    Write-Error "Cannot find run_cleanup.vbs at: $vbsPath"
    exit 1
}

$action = New-ScheduledTaskAction `
    -Execute 'wscript.exe' `
    -Argument "`"$vbsPath`""

$trigger = New-ScheduledTaskTrigger `
    -Daily `
    -At '7:00 PM'

$principal = New-ScheduledTaskPrincipal `
    -UserId (whoami) `
    -LogonType Interactive `

Register-ScheduledTask `
    -TaskName 'Nightly Azure Lab Cleanup' `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Description 'Silently deletes Azure resource groups matching lab wildcard patterns nightly' `
    -Settings (New-ScheduledTaskSettingsSet -StartWhenAvailable) `
    -Force

Write-Host 'Nightly Azure Lab Cleanup task registered successfully.' -ForegroundColor Green
Write-Host 'Schedule: Every day at 7:00 PM (local Windows time)'
Write-Host "Launcher: $vbsPath"