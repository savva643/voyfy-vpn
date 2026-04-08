const { Pool } = require('pg');
const config = require('../config');
const logger = require('../utils/logger');

const pool = new Pool({
  host: config.database.host,
  port: config.database.port,
  database: config.database.name,
  user: config.database.user,
  password: config.database.password,
});

pool.on('error', (err) => {
  logger.error('Unexpected database error', err);
  process.exit(-1);
});

const query = (text, params) => pool.query(text, params);

const initDatabase = async () => {
  try {
    // Users table
    await query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        uuid UUID UNIQUE DEFAULT gen_random_uuid(),
        subscription_url VARCHAR(255) UNIQUE,
        data_limit BIGINT DEFAULT 10737418240, -- 10GB default
        used_data BIGINT DEFAULT 0,
        expiry_date TIMESTAMP DEFAULT (CURRENT_TIMESTAMP + INTERVAL '30 days'),
        is_active BOOLEAN DEFAULT true,
        is_admin BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // VPN Servers table
    await query(`
      CREATE TABLE IF NOT EXISTS vpn_servers (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(255) NOT NULL,
        country VARCHAR(100) NOT NULL,
        country_code VARCHAR(10) NOT NULL,
        host VARCHAR(255) NOT NULL,
        port INTEGER DEFAULT 443,
        premium BOOLEAN DEFAULT false,
        is_active BOOLEAN DEFAULT true,
        load_percentage INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // User sessions for JWT refresh
    await query(`
      CREATE TABLE IF NOT EXISTS user_sessions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        refresh_token VARCHAR(255) NOT NULL,
        device_info JSONB,
        expires_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // User subscriptions tracking
    await query(`
      CREATE TABLE IF NOT EXISTS subscription_logs (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        server_id UUID REFERENCES vpn_servers(id) ON DELETE CASCADE,
        bytes_up BIGINT DEFAULT 0,
        bytes_down BIGINT DEFAULT 0,
        connected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        disconnected_at TIMESTAMP
      )
    `);

    logger.info('Database initialized successfully');
  } catch (err) {
    logger.error('Database initialization failed', err);
    throw err;
  }
};

module.exports = {
  query,
  initDatabase,
  pool,
};
