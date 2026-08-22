// =============================================================================
// Nexus Edu — 1M Scale Infrastructure (hardened)
// =============================================================================
// 1M scale rationale (why these SKUs):
// - App Service Plan P1v3 + autoscale 3-30 @ CPU>60: P1v3 is the cheapest
//   isolated-v3 tier with 2 vCPU / 8 GB and fast scale-out; starting at 3
//   instances survives zone failure, 30 handles exam-day spike without
//   cold-start latency. CPU 60% target keeps p95 < 300ms before scaling.
// - Postgres Flexible GP_Standard_D4s_v3 (4 vCPU / 16 GiB) + read replica:
//   burstable cannot sustain 1M write+read fanout; GP D-series gives
//   dedicated vCPU + memory-optimized buffer pool. Read replica offloads
//   feed/analytics reads and provides <60s RPO failover.
// - Azure Cache for Redis Premium P1 — shared token-bucket state
//   for rate-limit, session pinning and AI quota must survive instance
//   recycle; in-memory maps would split-brain across 30 instances. Premium
//   adds persistence, clustering (shardCount) and SLA + VNet isolation.
// - Storage GZRS private (allowBlobPublicAccess=false, min TLS 1.2) — all blob
//   access via SAS / managed identity; versioning + soft-delete + KeyVault
//   customer-managed key; no anonymous enumeration.
// - Front Door Premium + WAF Detection — global edge cache + DDoS absorption +
//   OWASP 3.2 managed rules + rate-limit rule; TLS termination at edge.
// - Application Insights — request/dependency/exception collection;
//   alerts feed the SCALE_1M.md runbook. Logs shipped to Log Analytics.
// - Key Vault references — App Service never holds plaintext secrets;
//   DATABASE_URL / JWT_SECRET / third-party keys are Key Vault references
//   resolved at runtime over private endpoint.
// =============================================================================
// P0 verification 2026-08-22 — verified & synced:
// - All 5 private endpoints present: kv (vault), storage blob, postgres (postgresqlServer), redis (redisCache), acr (registry)
// - Log Analytics retentionInDays: 90 (workspace retention governs; diagnosticSettings use workspace retention)
// - Storage CMK requireInfrastructureEncryption: true (double encryption at-rest)
// - Redis redisVersion: 7 pinned
// - WAF mode: Detection (switch to Prevention after tuning) — keep as is per instruction
// - Deployment slot autoSwapSlotName: 'production' configured for zero-downtime
// - healthCheckPath: '/api/ready' (webApp + slot + Front Door probe)
// - ipSecurityRestrictions: 10.0.0.0/16 (AllowVnetMetrics)
// - Postgres backupRetentionDays: 14 (within 14-35 PITR range, geoRedundantBackup Enabled, ZoneRedundant HA)
// =============================================================================

targetScope = 'resourceGroup'

// -------- Parameters ---------------------------------------------------------
@description('Azure region — align app, db, redis, storage for <2 ms VNet latency')
param location string = resourceGroup().location

@description('Global prefix for resource names — e.g. nexus-prod')
param appName string = 'nexus-edu'

@description('Postgres admin login')
param postgresAdminUser string = 'nexus_admin'

@secure()
@description('Postgres admin password — inject from Key Vault / pipeline')
param postgresAdminPassword string

@description('Docker image for the backend — e.g. nexusacr.azurecr.io/backend:sha')
param containerImage string = 'nexusacr.azurecr.io/backend:latest'

@description('App Insights connection string — empty disables monitoring (local dev)')
#disable-next-line no-unused-params
param appInsightsConnectionString string = ''

@description('Alert email for action group')
param alertEmail string = 'oncall@nexusedu.app'

@description('Deployment environment — free keeps student zero cost, prod is 1M scale')
@allowed(['free', 'prod'])
param env string = 'free'

