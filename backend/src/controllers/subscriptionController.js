const { query } = require('../db');
const config = require('../config');
const logger = require('../utils/logger');

/**
 * Build Hysteria2 URI for user
 * Format: hysteria2://password@host:port?params#name
 */
const buildHysteria2Url = (password, server, name) => {
  // Extract SNI safely
  let sni = 'www.gosuslugi.ru';
  if (server.masquerade_url) {
    try {
      sni = new URL(server.masquerade_url).hostname;
    } catch (e) {
      sni = server.masquerade_url; // Use as-is if not valid URL
    }
  }

  const params = new URLSearchParams({
    obfs: 'salamander',
    'obfs-password': server.obfs_password || config.server?.obfsPassword || 'voyfy_obfs_secret',
    sni: sni,
  });

  const port = server.port || config.server?.port || 8444;

  return `hysteria2://${password}@${server.host}:${port}?${params.toString()}#${encodeURIComponent(name)}`;
};

/**
 * Generate subscription content for user
 * Returns base64 encoded Hysteria2 links
 */
const generateSubscription = async (userId) => {
  try {
    // Get user info - Hysteria2 uses server password, not user UUID
    const userResult = await query(
      'SELECT id FROM users WHERE id = $1 AND is_active = true',
      [userId]
    );

    if (userResult.rows.length === 0) {
      throw new Error('User not found or inactive');
    }

    // Get active servers with Hysteria2 credentials
    const serversResult = await query(
      'SELECT * FROM vpn_servers WHERE is_active = true AND protocol = $1 ORDER BY country, name',
      ['hysteria2']
    );

    if (serversResult.rows.length === 0) {
      throw new Error('No active Hysteria2 servers available');
    }

    // Generate Hysteria2 URIs for each server
    const hysteria2Urls = serversResult.rows.map(server =>
      buildHysteria2Url(server.password, server, server.name || `${server.country}-${server.host}`)
    );

    // Join with newlines and encode
    const subscriptionContent = hysteria2Urls.join('\n');
    const base64Content = Buffer.from(subscriptionContent).toString('base64');

    return {
      success: true,
      content: base64Content,
      servers: serversResult.rows.map(server => ({
        id: server.id,
        name: server.name || `${server.country}-${server.host}`,
        country: server.country,
        host: server.host,
        port: server.port,
        protocol: 'hysteria2',
        security: 'tls'
      })),
      rawUrls: hysteria2Urls
    };
  } catch (err) {
    logger.error('Generate subscription error', err);
    return {
      success: false,
      message: 'Failed to generate subscription'
    };
  }
};

/**
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
          hysteria2Url: subscription.rawUrls[index],
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
 * Get user's Hysteria2 configuration for specific server
 */
const getUserConfig = async (userId, serverId) => {
  try {
    // Get user info
    const userResult = await query(
      'SELECT id FROM users WHERE id = $1 AND is_active = true',
      [userId]
    );

    if (userResult.rows.length === 0) {
      return {
        success: false,
        message: 'User not found or inactive'
      };
    }

    // Get Hysteria2 server info
    const serverResult = await query(
      'SELECT * FROM vpn_servers WHERE id = $1 AND is_active = true AND protocol = $2',
      [serverId, 'hysteria2']
    );

    if (serverResult.rows.length === 0) {
      return {
        success: false,
        message: 'Hysteria2 server not found or inactive'
      };
    }

    const server = serverResult.rows[0];

    // Generate Hysteria2 URI using buildHysteria2Url function
    const hysteria2Url = buildHysteria2Url(server.password, server, server.name || `${server.country}-${server.host}`);

    return {
      success: true,
      config: {
        hysteria2Url: hysteria2Url,
        serverId: server.id,
        serverName: server.name || `${server.country}-${server.host}`,
        host: server.host,
        port: server.port,
        protocol: 'hysteria2'
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
  buildHysteria2Url,
};