@maxLength(14)
@description('Suffix to the names of the resources.')
param resourceNameSuffix string = 'nortal-dev'
@description('Leave empty if you would like to deploy in the same resource group.')
param computeResourceGroupName string = ''
@description('Leave empty if you would like to deploy in the same resource group.')
param managementResourceGroupName string = ''
@description('Leave empty if you would like to deploy in the same resource group.')
param dataResourceGroupName string = ''
@description('Key Vault Resource Id where all secrets will get from.')
param keyVaultSecretsResourceId string
@description('Name of the secret that contains the password of Admin User.')
param jumpBoxVmAdminPasswordSecretName string = 'AdminPassword'
@maxValue(254)
@description('Environment network identifier is used as part of network address space: 10.x.0.0/16')
param networkIdentifier int = 0

param location string = resourceGroup().location

@description('Use false for develompment environments. Wont be used strict settings')
param isProductionEnvironment bool = false //true
param utcDeployment string = utcNow()

var config = {
    managementDeployment: {
        resourceName: 'managementDeployment-${resourceNameSuffix}-${utcDeployment}'
        resourceGroupName: empty(managementResourceGroupName) ? resourceGroup().name : managementResourceGroupName
    }
    networkDeployment: {
        resourceName: 'networkDeployment-${resourceNameSuffix}-${utcDeployment}'
        resourceGroupName: empty(computeResourceGroupName) ? resourceGroup().name : computeResourceGroupName
    }
    storageDeployment: {
        resourceName: 'storageDeployment-${resourceNameSuffix}-${utcDeployment}'
        resourceGroupName: empty(dataResourceGroupName) ? resourceGroup().name : dataResourceGroupName
    }
    keyVaultDeployment: {
        resourceName: 'keyVaultDeployment-${resourceNameSuffix}-${utcDeployment}'
        resourceGroupName: empty(dataResourceGroupName) ? resourceGroup().name : dataResourceGroupName
    }
    acrDeployment: {
        resourceName: 'acrDeployment-${resourceNameSuffix}-${utcDeployment}'
        resourceGroupName: empty(dataResourceGroupName) ? resourceGroup().name : dataResourceGroupName
    }
    jumpBoxVmDeployment: {
        resourceName: 'jumpBoxVmDeployment-${resourceNameSuffix}-${utcDeployment}'
        resourceGroupName: empty(computeResourceGroupName) ? resourceGroup().name : dataResourceGroupName
    }
    computeDeployment: {
        resourceName: 'computeDeployment-${resourceNameSuffix}-${utcDeployment}'
        resourceGroupName: empty(computeResourceGroupName) ? resourceGroup().name : computeResourceGroupName
    }
}
// Key Vault with secrets
resource keyVaultSecrets 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
    name: last(split(keyVaultSecretsResourceId, '/'))
    scope: resourceGroup(split(keyVaultSecretsResourceId, '/')[4])
}
// Management
module management 'modules/management.bicep' = {
    name: config.managementDeployment.resourceName
    scope: resourceGroup(config.managementDeployment.resourceGroupName)
    params: {
        resourceNameSuffix: resourceNameSuffix
        location: location
    }
}
// Network
module network 'modules/network.bicep' = {
    name: config.networkDeployment.resourceName
    scope: resourceGroup(config.computeDeployment.resourceGroupName)
    params: {
        resourceNameSuffix: resourceNameSuffix
        networkIdentifier: networkIdentifier
        isProductionEnvironment: isProductionEnvironment
        location: location
    }
}
// Storage Account
module storage 'modules/storage.bicep' = {
    name: config.storageDeployment.resourceName
    scope: resourceGroup(config.storageDeployment.resourceGroupName)
    params: {
        resourceNameSuffix: resourceNameSuffix
        isProductionEnvironment: isProductionEnvironment
        location: location
        vNetId: network.outputs.vNetId
        subnetId: network.outputs.subnetComputeId
    }
}
// Key Vault
module keyVault 'modules/keyvault.bicep' = {
    name: config.keyVaultDeployment.resourceName
    scope: resourceGroup(config.keyVaultDeployment.resourceGroupName)
    params: {
        resourceNameSuffix: resourceNameSuffix
        isProductionEnvironment: isProductionEnvironment
        location: location
        vNetId: network.outputs.vNetId
        subnetId: network.outputs.subnetComputeId
    }
}
// ACR
module acr 'modules/acr.bicep' = {
    name: config.acrDeployment.resourceName
    scope: resourceGroup(config.acrDeployment.resourceGroupName)
    params: {
        resourceNameSuffix: resourceNameSuffix
        isProductionEnvironment: isProductionEnvironment
        location: location
        vNetId: network.outputs.vNetId
        subnetId: network.outputs.subnetComputeId
    }
}
// ML
module compute 'modules/ml.bicep' = {
    name: config.computeDeployment.resourceName
    scope: resourceGroup(config.computeDeployment.resourceGroupName)
    params: {
        resourceNameSuffix: resourceNameSuffix
        applicationInsightResourceId: management.outputs.applicationInsightResourceId
        acrResourceId: acr.outputs.acrId
        keyVaultResourceId: keyVault.outputs.keyvaultId
        storageResourceId: storage.outputs.storageId
        subnetId: network.outputs.subnetComputeId
        vNetId: network.outputs.vNetId
        isProductionEnvironment: isProductionEnvironment
        location: location
    }
}
// JumpBox VM
module vm 'modules/jumpBoxVm.bicep' = if (isProductionEnvironment) {
    name: config.jumpBoxVmDeployment.resourceName
    scope: resourceGroup(config.jumpBoxVmDeployment.resourceGroupName)
    params: {
        resourceNameSuffix: resourceNameSuffix
        isProductionEnvironment: isProductionEnvironment
        location: location
        adminPassword: keyVaultSecrets.getSecret(jumpBoxVmAdminPasswordSecretName)
        subnetId: network.outputs.subnetBastionId
        nsgId: network.outputs.nsgId
    }
}
/*
*/
