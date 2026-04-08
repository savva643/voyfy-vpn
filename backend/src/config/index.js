require('dotenv').config();

const config = {
  port: process.env.PORT || 4000,
  
  // Database
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    name: process.env.DB_NAME || 'voyfy_vpn',
    user: process.env.DB_USER || 'voyfy',
    password: process.env.DB_PASSWORD || 'voyfy_secret',
  },
  
  // JWT Configuration
  jwt: {
    secret: process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production',
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    refreshSecret: process.env.JWT_REFRESH_SECRET || 'your-refresh-secret-key',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
  },
  
  // External Auth Service (for future integration)
  authService: {
    enabled: process.env.EXTERNAL_AUTH_ENABLED === 'true',
    url: process.env.AUTH_SERVICE_URL || 'https://auth.keep-pixel.ru',
  },
  
  // Xray Configuration
  xray: {
    apiHost: process.env.XRAY_API_HOST || 'localhost',
    apiPort: process.env.XRAY_API_PORT || 10085,
  },
  
  // Server Configuration
  server: {
    publicKey: process.env.XRAY_PUBLIC_KEY || '',
    privateKey: process.env.XRAY_PRIVATE_KEY || '',
    serverName: process.env.XRAY_SERVER_NAME || 'www.microsoft.com',
    port: process.env.XRAY_PORT || 443,
    shortId: process.env.XRAY_SHORT_ID || '0123456789abcdef',
  },
  
  // CORS
  cors: {
    origin: process.env.CORS_ORIGIN || '*',
    credentials: true,
  },
  
  // Logging
  logLevel: process.env.LOG_LEVEL || 'info',
};

module.exports = config;
