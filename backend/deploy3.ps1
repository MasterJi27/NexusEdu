$ErrorActionPreference = "Stop"

$RESOURCE_GROUP="NexusEdu-RG-3"
$LOCATION="southeastasia"
$RANDOM_SUFFIX = Get-Random -Minimum 10000 -Maximum 99999
$DB_SERVER_NAME="nexusedu-db-server-$RANDOM_SUFFIX"
$DB_NAME="nexusedu_db"
$DB_USER="nexusadmin"

$DB_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 20 | % {[char]$_}) + "A1!"
$JWT_SECRET = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | % {[char]$_})

$APP_SERVICE_PLAN="NexusEdu-Plan-3"
$WEB_APP_NAME="nexusedu-backend-$RANDOM_SUFFIX"

function az { python -m azure.cli $args }

Write-Host "Creating Resource Group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

Write-Host "Creating Azure Database for PostgreSQL..."
az postgres flexible-server create `
  --resource-group $RESOURCE_GROUP `
  --name $DB_SERVER_NAME `
  --location $LOCATION `
  --admin-user $DB_USER `
  --admin-password $DB_PASSWORD `
  --sku-name Standard_B1ms `
  --tier Burstable `
  --yes

Write-Host "Creating the database inside the server..."
az postgres flexible-server db create `
  --resource-group $RESOURCE_GROUP `
  --server-name $DB_SERVER_NAME `
  --name $DB_NAME

Write-Host "Securing Database..."
az postgres flexible-server firewall-rule create `
  --resource-group $RESOURCE_GROUP `
  --server-name $DB_SERVER_NAME `
  --name AllowAzureIps `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0

Write-Host "Creating App Service Plan..."
az appservice plan create `
  --name $APP_SERVICE_PLAN `
  --resource-group $RESOURCE_GROUP `
  --sku B1 `
  --is-linux

Write-Host "Creating Web App..."
az webapp create `
  --resource-group $RESOURCE_GROUP `
  --plan $APP_SERVICE_PLAN `
  --name $WEB_APP_NAME `
  --runtime "NODE:18-lts"

Write-Host "Enforcing HTTPS Only..."
az webapp update `
  --resource-group $RESOURCE_GROUP `
  --name $WEB_APP_NAME `
  --https-only true

Write-Host "Configuring Environment Variables..."
$DB_HOST = az postgres flexible-server show --resource-group $RESOURCE_GROUP --name $DB_SERVER_NAME --query "fullyQualifiedDomainName" -o tsv
if ($null -ne $DB_HOST) {
    $DB_HOST = $DB_HOST.Trim()
}
$DATABASE_URL = "postgresql://$DB_USER`:$DB_PASSWORD@$DB_HOST/$DB_NAME?sslmode=require"

az webapp config appsettings set `
  --resource-group $RESOURCE_GROUP `
  --name $WEB_APP_NAME `
  --settings DATABASE_URL="$DATABASE_URL" JWT_SECRET="$JWT_SECRET" PORT="8080"

Write-Host "Enabling Always On..."
az webapp config set `
  --resource-group $RESOURCE_GROUP `
  --name $WEB_APP_NAME `
  --always-on true

Write-Host "================================================="
Write-Host "Deployment resources created successfully!"
Write-Host "Your API will be hosted at: https://$WEB_APP_NAME.azurewebsites.net"
Write-Host "Your Database URL is: $DATABASE_URL"
Write-Host "Your JWT Secret is: $JWT_SECRET"
Write-Host "================================================="