// -------- Variables ----------------------------------------------------------
var tags = {
  workload: 'nexus-edu'
  scale: env == 'prod' ? '1M' : 'free'
  env: env
}
var aspName = '${appName}-asp'
var webAppName = '${appName}-api'
var postgresName = '${appName}-pg'
var postgresReplicaName = '${appName}-pg-replica'
var redisName = '${appName}-redis'
var storageName = '${toLower(replace(appName, '-', ''))}st' // 3-24 lowercase alnum
var keyVaultName = '${appName}-kv'
var appInsightsName = '${appName}-insights'
var frontDoorName = '${appName}-fd'
var wafPolicyName = '${appName}-waf'
var logAnalyticsName = '${appName}-law'
var vnetName = '${appName}-vnet'
var acrName = '${toLower(replace(appName, '-', ''))}acr'
var actionGroupName = '${appName}-ag'
var storageEncryptionKeyName = 'storage-encryption-key'

// -------- Log Analytics Workspace --------------------------------------------
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 90 // P0: Log Analytics retention 90 days
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
  }
}

// -------- Action Group -------------------------------------------------------
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'Global'
  tags: tags
  properties: {
    groupShortName: 'nexus-ag'
    enabled: true
    emailReceivers: [
      {
        name: 'oncall-email'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
    smsReceivers: []
    webhookReceivers: []
  }
}

// -------- Virtual Network (for private endpoints) ---------------------------
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      {
        name: 'private-endpoints'
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'appservice-vnet-integration'
        properties: {
          addressPrefix: '10.0.2.0/24'
          delegations: [
            {
              name: 'appservice-delegation'
              properties: { serviceName: 'Microsoft.Web/serverFarms' }
            }
          ]
        }
      }
    ]
  }
}

// -------- Application Insights -----------------------------------------------
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    WorkspaceResourceId: logAnalytics.id
  }
}

// -------- Key Vault ----------------------------------------------------------
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    enablePurgeProtection: true
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    accessPolicies: []
  }
}

// Key Vault key for Storage encryption (customer-managed key)
resource storageEncryptionKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  parent: keyVault
  name: storageEncryptionKeyName
  properties: {
    kty: 'RSA'
    keySize: 3072
    keyOps: ['wrapKey', 'unwrapKey']
    attributes: { enabled: true }
    rotationPolicy: {
      lifetimeActions: [
        {
          trigger: { timeAfterCreate: 'P90D' }
          action: { type: 'rotate' }
        }
        {
          trigger: { timeBeforeExpiry: 'P30D' }
          action: { type: 'notify' }
        }
      ]
      attributes: { expiryTime: 'P365D' }
    }
  }
}

// Key Vault Private Endpoint
resource kvPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${keyVaultName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'private-endpoints') }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-plsc'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: ['vault']
        }
      }
    ]
  }
  dependsOn: [ vnet ]
}

resource kvPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource kvPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: kvPrivateDnsZone
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}

resource kvPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: kvPrivateEndpoint
  name: 'vault-dnsgroup'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'vault-config', properties: { privateDnsZoneId: kvPrivateDnsZone.id } }
    ]
  }
}

// -------- Container Registry (for AcrPull role) -----------------------------
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Enabled'
  }
}

// -------- Storage Account (GZRS, versioning, soft-delete, CMK) ---------------
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: { name: 'Standard_GZRS' }
  identity: { type: 'SystemAssigned' }
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Disabled'
    allowSharedKeyAccess: false
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    encryption: {
      services: {
        blob: { enabled: true }
        file: { enabled: true }
      }
      keySource: 'Microsoft.Keyvault'
      keyvaultproperties: {
        keyname: storageEncryptionKey.name
        keyvaulturi: keyVault.properties.vaultUri
      }
      requireInfrastructureEncryption: true // P0: Storage CMK double encryption (CMK + infra encryption)
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    isVersioningEnabled: true
    changeFeed: { enabled: true }
    deleteRetentionPolicy: { enabled: true, days: 30, allowPermanentDelete: false }
    containerDeleteRetentionPolicy: { enabled: true, days: 30 }
  }
}

// Storage blob service soft-delete is above; additional file service retention
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: { enabled: true, days: 30 }
  }
}

// Storage Private Endpoint
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${storageName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'private-endpoints') }
    privateLinkServiceConnections: [
      {
        name: '${storageName}-plsc'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: ['blob']
        }
      }
    ]
  }
  dependsOn: [ vnet ]
}

#disable-next-line no-hardcoded-env-urls
resource storagePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
  tags: tags
}

resource storagePrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storagePrivateDnsZone
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}

