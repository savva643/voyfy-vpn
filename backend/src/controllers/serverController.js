const { query } = require('../db');
const logger = require('../utils/logger');
const { generateSubscription } = require('./subscriptionController');

/**
 * Get all servers
 * GET /api/servers
 */
const getServers = async (req, res) => {
  try {
    const includePremium = req.user ? true : false;
    
    let serversResult;
    if (includePremium) {
      serversResult = await query(
        'SELECT id, name, country, country_code, host, port, premium, load_percentage, is_active FROM vpn_servers WHERE is_active = true ORDER BY country',
        []
      );
    } else {
      serversResult = await query(
        'SELECT id, name, country, country_code, host, port, premium, load_percentage, is_active FROM vpn_servers WHERE is_active = true AND premium = false ORDER BY country',
        []
      );
    }
    
    res.json({
      success: true,
      data: {
        servers: serversResult.rows.map(s => ({
          id: s.id,
          name: s.name,
          country: s.country,
          countryCode: s.country_code,
          host: s.host,
          port: s.port,
          premium: s.premium,
          load: s.load_percentage,
        }))
      }
    });
  } catch (err) {
    logger.error('Get servers error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to get servers'
    });
  }
};

/**
 * Get server by ID
 * GET /api/servers/:id
 */
const getServerById = async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await query(
      'SELECT * FROM vpn_servers WHERE id = $1',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Server not found'
      });
    }
    
    res.json({
      success: true,
      data: {
        server: result.rows[0]
      }
    });
  } catch (err) {
    logger.error('Get server by ID error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to get server'
    });
  }
};

/**
 * Add new server (Admin only)
 * POST /api/admin/servers
 */
const addServer = async (req, res) => {
  try {
    const { name, country, countryCode, host, port, premium } = req.body;
    
    if (!name || !country || !countryCode || !host) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: name, country, countryCode, host'
      });
    }
    
    const result = await query(
      `INSERT INTO vpn_servers (name, country, country_code, host, port, premium)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [name, country, countryCode, host, port || 443, premium || false]
    );
    
    const server = result.rows[0];
    
    logger.info(`Server added: ${server.name} (${server.country})`);
    
    res.status(201).json({
      success: true,
      message: 'Server added successfully',
      data: { server }
    });
  } catch (err) {
    logger.error('Add server error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to add server'
    });
  }
};

/**
 * Update server (Admin only)
 * PUT /api/admin/servers/:id
 */
const updateServer = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, country, countryCode, host, port, premium, isActive, loadPercentage } = req.body;
    
    const result = await query(
      `UPDATE vpn_servers 
       SET name = COALESCE($1, name),
           country = COALESCE($2, country),
           country_code = COALESCE($3, country_code),
           host = COALESCE($4, host),
           port = COALESCE($5, port),
           premium = COALESCE($6, premium),
           is_active = COALESCE($7, is_active),
           load_percentage = COALESCE($8, load_percentage),
           updated_at = NOW()
       WHERE id = $9
       RETURNING *`,
      [name, country, countryCode, host, port, premium, isActive, loadPercentage, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Server not found'
      });
    }
    
    logger.info(`Server updated: ${id}`);
    
    res.json({
      success: true,
      message: 'Server updated successfully',
      data: { server: result.rows[0] }
    });
  } catch (err) {
    logger.error('Update server error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to update server'
    });
  }
};

/**
 * Delete server (Admin only)
 * DELETE /api/admin/servers/:id
 */
const deleteServer = async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await query(
      'DELETE FROM vpn_servers WHERE id = $1 RETURNING id',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Server not found'
      });
    }
    
    logger.info(`Server deleted: ${id}`);
    
    res.json({
      success: true,
      message: 'Server deleted successfully'
    });
  } catch (err) {
    logger.error('Delete server error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to delete server'
    });
  }
};

/**
 * Get Xray configuration for all users
 * This generates the Xray config with all user UUIDs
 * GET /api/admin/xray-config
 */
const getXrayConfig = async (req, res) => {
  try {
    // Get all active users with their UUIDs
    const usersResult = await query(
      'SELECT uuid, email FROM users WHERE is_active = true AND expiry_date > NOW()',
      []
    );
    
    // Get all active servers
    const serversResult = await query(
      'SELECT * FROM vpn_servers WHERE is_active = true',
      []
    );
    
    const config = {
      log: {
        loglevel: 'warning'
      },
      inbounds: serversResult.rows.map(server => ({
        port: server.port || 443,
        protocol: 'vless',
        settings: {
          clients: usersResult.rows.map(user => ({
            id: user.uuid,
            flow: 'xtls-rprx-vision',
            email: user.email,
          })),
          decryption: 'none',
        },
        streamSettings: {
          network: 'tcp',
          security: 'reality',
          realitySettings: {
            show: false,
            dest: 'www.microsoft.com:443',
            xver: 0,
            serverNames: ['www.microsoft.com', 'microsoft.com'],
            privateKey: process.env.XRAY_PRIVATE_KEY,
            publicKey: process.env.XRAY_PUBLIC_KEY,
            shortIds: [process.env.XRAY_SHORT_ID || '0123456789abcdef'],
          },
        },
        sniffing: {
          enabled: true,
          destOverride: ['http', 'tls', 'quic'],
        },
      })),
      outbounds: [
        {
          protocol: 'freedom',
          tag: 'direct',
        },
        {
          protocol: 'blackhole',
          tag: 'block',
        },
      ],
    };
    
    res.json({
      success: true,
      data: { config }
    });
  } catch (err) {
    logger.error('Get Xray config error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to generate Xray config'
    });
  }
};

module.exports = {
  getServers,
  getServerById,
  addServer,
  updateServer,
  deleteServer,
  getXrayConfig,
};
