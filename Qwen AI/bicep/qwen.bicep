
param location string
param subscriptionSuffix string
param adminUsername string

@secure()
param adminPassword string

param subnetId string

@description('Azure VM size: 2 vCPUs and 8 GiB RAM.')
param vmSize string = 'Standard_B2as_v2'

@description('OS disk size in GB.')
param osDiskSizeGB int = 50

@description('Persistent AI data disk size in GB.')
param dataDiskSizeGB int = 100

var vmName = 'qwen-${subscriptionSuffix}'
var nicName = '${vmName}-nic'
var publicIpName = '${vmName}-pip'
var dataDiskName = '${vmName}-data'

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

  // Rocky Linux Marketplace plan
  plan: {
    name: '9-base'
    product: 'rockylinux-x86_64'
    publisher: 'resf'
  }

  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }

    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword

      linuxConfiguration: {
        provisionVMAgent: true
        disablePasswordAuthentication: false
      }

      customData: base64(loadTextContent('cloud-init.yaml'))
    }

    storageProfile: {
      imageReference: {
        publisher: 'resf'
        offer: 'rockylinux-x86_64'
        sku: '9-base'
        version: 'latest'
      }

      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: osDiskSizeGB
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }

      dataDisks: [
        {
          lun: 0
          name: dataDiskName
          createOption: 'Empty'
          diskSizeGB: dataDiskSizeGB
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
      ]
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

output vmName string = vm.name
output vmPublicIpAddress string = publicIp.properties.ipAddress
output vmPrivateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output osDiskSizeGB int = osDiskSizeGB
output dataDiskSizeGB int = dataDiskSizeGB