# Azure Machine Learning secure setup

Here is a draft of Azure Machine Learning secure setup.

## Infrastructure diagram

![Infrastructure diagram](/infrastructure-diagram.jpg)

## How to deploy

Use PowerShell to deploy the bicep code

1. Connect to Azure

```powershell
Connect-AzAccount
```

2. Initialization of parameters

```powershell
$ARMFileTemplate = ".\main.bicep"
# RG where you are going to deploy to     
$ResourceGroupName = "env-nortal-dev-compute"
# Prefix for all resources
$resourceNameSuffix = "nortal-dev"
# RG for management resources. See the bicep code how it works
$managementResourceGroupName = 'env-nortal-dev-management'
# Key Vault Resource Id where all secrets will get from
$keyVaultSecretsResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/env-nortal-dev-management/providers/Microsoft.KeyVault/vaults/mlnortal-dev-secrets'

```

3. Verify deployment

```powershell
Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
    -TemplateFile $ARMFileTemplate `
    -resourceNameSuffix $resourceNameSuffix `
    -managementResourceGroupName $managementResourceGroupName `
    -keyVaultSecretsResourceId $keyVaultSecretsResourceId `
    -Verbose
```

4. Deploy

```powershell
New-AzResourceGroupDeployment -Name ((Get-Item "$ARMFileTemplate").BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
    -TemplateFile $ARMFileTemplate `
    -ResourceGroupName $ResourceGroupName `
    -resourceNameSuffix $resourceNameSuffix `
    -managementResourceGroupName $managementResourceGroupName `
    -keyVaultSecretsResourceId $keyVaultSecretsResourceId `
    -Mode Incremental `
    -Verbose
```
