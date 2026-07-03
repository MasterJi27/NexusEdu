$ErrorActionPreference = "Stop"

$RESOURCE_GROUP="NexusEdu-RG-3"
$APP_SERVICE_PLAN="NexusEdu-Plan-3"
$WEB_APP_NAME="nexusedu-backend-56407"

$DATABASE_URL = "postgresql://nexusadmin:G8bhvnxCm3aZXwPg7ofEA1!`@nexusedu-db-server-56407.postgres.database.azure.com/nexusedu_db?sslmode=require"
$JWT_SECRET = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | % {[char]$_})

function az { python -m azure.cli $args }

Write-Host "Creating Web App..."
az webapp create `
  --resource-group $RESOURCE_GROUP `
  --plan $APP_SERVICE_PLAN `
  --name $WEB_APP_NAME `
  --runtime "NODE|22-lts"

Write-Host "Enforcing HTTPS Only..."
az webapp update `
  --resource-group $RESOURCE_GROUP `
  --name $WEB_APP_NAME `
  --https-only true

Write-Host "Configuring Environment Variables..."
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
