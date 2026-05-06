const { query } = require('../db');
const config = require('../config');
const logger = require('../utils/logger');

/**
 * Build VLESS URL for user
 * Format: vless://uuid@host:port?params#name
 */
const buildVlessUrl = (userUuid, server, name) => {
  // Remove Hash32: prefix from public_key if present
  const publicKey = (server.public_key || config.server.publicKey).replace(/^Hash32:\s*/, '');
  
  const params = new URLSearchParams({
    security: 'reality',
    encryption: 'none',
    pbk: publicKey,
    headerType: 'none',
    fp: 'chrome',
    type: 'tcp',
    flow: 'xtls-rprx-vision',
    sni: config.server.serverName,
    sid: server.short_id || config.server.shortId,
  });
  
  return `vless://${userUuid}@${server.host}:${server.port || config.server.port}?${params.toString()}#${encodeURIComponent(name)}`;
};

/**
 * Generate subscription content for user
 * Returns base64 encoded VLESS links
 */
const generateSubscription = async (userId) => {
  try {
    // Get user info
    const userResult = await query(
      'SELECT uuid FROM users WHERE id = $1 AND is_active = true',
      [userId]
    );
    
    if (userResult.rows.length === 0) {
      throw new Error('User not found or inactive');
    }
    
    const userUuid = userResult.rows[0].uuid;
    
    // Get active servers
    const serversResult = await query(
      'SELECT * FROM vpn_servers WHERE is_active = true ORDER BY country, name',
      []
    );
    
    const servers = serversResult.rows;
    
    if (servers.length === 0) {
      throw new Error('No active servers available');
    }
    
    // Build VLESS URLs for each server
    const urls = servers.map(server => {
      const name = `${server.country} - ${server.name}${server.premium ? ' (Premium)' : ''}`;
      return buildVlessUrl(userUuid, server, name);
    });
    
    // Join and encode
    const subscriptionContent = urls.join('\n');
    const base64Content = Buffer.from(subscriptionContent).toString('base64');
    
    return {
      content: base64Content,
      servers: servers.map(s => ({
        id: s.id,
        name: s.name,
        country: s.country,
        countryCode: s.country_code,
        host: s.host,
        port: s.port,
        premium: s.premium,
        load: s.load_percentage,
      })),
      rawUrls: urls,
    };
  } catch (err) {
    logger.error('Generate subscription error', err);
    throw err;
  }
};

/**
 * Get subscription for authenticated user
 * GET /api/subscription
 */
const getSubscription = async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Get user subscription info
    const userResult = await query(
      'SELECT data_limit, used_data, expiry_date FROM users WHERE id = $1',
      [userId]
    );
    
    if (userResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    const user = userResult.rows[0];
    
    // Generate subscription
    const subscription = await generateSubscription(userId);
    
    res.json({
      success: true,
      data: {
        subscriptionUrl: `${req.protocol}://${req.get('host')}/api/subscription/${req.user.uuid}`,
        subscriptionContent: subscription.content,
        servers: subscription.servers,
        stats: {
          dataLimit: parseInt(user.data_limit),
          usedData: parseInt(user.used_data),
          remainingData: parseInt(user.data_limit) - parseInt(user.used_data),
          expiryDate: user.expiry_date,
          isActive: new Date(user.expiry_date) > new Date(),
        }
      }
    });
  } catch (err) {
    logger.error('Get subscription error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to generate subscription'
    });
  }
};

/**
 * Get subscription by UUID (for VPN clients)
 * GET /api/subscription/:uuid
 */
const getSubscriptionByUuid = async (req, res) => {
  try {
    const { uuid } = req.params;
    
    // Find user by UUID
    const userResult = await query(
      'SELECT id, is_active, expiry_date FROM users WHERE uuid = $1',
      [uuid]
    );
    
    if (userResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Subscription not found'
      });
    }
    
    const user = userResult.rows[0];
    
    if (!user.is_active) {
      return res.status(403).json({
        success: false,
        message: 'Subscription is deactivated'
      });
    }
    
    if (new Date(user.expiry_date) < new Date()) {
      return res.status(403).json({
        success: false,
        message: 'Subscription expired'
      });
    }
    
    // Generate subscription
    const subscription = await generateSubscription(user.id);
    
    // Return as plain text for VPN clients
    res.setHeader('Content-Type', 'text/plain');
    res.setHeader('Subscription-Userinfo', `upload=0; download=${user.used_data}; total=${user.data_limit}; expire=${Math.floor(new Date(user.expiry_date).getTime() / 1000)}`);
    res.send(subscription.content);
  } catch (err) {
    logger.error('Get subscription by UUID error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to generate subscription'
    });
  }
};

/**
 * Get subscription in JSON format with server details
 * GET /api/subscription/json
 */
const getSubscriptionJson = async (req, res) => {
  try {
    const userId = req.user.id;
    
    const subscription = await generateSubscription(userId);
    
    res.json({
      success: true,
      data: {
        servers: subscription.servers.map((server, index) => ({
          ...server,
          vlessUrl: subscription.rawUrls[index],
        })),
      }
    });
  } catch (err) {
    logger.error('Get subscription JSON error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to generate subscription'
    });
  }
};

/**
 * Update user data usage
 * POST /api/subscription/usage (internal/admin)
 */
const updateUsage = async (req, res) => {
  try {
    const { userId, bytesUsed } = req.body;
    
    await query(
      'UPDATE users SET used_data = used_data + $1, updated_at = NOW() WHERE id = $2',
      [bytesUsed, userId]
    );
    
    res.json({
      success: true,
      message: 'Usage updated'
    });
  } catch (err) {
    logger.error('Update usage error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to update usage'
    });
  }
};

/**
 * Get user's VLESS configuration for specific server
 */
const getUserConfig = async (userId, serverId) => {
  try {
    // Get user info
    const userResult = await query(
      'SELECT uuid FROM users WHERE id = $1 AND is_active = true',
      [userId]
    );
    
    if (userResult.rows.length === 0) {
      return {
        success: false,
        message: 'User not found or inactive'
      };
    }
    
    const userUuid = userResult.rows[0].uuid;
    
    // Get server info
    const serverResult = await query(
      'SELECT * FROM vpn_servers WHERE id = $1 AND is_active = true',
      [serverId]
    );
    
    if (serverResult.rows.length === 0) {
      return {
        success: false,
        message: 'Server not found or inactive'
      };
    }
    
    const server = serverResult.rows[0];
    
    // Generate VLESS URL using buildVlessUrl function (removes Hash32 prefix)
    const vlessUrl = buildVlessUrl(userUuid, server, server.name || `${server.country}-${server.host}`);
    
    return {
      success: true,
      config: {
        vlessUrl: vlessUrl,
        serverId: server.id,
        serverName: server.name || `${server.country}-${server.host}`,
        host: server.host,
        port: server.port
      }
    };
  } catch (err) {
    logger.error('Get user config error', err);
    return {
      success: false,
      message: 'Failed to get configuration'
    };
  }
};

module.exports = {
  getSubscriptionByUuid,
  getSubscriptionJson,
  updateUsage,
  generateSubscription,
  getUserConfig,
  buildVlessUrl,
};