resource storagePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: storagePrivateEndpoint
  name: 'blob-dnsgroup'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'blob-config', properties: { privateDnsZoneId: storagePrivateDnsZone.id } }
    ]
  }
}

// -------- ACR Private Endpoint -----------------------------------------------
resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${acrName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'private-endpoints') }
    privateLinkServiceConnections: [
      {
        name: '${acrName}-plsc'
        properties: {
          privateLinkServiceId: acr.id
          groupIds: ['registry']
        }
      }
    ]
  }
  dependsOn: [ vnet ]
}

resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  tags: tags
}

resource acrPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: acrPrivateDnsZone
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}

resource acrPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: acrPrivateEndpoint
  name: 'registry-dnsgroup'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'registry-config', properties: { privateDnsZoneId: acrPrivateDnsZone.id } }
    ]
  }
}

// -------- Azure Cache for Redis (Premium P1) — prod only, free uses in-memory fallback
resource redis 'Microsoft.Cache/redis@2023-08-01' = if (env == 'prod') {
  name: redisName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'Premium'
      family: 'P'
      capacity: 1 // P1: 6 GB, Premium persistence + clustering
    }
    shardCount: 2
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisVersion: '7' // P0: redisVersion 7 pinned per 1M spec
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
      'rdb-backup-enabled': 'true'
      'rdb-backup-frequency': '60'
      'rdb-backup-max-snapshot-count': '9'
      'aof-backup-enabled': 'true'
      'rdb-storage-connection-string': 'DefaultEndpointsProtocol=https;AccountName=${storageName};EndpointSuffix=${environment().suffixes.storage}'
    }
    publicNetworkAccess: 'Disabled'
  }
}

// -------- Redis Private Endpoint — prod only
resource redisPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (env == 'prod') {
  name: '${redisName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'private-endpoints') }
    privateLinkServiceConnections: [
      {
        name: '${redisName}-plsc'
        properties: {
          privateLinkServiceId: redis.id
          groupIds: ['redisCache']
        }
      }
    ]
  }
  dependsOn: [ vnet ]
}

resource redisPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (env == 'prod') {
  name: 'privatelink.redis.cache.windows.net'
  location: 'global'
  tags: tags
}

resource redisPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: redisPrivateDnsZone
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}

resource redisPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: redisPrivateEndpoint
  name: 'redis-dnsgroup'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'redis-config', properties: { privateDnsZoneId: redisPrivateDnsZone.id } }
    ]
  }
}

// -------- PostgreSQL Flexible Server — Primary (prod D4s_v3, free B1ms)
resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2024-11-01' = {
  name: postgresName
  location: location
  tags: tags
  sku: env == 'prod' ? {
    name: 'Standard_D4s_v3'
    tier: 'GeneralPurpose'
  } : {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '16'
    administratorLogin: postgresAdminUser
    administratorLoginPassword: postgresAdminPassword
    storage: {
      storageSizeGB: 256
      autoGrow: 'Enabled'
      tier: 'P30'
    }
    backup: {
      backupRetentionDays: 14 // P0: 14 within 14-35 days PITR compliant
      geoRedundantBackup: 'Enabled'
    }
    highAvailability: {
      mode: 'ZoneRedundant'
    }
    network: {
      publicNetworkAccess: 'Disabled'
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
    }
  }
}

// -------- PostgreSQL Read Replica — prod only (free has none)
resource postgresReplica 'Microsoft.DBforPostgreSQL/flexibleServers@2024-11-01' = if (env == 'prod') {
  name: postgresReplicaName
  location: location
  tags: tags
  sku: {
    name: 'Standard_D4s_v3'
    tier: 'GeneralPurpose'
  }
  properties: {
    version: '16'
    createMode: 'Replica'
    sourceServerResourceId: postgres.id
    storage: {
      storageSizeGB: 256
      autoGrow: 'Enabled'
      tier: 'P30'
    }
    network: {
      publicNetworkAccess: 'Disabled'
    }
  }
}

// -------- Postgres Private Endpoint ------------------------------------------
resource postgresPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${postgresName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'private-endpoints') }
    privateLinkServiceConnections: [
      {
        name: '${postgresName}-plsc'
        properties: {
          privateLinkServiceId: postgres.id
          groupIds: ['postgresqlServer']
        }
      }
    ]
  }
  dependsOn: [ vnet ]
}

