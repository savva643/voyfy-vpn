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
    // Subscription plans table
    await query(`
      CREATE TABLE IF NOT EXISTS subscription_plans (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(255) NOT NULL,
        description TEXT,
        duration_days INTEGER NOT NULL,
        data_limit_gb BIGINT,
        price_usd DECIMAL(10, 2) NOT NULL,
        price_rub DECIMAL(10, 2) NOT NULL,
        price_eur DECIMAL(10, 2) NOT NULL,
        features JSONB,
        is_popular BOOLEAN DEFAULT false,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Locations table for VPN server locations
    const locationsTableExists = await query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_name = 'locations'
      )
    `);

    if (locationsTableExists.rows[0].exists) {
      // Check if table has wrong constraint
      const constraints = await query(`
        SELECT constraint_name
        FROM information_schema.table_constraints
        WHERE table_name = 'locations'
        AND constraint_type = 'UNIQUE'
      `);

      const hasOldConstraint = constraints.rows.some(c => c.constraint_name === 'locations_country_code_key');

      if (hasOldConstraint) {
        logger.info('Recreating locations table with correct schema...');
        await query('DROP TABLE locations CASCADE');
        await query(`
          CREATE TABLE locations (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            country VARCHAR(100) NOT NULL,
            country_code VARCHAR(10) NOT NULL,
            city VARCHAR(100),
            region VARCHAR(100),
            flag_emoji VARCHAR(10),
            is_active BOOLEAN DEFAULT true,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(country_code, city)
          )
        `);
      }
    } else {
      await query(`
        CREATE TABLE locations (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          country VARCHAR(100) NOT NULL,
          country_code VARCHAR(10) NOT NULL,
          city VARCHAR(100),
          region VARCHAR(100),
          flag_emoji VARCHAR(10),
          is_active BOOLEAN DEFAULT true,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(country_code, city)
        )
      `);
    }

    // Insert default locations using INSERT ... ON CONFLICT
    const defaultLocations = [
        ['Germany', 'DE', 'Frankfurt', 'Europe', '🇩🇪'],
        ['Germany', 'DE', 'Berlin', 'Europe', '🇩🇪'],
        ['Germany', 'DE', 'Munich', 'Europe', '🇩🇪'],
        ['United States', 'US', 'New York', 'North America', '🇺🇸'],
        ['United States', 'US', 'Los Angeles', 'North America', '🇺🇸'],
        ['United States', 'US', 'Chicago', 'North America', '🇺🇸'],
        ['United Kingdom', 'GB', 'London', 'Europe', '🇬🇧'],
        ['Netherlands', 'NL', 'Amsterdam', 'Europe', '🇳🇱'],
        ['France', 'FR', 'Paris', 'Europe', '🇫🇷'],
        ['Switzerland', 'CH', 'Zurich', 'Europe', '🇨🇭'],
        ['Japan', 'JP', 'Tokyo', 'Asia', '🇯🇵'],
        ['Singapore', 'SG', 'Singapore', 'Asia', '🇸🇬'],
        ['Australia', 'AU', 'Sydney', 'Oceania', '🇦🇺'],
        ['Canada', 'CA', 'Toronto', 'North America', '🇨🇦'],
        ['Russia', 'RU', 'Moscow', 'Europe', '🇷🇺'],
        ['Russia', 'RU', 'Saint Petersburg', 'Europe', '🇷🇺'],
        ['Turkey', 'TR', 'Istanbul', 'Europe', '🇹🇷'],
        ['Poland', 'PL', 'Warsaw', 'Europe', '🇵🇱'],
        ['Sweden', 'SE', 'Stockholm', 'Europe', '🇸🇪'],
        ['Finland', 'FI', 'Helsinki', 'Europe', '🇫🇮'],
        ['Spain', 'ES', 'Madrid', 'Europe', '🇪🇸'],
        ['Italy', 'IT', 'Milan', 'Europe', '🇮🇹'],
        ['Brazil', 'BR', 'São Paulo', 'South America', '🇧🇷'],
        ['India', 'IN', 'Mumbai', 'Asia', '🇮🇳'],
        ['South Korea', 'KR', 'Seoul', 'Asia', '🇰🇷'],
        ['Hong Kong', 'HK', 'Hong Kong', 'Asia', '🇭🇰']
    ];

    for (const [country, countryCode, city, region, flag] of defaultLocations) {
      await query(`
        INSERT INTO locations (country, country_code, city, region, flag_emoji)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (country_code, city) DO NOTHING
      `, [country, countryCode, city, region, flag]);
    }
    logger.info('Default locations ensured');

    // Insert default subscription plans
    const plansExist = await query('SELECT id FROM subscription_plans LIMIT 1');
    if (plansExist.rows.length === 0) {
      await query(`
        INSERT INTO subscription_plans (name, description, duration_days, data_limit_gb, price_usd, price_rub, price_eur, features, is_popular) VALUES
        ('Free', 'Basic VPN access with limited data', 30, 10, 0.00, 0.00, 0.00, '["10GB data limit", "Standard speed", "Basic servers"]'::jsonb, false),
        ('Monthly', 'Full access for one month', 30, NULL, 9.99, 899.00, 9.49, '["Unlimited data", "High speed", "All servers", "No logs", "24/7 support"]'::jsonb, true),
        ('Quarterly', 'Save 20% with 3-month plan', 90, NULL, 23.99, 2159.00, 22.79, '["Unlimited data", "High speed", "All servers", "No logs", "24/7 support", "Priority support"]'::jsonb, false),
        ('Yearly', 'Best value - save 50%', 365, NULL, 59.99, 5399.00, 56.99, '["Unlimited data", "High speed", "All servers", "No logs", "24/7 support", "Priority support", "Exclusive servers"]'::jsonb, false)
      `);
      logger.info('Default subscription plans created');
    }

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
        subscription_plan_id UUID REFERENCES subscription_plans(id) ON DELETE SET NULL,
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
        current_users INTEGER DEFAULT 0,
        ping_ms INTEGER,
        last_seen TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // User sessions for JWT refresh
    await query(`
      CREATE TABLE IF NOT EXISTS user_sessions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        refresh_token TEXT NOT NULL,
        device_info JSONB,
        expires_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Alter existing table to increase refresh_token size if needed
    try {
      await query(`
        ALTER TABLE user_sessions ALTER COLUMN refresh_token TYPE TEXT
      `);
    } catch (err) {
      // Column may already be TEXT or table doesn't exist yet
    }

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

    // Server pairing codes (one-time use for VPN server registration)
    await query(`
      CREATE TABLE IF NOT EXISTS server_pairing_codes (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        code VARCHAR(20) UNIQUE NOT NULL,
        server_name VARCHAR(255) NOT NULL,
        country VARCHAR(10) NOT NULL,
        premium BOOLEAN DEFAULT false,
        provider VARCHAR(255),
        used BOOLEAN DEFAULT false,
        expires_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        used_at TIMESTAMP,
        used_by_ip VARCHAR(255)
      )
    `);

    // Add columns to vpn_servers if not exist
    await query(`
      ALTER TABLE vpn_servers
      ADD COLUMN IF NOT EXISTS protocol VARCHAR(10) DEFAULT 'vless',
      ADD COLUMN IF NOT EXISTS public_key TEXT,
      ADD COLUMN IF NOT EXISTS server_names JSONB,
      ADD COLUMN IF NOT EXISTS short_id VARCHAR(255),
      ADD COLUMN IF NOT EXISTS current_users INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS ping_ms INTEGER,
      ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP,
      ADD COLUMN IF NOT EXISTS provider VARCHAR(255)
    `);

    // Create default admin user if not exists
    const bcrypt = require('bcryptjs');
    const { v4: uuidv4 } = require('uuid');
    
    const adminExists = await query('SELECT id FROM users WHERE email = $1', ['admin@voyfy.com']);
    if (adminExists.rows.length === 0) {
      const adminId = uuidv4();
      const adminUuid = uuidv4();
      const passwordHash = await bcrypt.hash('admin123', 10);
      const subscriptionUrl = `${process.env.SERVER_NAME || 'http://localhost:4000'}/sub/${adminUuid}`;
      
      await query(
        `INSERT INTO users (id, email, password_hash, uuid, subscription_url, is_admin) 
         VALUES ($1, $2, $3, $4, $5, true)`,
        [adminId, 'admin@voyfy.com', passwordHash, adminUuid, subscriptionUrl]
      );
      
      logger.info('Default admin user created: admin@voyfy.com / admin123');
    }
    
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
