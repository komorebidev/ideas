param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupNamePatterns,

    [Parameter(Mandatory = $true)]
    [bool]$DryRun,

    [Parameter(Mandatory = $true)]
    [string]$ExcludedResourceGroupName
)

$ErrorActionPreference = 'Stop'

Disable-AzContextAutosave -Scope Process | Out-Null
$context = (Connect-AzAccount -Identity).Context
Set-AzContext -SubscriptionId $context.Subscription.Id -DefaultProfile $context | Out-Null

$patterns = $ResourceGroupNamePatterns -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$resourceGroups = Get-AzResourceGroup

$targets = @($resourceGroups | Where-Object {
    $name = $_.ResourceGroupName

    if ($name -eq $ExcludedResourceGroupName) {
        return $false
    }

    foreach ($pattern in $patterns) {
        if ($name -like $pattern) {
            return $true
        }
    }

    return $false
})

if ($targets.Count -eq 0) {
    Write-Output 'No resource groups matched the configured patterns.'
    return
}

foreach ($target in $targets) {
    if ($DryRun) {
        Write-Output "DRY RUN: would delete resource group '$($target.ResourceGroupName)'."
        continue
    }

    Write-Output "Deleting resource group '$($target.ResourceGroupName)'."
    Remove-AzResourceGroup -Name $target.ResourceGroupName -Force -AsJob
}