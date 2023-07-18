@maxLength(14)
@description('Suffix to the names of the resources.')
param resourceNameSuffix string

@description('The reference of the virtual network.')
param vNetId string

@description('The ID of the subnet from which the private IP will be allocated.')
param subnetId string

@description('Use false for develompment environments. Wont be used strict settings')
param isProductionEnvironment bool = false //true

param location string = resourceGroup().location

var config = {
    keyVault: {
        resourceName: take('${resourceNameSuffix}kv${uniqueString(resourceGroup().id)}', 24)
    }
    keyVaultPrivateEndpoint: {
        resourceName: '${resourceNameSuffix}-pe-kv'
    }
    keyVaultPrivateDnsZone: {
        resourceName: 'privatelink${environment().suffixes.keyvaultDns}'
    }
    keyVaultPrivateDnsZoneGroup: {
        resourceName: 'vault-PrivateDnsZoneGroup'
    }
    keyVaultPrivateDnsZoneVnetLink: {}
}
var tags = {
    resourceSuffix: resourceNameSuffix
}
// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
    name: config.keyVault.resourceName
    location: location
    tags: tags
    properties: {
        createMode: 'default'
        enabledForDeployment: false
        enabledForDiskEncryption: false
        enabledForTemplateDeployment: false
        enableSoftDelete: true
        enableRbacAuthorization: true
        enablePurgeProtection: true
        networkAcls: {
            bypass: 'AzureServices'
            defaultAction: 'Deny'
        }
        sku: {
            family: 'A'
            name: 'standard'
        }
        softDeleteRetentionInDays: 7
        tenantId: subscription().tenantId
    }
}
// Key Vault Private Endpoint
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
    name: config.keyVaultPrivateEndpoint.resourceName
    location: location
    tags: tags
    properties: {
        privateLinkServiceConnections: [
            {
                name: config.keyVaultPrivateEndpoint.resourceName
                properties: {
                    groupIds: [
                        'vault'
                    ]
                    privateLinkServiceId: keyVault.id
                }
            }
        ]
        subnet: {
            id: subnetId
        }
    }
}
// Key Vault Private Dns Zone
resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
    name: config.keyVaultPrivateDnsZone.resourceName
    location: 'global'
}
// Key Vault Private Dns Zone Group
resource keyVaultPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
    name: config.keyVaultPrivateDnsZoneGroup.resourceName
    parent: keyVaultPrivateEndpoint
    properties: {
        privateDnsZoneConfigs: [
            {
                name: keyVaultPrivateDnsZone.name
                properties: {
                    privateDnsZoneId: keyVaultPrivateDnsZone.id
                }
            }
        ]
    }
}
// Key Vault vNet Link
resource keyVaultPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
    name: uniqueString(keyVault.id)
    location: 'global'
    parent: keyVaultPrivateDnsZone
    properties: {
        registrationEnabled: false
        virtualNetwork: {
            id: vNetId
        }
    }
}

output keyvaultId string = keyVault.id
