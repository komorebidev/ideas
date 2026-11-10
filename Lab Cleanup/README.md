# Nightly Azure Resource Group Cleanup

Schedule: every night at 19:00 Japan Standard Time (`Japan Standard Time`).

## Important
- Deployment defaults to `dryRun = false`: matching resource groups are deleted.
- Keep the Automation Account's containing resource group excluded from all cleanup patterns.
- The Automation Account's managed identity receives subscription-level `Contributor` in this initial template. This is broad authority; use a custom role if you want narrower permissions.
- Bicep provisions the Automation Account, runbook resource, schedule, job association, and role assignment. The local PowerShell runbook content must be imported and published separately after deployment.

## Deploy
```bash
az deployment sub create \
  --location japaneast \
  --template-file main.bicep \
  --parameters cleanupResourceGroupName=rg-nightly-cleanup \
               automationAccountName=aa-nightly-rg-cleanup \
               resourceGroupNamePatterns='["testlab-*","natgw-lab-*"]' \
               dryRun=false
```

## Manual import and publish the script
In Azure Portal, open Automation Account `aa-nightly-rg-cleanup` -> Runbooks -> `NightlyResourceGroupCleanup`, edit/import the content from `runbook.ps1`, then Publish. Make sure Az.Accounts and Az.Resources modules are available in the Automation Account runtime environment.

## Validate
Run the runbook manually with dry-run enabled and inspect its output. After confirming the precise matches, redeploy with `dryRun=false`.

## Files
- `main.bicep`: subscription-scope entry point, cleanup resource group, and subscription RBAC
- `automation.bicep`: Automation Account, runbook metadata, schedule, and job association
- `runbook.ps1`: wildcard matching and cleanup execution