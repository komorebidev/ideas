targetScope = 'subscription'

@description('Name of the disposable lab resource group.')
param labResourceGroupName string

var roleGuid = guid(subscription().id, labResourceGroupName, 'TestLabVmControl')

resource labVmControlRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleGuid
  properties: {
    roleName: 'Test Lab VM Control ${uniqueString(labResourceGroupName)}'
    description: 'Start, stop, restart, and view virtual machines in the lab.'
    type: 'CustomRole'
    assignableScopes: [
      subscription().id
    ]
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/instanceView/read'
          'Microsoft.Compute/virtualMachines/start/action'
          'Microsoft.Compute/virtualMachines/powerOff/action'
          'Microsoft.Compute/virtualMachines/deallocate/action'
          'Microsoft.Compute/virtualMachines/restart/action'
          'Microsoft.Network/networkInterfaces/read'
          'Microsoft.Network/publicIPAddresses/read'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
  }
}

output roleDefinitionId string = labVmControlRole.id
