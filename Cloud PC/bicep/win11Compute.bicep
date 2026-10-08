param location string
param subscriptionSuffix string
param adminUsername string

@secure()
param adminPassword string

param subnetId string

var vmName = 'win11VM-${subscriptionSuffix}'
var nicName = '${vmName}-nic'

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: nicName
  location: location

  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'

        properties: {
          subnet: {
            id: subnetId
          }

          privateIPAllocationMethod: 'Dynamic'

          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vmName
  location: location

  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B4as_v2' // 4vcpu, 16gb ram 1日に約６００円
    }

    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword

      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }

    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-11'
        sku: 'win11-24h2-ent'
        version: 'latest'
      }

      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        diskSizeGB: 127
      }
    }

    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource requirementsExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: vm
  name: 'requirementsInstall'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'powershell.exe -NonInteractive -ExecutionPolicy Unrestricted -Command "$scriptBytes = [System.Convert]::FromBase64String(\'${loadFileAsBase64('requirements.ps1')}\'); [System.IO.Directory]::CreateDirectory(\'C:\\temp\') | Out-Null; [System.IO.File]::WriteAllBytes(\'C:\\temp\\requirements.ps1\', $scriptBytes); & \'C:\\temp\\requirements.ps1\'"'
    }
  }
}

resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShudownTask'
    dailyRecurrence: {
      time: '00:00' // Midnight (12:00 AM)
    }
    timeZoneId: 'Tokyo Standard Time'
    targetResourceId: vm.id
  }
}

output vmPrivateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress