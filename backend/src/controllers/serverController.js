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

    // Format for Flutter app compatibility
    const servers = serversResult.rows.map((s, index) => ({
      serverId: index + 1, // Sequential ID for Flutter app
      id: s.id, // Real UUID
      name: s.name,
      country: s.country,
      countryCode: s.country_code,
      host: s.host,
      port: s.port,
      premium: s.premium,
      isFree: !s.premium, // Flutter uses isFree
      load: s.load_percentage,
      src: `assets/images/${s.country_code.toLowerCase()}.jpeg`, // Flag image path
      locations: 1, // Number of locations (can be calculated from location data)
    }));

    res.json({
      success: true,
      data: {
        servers: servers
      },
      // Also support Flutter's expected format
      servers: servers
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

// ==========================================
// Simple Server Registration (No Activation Key)
// ==========================================

const { v4: uuidv4 } = require('uuid');

const registerServer = async (req, res) => {
  try {
    const {
      name, country, countryCode, host, port = 443,
      publicKey, serverNames, shortId,
      pairingCode,
      premium = false
    } = req.body;

    // Validate pairing code if provided
    let codeData = null;
    if (pairingCode) {
      const codeResult = await query(
        `SELECT * FROM server_pairing_codes
         WHERE code = $1 AND used = false AND expires_at > NOW()`,
        [pairingCode]
      );

      if (codeResult.rows.length === 0) {
        return res.status(401).json({
          success: false,
          message: 'Invalid or expired pairing code'
        });
      }

      codeData = codeResult.rows[0];
    }

    // Use data from request first, fallback to pairing code if available
    const serverName = name || (codeData ? codeData.server_name : null);
    const serverCountry = country || (codeData ? codeData.country : null);
    const serverPremium = premium !== undefined ? premium : (codeData ? codeData.premium : false);
    const serverProvider = codeData ? codeData.provider : null;

    if (!serverName || !serverCountry || !host || !publicKey) {
      return res.status(400).json({
        success: false,
        message: 'name, country, host, publicKey required (or valid pairing code)'
      });
    }

    // Check if server with this host already exists
    const existing = await query('SELECT id FROM vpn_servers WHERE host = $1', [host]);
    if (existing.rows.length > 0) {
      // Update existing server
      const serverId = existing.rows[0].id;
      await query(
        `UPDATE vpn_servers SET
         name = $1, country = $2, country_code = $3, port = $4,
         public_key = $5, server_names = $6, short_id = $7,
         premium = $8, provider = $9, is_active = true, last_seen = NOW()
         WHERE id = $10`,
        [serverName, serverCountry, countryCode || serverCountry, port, publicKey,
         JSON.stringify(serverNames || []), shortId, serverPremium, serverProvider, serverId]
      );

      // Mark pairing code as used
      if (codeData) {
        await query(
          `UPDATE server_pairing_codes SET used = true, used_at = NOW(), used_by_ip = $1 WHERE code = $2`,
          [host, pairingCode]
        );
      }

      logger.info(`Server updated: ${serverName} (${serverId})`);

      return res.json({
        success: true,
        serverId,
        serverName: serverName,
        apiKey: process.env.ADMIN_API_KEY,
        message: 'Server updated successfully'
      });
    }

    // Create new server
        // Create new server
    const serverId = uuidv4();
    
    // Ensure countryCode is a short code (2-3 chars), not full country name
    let finalCountryCode = countryCode;
    if (!finalCountryCode || finalCountryCode.length > 3) {
      // Extract code from pairing code data or use first 2 chars of country
      finalCountryCode = (codeData && codeData.country_code) ? codeData.country_code : serverCountry.substring(0, 2).toUpperCase();
    }
    
    await query(
      `INSERT INTO vpn_servers (id, name, country, country_code, host, port,
       protocol, public_key, server_names, short_id, premium, provider, is_active, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, true, NOW())`,
      [
        serverId,
        serverName,
        serverCountry,
        finalCountryCode,
        host,
        port,
        'vless',
        publicKey,
        JSON.stringify(serverNames || []),
        shortId,
        serverPremium,
        serverProvider
      ]
    );

    // Mark pairing code as used
    if (codeData) {
      await query(
        `UPDATE server_pairing_codes SET used = true, used_at = NOW(), used_by_ip = $1 WHERE code = $2`,
        [host, pairingCode]
      );
    }

    logger.info(`Server registered: ${serverName} (${serverId}) from ${host}`);

    res.json({
      success: true,
      serverId,
      serverName: serverName,
      apiKey: process.env.ADMIN_API_KEY,
      message: 'Server registered successfully'
    });
  } catch (err) {
    logger.error('Register server error', err);
    res.status(500).json({ success: false, message: 'Failed to register server' });
  }
};

const getAdminServers = async (req, res) => {
  try {
    const result = await query(
      `SELECT id, name, country, country_code, host, port, premium,
              is_active, load_percentage, current_users, last_seen,
              public_key, short_id, provider, created_at, ping_ms
       FROM vpn_servers ORDER BY created_at DESC`,
      []
    );

    res.json({
      success: true,
      servers: result.rows.map(s => ({
        id: s.id,
        name: s.name,
        country: s.country,
        countryCode: s.country_code,
        host: s.host,
        port: s.port,
        premium: s.premium,
        isActive: s.is_active,
        load: s.load_percentage,
        currentUsers: s.current_users,
        lastSeen: s.last_seen,
        publicKey: s.public_key,
        shortId: s.short_id,
        provider: s.provider,
        createdAt: s.created_at,
        ping_ms: s.ping_ms
      }))
    });
  } catch (err) {
    logger.error('Get admin servers error', err);
    res.status(500).json({ success: false, message: 'Failed to get servers' });
  }
};

const serverHeartbeat = async (req, res) => {
  try {
    const { id } = req.params;
    const { loadPercent, currentUsers, ping } = req.body;
    
    // Обновляем нагрузку, пользователей, пинг и время последнего контакта
    await query(
      `UPDATE vpn_servers SET load_percentage = $1, current_users = $2, ping_ms = $3, last_seen = NOW(), is_active = true WHERE id = $4`,
      [loadPercent || 0, currentUsers || 0, ping || null, id]
    );
    
    res.json({ success: true, received: { loadPercent, currentUsers, ping } });
  } catch (err) {
    logger.error('Heartbeat error', err);
    res.status(500).json({ success: false, message: 'Failed to update heartbeat' });
  }
};

// ==========================================
// Server Pairing Codes (One-time use)
// ==========================================

const generatePairingCode = () => {
  return 'VOYFY-' + Math.random().toString(36).substring(2, 8).toUpperCase();
};

const createPairingCode = async (req, res) => {
  try {
    const { serverName, country, premium = false, provider } = req.body;

    if (!serverName || !country) {
      return res.status(400).json({
        success: false,
        message: 'serverName and country required'
      });
    }

    const code = generatePairingCode();
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 24); // 24 hours validity

    await query(
      `INSERT INTO server_pairing_codes (code, server_name, country, premium, provider, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [code, serverName, country, premium, provider, expiresAt]
    );

    logger.info(`Pairing code created: ${code} for ${serverName}`);

    res.json({
      success: true,
      code,
      serverName,
      country,
      premium,
      provider,
      expiresAt,
      installCommand: `curl -fsSL https://vip.necsoura.ru/vpn-server/install.sh | bash -s -- "${code}"`
    });
  } catch (err) {
    logger.error('Create pairing code error', err);
    res.status(500).json({ success: false, message: 'Failed to create code' });
  }
};

