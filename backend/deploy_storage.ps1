$ErrorActionPreference = "Stop"

$RESOURCE_GROUP = "NexusEdu-RG-3"
$LOCATION = "southeastasia"
$RANDOM_SUFFIX = Get-Random -Minimum 10000 -Maximum 99999
$STORAGE_ACCOUNT_NAME = "nexusstorage$RANDOM_SUFFIX"
$CONTAINER_NAME = "nexus-media"
$WEB_APP_NAME="nexusedu-backend-56407"

function az { python -m azure.cli $args }

Write-Host "Creating Azure Storage Account in southeastasia..."
az storage account create `
  --name $STORAGE_ACCOUNT_NAME `
  --resource-group $RESOURCE_GROUP `
  --location $LOCATION `
  --sku Standard_LRS `
  --allow-blob-public-access true

Write-Host "Getting Storage Account Key..."
$KEY = az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv
if ($null -ne $KEY) {
    $KEY = $KEY.Trim()
}

Write-Host "Creating Blob Container..."
az storage container create `
  --name $CONTAINER_NAME `
  --account-name $STORAGE_ACCOUNT_NAME `
  --account-key $KEY `
  --public-access blob

Write-Host "Setting Environment Variable on Web App..."
$CONNECTION_STRING = "DefaultEndpointsProtocol=https;AccountName=$STORAGE_ACCOUNT_NAME;AccountKey=$KEY;EndpointSuffix=core.windows.net"

az webapp config appsettings set `
  --resource-group $RESOURCE_GROUP `
  --name $WEB_APP_NAME `
  --settings AZURE_STORAGE_CONNECTION_STRING="$CONNECTION_STRING"

Write-Host "================================================="
Write-Host "Storage Account Created Successfully!"
Write-Host "Storage Name: $STORAGE_ACCOUNT_NAME"
Write-Host "Container Name: $CONTAINER_NAME"
Write-Host "================================================="
