# bicep

* Run documentation

## Summary


### Azure Qwen AI Lab

Deploy a Rocky Linux VM on Azure running Ollama with Qwen 3 4B and Open WebUI, accessible remotely through Tailscale Funnel.

- **Infrastructure:** Azure Bicep, deployed to Korea Central.
- **VM:** 2 vCPUs, 8 GiB RAM.
- **Storage:** 50 GB OS disk + 100 GB persistent data disk for models and Open WebUI data.
- **Access:** Tailscale Funnel; no custom domain required.
- **Naming:** Resource names use the last four characters of the Azure subscription ID.
- **Deployment:** Reprovision infrastructure using `main.bicep`.

## Accept marketplace terms

```powershell
az vm image terms accept --urn resf:rockylinux-x86_64:9-base:latest
```

## Run command

```powershell
az deployment sub create --location koreacentral --template-file main.bicep --parameters adminUsername=qwenuser adminPassword=xxx
```

## Networking

* No rules were applied
* Access it using Bastion

## Cleanup:

```powershell
az group delete --name qwen-6411
```

## Creating Entra applications for SSO

```powershell
# ============================================================
# Open WebUI - Microsoft Entra ID SSO
# ============================================================

$displayName = "qwen-open-webui-sso"

# Replace with the actual HTTPS URL provided by Tailscale Funnel.
$openWebUIUrl = "https://YOUR-TAILSCALE-FUNNEL-HOSTNAME"

$redirectUri = "$openWebUIUrl/oauth/oidc/callback"

# ------------------------------------------------------------
# 1. Create app registration
# ------------------------------------------------------------

$appregID = az ad app create `
    --display-name $displayName `
    --sign-in-audience AzureADMyOrg `
    --web-redirect-uris $redirectUri `
    --query appId -o tsv

if (-not $appregID) {
    throw "Failed to create Entra app registration."
}

Write-Host "Application (client) ID: $appregID"

# ------------------------------------------------------------
# 2. Get tenant ID
# ------------------------------------------------------------

$tenantID = az account show --query tenantId -o tsv

Write-Host "Tenant ID: $tenantID"

# ------------------------------------------------------------
# 3. Create enterprise application / service principal
# ------------------------------------------------------------

az ad sp create --id $appregID

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create service principal."
}

Write-Host "Enterprise application created."

# ------------------------------------------------------------
# 4. Generate client secret
# ------------------------------------------------------------

$generateappregSecret = az ad app credential reset `
    --id $appregID `
    --display-name "qwen-open-webui-secret" `
    --years 1 `
    --query password -o tsv

if (-not $generateappregSecret) {
    throw "Failed to generate client secret."
}

Write-Host "Client secret generated. Store it securely."
Write-Host "Do not commit the secret to GitHub."

# ------------------------------------------------------------
# 5. Display configuration for Open WebUI
# ------------------------------------------------------------

Write-Host ""
Write-Host "===== Open WebUI SSO configuration ====="
Write-Host "Tenant ID:      $tenantID"
Write-Host "Client ID:      $appregID"
Write-Host "Client Secret:  (store securely)"
Write-Host "Issuer URL:     https://login.microsoftonline.com/$tenantID/v2.0"
Write-Host "Redirect URI:   $redirectUri"
```