const getPairingCodes = async (req, res) => {
  try {
    const result = await query(
      `SELECT code, server_name, country, premium, used, 
              expires_at, created_at, used_at, used_by_ip
       FROM server_pairing_codes ORDER BY created_at DESC`,
      []
    );
    
    res.json({
      success: true,
      codes: result.rows.map(c => ({
        code: c.code,
        serverName: c.server_name,
        country: c.country,
        premium: c.premium,
        used: c.used,
        expiresAt: c.expires_at,
        createdAt: c.created_at,
        usedAt: c.used_at,
        usedByIp: c.used_by_ip
      }))
    });
  } catch (err) {
    logger.error('Get pairing codes error', err);
    res.status(500).json({ success: false, message: 'Failed to get codes' });
  }
};

const verifyPairingCode = async (req, res) => {
  try {
    const { code } = req.body;
    
    if (!code) {
      return res.status(400).json({ success: false, message: 'code required' });
    }
    
    const result = await query(
      `SELECT * FROM server_pairing_codes 
       WHERE code = $1 AND used = false AND expires_at > NOW()`,
      [code]
    );
    
    if (result.rows.length === 0) {
      return res.status(401).json({ success: false, message: 'Invalid or expired code' });
    }
    
    const codeData = result.rows[0];
    
    // Map country codes to full names
    const countryNames = {
      'NL': 'Netherlands', 'DE': 'Germany', 'US': 'United States', 'GB': 'United Kingdom',
      'FR': 'France', 'IT': 'Italy', 'ES': 'Spain', 'PL': 'Poland', 'UA': 'Ukraine',
      'RU': 'Russia', 'TR': 'Turkey', 'SG': 'Singapore', 'JP': 'Japan', 'KR': 'South Korea',
      'AU': 'Australia', 'CA': 'Canada', 'BR': 'Brazil', 'IN': 'India', 'CN': 'China',
      'SE': 'Sweden', 'NO': 'Norway', 'FI': 'Finland', 'DK': 'Denmark', 'CH': 'Switzerland',
      'AT': 'Austria', 'BE': 'Belgium', 'CZ': 'Czech Republic', 'RO': 'Romania',
      'HU': 'Hungary', 'PT': 'Portugal', 'GR': 'Greece', 'IL': 'Israel', 'AE': 'UAE'
    };
    
    const countryCode = codeData.country_code || codeData.country;
    const countryName = countryNames[countryCode] || codeData.country || countryCode;
    
    res.json({
      success: true,
      valid: true,
      serverName: codeData.server_name,
      country: countryName,
      countryCode: countryCode,
      premium: codeData.premium
    });
  } catch (err) {
    logger.error('Verify pairing code error', err);
    res.status(500).json({ success: false, message: 'Failed to verify code' });
  }
};

