# Local workaround

* Azure student accounts cannot deploy to the region which is needed by Azure automation resource
* Run locally instead
* Use self signed certificate to authenticate as a service principal to Azure

## Make 99 year certificate (this one is public for upload to Azure)

* The private part is stored in Windows store automatically on the local PC

```powershell
$cert = New-SelfSignedCertificate `
>>     -Subject "CN=labCleanup" `
>>     -CertStoreLocation "Cert:\CurrentUser\My" `
>>     -KeySpec Signature `
>>     -KeyExportPolicy Exportable `
>>     -NotAfter (Get-Date).AddYears(99)
```

## test command
```powershell
$tenantId = '<tenant-id>'
$appId = '<application-client-id>'
$thumbprint = '<certificate-thumbprint>'
$subscriptionId = '<subscription-id>'

Connect-AzAccount `
    -ServicePrincipal `
    -Tenant $tenantId `
    -ApplicationId $appId `
    -CertificateThumbprint $thumbprint

Set-AzContext -SubscriptionId $subscriptionId

Get-AzResourceGroup
```

## Get thumbprint

```powershell
Get-ChildItem Cert:\CurrentUser\My |
>>     Select-Object Subject, Thumbprint, NotAfter
```

## Tenant variables and authentication test

```powershell
$tenantId = 'b021614f-bc20-4b53-b919-2a753834fa6f'
$appId = '755ca023-4e03-4586-9493-0414afb1f2fa'
$thumbprint = '83C7A2A516AFA858653EE1DBBB0CB3A5E63172AD'
$subscriptionId = '89ca3363-489e-48b8-b449-f61c1069d3c0'

Connect-AzAccount `
    -ServicePrincipal `
    -Tenant $tenantId `
    -ApplicationId $appId `
    -CertificateThumbprint $thumbprint

Set-AzContext -SubscriptionId $subscriptionId
```

## Set task that deletes at 19pm JST (run from cleanup.ps1 folder)

* It uses VBS script to launch the powershell
* The task will launch the VBS


```powershell
set_task.ps1
```

### Manually set the task
```powershell
$vbsPath = (Resolve-Path '.\run_cleanup.vbs').Path

$action = New-ScheduledTaskAction `
    -Execute 'wscript.exe' `
    -Argument "`"$vbsPath`""

$trigger = New-ScheduledTaskTrigger `
    -Daily `
    -At '7:00 PM'

$principal = New-ScheduledTaskPrincipal `
    -UserId (whoami) `
    -LogonType Interactive `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName 'Nightly Azure Lab Cleanup' `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Description 'Silently deletes Azure resource groups matching lab wildcard patterns nightly' `
    -Settings (New-ScheduledTaskSettingsSet -StartWhenAvailable) `
    -Force
```

## Manually run the task

```powershell
Get-ScheduledTaskInfo -TaskName 'Nightly Azure Lab Cleanup'
```