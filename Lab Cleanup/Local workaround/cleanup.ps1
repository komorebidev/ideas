$resourceGroupNamePatterns = @(
    'lab*'
)

# $excludedResourceGroupName = 'rg-nightly-cleanup'
$dryRun = $false

# Entra App Registration
$tenantId = 'b021614f-bc20-4b53-b919-2a753834fa6f'
$appId = '755ca023-4e03-4586-9493-0414afb1f2fa'
$thumbprint = '83C7A2A516AFA858653EE1DBBB0CB3A5E63172AD'
$subscriptionId = '89ca3363-489e-48b8-b449-f61c1069d3c0'

# Authenticate using certificate
Connect-AzAccount `
    -ServicePrincipal `
    -Tenant $tenantId `
    -ApplicationId $appId `
    -CertificateThumbprint $thumbprint

# Select subscription
Set-AzContext -SubscriptionId $subscriptionId

# Find matching resource groups
$resourceGroups = Get-AzResourceGroup

foreach ($rg in $resourceGroups) {

    if ($rg.ResourceGroupName -eq $excludedResourceGroupName) {
        continue
    }

    $matchesPattern = $false

    foreach ($pattern in $resourceGroupNamePatterns) {
        if ($rg.ResourceGroupName -like $pattern) {
            $matchesPattern = $true
            break
        }
    }

    if (-not $matchesPattern) {
        continue
    }

    if ($dryRun) {
        Write-Host "DRY RUN: Would delete $($rg.ResourceGroupName)" -ForegroundColor Yellow
    }
    else {
        Write-Host "Deleting $($rg.ResourceGroupName)" -ForegroundColor Red

        Remove-AzResourceGroup `
            -Name $rg.ResourceGroupName `
            -Force
    }
}