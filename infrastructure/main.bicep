@description('The name of the web app')
param webAppName string = 'simple-react-router-${uniqueString(resourceGroup().id)}'

@description('Location for all resources')
param location string = resourceGroup().location

@description('The pricing tier for the App Service Plan')
@allowed([
  'F1'  // Free
  'B1'  // Basic
  'S1'  // Standard
  'P1V2' // Premium V2
])
param appServicePlanSku string = 'F1'

@description('Node.js version')
param nodeVersion string = '22-lts'

var appServicePlanName = '${webAppName}-plan'

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// Web App
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|${nodeVersion}'
      appSettings: [
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~${nodeVersion}'
        }
      ]
      alwaysOn: appServicePlanSku != 'F1' // Always On not available on Free tier
    }
    httpsOnly: true
  }
}

output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output webAppId string = webApp.id