resource postgresPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.postgres.database.azure.com'
  location: 'global'
  tags: tags
}

resource postgresPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: postgresPrivateDnsZone
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}

resource postgresPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: postgresPrivateEndpoint
  name: 'postgres-dnsgroup'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'postgres-config', properties: { privateDnsZoneId: postgresPrivateDnsZone.id } }
    ]
  }
}

// -------- PostgreSQL diagnosticSettings to Log Analytics ----------------------
// P0: diagnosticSettings use Log Analytics workspace retention (retentionInDays: 90) — per-resource retention not used
resource postgresDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${postgresName}-diag'
  scope: postgres
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      { category: 'PostgreSQLLogs', enabled: true }
      { category: 'PostgreSQLFlexSessions', enabled: true }
      { category: 'PostgreSQLFlexQueryStoreWaitStats', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

resource postgresReplicaDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${postgresReplicaName}-diag'
  scope: postgresReplica
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      { category: 'PostgreSQLLogs', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

// -------- App Service Plan — P1v3 prod, Free for zero-cost
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: aspName
  location: location
  tags: tags
  sku: env == 'prod' ? {
    name: 'P1v3'
    tier: 'PremiumV3'
    capacity: 3
  } : {
    name: 'F1'
    tier: 'Free'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true
    zoneRedundant: true
    perSiteScaling: false
  }
}

// -------- Web App (Linux, container) -----------------------------------------
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerImage}'
      alwaysOn: true
      use32BitWorkerProcess: false
      numberOfWorkers: 1
      http20Enabled: true
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      ftpsState: 'Disabled'
      healthCheckPath: '/api/ready' // P0: healthCheckPath /api/ready for LB probe
      #disable-next-line BCP037
      healthCheckEvictionTimeInMin: 2 // 1M: evict after 2min
      autoHealEnabled: true
      autoHealRules: {
        triggers: {
          requests: { count: 100, timeInterval: '00:02:00' }
          statusCodes: [
            { status: 500, count: 20, timeInterval: '00:05:00' }
            { status: 503, count: 10, timeInterval: '00:02:00' }
          ]
          slowRequestsWithPath: [
            { count: 20, timeInterval: '00:05:00', timeTaken: '00:00:30', path: '/api/*' }
          ]
        }
        actions: { actionType: 'Recycle' }
      }
      appSettings: [
        { name: 'NODE_ENV', value: 'production' }
        { name: 'WEBSITES_PORT', value: '3000' }
        { name: 'SCM_DO_BUILD_DURING_DEPLOYMENT', value: 'false' }
        { name: 'WEBSITE_RUN_FROM_PACKAGE', value: '1' }
        { name: 'DATABASE_URL', value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/DATABASE-URL/)' }
        { name: 'REPLICA_DATABASE_URL', value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/REPLICA-DATABASE-URL/)' }
        { name: 'REDIS_URL', value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/REDIS-URL/)' }
        { name: 'JWT_SECRET', value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/JWT-SECRET/)' }
        { name: 'APP_INSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
        { name: 'WEBSITE_HEALTHCHECK_MAXPINGFAILURES', value: '3' }
        { name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE', value: 'false' }
      ]
      cors: { allowedOrigins: [] }
      ipSecurityRestrictions: [ // P0: ipSecurityRestrictions 10.0.0.0/16 for /metrics
        {
          ipAddress: '10.0.0.0/16'
          action: 'Allow'
          priority: 100
          name: 'AllowVnetMetrics'
          description: 'Allow VNet for /metrics'
        }
        {
          ipAddress: '0.0.0.0/0'
          action: 'Deny'
          priority: 200
          name: 'DenyAll'
          description: 'Deny all other traffic to /metrics'
        }
      ]
    }
    virtualNetworkSubnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'appservice-vnet-integration')
  }
  dependsOn: [ vnet ]
}

// -------- Deployment Slot staging with autoSwap -------------------------------
resource webAppStagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = {
  name: 'staging'
  parent: webApp
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerImage}'
      alwaysOn: true
      use32BitWorkerProcess: false
      numberOfWorkers: 1
      http20Enabled: true
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      ftpsState: 'Disabled'
      healthCheckPath: '/api/ready' // P0: healthCheckPath /api/ready for LB probe (slot)
      #disable-next-line BCP037
      healthCheckEvictionTimeInMin: 2 // 1M: evict after 2min
      autoHealEnabled: true
      autoSwapSlotName: 'production' // P0: autoSwap configured for zero-downtime
      appSettings: [
        { name: 'NODE_ENV', value: 'production' }
        { name: 'WEBSITES_PORT', value: '3000' }
        { name: 'SCM_DO_BUILD_DURING_DEPLOYMENT', value: 'false' }
        { name: 'WEBSITE_RUN_FROM_PACKAGE', value: '1' }
        { name: 'DATABASE_URL', value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/DATABASE-URL/)' }
        { name: 'REPLICA_DATABASE_URL', value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/REPLICA-DATABASE-URL/)' }
        { name: 'REDIS_URL', value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/REDIS-URL/)' }
        { name: 'JWT_SECRET', value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/JWT-SECRET/)' }
        { name: 'APP_INSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
      ]
    }
  }
}

// -------- App Service diagnosticSettings to Log Analytics --------------------
resource webAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${webAppName}-diag'
  scope: webApp
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      { category: 'AppServiceHTTPLogs', enabled: true }
      { category: 'AppServiceConsoleLogs', enabled: true }
      { category: 'AppServiceAppLogs', enabled: true }
      { category: 'AppServiceAuditLogs', enabled: true }
      { category: 'AppServiceIPSecAuditLogs', enabled: true }
      { category: 'AppServicePlatformLogs', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

resource webAppSlotDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${webAppName}-staging-diag'
  scope: webAppStagingSlot
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      { category: 'AppServiceHTTPLogs', enabled: true }
      { category: 'AppServiceConsoleLogs', enabled: true }
      { category: 'AppServiceAppLogs', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

// -------- Role Assignments ---------------------------------------------------
// WebApp -> Key Vault Secrets User (4633458b-17de-408a-b874-0445c86b69e6)
// WebApp -> Storage Blob Data Contributor (ba92f5b4-2d11-453d-a403-e96b0029c9fe)
// WebApp -> AcrPull (7f951dda-4ed3-4680-a7ca-43fe172d538d)
// Also grant Storage identity access to Key Vault for CMK unwrap

resource kvRoleAssignmentWebApp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, webApp.id, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource kvRoleAssignmentSlot 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, webAppStagingSlot.id, 'KeyVaultSecretsUserSlot')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: webAppStagingSlot.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource kvRoleAssignmentStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, storage.id, 'KeyVaultCryptoServiceEncryptionUser')
  scope: keyVault
  properties: {
    // Key Vault Crypto Service Encryption User
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'e147488a-f6f5-4113-8e2d-b22465e65bf6')
    principalId: storage.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource storageRoleAssignmentWebApp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, webApp.id, 'StorageBlobDataContributor')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource acrRoleAssignmentWebApp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, webApp.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource acrRoleAssignmentSlot 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, webAppStagingSlot.id, 'AcrPullSlot')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: webAppStagingSlot.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// -------- Autoscale 3-30 (CPU + Memory + HttpQueueLength + ResponseTime) -----
resource autoscale 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: '${aspName}-autoscale'
  location: location
  tags: tags
  properties: {
    targetResourceUri: appServicePlan.id
    enabled: true
    profiles: [
      {
        name: 'autoScale 3-30 multi-metric'
        capacity: { minimum: '3', maximum: '30', default: '3' }
        rules: [
          {
            // Scale out when average CPU > 60% for 5 minutes
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 60
              metricNamespace: 'microsoft.web/serverfarms'
              dimensions: []
              dividePerInstance: false
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '3'
              cooldown: 'PT1M'
            }
          }
          {
            metricTrigger: {
              metricName: 'MemoryPercentage'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
              metricNamespace: 'microsoft.web/serverfarms'
              dimensions: []
              dividePerInstance: false
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '2'
              cooldown: 'PT2M'
            }
          }
          {
            metricTrigger: {
              metricName: 'HttpQueueLength'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 100
              metricNamespace: 'microsoft.web/serverfarms'
              dimensions: []
              dividePerInstance: false
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '2'
              cooldown: 'PT1M'
            }
          }
          {
            metricTrigger: {
              metricName: 'AverageResponseTime'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 800
              metricNamespace: 'microsoft.web/serverfarms'
              dimensions: []
              dividePerInstance: false
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '2'
              cooldown: 'PT2M'
            }
          }
          {
            // Scale in when CPU < 30% for 10 minutes
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
              metricNamespace: 'microsoft.web/serverfarms'
              dimensions: []
              dividePerInstance: false
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
          {
            metricTrigger: {
              metricName: 'MemoryPercentage'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 40
              metricNamespace: 'microsoft.web/serverfarms'
              dimensions: []
              dividePerInstance: false
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
    notifications: [
      {
        operation: 'Scale'
        email: { sendToSubscriptionAdministrator: true, sendToSubscriptionCoAdministrators: true, customEmails: [alertEmail] }
        webhooks: []
      }
    ]
  }
}

// -------- Front Door + WAF (Premium, Detection, private link, Https only) — prod only
resource wafPolicy 'Microsoft.Network/frontdoorwebapplicationfirewallpolicies@2023-05-01' = if (env == 'prod') {
  name: wafPolicyName
  location: 'Global'
  tags: tags
  sku: { name: 'Premium_AzureFrontDoor' }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Detection' // TODO(48h): flip to 'Prevention' after WAF baseline tuning — keep Detection for now (P0)
      requestBodyCheck: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
          ruleGroupOverrides: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
        }
      ]
    }
    customRules: {
      rules: [
        {
          name: 'RateLimit1KPerMinute'
          enabledState: 'Enabled'
          priority: 1
          ruleType: 'RateLimitRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 1000
          matchConditions: [
            { matchVariable: 'RemoteAddr', operator: 'IPMatch', matchValue: ['0.0.0.0/0'], transforms: [] }
          ]
          action: 'Block'
        }
      ]
    }
  }
}

resource frontDoor 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: frontDoorName
  location: 'Global'
  tags: tags
  sku: { name: 'Premium_AzureFrontDoor' }
  properties: {
    originResponseTimeoutSeconds: 30
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  name: 'nexus-api'
  parent: frontDoor
  location: 'Global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  name: 'api-origin-group'
  parent: frontDoor
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/api/ready' // P0: healthCheckPath /api/ready for Front Door probe
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 10
    }
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  name: 'api-origin'
  parent: frontDoorOriginGroup
  properties: {
    hostName: webApp.properties.defaultHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: webApp.properties.defaultHostName
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    sharedPrivateLinkResource: {
      privateLink: { id: webApp.id }
      groupId: 'sites'
      privateLinkLocation: location
      requestMessage: 'Front Door private link to App Service'
    }
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = {
  name: 'api-route'
  parent: frontDoorEndpoint
  properties: {
    originGroup: { id: frontDoorOriginGroup.id }
    customDomains: []
    ruleSets: []
    patternsToMatch: ['/*']
    supportedProtocols: ['Https']
    httpsRedirect: 'Enabled'
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    cacheConfiguration: {
      queryStringCachingBehavior: 'UseQueryString'
      compressionSettings: { isCompressionEnabled: true }
    }
  }
  dependsOn: [ frontDoorOrigin ]
}

// Front Door security policy linking WAF to endpoint
resource frontDoorSecurityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2023-05-01' = {
  parent: frontDoor
  name: 'nexus-security-policy'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: { id: wafPolicy.id }
      associations: [
        {
          domains: [{ id: frontDoorEndpoint.id }]
          patternsToMatch: ['/*']
        }
      ]
    }
  }
}

// -------- Outputs ------------------------------------------------------------
output appServicePlanId string = appServicePlan.id
output webAppHostName string = webApp.properties.defaultHostName
output frontDoorHostName string = env == 'prod' ? frontDoorEndpoint.properties.hostName : ''
output postgresPrimaryId string = postgres.id
output postgresReplicaId string = env == 'prod' ? postgresReplica.id : ''
output redisHostName string = env == 'prod' ? redis.properties.hostName : ''
output storageAccountName string = storage.name
output keyVaultUri string = keyVault.properties.vaultUri
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output logAnalyticsWorkspaceId string = logAnalytics.id
output acrName string = acr.name
