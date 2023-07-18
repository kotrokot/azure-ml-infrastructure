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
  acr: {
    resourceName: '${toLower(replace(resourceNameSuffix, '-', ''))}acr'
  }
  acrPrivateEndpoint: {
    resourceName: '${resourceNameSuffix}-pe-acr'
    groupName: 'registry'
  }
  acrPrivateDnsZone: {
    resourceName: 'privatelink${environment().suffixes.acrLoginServer}'
  }
  acrPrivateDnsZoneGroup: {
    resourceName: 'acr-PrivateDnsZoneGroup'
  }
  acrPrivateDnsZoneVnetLink: {}
}
var tags = {
  resourceSuffix: resourceNameSuffix
}
// ACR
resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: config.acr.resourceName
  location: location
  tags: tags
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'AzureServices'
    networkRuleSet: {
      defaultAction: 'Deny'
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      retentionPolicy: {
        status: 'enabled'
        days: 7
      }
      trustPolicy: {
        status: 'disabled'
        type: 'Notary'
      }
    }
    publicNetworkAccess: 'Disabled'
    zoneRedundancy: 'Disabled'
  }
}
// ACR Private Endpoint
resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: config.acrPrivateEndpoint.resourceName
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: config.acrPrivateEndpoint.resourceName
        properties: {
          groupIds: [
            config.acrPrivateEndpoint.groupName
          ]
          privateLinkServiceId: acr.id
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

// ACR Private Dns Zone
resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: config.acrPrivateDnsZone.resourceName
  location: 'global'
}
// ACR Private Dns Zone Group
resource acrPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  name: config.acrPrivateDnsZoneGroup.resourceName
  parent: acrPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: config.acrPrivateDnsZoneGroup.resourceName
        properties: {
          privateDnsZoneId: acrPrivateDnsZone.id
        }
      }
    ]
  }
}
// ACR vNet Link
resource acrPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: uniqueString(acr.id)
  location: 'global'
  parent: acrPrivateDnsZone
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vNetId
    }
  }
}

output acrId string = acr.id
