targetScope = 'resourceGroup'

param location string
param automationAccountName string
param resourceGroupNamePatterns array
param scheduleTime string
param dryRun bool
param excludedResourceGroupName string

resource automation 'Microsoft.Automation/automationAccounts@2024-10-23' = {
  name: automationAccountName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
    publicNetworkAccess: true
  }
}

resource automationContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(automation.id, deploymentScript.identity.principalId, 'automation-contributor')
  scope: automation
  properties: {
    principalId: deploymentScript.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f353d9bd-d4a6-484e-a77a-8050b599b867')
  }
}

resource cleanupContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, automation.identity.principalId, 'subscription-contributor')
  scope: subscription()
  properties: {
    principalId: automation.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  }
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'configureNightlyCleanupAutomation'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    azPowerShellVersion: '13.0'
    scriptContent: '''
      $ErrorActionPreference = 'Stop'
      $accountName = '${automationAccountName}'
      $automationResourceGroup = '${resourceGroup().name}'
      $runbookName = 'NightlyResourceGroupCleanup'
      $runbookContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64(loadTextContent('runbook.ps1'))}'))
      $scriptPath = Join-Path $env:TEMP 'NightlyResourceGroupCleanup.ps1'
      Set-Content -Path $scriptPath -Value $runbookContent -Encoding utf8

      Import-AzAutomationRunbook -AutomationAccountName $accountName -ResourceGroupName $automationResourceGroup -Name $runbookName -Type PowerShell -Path $scriptPath -Force
      Publish-AzAutomationRunbook -AutomationAccountName $accountName -ResourceGroupName $automationResourceGroup -Name $runbookName

      $scheduleName = 'NightlyAt1900JST'
      $schedule = Get-AzAutomationSchedule -AutomationAccountName $accountName -ResourceGroupName $automationResourceGroup -Name $scheduleName -ErrorAction SilentlyContinue
      if ($null -eq $schedule) {
        $tokyo = [System.TimeZoneInfo]::FindSystemTimeZoneById('Tokyo Standard Time')
        $nowJst = [System.TimeZoneInfo]::ConvertTime([DateTimeOffset]::UtcNow, $tokyo)
        $startTime = $nowJst.Date.AddDays(1).AddHours(19)
        New-AzAutomationSchedule -AutomationAccountName $accountName -ResourceGroupName $automationResourceGroup -Name $scheduleName -StartTime $startTime -TimeZone 'Japan Standard Time' -DayInterval 1 -Description 'Nightly cleanup at 19:00 JST'
      }

      $association = Get-AzAutomationScheduledRunbook -AutomationAccountName $accountName -ResourceGroupName $automationResourceGroup -RunbookName $runbookName -ErrorAction SilentlyContinue
      if ($null -eq $association) {
        $parameters = @{
          ResourceGroupNamePatterns = '${join(resourceGroupNamePatterns, ',')}'
          DryRun = [bool]::Parse('${string(dryRun)}')
          ExcludedResourceGroupName = '${excludedResourceGroupName}'
        }
        Register-AzAutomationScheduledRunbook -AutomationAccountName $accountName -ResourceGroupName $automationResourceGroup -RunbookName $runbookName -ScheduleName $scheduleName -Parameters $parameters
      }
    '''
    timeout: 'PT45M'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
  dependsOn: [
    automationContributorRole
    cleanupContributorRole
  ]
}

output automationAccountName string = automation.name
output automationPrincipalId string = automation.identity.principalId