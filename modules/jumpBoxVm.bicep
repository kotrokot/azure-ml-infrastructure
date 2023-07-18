@maxLength(14)
@description('Suffix to the names of the resources.')
param resourceNameSuffix string

@description('The ID of the subnet from which the private IP will be allocated.')
param subnetId string

@description('The ID of the Network Security Group.')
param nsgId string

@description('Virtual machine admin username')
param adminUsername string = 'userA'

@secure()
@minLength(8)
@description('Virtual machine admin password')
param adminPassword string

@description('Use false for develompment environments. Wont be used strict settings')
param isProductionEnvironment bool = false //true

param location string = resourceGroup().location

var config = {
  bastion: {
    resourceName: '${resourceNameSuffix}-bastion'
  }
  pip: {
    resourceName: '${resourceNameSuffix}-bastion-pip'
  }
  vm: {
    resourceName: '${resourceNameSuffix}-vm'
    vmSize: 'Standard_DS3_v2'
    storageAccountType: 'Standard_HDD'
  }
  nic: {
    resourceName: '${resourceNameSuffix}-vm-nic'
  }
}
var tags = {
  resourceSuffix: resourceNameSuffix
}
// Public IP
resource pip 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: config.pip.resourceName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}
// Bastion
resource bastion 'Microsoft.Network/bastionHosts@2022-01-01' = {
  name: config.bastion.resourceName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
  }
}
// Nic
resource nic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: config.nic.resourceName
  location: location
  tags: tags
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
    networkSecurityGroup: {
      id: nsgId
    }
  }
}
// VM
resource vm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: config.vm.resourceName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: config.vm.vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: config.vm.storageAccountType
        }
      }
      imageReference: {
        publisher: 'microsoft-dsvm'
        offer: 'dsvm-win-2019'
        sku: 'server-2019'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    osProfile: {
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          enableHotpatching: false
          patchMode: 'AutomaticByOS'
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}
// AAD Login Extention
resource aadLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: 'AADLoginForWindows'
  parent: vm
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

output dsvmId string = vm.id
