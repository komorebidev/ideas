$resourceGroupNamePatterns = @(
    'lab*'
)

$dryRun = $false

# Entra App Registration
$tenantId = 'b021614f-bc20-4b53-b919-2a753834fa6f'
$appId = '755ca023-4e03-4586-9493-0414afb1f2fa'
$thumbprint = '83C7A2A516AFA858653EE1DBBB0CB3A5E63172AD'
$subscriptionId = '89ca3363-489e-48b8-b449-f61c1069d3c0'

# Authenticate
Connect-AzAccount `
    -ServicePrincipal `
    -Tenant $tenantId `
    -ApplicationId $appId `
    -CertificateThumbprint $thumbprint `
    -ErrorAction Stop

Set-AzContext -SubscriptionId $subscriptionId -ErrorAction Stop

# Find matching resource groups
$resourceGroups = Get-AzResourceGroup -ErrorAction Stop
$matchedResourceGroups = @(
    $resourceGroups | Where-Object {
        $resourceGroupName = $_.ResourceGroupName

        foreach ($pattern in $resourceGroupNamePatterns) {
            if ($resourceGroupName -like $pattern) {
                return $true
            }
        }

        return $false
    }
)

# Summary counters
$deleted = @()
$failed = @()

Write-Host ""
Write-Host "Starting resource group cleanup..." -ForegroundColor Cyan

if ($matchedResourceGroups.Count -eq 0) {
    Write-Host "No resource groups matched the configured patterns." -ForegroundColor Yellow
}
else {
    foreach ($rg in $matchedResourceGroups) {

        if ($dryRun) {
            Write-Host "DRY RUN: Would delete $($rg.ResourceGroupName)" -ForegroundColor Yellow
            continue
        }

        Write-Host "Deleting: $($rg.ResourceGroupName)" -ForegroundColor Cyan

        try {
            Remove-AzResourceGroup `
                -Name $rg.ResourceGroupName `
                -Force `
                -ErrorAction Stop

            $deleted += $rg.ResourceGroupName
            Write-Host "Deleted: $($rg.ResourceGroupName)" -ForegroundColor Green
        }
        catch {
            $failed += $rg.ResourceGroupName
            Write-Host "FAILED: $($rg.ResourceGroupName) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Final summary
Write-Host ""
Write-Host "========== CLEANUP SUMMARY ==========" -ForegroundColor Cyan

if ($dryRun) {
    Write-Host "Dry run completed. No resource groups were deleted."
}
else {
    Write-Host "Successfully deleted: $($deleted.Count)"
    foreach ($name in $deleted) {
        Write-Host "  - $name" -ForegroundColor Green
    }

    Write-Host "Failed deletions: $($failed.Count)"
    foreach ($name in $failed) {
        Write-Host "  - $name" -ForegroundColor Red
    }

    if ($matchedResourceGroups.Count -eq 0) {
        Write-Host "Result: Nothing matched. Nothing was deleted." -ForegroundColor Yellow
    }
    elseif ($deleted.Count -eq 0 -and $failed.Count -gt 0) {
        Write-Host "Result: No resource groups were successfully deleted." -ForegroundColor Red
    }
    elseif ($failed.Count -eq 0) {
        Write-Host "Result: Cleanup completed successfully." -ForegroundColor Green
    }
    else {
        Write-Host "Result: Cleanup completed with some failures." -ForegroundColor Yellow
    }
}

Write-Host "=====================================" -ForegroundColor Cyan