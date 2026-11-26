# Azure Lab Web App (`labapp-d3c0`)

A Python/Flask web application designed to run on Azure App Service for managing and interacting with Azure Virtual Machines using Managed Identities and Azure Resource Manager (ARM) APIs.

## Marketplace Image

- **Publisher:** `microsoftwindowsdesktop`
- **Offer:** `windows11preview-arm64`
- **Plan / SKU:** `win11-25h2-ent`

## VM Size

Example: `Standard_D2ps_v5` (2 vCPUs, 8 GiB RAM).

## Notes

- Verify image and VM size availability in the target region.
- Windows ARM64 Preview may have compatibility limitations.
- Check Marketplace licensing requirements.
- Secure RDP access
- Auto shutdown at 19pm JST
- Don't forget the resources are deployed into two different rg
- Make sure to turn on easy auth from the app service otherwise it will not return anything

## Validate

```powershell
# Make sure your variables/parameters are defined first
$today = Get-Date -Format "yyyy-MM-dd"
$aPass = "${today}Pass!"
$clientIp = (Invoke-RestMethod -Uri "https://ipinfo.io/ip")

# Run the validation
az deployment sub validate `
    --location japaneast `
    --template-file main.bicep `
    --parameters clientIp=$clientIp adminUsername='auser' adminPassword=$aPass 
```

## Validate from Office
```powershell
function Get-TodayDateString {
    $dateString = Get-Date -Format "yyyyMMdd"
    return $dateString
}
$today = Get-Date -Format "yyyyMMdd"
$aPass = "${today}Pass!"
$clientIp = "121.101.121.13"

# Run the validation
az deployment sub validate `
    --location japaneast `
    --template-file main.bicep `
    --parameters clientIp=$clientIp adminUsername='auser' adminPassword=$aPass
```

## Deploy

```powershell
function Get-TodayDateString {
    $dateString = Get-Date -Format "yyyyMMdd"
    return $dateString
}

# Example Usage:
$today = Get-TodayDateString
$clientIp = (Invoke-RestMethod -Uri "https://ipinfo.io/ip")

$aPassword = "${today}Pass!"

az deployment sub create `
    --location japaneast `
    --template-file main.bicep `
    --parameters clientIp=$clientIp adminUsername='auser' adminPassword=$aPassword
```

## Deploy from Office

```powershell
function Get-TodayDateString {
    $dateString = Get-Date -Format "yyyyMMdd"
    return $dateString
}

# Example Usage:
$today = Get-TodayDateString

# Add letters, symbols, and ensure length >= 12 (e.g., Admin-$today!)
$aPassword = "${today}Pass!"
$clientIp = "121.101.121.13"

az deployment sub create `
    --location japaneast `
    --template-file main.bicep `
    --parameters clientIp=$clientIp adminUsername='auser' adminPassword=$aPassword
```

* If running from Azure Shell, manually set the client IP variable

```powershell
$ClientIp = "xxx"
```

### Package zip command

* Inside the package or app directory (flask files)

```python
python -c "import os, zipfile; zip_path = '../app.zip'; zipf = zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED); [zipf.write(os.path.relpath(os.path.join(r, f), '.')) for r, d, fs in os.walk('.') for f in fs if os.path.relpath(os.path.join(r, f), '.') != '../app.zip']; zipf.close(); print(f'Successfully created zip at: {os.path.abspath(zip_path)}')"
```

### Flask zip upload (hard-coded)

```powershell
az webapp deploy --name labapp-d3c0 --resource-group testlabapp-d3c0 --src-path app.zip --type zip
```

### Flask zip upload (variables)

```powershell
$subId = az account show --query id --output tsv
$suffix = $subId.Substring($subId.Length - 4)
$rg = "testlabapp-$suffix"
$app = "labapp-$suffix"

az webapp deploy `
  --resource-group $rg `
  --name $app `
  --src-path "app.zip" `
  --type zip
```

## Check service plan tier

* Make sure it is free tier

```powershell
az appservice plan list --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location, Tier:sku.tier, SKU:sku.name, Capacity:sku.capacity}" -o table
```

## Scaling up and down service plans

### B1 tier paid

```powershell
az appservice plan update --name testlab-plan-d3c0 --resource-group testlabapp-d3c0 --sku B1
```

### F1 Tier free

```powershell
az appservice plan update --name testlab-plan-d3c0 --resource-group testlabapp-d3c0 --sku F1
```
## Get Public IP

```powershell
$subscriptionId = az account show --query id -o tsv
$subscriptionSuffix = $subscriptionId.Substring($subscriptionId.Length - 4)

$resourceGroupName = "testLab-$subscriptionSuffix"
$vmName = "test-lab-$subscriptionSuffix"
$publicIpName = "$vmName-pip"

$publicIp = az network public-ip show `
    --resource-group $resourceGroupName `
    --name $publicIpName `
    --query ipAddress `
    --output tsv

Write-Host "VM Public IP: $publicIp"
```

## Remove test VM from Entra records

### Connect to Microsoft Graph

```powershell
Connect-MgGraph -Scopes "Device.ReadWrite.All"
```

### Find the device

```powershell
Get-MgDevice -Filter "displayName eq 'xxx'" |
    Select-Object DisplayName, Id
```

### Remove the device