/**
 * Get clients for a specific server (for Xray config sync)
 * GET /api/servers/:id/clients
 * VPN servers use this to sync user list
 */
const getServerClients = async (req, res) => {
  try {
    const { id } = req.params;
    
    // Verify server exists and is active
    const serverResult = await query(
      'SELECT id, host, public_key FROM vpn_servers WHERE id = $1 AND is_active = true',
      [id]
    );
    
    if (serverResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Server not found or inactive'
      });
    }
    
    const server = serverResult.rows[0];
    
    // Get all active users with valid subscription
    const usersResult = await query(
      `SELECT uuid, email 
       FROM users 
       WHERE is_active = true 
         AND (expiry_date > NOW() OR expiry_date IS NULL)`,
      []
    );
    
    // Format clients for Xray
    const clients = usersResult.rows.map(user => ({
      id: user.uuid,
      flow: 'xtls-rprx-vision',
      email: user.email,
    }));
    
    logger.info(`Server ${id} (${server.host}) synced ${clients.length} clients`);
    
    res.json({
      success: true,
      serverId: id,
      clientCount: clients.length,
      clients: clients,
      // Also return server config for convenience
      server: {
        host: server.host,
        publicKey: server.public_key,
      }
    });
  } catch (err) {
    logger.error('Get server clients error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to get server clients'
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
  registerServer,
  getAdminServers,
  serverHeartbeat,
  createPairingCode,
  getPairingCodes,
  verifyPairingCode,
  getServerClients,
};
