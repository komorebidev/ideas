param location string
param subscriptionSuffix string
param adminUsername string

@secure()
param adminPassword string

param subnetId string

param postgresHostname string
param postgresAdministratorLogin string

@secure()
param postgresAdministratorPassword string

param guacamolePostgresUsername string

@secure()
param guacamolePostgresPassword string

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
      vmSize: 'Standard_B4as_v2'
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
    settings: {
      // Correct built-in Bicep function combination for embedding script content
      script: base64(loadTextContent('requirements.ps1'))
    }
    protectedSettings: {
      // Securely pass parameters directly to the script block natively
      parameters: {
        PostgresHostname: postgresHostname
        PostgresAdministratorLogin: postgresAdministratorLogin
        PostgresAdministratorPassword: postgresAdministratorPassword
        GuacamolePostgresUsername: guacamolePostgresUsername
        GuacamolePostgresPassword: guacamolePostgresPassword
      }
    }
  }
}

resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: '00:00'
    }
    timeZoneId: 'Tokyo Standard Time'
    targetResourceId: vm.id
  }
}

output vmPrivateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress