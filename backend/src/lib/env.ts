const required = (name: string): string => {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
};

export const env = {
  JWT_SECRET: required('JWT_SECRET'),
  DATABASE_URL: required('DATABASE_URL'),
  NODE_ENV: process.env.NODE_ENV || 'development',
  isProduction: (process.env.NODE_ENV || 'development') === 'production',
  GROQ_API_KEY: process.env.GROQ_API_KEY,
  WOLFRAM_APP_ID: process.env.WOLFRAM_APP_ID,
  GOOGLE_SERVER_CLIENT_ID: process.env.GOOGLE_SERVER_CLIENT_ID,
  ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS,
  // Explicit opt-in only — see the CORS setup in index.ts for why this isn't
  // inferred from NODE_ENV. Never set this outside a local .env.
  ALLOW_ALL_ORIGINS_DEV: process.env.ALLOW_ALL_ORIGINS_DEV === 'true',
  // Composio (agent platform) API key — used to send the parent digest email
  // through a connected Gmail account (GMAIL_SEND_EMAIL). Optional: when unset
  // the digest falls back to SMTP_* or stays in-app.
  COMPOSIO_API_KEY: process.env.COMPOSIO_API_KEY,
  // AI
  AI_MODEL: process.env.AI_MODEL,
  // RAG (free embeddings): provider is 'openrouter' (nvidia/nemotron-3-embed-
  // 1b:free, needs OPENROUTER_API_KEY) or 'groq' (nomic-embed-text-v1_5,
  // reuses GROQ_API_KEY — only if the Groq account has embeddings access).
  // RAG_ENABLED=false turns retrieval off entirely.
  RAG_ENABLED: process.env.RAG_ENABLED !== 'false',
  EMBEDDING_PROVIDER: process.env.EMBEDDING_PROVIDER || 'openrouter',
  EMBEDDING_MODEL: process.env.EMBEDDING_MODEL,
  OPENROUTER_API_KEY: process.env.OPENROUTER_API_KEY,
  // App public URL used in reset-password links (dev convenience).
  APP_URL: process.env.APP_URL || 'http://localhost:3000',
  // Explicit opt-in to echo password-reset tokens in API responses. NEVER set
  // this in production; forgot-password must deliver tokens out-of-band.
  DEV_ALLOW_RESET_TOKEN_IN_RESPONSE: process.env.DEV_ALLOW_RESET_TOKEN_IN_RESPONSE === 'true',
  // Optional SMTP. When unset, the parent digest is in-app only and the daily
  // email worker is a no-op (see src/services/digestMailer.ts).
  SMTP_HOST: process.env.SMTP_HOST,
  SMTP_PORT: Number(process.env.SMTP_PORT || 587),
  SMTP_USER: process.env.SMTP_USER,
  SMTP_PASS: process.env.SMTP_PASS,
  DIGEST_FROM_EMAIL: process.env.DIGEST_FROM_EMAIL || 'Nexus Edu <digest@nexusedu.app>',
  DIGEST_ENABLED: process.env.DIGEST_ENABLED !== 'false',
  // Azure AI services (free F0 tiers)
  AZURE_SPEECH_KEY: process.env.AZURE_SPEECH_KEY,
  AZURE_SPEECH_REGION: process.env.AZURE_SPEECH_REGION || 'southeastasia',
  // Azure OpenAI — when all three are set, AI answers use it instead of Groq.
  AZURE_OPENAI_API_KEY: process.env.AZURE_OPENAI_API_KEY,
  AZURE_OPENAI_ENDPOINT: process.env.AZURE_OPENAI_ENDPOINT,
  AZURE_OPENAI_DEPLOYMENT: process.env.AZURE_OPENAI_DEPLOYMENT,
  AZURE_TRANSLATOR_KEY: process.env.AZURE_TRANSLATOR_KEY,
  AZURE_TRANSLATOR_REGION: process.env.AZURE_TRANSLATOR_REGION || 'global',
  AZURE_DOC_INTEL_KEY: process.env.AZURE_DOC_INTEL_KEY,
  AZURE_DOC_INTEL_ENDPOINT: process.env.AZURE_DOC_INTEL_ENDPOINT,
  AZURE_CONTENT_SAFETY_KEY: process.env.AZURE_CONTENT_SAFETY_KEY,
  AZURE_CONTENT_SAFETY_ENDPOINT: process.env.AZURE_CONTENT_SAFETY_ENDPOINT,
  AZURE_LANGUAGE_KEY: process.env.AZURE_LANGUAGE_KEY,
  AZURE_LANGUAGE_ENDPOINT: process.env.AZURE_LANGUAGE_ENDPOINT,
  AZURE_VISION_KEY: process.env.AZURE_VISION_KEY,
  AZURE_VISION_ENDPOINT: process.env.AZURE_VISION_ENDPOINT,
  // Application Insights connection string — when unset, monitoring is off.
  APP_INSIGHTS_CONNECTION_STRING: process.env.APP_INSIGHTS_CONNECTION_STRING,
};
