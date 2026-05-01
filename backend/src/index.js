const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const config = require('./config');
const logger = require('./utils/logger');
const { initDatabase } = require('./db');
const { authenticate, requireAdmin } = require('./middleware/auth');

// Controllers
const authController = require('./controllers/authController');
const subscriptionController = require('./controllers/subscriptionController');
const serverController = require('./controllers/serverController');
const userController = require('./controllers/userController');
const subscriptionRoutes = require('./routes/subscriptions');

const app = express();

// Middleware
app.use(cors(config.cors));
app.use(express.json());

// Static files - Admin panel
app.use(express.static(path.join(__dirname, 'public')));

// Admin panel route
app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

// Request logging
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    ip: req.ip,
    userAgent: req.get('user-agent'),
  });
  next();
});

// ==========================================
// Health Check
// ==========================================
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    service: 'voyfy-backend',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

// ==========================================
// Auth Routes (Test Mode)
// ==========================================
app.post('/api/auth/register', authController.register);
app.post('/api/auth/login', authController.login);
app.post('/api/auth/refresh', authController.refreshToken);
app.post('/api/auth/logout', authController.logout);
app.get('/api/auth/validate', authenticate, authController.validateSession);
app.get('/api/auth/validate-session', authenticate, authController.validateSession); // Alias for frontend

// FUTURE: External OAuth/SSO
app.post('/api/auth/oauth/login', authController.externalLogin);

// ==========================================
// Subscription Routes
// ==========================================
// First: mount the subscription routes (MUST be before /api/subscription/:uuid)
app.use('/api/subscriptions', subscriptionRoutes);

// Then: individual subscription endpoints
app.get('/api/subscription', authenticate, subscriptionController.getSubscription);
app.get('/api/subscription/json', authenticate, subscriptionController.getSubscriptionJson);
app.get('/api/subscription/:uuid', subscriptionController.getSubscriptionByUuid);

// ==========================================
// Server Routes (Public)
// ==========================================
app.get('/api/servers', serverController.getServers);

// ==========================================
// Xray Binary Routes (Public)
// ==========================================
const fs = require('fs');
const path = require('path');

const XRAY_BINARIES_DIR = path.join(__dirname, 'xray-binaries');

// Map of platform-arch to binary filename
const XRAY_BINARIES = {
  'windows-amd64': 'xray-windows-64.exe',
  'windows-arm64': 'xray-windows-arm64.exe',
  'linux-amd64': 'xray-linux-64',
  'linux-arm64': 'xray-linux-arm64-v8a',
  'darwin-amd64': 'xray-darwin-64',      // macOS Intel
  'darwin-arm64': 'xray-darwin-arm64',   // macOS Apple Silicon
};

// Download Xray binary
app.get('/xray/download', (req, res) => {
  const { platform, arch } = req.query;
  
  if (!platform || !arch) {
    return res.status(400).json({ 
      error: 'Missing parameters. Required: platform, arch' 
    });
  }
  
  const key = `${platform}-${arch}`;
  const filename = XRAY_BINARIES[key];
  
  if (!filename) {
    return res.status(404).json({ 
      error: 'Binary not found for platform-arch combination',
      supported: Object.keys(XRAY_BINARIES)
    });
  }
  
  const filePath = path.join(XRAY_BINARIES_DIR, filename);
  
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ 
      error: 'Binary file not found on server',
      file: filename
    });
  }
  
  // Set headers for download
  res.setHeader('Content-Type', 'application/octet-stream');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  res.setHeader('Content-Length', fs.statSync(filePath).size);
  
  // Stream file
  const stream = fs.createReadStream(filePath);
  stream.pipe(res);
  
  logger.info(`Xray binary downloaded: ${filename} (${platform}-${arch})`);
});

// Get binary checksum
app.get('/xray/checksum', (req, res) => {
  const { platform, arch } = req.query;
  
  if (!platform || !arch) {
    return res.status(400).json({ 
      error: 'Missing parameters. Required: platform, arch' 
    });
  }
  
  const key = `${platform}-${arch}`;
  const filename = XRAY_BINARIES[key];
  
  if (!filename) {
    return res.status(404).json({ 
      error: 'Binary not found for platform-arch combination',
      supported: Object.keys(XRAY_BINARIES)
    });
  }
  
  const filePath = path.join(XRAY_BINARIES_DIR, filename);
  
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ 
      error: 'Binary file not found on server' 
    });
  }
  
  // Calculate SHA256
  const crypto = require('crypto');
  const fileBuffer = fs.readFileSync(filePath);
  const hash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
  
  res.json({
    platform,
    arch,
    filename,
    sha256: hash,
    size: fs.statSync(filePath).size,
  });
});
app.get('/api/servers/:id', serverController.getServerById);

// ==========================================
// User Routes (Authenticated)
// ==========================================
app.get('/api/user/profile', authenticate, userController.getProfile);

// ==========================================
// VPN Server Management (Admin & Server)
// ==========================================
// Server self-registration (uses pairing code)
app.post('/api/servers/register', serverController.registerServer);
app.post('/api/servers/:id/heartbeat', serverController.serverHeartbeat);
app.post('/api/servers/verify-code', serverController.verifyPairingCode);

// Admin server listing with full details
app.get('/api/admin/servers', authenticate, requireAdmin, serverController.getAdminServers);
app.delete('/api/admin/servers/:id', authenticate, requireAdmin, serverController.deleteServer);

// Pairing codes (Admin only)
app.get('/api/admin/pairing-codes', authenticate, requireAdmin, serverController.getPairingCodes);
app.post('/api/admin/pairing-codes', authenticate, requireAdmin, serverController.createPairingCode);
app.get('/api/admin/xray-config', authenticate, requireAdmin, serverController.getXrayConfig);

// ==========================================
// Admin Routes (Admin Only)
// ==========================================

// User Management
app.get('/api/admin/users', authenticate, requireAdmin, userController.getAllUsers);
app.put('/api/admin/users/:id', authenticate, requireAdmin, userController.updateUser);
app.post('/api/admin/users/:id/reset-usage', authenticate, requireAdmin, userController.resetUsage);
app.delete('/api/admin/users/:id', authenticate, requireAdmin, userController.deleteUser);

// Usage Update (for Xray stats collection)
app.post('/api/subscription/usage', authenticate, requireAdmin, subscriptionController.updateUsage);

// ==========================================
// Admin Panel Static Files
// ==========================================
app.use('/admin', express.static(path.join(__dirname, 'public')));
app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

// ==========================================
// Error Handling
// ==========================================
app.use((err, req, res, next) => {
  logger.error('Unhandled error', err);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
  });
});

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Endpoint not found',
  });
});

// ==========================================
// Server Startup
// ==========================================
const startServer = async () => {
  try {
    // Initialize database
    await initDatabase();
    logger.info('Database initialized');
    
    // Start server
    app.listen(config.port, () => {
      logger.info(`Voyfy backend is running on http://localhost:${config.port}`);
      logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
    });
  } catch (err) {
    logger.error('Failed to start server', err);
    process.exit(1);
  }
};

startServer();


