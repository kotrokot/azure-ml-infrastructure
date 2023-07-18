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
    storage: {
        resourceName: take('${toLower(replace(resourceNameSuffix, '-', ''))}st${uniqueString(resourceGroup().id)}', 24)
        SkuName: 'Standard_LRS'
    }
    storagePrivateEndpointBlob: {
        resourceName: '${resourceNameSuffix}-pe-st-blob'
    }
    storagePrivateEndpointFile: {
        resourceName: '${resourceNameSuffix}-pe-st-file'
    }
    blobPrivateDnsZone: {
        resourceName: 'privatelink.blob.${environment().suffixes.storage}'
    }
    blobPrivateDnsZoneGroup: {
        resourceName: 'blob-PrivateDnsZoneGroup'
    }
    blobPrivateDnsZoneVnetLink: {}
    filePrivateDnsZone: {
        resourceName: 'privatelink.file.${environment().suffixes.storage}'
    }
    filePrivateDnsZoneGroup: {
        resourceName: 'file-PrivateDnsZoneGroup'
    }
    filePrivateDnsZoneVnetLink: {}
}
var tags = {
    resourceSuffix: resourceNameSuffix
}

// Storage
resource storage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
    name: config.storage.resourceName
    location: location
    tags: tags
    sku: {
        name: config.storage.SkuName
    }
    kind: 'StorageV2'
    properties: {
        accessTier: 'Hot'
        allowBlobPublicAccess: false
        allowCrossTenantReplication: false
        allowSharedKeyAccess: true
        encryption: {
            keySource: 'Microsoft.Storage'
            requireInfrastructureEncryption: false
            services: {
                blob: {
                    enabled: true
                    keyType: 'Account'
                }
                file: {
                    enabled: true
                    keyType: 'Account'
                }
                queue: {
                    enabled: true
                    keyType: 'Service'
                }
                table: {
                    enabled: true
                    keyType: 'Service'
                }
            }
        }
        isHnsEnabled: false
        isNfsV3Enabled: false
        keyPolicy: {
            keyExpirationPeriodInDays: 7
        }
        largeFileSharesState: 'Disabled'
        minimumTlsVersion: 'TLS1_2'
        networkAcls: {
            bypass: 'AzureServices'
            defaultAction: 'Deny'
        }
        supportsHttpsTrafficOnly: true
    }
}
// Storage Blob privateEndpoint
resource storagePrivateEndpointBlob 'Microsoft.Network/privateEndpoints@2022-01-01' = {
    name: config.storagePrivateEndpointBlob.resourceName
    location: location
    tags: tags
    properties: {
        privateLinkServiceConnections: [
            {
                name: config.storagePrivateEndpointBlob.resourceName
                properties: {
                    groupIds: [
                        'blob'
                    ]
                    privateLinkServiceId: storage.id
                    privateLinkServiceConnectionState: {
                        status: 'Approved'
                        description: 'Auto-Approved'
                        actionsRequired: 'None'
                    }
                }
            }
        ]
        subnet: {
            id: subnetId
        }
    }
}
// Storage Blob Private DNS Zone
resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
    name: config.blobPrivateDnsZone.resourceName
    location: 'global'
}
// Storage Blob Private Dns Zone Group
resource blobPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
    name: config.blobPrivateDnsZoneGroup.resourceName
    parent: storagePrivateEndpointBlob
    properties: {
        privateDnsZoneConfigs: [
            {
                name: blobPrivateDnsZone.name
                properties: {
                    privateDnsZoneId: blobPrivateDnsZone.id
                }
            }
        ]
    }
}
// Storage Blob vNet Link
resource blobPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
    name: uniqueString(storage.id)
    parent: blobPrivateDnsZone
    location: 'global'
    properties: {
        registrationEnabled: false
        virtualNetwork: {
            id: vNetId
        }
    }
}
// Storage File privateEndpoint
resource storagePrivateEndpointFile 'Microsoft.Network/privateEndpoints@2022-01-01' = {
    name: config.storagePrivateEndpointFile.resourceName
    location: location
    tags: tags
    properties: {
        privateLinkServiceConnections: [
            {
                name: config.storagePrivateEndpointFile.resourceName
                properties: {
                    groupIds: [
                        'file'
                    ]
                    privateLinkServiceId: storage.id
                    privateLinkServiceConnectionState: {
                        status: 'Approved'
                        description: 'Auto-Approved'
                        actionsRequired: 'None'
                    }
                }
            }
        ]
        subnet: {
            id: subnetId
        }
    }
}
// Storage File Private DNS Zone
resource filePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
    name: config.filePrivateDnsZone.resourceName
    location: 'global'
}
// Storage File Private Dns Zone Group
resource filePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
    name: config.filePrivateDnsZoneGroup.resourceName
    parent: storagePrivateEndpointFile
    properties: {
        privateDnsZoneConfigs: [
            {
                name: filePrivateDnsZone.name
                properties: {
                    privateDnsZoneId: filePrivateDnsZone.id
                }
            }
        ]
    }
}
// Storage File vNet Link
resource filePrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
    name: uniqueString(storage.id)
    parent: filePrivateDnsZone
    location: 'global'
    properties: {
        registrationEnabled: false
        virtualNetwork: {
            id: vNetId
        }
    }
}

output storageId string = storage.id
