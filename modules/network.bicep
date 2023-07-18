@maxLength(14)
@description('Suffix to the names of the resources.')
param resourceNameSuffix string

@description('Use false for develompment environments. Wont be used strict settings')
param isProductionEnvironment bool = false //true

@maxValue(254)
@description('Environment network identifier is used as part of network address space: 10.x.0.0/16')
param networkIdentifier int = 0

param location string = resourceGroup().location

var config = {
    vnet: {
        resourceName: '${resourceNameSuffix}-vNet'
        addressPrefix: format('10.{0}.0.0/16', networkIdentifier)
    }
    subnetCompute: {
        resourceName: 'ComputeSubnet'
        addressPrefix: format('10.{0}.128.0/17', networkIdentifier)
    }
    subnetBastion: {
        resourceName: 'AzureBastionSubnet'
        addressPrefix: format('10.{0}.2.0/24', networkIdentifier)
    }
    nsg: {
        resourceName: '${resourceNameSuffix}-nsgCompute'
    }
}
var tags = {
    resourceSuffix: resourceNameSuffix
}
// Network
resource vNet 'Microsoft.Network/virtualNetworks@2021-03-01' = {
    name: config.vnet.resourceName
    location: location
    tags: tags
    properties: {
        addressSpace: {
            addressPrefixes: [
                config.vnet.addressPrefix
            ]
        }
        subnets: [
            {
                name: config.subnetCompute.resourceName
                properties: {
                    addressPrefix: config.subnetCompute.addressPrefix
                    privateEndpointNetworkPolicies: 'Disabled'
                    serviceEndpoints: [
                        {
                            service: 'Microsoft.KeyVault'
                        }
                        {
                            service: 'Microsoft.ContainerRegistry'
                        }
                        {
                            service: 'Microsoft.Storage'
                        }
                    ]
                    networkSecurityGroup: {
                        id: nsg.id
                    }
                }
            }
            {
                name: config.subnetBastion.resourceName
                properties: {
                    addressPrefix: config.subnetBastion.addressPrefix
                }
            }
        ]
    }
    resource subnetCompute 'subnets' existing = {
        name: config.subnetCompute.resourceName
    }
    resource subnetBastion 'subnets' existing = {
        name: config.subnetBastion.resourceName
    }
}
// NSG
resource nsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
    name: config.nsg.resourceName
    location: location
    tags: tags
    properties: {
        securityRules: [
            {
                name: 'BatchNodeManagement'
                properties: {
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    destinationPortRange: '29876-29877'
                    sourceAddressPrefix: 'BatchNodeManagement'
                    destinationAddressPrefix: '*'
                    access: 'Allow'
                    priority: 120
                    direction: 'Inbound'
                }
            }
            {
                name: 'AzureMachineLearning'
                properties: {
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    destinationPortRange: '44224'
                    sourceAddressPrefix: 'AzureMachineLearning'
                    destinationAddressPrefix: '*'
                    access: 'Allow'
                    priority: 130
                    direction: 'Inbound'
                }
            }
            {
                name: 'AzureActiveDirectory'
                properties: {
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    destinationPortRange: '*'
                    sourceAddressPrefix: '*'
                    destinationAddressPrefix: 'AzureActiveDirectory'
                    access: 'Allow'
                    priority: 140
                    direction: 'Outbound'
                }
            }
            {
                name: 'AzureMachineLearningOutbound'
                properties: {
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    destinationPortRange: '443'
                    sourceAddressPrefix: '*'
                    destinationAddressPrefix: 'AzureMachineLearning'
                    access: 'Allow'
                    priority: 150
                    direction: 'Outbound'
                }
            }
            {
                name: 'AzureResourceManager'
                properties: {
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    destinationPortRange: '443'
                    sourceAddressPrefix: '*'
                    destinationAddressPrefix: 'AzureResourceManager'
                    access: 'Allow'
                    priority: 160
                    direction: 'Outbound'
                }
            }
            {
                name: 'AzureStorageAccount'
                properties: {
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    destinationPortRange: '443'
                    sourceAddressPrefix: '*'
                    destinationAddressPrefix: 'Storage.${location}'
                    access: 'Allow'
                    priority: 170
                    direction: 'Outbound'
                }
            }
            {
                name: 'AzureFrontDoor'
                properties: {
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    destinationPortRange: '443'
                    sourceAddressPrefix: '*'
                    destinationAddressPrefix: 'AzureFrontDoor.FrontEnd'
                    access: 'Allow'
                    priority: 180
                    direction: 'Outbound'
                }
            }
            {
                name: 'AzureContainerRegistry'
                properties: {
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    destinationPortRange: '443'
                    sourceAddressPrefix: '*'
                    destinationAddressPrefix: 'AzureContainerRegistry.${location}'
                    access: 'Allow'
                    priority: 190
                    direction: 'Outbound'
                }
            }
            {
                name: 'MicrosoftContainerRegistry'
                properties: {
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    destinationPortRange: '443'
                    sourceAddressPrefix: 'VirtualNetwork'
                    destinationAddressPrefix: 'MicrosoftContainerRegistry'
                    access: 'Allow'
                    priority: 200
                    direction: 'Outbound'
                }
            }
        ]
    }
}

output vNetId string = vNet.id
output subnetComputeId string = vNet::subnetCompute.id
output subnetBastionId string = vNet::subnetBastion.id
output nsgId string = nsg.id