```powershell
Remove-MgDevice -DeviceId "Id"
```

## List resource groups

```powershell
az group list --output table
```

## Cleanup:

```powershell
az group delete --name ***
```

# Troubleshooting Log

## 🚀 Overview of Issues Encountered & Fixes

During the deployment and configuration of this lab application, several key issues were resolved to ensure stable execution on Linux App Service.

### 1. Malformed Subscription ID
* **Problem:** The `AZURE_SUBSCRIPTION_ID` configuration was incorrectly stored with a `/subscriptions/` prefix, causing malformed ARM API requests.
* **Fix:** Cleaned the setting to contain **only the raw GUID**:
  ```powershell
  az webapp config appsettings set --name labapp-d3c0 --resource-group testlabapp-d3c0 --settings AZURE_SUBSCRIPTION_ID="<your-guid>"
  ```
### 2. Free Tier CPU Quota Exhaustion
* **Problem:** Frequent crash-loops on startup exhausted the Free (`F1`) tier's daily 60-minute CPU execution limit.
* **Fix:** Upgraded the App Service plan temporarily to Basic (`B1`) to remove limits and provide stable build performance:
  ```powershell
  az appservice plan update --name testlab-plan-d3c0 --resource-group testlabapp-d3c0 --sku B1
  ```
### 3. Missing Runtime Dependencies (`ModuleNotFoundError`)
* **Problem:** Azure's Oryx build engine did not automatically compile the virtual environment (`antenv`) or install `requirements.txt` packages from raw zip uploads.
* **Fix:** Enabled remote build automation via app settings and deployed using the standard zip deployment tool:
  ```powershell
  az webapp config appsettings set --name labapp-d3c0 --resource-group testlabapp-d3c0 --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true
  az webapp deploy --name labapp-d3c0 --resource-group testlabapp-d3c0 --src-path ../app.zip --type zip
  ```
### 4. Managed Identity & Azure Permissions
* **Problem:** The app utilizes `DefaultAzureCredential()` to perform actions on Azure VMs, but lacked identity assignment.
* **Fix:** Enabled system-assigned managed identity on the Web App:
  ```powershell
  az webapp identity assign --name labapp-d3c0 --resource-group testlabapp-d3c0
  ```
### 5. Entra ID Authentication (`401 Unauthorized`)
* **Problem:** Code-level security checks look for Easy Auth headers (`X-MS-CLIENT-PRINCIPAL`). Without Microsoft Entra ID configured, the app returns a `401 Authentication Required` message.
* **Fix:** Either configure Microsoft Entra ID (Easy Auth) under the **Authentication** blade in the Azure Portal, or comment out the `require_authentication()` block in `app.py` for direct testing.

---

## 🛠️ Quick Deployment Commands

1. **Set Build Flag:**
   ```powershell
   az webapp config appsettings set --name labapp-d3c0 --resource-group testlabapp-d3c0 --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true
   ```
2. **Deploy Zip Package:**
   ```powershell
   az webapp deploy --name labapp-d3c0 --resource-group testlabapp-d3c0 --src-path ../app.zip --type zip
   ```
3. **Tail Live Logs:**
   ```powershell
   az webapp log tail --name labapp-d3c0 --resource-group testlabapp-d3c0

   # Azure Test Lab — RDP Client IP

## Client IP Problem

RDP connections to the Windows VM failed because the subnet's Network Security Group (NSG) allowed an outdated client IP address.

## Root Cause

The Bicep template creates an inbound rule allowing TCP port `3389` from the `clientIp` parameter:

- NSG: `vnet-testlab-d3c0-nsg`
- Rule: `allow-rdp-client-ip`
- Priority: `100`
- Destination port: `3389/TCP`
- Access: `Allow`
- Previously allowed IP: `23.97.62.121/32`
- Actual PC public IP: `20.210.133.210`

The deployment was run from GitHub Codespaces, so the IP lookup returned the Codespace's public IP instead of the PC's public IP.

**Important:** An IP lookup command returns the public IP of the environment running it. Codespaces and a local Windows PC can have different public IPs.

## Get the Correct Client IP

Run this command in PowerShell on the Windows PC used for RDP, **outside GitHub Codespaces**:

```powershell
$clientIp = (Invoke-RestMethod -Uri "https://ipinfo.io/ip").Trim()
$clientIp
```

## Deploy with the Correct IP

Pass the PC's public IP to the Bicep deployment:

```powershell
az deployment sub create --location japaneast --template-file main.bicep --parameters location=japaneast subscriptionSuffix=d3c0 clientIp=20.210.133.210
```

Replace the IP with the current value returned by the lookup command. Ensure the template path and other parameters match your deployment.

## Verify the NSG Rule

```powershell
az network nsg rule show --resource-group testlab-d3c0 --nsg-name vnet-testlab-d3c0-nsg --name allow-rdp-client-ip --query "{Source:sourceAddressPrefix,Port:destinationPortRange,Access:access}" -o table
```

The source should match the PC's current public IP, followed by `/32`.

## Security Notes

- Restrict RDP access to your own public IP using `/32`.
- Do not use `Any IP` for permanent RDP access.
- If your public IP changes, update the `clientIp` parameter and redeploy.
- If RDP still fails with the correct IP, check the VM's NIC-level NSG, effective security rules, public IP assignment, and Windows RDP configuration.
