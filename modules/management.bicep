@maxLength(14)
@description('Suffix to the names of the resources.')
param resourceNameSuffix string

param location string = resourceGroup().location

var config = {
    logAnalytics: {
        resourceName: '${resourceNameSuffix}-logAnalytics'
        SKUName: 'PerGB2018'
        dailyQuotaGb: 1
    }
    applicationInsight: {
        resourceName: '${resourceNameSuffix}-appInsights'
        SamplingPercentage: 100
        RetentionInDays: 30 // RetentionInDays has to be one of the following values: 30,60,90,120,180,270,365,550,730
    }
}
var tags = {
    resourceSuffix: resourceNameSuffix
}
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
    name: config.logAnalytics.resourceName
    location: location
    tags: tags
    properties: {
        sku: {
            name: config.logAnalytics.SKUName
        }
        workspaceCapping: {
            dailyQuotaGb: config.logAnalytics.dailyQuotaGb
        }
    }
}
resource applicationInsight 'Microsoft.Insights/components@2020-02-02' = {
    name: config.applicationInsight.resourceName
    location: location
    tags: tags
    kind: 'web'
    properties: {
        Application_Type: 'web'
        SamplingPercentage: config.applicationInsight.SamplingPercentage
        RetentionInDays: config.applicationInsight.RetentionInDays
        WorkspaceResourceId: logAnalytics.id
    }
}

output logAnalyticsWorkspaceResourceId string = logAnalytics.id
output applicationInsightResourceId string = applicationInsight.id
