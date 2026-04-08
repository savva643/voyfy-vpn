const jwt = require('jsonwebtoken');
const config = require('../config');
const { query } = require('../db');
const logger = require('../utils/logger');

/**
 * JWT Authentication Middleware
 * Verifies access token and attaches user info to request
 */
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ 
        success: false, 
        message: 'Access token required' 
      });
    }

    const token = authHeader.substring(7);
    
    try {
      const decoded = jwt.verify(token, config.jwt.secret);
      
      // Verify user still exists and is active
      const userResult = await query(
        'SELECT id, email, uuid, is_active, is_admin, data_limit, used_data, expiry_date FROM users WHERE id = $1',
        [decoded.userId]
      );
      
      if (userResult.rows.length === 0) {
        return res.status(401).json({ 
          success: false, 
          message: 'User not found' 
        });
      }
      
      const user = userResult.rows[0];
      
      if (!user.is_active) {
        return res.status(401).json({ 
          success: false, 
          message: 'Account is deactivated' 
        });
      }
      
      // Check subscription expiry
      if (new Date(user.expiry_date) < new Date()) {
        return res.status(403).json({ 
          success: false, 
          message: 'Subscription expired' 
        });
      }
      
      // Attach user to request
      req.user = {
        id: user.id,
        email: user.email,
        uuid: user.uuid,
        isAdmin: user.is_admin,
        dataLimit: user.data_limit,
        usedData: user.used_data,
        expiryDate: user.expiry_date,
      };
      
      next();
    } catch (jwtErr) {
      if (jwtErr.name === 'TokenExpiredError') {
        return res.status(401).json({ 
          success: false, 
          message: 'Token expired',
          code: 'TOKEN_EXPIRED'
        });
      }
      
      return res.status(401).json({ 
        success: false, 
        message: 'Invalid token' 
      });
    }
  } catch (err) {
    logger.error('Authentication error', err);
    return res.status(500).json({ 
      success: false, 
      message: 'Internal server error' 
    });
  }
};

/**
 * Admin-only middleware
 */
const requireAdmin = (req, res, next) => {
  if (!req.user || !req.user.isAdmin) {
    return res.status(403).json({ 
      success: false, 
      message: 'Admin access required' 
    });
  }
  next();
};

/**
 * Optional authentication - attaches user if token valid, but doesn't require it
 */
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next();
    }

    const token = authHeader.substring(7);
    
    try {
      const decoded = jwt.verify(token, config.jwt.secret);
      
      const userResult = await query(
        'SELECT id, email, uuid, is_active, is_admin FROM users WHERE id = $1',
        [decoded.userId]
      );
      
      if (userResult.rows.length > 0) {
        const user = userResult.rows[0];
        req.user = {
          id: user.id,
          email: user.email,
          uuid: user.uuid,
          isAdmin: user.is_admin,
        };
      }
    } catch (err) {
      // Ignore token errors for optional auth
    }
    
    next();
  } catch (err) {
    next();
  }
};

module.exports = {
  authenticate,
  requireAdmin,
  optionalAuth,
};
