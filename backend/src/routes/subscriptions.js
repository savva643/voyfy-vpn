const express = require('express');
const router = express.Router();
const { query } = require('../db');
const logger = require('../utils/logger');
const { authenticate } = require('../middleware/auth');
const config = require('../config');
const { buildVlessUrl } = require('../controllers/subscriptionController');

// Get all locations
router.get('/locations', async (req, res) => {
  try {
    const result = await query(`
      SELECT id, country, country_code, city, region, flag_emoji
      FROM locations
      WHERE is_active = true
      ORDER BY country, city
    `);

    res.json({
      success: true,
      locations: result.rows
    });
  } catch (err) {
    logger.error('Error fetching locations:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch locations'
    });
  }
});

// Get all subscription plans
router.get('/plans', async (req, res) => {
  try {
    const result = await query(`
      SELECT id, name, description, duration_days, data_limit_gb,
             price_usd, price_rub, price_eur, features, is_popular
      FROM subscription_plans
      WHERE is_active = true
      ORDER BY price_usd ASC
    `);

    res.json({
      success: true,
      plans: result.rows
    });
  } catch (err) {
    logger.error('Error fetching subscription plans:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch subscription plans'
    });
  }
});

// Get VLESS config for specific server
router.get('/config/:serverId', authenticate, async (req, res) => {
  try {
    const userId = req.user?.id;
    const { serverId } = req.params;

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    // Get user UUID
    const userResult = await query(
      'SELECT uuid FROM users WHERE id = $1 AND is_active = true',
      [userId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    const userUuid = userResult.rows[0].uuid;

    // Get server details
    const serverResult = await query(
      'SELECT * FROM vpn_servers WHERE id = $1 AND is_active = true',
      [serverId]
    );

    if (serverResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Server not found'
      });
    }

    const server = serverResult.rows[0];

    // Build VLESS URL using buildVlessUrl function (removes Hash32 prefix)
    const vlessUrl = buildVlessUrl(userUuid, server, server.name);

    res.json({
      success: true,
      config: {
        vlessUrl,
        serverId: server.id,
        serverName: server.name,
        host: server.host,
        port: server.port || config.server.port
      }
    });
  } catch (err) {
    logger.error('Error generating config:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to generate config'
    });
  }
});

module.exports = router;