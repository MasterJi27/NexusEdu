$ErrorActionPreference = "Stop"

$RESOURCE_GROUP = "NexusEdu-RG-3"
$LOCATION = "southeastasia"
$WEB_APP_NAME="nexusedu-backend-56407"
$STORAGE_ACCOUNT_NAME = "nexusstorage16387" # Extracted from previous deployment
$RANDOM_SUFFIX = Get-Random -Minimum 10000 -Maximum 99999

function az { python -m azure.cli $args }

Write-Host "Registering Providers..."
az provider register -n Microsoft.Insights
az provider register -n Microsoft.CognitiveServices
az provider register -n Microsoft.Cdn

Write-Host "Creating Application Insights Workspace..."
$WORKSPACE_NAME = "nexus-workspace"
az monitor log-analytics workspace create `
    --resource-group $RESOURCE_GROUP `
    --workspace-name $WORKSPACE_NAME `
    --location $LOCATION

$WORKSPACE_ID = (az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP --workspace-name $WORKSPACE_NAME --query id -o tsv).Trim()

Write-Host "Creating Application Insights Component..."
$APP_INSIGHTS_NAME = "nexus-app-insights"
az monitor app-insights component create `
    --app $APP_INSIGHTS_NAME `
    --location $LOCATION `
    --kind web `
    --resource-group $RESOURCE_GROUP `
    --workspace $WORKSPACE_ID

$APP_INSIGHTS_KEY = (az monitor app-insights component show --app $APP_INSIGHTS_NAME --resource-group $RESOURCE_GROUP --query connectionString -o tsv).Trim()

Write-Host "Creating Cognitive Services (Free Tier)..."
$COG_NAME = "nexus-cog-$RANDOM_SUFFIX"
az cognitiveservices account create `
    --name $COG_NAME `
    --resource-group $RESOURCE_GROUP `
    --kind CognitiveServices `
    --sku F0 `
    --location $LOCATION `
    --yes

$COG_KEY = (az cognitiveservices account keys list --name $COG_NAME --resource-group $RESOURCE_GROUP --query key1 -o tsv).Trim()
$COG_ENDPOINT = (az cognitiveservices account show --name $COG_NAME --resource-group $RESOURCE_GROUP --query properties.endpoint -o tsv).Trim()

Write-Host "Creating Azure CDN Profile..."
$CDN_PROFILE = "nexus-cdn-profile"
$CDN_ENDPOINT = "nexus-cdn-endpt-$RANDOM_SUFFIX"

az cdn profile create `
    --name $CDN_PROFILE `
    --resource-group $RESOURCE_GROUP `
    --sku Standard_Microsoft `
    --location $LOCATION

# az cdn endpoint create `
#     --name $CDN_ENDPOINT `
#     --profile-name $CDN_PROFILE `
#     --resource-group $RESOURCE_GROUP `
#     --origin "$STORAGE_ACCOUNT_NAME.blob.core.windows.net" `
#     --origin-host-header "$STORAGE_ACCOUNT_NAME.blob.core.windows.net"

Write-Host "Updating Web App Environment Variables..."
az webapp config appsettings set `
  --resource-group $RESOURCE_GROUP `
  --name $WEB_APP_NAME `
  --settings APPLICATIONINSIGHTS_CONNECTION_STRING="$APP_INSIGHTS_KEY" COGNITIVE_SERVICES_KEY="$COG_KEY" COGNITIVE_SERVICES_ENDPOINT="$COG_ENDPOINT"

Write-Host "Deployment Complete!"
