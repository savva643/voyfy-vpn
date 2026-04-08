const express = require('express');
const cors = require('cors');
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

const app = express();

// Middleware
app.use(cors(config.cors));
app.use(express.json());

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

// FUTURE: External OAuth/SSO
app.post('/api/auth/oauth/login', authController.externalLogin);

// ==========================================
// Subscription Routes
// ==========================================
app.get('/api/subscription', authenticate, subscriptionController.getSubscription);
app.get('/api/subscription/json', authenticate, subscriptionController.getSubscriptionJson);
app.get('/api/subscription/:uuid', subscriptionController.getSubscriptionByUuid);

// ==========================================
// Server Routes (Public)
// ==========================================
app.get('/api/servers', serverController.getServers);
app.get('/api/servers/:id', serverController.getServerById);

// ==========================================
// User Routes (Authenticated)
// ==========================================
app.get('/api/user/profile', authenticate, userController.getProfile);

// ==========================================
// Admin Routes (Admin Only)
// ==========================================

// Server Management
app.post('/api/admin/servers', authenticate, requireAdmin, serverController.addServer);
app.put('/api/admin/servers/:id', authenticate, requireAdmin, serverController.updateServer);
app.delete('/api/admin/servers/:id', authenticate, requireAdmin, serverController.deleteServer);
app.get('/api/admin/xray-config', authenticate, requireAdmin, serverController.getXrayConfig);

// User Management
app.get('/api/admin/users', authenticate, requireAdmin, userController.getAllUsers);
app.put('/api/admin/users/:id', authenticate, requireAdmin, userController.updateUser);
app.post('/api/admin/users/:id/reset-usage', authenticate, requireAdmin, userController.resetUsage);
app.delete('/api/admin/users/:id', authenticate, requireAdmin, userController.deleteUser);

// Usage Update (for Xray stats collection)
app.post('/api/subscription/usage', authenticate, requireAdmin, subscriptionController.updateUsage);

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


