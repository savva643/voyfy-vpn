const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const { query } = require('../db');
const config = require('../config');
const logger = require('../utils/logger');

/**
 * Generate JWT tokens for user
 */
const generateTokens = (userId, email) => {
  const accessToken = jwt.sign(
    { userId, email, type: 'access' },
    config.jwt.secret,
    { expiresIn: config.jwt.expiresIn }
  );
  
  const refreshToken = jwt.sign(
    { userId, email, type: 'refresh' },
    config.jwt.refreshSecret,
    { expiresIn: config.jwt.refreshExpiresIn }
  );
  
  return { accessToken, refreshToken };
};

/**
 * TEST AUTH: Register new user (test mode - no external auth)
 * POST /api/auth/register
 */
const register = async (req, res) => {
  try {
    const { email, password, name } = req.body;
    
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required'
      });
    }
    
    // Check if user exists
    const existingUser = await query('SELECT id FROM users WHERE email = $1', [email]);
    if (existingUser.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'User already exists'
      });
    }
    
    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);
    
    // Generate unique UUID for Xray
    const userUuid = uuidv4();
    
    // Create subscription URL
    const subscriptionUrl = `${config.serverName}/sub/${userUuid}`;
    
    // Create user
    const result = await query(
      `INSERT INTO users (email, password_hash, uuid, subscription_url) 
       VALUES ($1, $2, $3, $4) 
       RETURNING id, email, uuid, subscription_url, created_at`,
      [email, passwordHash, userUuid, subscriptionUrl]
    );
    
    const user = result.rows[0];
    
    // Generate tokens
    const { accessToken, refreshToken } = generateTokens(user.id, user.email);
    
    // Save refresh token
    await query(
      `INSERT INTO user_sessions (user_id, refresh_token, device_info, expires_at)
       VALUES ($1, $2, $3, $4)`,
      [
        user.id,
        refreshToken,
        JSON.stringify({
          platform: req.headers['platform'] || 'unknown',
          deviceType: req.headers['device-type'] || 'unknown',
          appVersion: req.headers['app-version'] || 'unknown',
        }),
        new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
      ]
    );
    
    logger.info(`User registered: ${email}`);
    
    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      data: {
        userId: user.id,
        email: user.email,
        uuid: user.uuid,
        subscriptionUrl: user.subscription_url,
        tokens: {
          accessToken,
          refreshToken,
          expiresIn: config.jwt.expiresIn,
        }
      }
    });
  } catch (err) {
    logger.error('Registration error', err);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * TEST AUTH: Login user (test mode - no external auth)
 * POST /api/auth/login
 */
const login = async (req, res) => {
  try {
    const { email, password } = req.body;
    
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required'
      });
    }
    
    // Find user
    const result = await query(
      'SELECT id, email, password_hash, uuid, is_active, subscription_url FROM users WHERE email = $1',
      [email]
    );
    
    if (result.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }
    
    const user = result.rows[0];
    
    if (!user.is_active) {
      return res.status(401).json({
        success: false,
        message: 'Account is deactivated'
      });
    }
    
    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }
    
    // Generate tokens
    const { accessToken, refreshToken } = generateTokens(user.id, user.email);
    
    // Save refresh token
    await query(
      `INSERT INTO user_sessions (user_id, refresh_token, device_info, expires_at)
       VALUES ($1, $2, $3, $4)`,
      [
        user.id,
        refreshToken,
        JSON.stringify({
          platform: req.headers['platform'] || 'unknown',
          deviceType: req.headers['device-type'] || 'unknown',
          appVersion: req.headers['app-version'] || 'unknown',
        }),
        new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
      ]
    );
    
    logger.info(`User logged in: ${email}`);
    
    res.json({
      success: true,
      message: 'Login successful',
      data: {
        userId: user.id,
        email: user.email,
        uuid: user.uuid,
        subscriptionUrl: user.subscription_url,
        tokens: {
          accessToken,
          refreshToken,
          expiresIn: config.jwt.expiresIn,
        }
      }
    });
  } catch (err) {
    logger.error('Login error', err);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Refresh access token
 * POST /api/auth/refresh
 */
const refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    
    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        message: 'Refresh token required'
      });
    }
    
    try {
      const decoded = jwt.verify(refreshToken, config.jwt.refreshSecret);
      
      // Check if refresh token exists in database
      const sessionResult = await query(
        'SELECT user_id FROM user_sessions WHERE refresh_token = $1 AND expires_at > NOW()',
        [refreshToken]
      );
      
      if (sessionResult.rows.length === 0) {
        return res.status(401).json({
          success: false,
          message: 'Invalid or expired refresh token'
        });
      }
      
      // Get user info
      const userResult = await query(
        'SELECT id, email FROM users WHERE id = $1 AND is_active = true',
        [decoded.userId]
      );
      
      if (userResult.rows.length === 0) {
        return res.status(401).json({
          success: false,
          message: 'User not found or inactive'
        });
      }
      
      const user = userResult.rows[0];
      
      // Generate new tokens
      const tokens = generateTokens(user.id, user.email);
      
      // Update refresh token in database
      await query(
        'UPDATE user_sessions SET refresh_token = $1, expires_at = $2 WHERE refresh_token = $3',
        [
          tokens.refreshToken,
          new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
          refreshToken
        ]
      );
      
      res.json({
        success: true,
        data: {
          tokens: {
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresIn: config.jwt.expiresIn,
          }
        }
      });
    } catch (jwtErr) {
      return res.status(401).json({
        success: false,
        message: 'Invalid refresh token'
      });
    }
  } catch (err) {
    logger.error('Refresh token error', err);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Logout user
 * POST /api/auth/logout
 */
const logout = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    const userId = req.user?.id;
    
    if (refreshToken) {
      // Remove specific session
      await query('DELETE FROM user_sessions WHERE refresh_token = $1', [refreshToken]);
    } else if (userId) {
      // Remove all user sessions
      await query('DELETE FROM user_sessions WHERE user_id = $1', [userId]);
    }
    
    res.json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (err) {
    logger.error('Logout error', err);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Validate session/token
 * GET /api/auth/validate
 */
const validateSession = async (req, res) => {
  try {
    // User is already attached by authenticate middleware
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid session'
      });
    }
    
    res.json({
      success: true,
      data: {
        user: req.user
      }
    });
  } catch (err) {
    logger.error('Validate session error', err);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * FUTURE: External OAuth/SSO login
 * POST /api/auth/oauth/login
 * This is a placeholder for future external auth integration
 */
const externalLogin = async (req, res) => {
  // TODO: Implement external auth service integration
  // This will be used when connecting to existing ecosystem
  res.status(501).json({
    success: false,
    message: 'External authentication not yet implemented. Use /api/auth/login for test mode.'
  });
};

module.exports = {
  register,
  login,
  refreshToken,
  logout,
  validateSession,
  externalLogin,
};
