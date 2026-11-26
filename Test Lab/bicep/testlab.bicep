param location string
param subscriptionSuffix string
param adminUsername string

@secure()
param adminPassword string

param subnetId string

var vmName = 'labvm-${subscriptionSuffix}'
var nicName = '${vmName}-nic'
var publicIpName = '${vmName}-pip'

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIpName
  location: location

  sku: {
    name: 'Standard'
  }

  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

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
      vmSize: 'Standard_B2ps_v2'
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
        publisher: 'microsoftwindowsdesktop'
        offer: 'windows11preview-arm64'
        sku: 'win11-22h2-ent'
        version: 'latest'
      }

      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
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

// Auto-shutdown configuration for 19:00 Japan Time
resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: '1900'
    }
    timeZoneId: 'Tokyo Standard Time'
    targetResourceId: vm.id
    notificationSettings: {
      status: 'Disabled'
    }
  }
}

output vmPublicIpAddress string = publicIp.properties.ipAddress
output vmPrivateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output vmName string = vmName
output adminUsername string = adminUsername
@secure()
output adminPassword string = adminPassword