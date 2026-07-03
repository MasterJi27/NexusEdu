#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Configuration
RESOURCE_GROUP="NexusEdu-RG"
LOCATION="canadacentral"
DB_SERVER_NAME="nexusedu-db-server-$RANDOM"
DB_NAME="nexusedu_db"
DB_USER="nexusadmin"
# Automatically generates a secure random password for DB and JWT Secret
DB_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)"A1!" 
JWT_SECRET=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9')
APP_SERVICE_PLAN="NexusEdu-Plan"
WEB_APP_NAME="nexusedu-backend-$RANDOM"

echo "Logging in to Azure..."
az login

echo "Creating Resource Group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "Creating Azure Database for PostgreSQL (Flexible Server)..."
echo "Generated Secure Database Password: $DB_PASSWORD"
# Removed --public-access all to prevent open internet access
az postgres flexible-server create \
  --resource-group $RESOURCE_GROUP \
  --name $DB_SERVER_NAME \
  --location $LOCATION \
  --admin-user $DB_USER \
  --admin-password $DB_PASSWORD \
  --sku-name Standard_B1ms \
  --tier Burstable


echo "Creating the database inside the server..."
az postgres flexible-server db create \
  --resource-group $RESOURCE_GROUP \
  --server-name $DB_SERVER_NAME \
  --database-name $DB_NAME

echo "Securing Database: Allowing access ONLY from other Azure Services..."
az postgres flexible-server firewall-rule create \
  --resource-group $RESOURCE_GROUP \
  --name $DB_SERVER_NAME \
  --rule-name AllowAzureIps \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

echo "Creating App Service Plan (Basic Tier for Always On)..."
az appservice plan create \
  --name $APP_SERVICE_PLAN \
  --resource-group $RESOURCE_GROUP \
  --sku B1 \
  --is-linux

echo "Creating Web App..."
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan $APP_SERVICE_PLAN \
  --name $WEB_APP_NAME \
  --runtime "NODE:18-lts"

echo "Enforcing HTTPS Only on Web App for Security..."
az webapp update \
  --resource-group $RESOURCE_GROUP \
  --name $WEB_APP_NAME \
  --https-only true

echo "Configuring Environment Variables for Web App..."
DB_HOST=$(az postgres flexible-server show --resource-group $RESOURCE_GROUP --name $DB_SERVER_NAME --query "fullyQualifiedDomainName" -o tsv)
DATABASE_URL="postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST/$DB_NAME?sslmode=require"

az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name $WEB_APP_NAME \
  --settings DATABASE_URL="$DATABASE_URL" JWT_SECRET="$JWT_SECRET" PORT="8080"

echo "Enabling 'Always On' to prevent cold starts (low response time)..."
az webapp config set \
  --resource-group $RESOURCE_GROUP \
  --name $WEB_APP_NAME \
  --always-on true

echo "================================================="
echo "Deployment resources created successfully!"
echo "Your API will be hosted at: https://$WEB_APP_NAME.azurewebsites.net"
echo "Your Database URL is: $DATABASE_URL"
echo "Your JWT Secret is: $JWT_SECRET"
echo "SAVE THESE DETAILS SECURELY."
echo "================================================="

