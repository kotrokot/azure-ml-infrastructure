@maxLength(14)
@description('Suffix to the names of the resources.')
param resourceNameSuffix string

@description('Use false for develompment environments. Wont be used strict settings')
param isProductionEnvironment bool = false //true

@description('ARM id of the application insights associated with this workspace.')
param applicationInsightResourceId string
@description('ARM id of the Key Vault associated with this workspace.')
param keyVaultResourceId string
@description('ARM id of the ACR associated with this workspace.')
param acrResourceId string
@description('ARM id of the Storage Account associated with this workspace.')
param storageResourceId string
@description('The reference of the virtual network.')
param vNetId string
@description('The ID of the subnet from which the private IP will be allocated.')
param subnetId string

param location string = resourceGroup().location

var config = {
    ml: {
        resourceName: '${resourceNameSuffix}-mlWorkspaces'
    }
    mlCompute: {
        resourceName: '${resourceNameSuffix}-mlCompute'
        vmSize: 'Standard_DS3_v2'
        minNodeCount: 0
        maxNodeCount: 5
    }
    mlPrivateEndpoint: {
        resourceName: '${resourceNameSuffix}-pe-ml'
        groupName: 'amlworkspace'
    }
    mlPrivateDnsZone: {
        resourceName: 'privatelink.api.azureml.ms'
    }
    mlPrivateDnsZoneGroup: {
        resourceName: 'ml-PrivateDnsZoneGroup'
    }
    mlPrivateDnsZoneVnetLink: {}
    notebookPrivateDnsZone: {
        resourceName: 'privatelink.notebooks.azure.net'
    }
    notebookPrivateDnsZoneVnetLink: {}
}
var tags = {
    resourceSuffix: resourceNameSuffix
}
// MachineLearningServices
resource ml 'Microsoft.MachineLearningServices/workspaces@2022-05-01' = {
    name: config.ml.resourceName
    location: location
    tags: tags
    identity: {
        type: 'SystemAssigned'
    }
    properties: {
        applicationInsights: applicationInsightResourceId
        containerRegistry: acrResourceId
        keyVault: keyVaultResourceId
        storageAccount: storageResourceId

        imageBuildCompute: 'mlCluster'
        publicNetworkAccess: 'Disabled'
    }
}
// ML Compute Cluster
resource mlCompute 'Microsoft.MachineLearningServices/workspaces/computes@2022-05-01' = {
    name: config.mlCompute.resourceName
    parent: ml
    location: location
    tags: tags
    identity: {
        type: 'SystemAssigned'
    }
    properties: {
        computeType: 'AmlCompute'
        computeLocation: location
        disableLocalAuth: true
        properties: {
            vmPriority: 'Dedicated'
            vmSize: config.mlCompute.vmSize
            enableNodePublicIp: false
            isolatedNetwork: false
            osType: 'Linux'
            remoteLoginPortPublicAccess: 'Disabled'
            scaleSettings: {
                minNodeCount: config.mlCompute.minNodeCount
                maxNodeCount: config.mlCompute.maxNodeCount
                nodeIdleTimeBeforeScaleDown: 'PT120S'
            }
            subnet: {
                id: subnetId
            }
        }
    }
    dependsOn: [
        mlPrivateEndpoint
    ]
}
// ML Private Endpoint
resource mlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
    name: config.mlPrivateEndpoint.resourceName
    location: location
    tags: tags
    properties: {
        privateLinkServiceConnections: [
            {
                name: config.mlPrivateEndpoint.resourceName
                properties: {
                    groupIds: [
                        config.mlPrivateEndpoint.groupName
                    ]
                    privateLinkServiceId: ml.id
                }
            }
        ]
        subnet: {
            id: subnetId
        }
    }
}
// ML Private Dns Zone
resource mlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
    name: config.mlPrivateDnsZone.resourceName
    location: 'global'
}
// ML Private Dns Zone vNet Link
resource mlPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
    name: uniqueString(ml.id)
    parent: mlPrivateDnsZone
    location: 'global'
    properties: {
        registrationEnabled: false
        virtualNetwork: {
            id: vNetId
        }
    }
}
// Notebook Private Dns Zone
resource notebookPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
    name: config.notebookPrivateDnsZone.resourceName
    location: 'global'
}
// Notebook Private Dns Zone vNet Link
resource notebookPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
    name: uniqueString(ml.id)
    parent: notebookPrivateDnsZone
    location: 'global'
    properties: {
        registrationEnabled: false
        virtualNetwork: {
            id: vNetId
        }
    }
}
// ML Private Dns Zone Group
resource mlPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
    name: config.mlPrivateDnsZoneGroup.resourceName
    parent: mlPrivateEndpoint
    properties: {
        privateDnsZoneConfigs: [
            {
                name: config.mlPrivateDnsZone.resourceName
                properties: {
                    privateDnsZoneId: mlPrivateDnsZone.id
                }
            }
            {
                name: config.notebookPrivateDnsZone.resourceName
                properties: {
                    privateDnsZoneId: notebookPrivateDnsZone.id
                }
            }
        ]
    }
}
