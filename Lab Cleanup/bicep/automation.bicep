targetScope = 'resourceGroup'

param location string
param automationAccountName string
param resourceGroupNamePatterns array
param scheduleStartTime string
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

resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2024-10-23' = {
  parent: automation
  name: 'NightlyResourceGroupCleanup'
  location: location
  properties: {
    runbookType: 'PowerShell'
    description: 'Deletes resource groups matching configured wildcard patterns. Supports dry-run mode.'
    logProgress: true
    logVerbose: true
  }
}

resource schedule 'Microsoft.Automation/automationAccounts/schedules@2024-10-23' = {
  parent: automation
  name: 'NightlyAt1900JST'
  properties: {
    description: 'Nightly cleanup at 19:00 Japan Standard Time'
    startTime: scheduleStartTime
    timeZone: 'Japan Standard Time'
    frequency: 'Day'
    interval: 1
  }
}

resource jobSchedule 'Microsoft.Automation/automationAccounts/jobSchedules@2024-10-23' = {
  parent: automation
  name: guid(automation.id, runbook.name, schedule.name)
  properties: {
    runbook: {
      name: runbook.name
    }
    schedule: {
      name: schedule.name
    }
    parameters: {
      ResourceGroupNamePatterns: join(resourceGroupNamePatterns, ',')
      DryRun: string(dryRun)
      ExcludedResourceGroupName: excludedResourceGroupName
    }
  }
}

output principalId string = automation.identity.principalId