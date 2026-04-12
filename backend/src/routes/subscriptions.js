const express = require('express');
const router = express.Router();
const { query } = require('../db');
const logger = require('../utils/logger');

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

// Generate server name based on location
router.post('/generate-server-name', async (req, res) => {
  try {
    const { locationId } = req.body;

    if (!locationId) {
      return res.status(400).json({
        success: false,
        error: 'Location ID is required'
      });
    }

    // Get location details
    const locationResult = await query(`
      SELECT country, country_code, city
      FROM locations
      WHERE id = $1 AND is_active = true
    `, [locationId]);

    if (locationResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Location not found'
      });
    }

    const location = locationResult.rows[0];

    // Count existing servers for this location
    const countResult = await query(`
      SELECT COUNT(*) as count
      FROM vpn_servers
      WHERE country_code = $1
    `, [location.country_code]);

    const count = parseInt(countResult.rows[0].count) + 1;

    // Generate server name
    const serverName = location.city
      ? `${location.country}-${location.city}-${count}`
      : `${location.country}-${count}`;

    res.json({
      success: true,
      serverName,
      countryCode: location.country_code,
      country: location.country,
      city: location.city
    });
  } catch (err) {
    logger.error('Error generating server name:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to generate server name'
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

// Get subscription plan by ID
router.get('/plans/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await query(`
      SELECT id, name, description, duration_days, data_limit_gb,
             price_usd, price_rub, price_eur, features, is_popular
      FROM subscription_plans
      WHERE id = $1 AND is_active = true
    `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Subscription plan not found'
      });
    }

    res.json({
      success: true,
      plan: result.rows[0]
    });
  } catch (err) {
    logger.error('Error fetching subscription plan:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch subscription plan'
    });
  }
});

// Get user's current subscription
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const result = await query(`
      SELECT u.id, u.email, u.expiry_date, u.data_limit, u.used_data,
             sp.id as plan_id, sp.name as plan_name, sp.description,
             sp.duration_days, sp.data_limit_gb, sp.price_usd, sp.price_rub, sp.price_eur, sp.features
      FROM users u
      LEFT JOIN subscription_plans sp ON u.subscription_plan_id = sp.id
      WHERE u.id = $1
    `, [userId]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    const user = result.rows[0];
    const isExpired = new Date(user.expiry_date) < new Date();
    const dataUsed = user.used_data || 0;
    const dataLimit = user.data_limit;
    const dataRemaining = dataLimit - dataUsed;
    const dataPercentage = dataLimit > 0 ? (dataUsed / dataLimit) * 100 : 0;

    res.json({
      success: true,
      subscription: {
        planId: user.plan_id,
        planName: user.plan_name,
        description: user.description,
        features: user.features ? JSON.parse(user.features) : [],
        durationDays: user.duration_days,
        dataLimitGb: user.data_limit_gb,
        expiryDate: user.expiry_date,
        isExpired,
        dataUsed,
        dataLimit,
        dataRemaining,
        dataPercentage: Math.min(dataPercentage, 100)
      }
    });
  } catch (err) {
    logger.error('Error fetching user subscription:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch user subscription'
    });
  }
});

// Update user subscription plan
router.post('/user/:userId/subscribe', async (req, res) => {
  try {
    const { userId } = req.params;
    const { planId } = req.body;

    if (!planId) {
      return res.status(400).json({
        success: false,
        error: 'Plan ID is required'
      });
    }

    // Get plan details
    const planResult = await query(`
      SELECT duration_days, data_limit_gb
      FROM subscription_plans
      WHERE id = $1 AND is_active = true
    `, [planId]);

    if (planResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Subscription plan not found'
      });
    }

    const plan = planResult.rows[0];
    const dataLimit = plan.data_limit_gb ? plan.data_limit_gb * 1073741824 : null; // Convert GB to bytes
    const expiryDate = new Date();
    expiryDate.setDate(expiryDate.getDate() + plan.duration_days);

    // Update user subscription
    await query(`
      UPDATE users
      SET subscription_plan_id = $1,
          data_limit = $2,
          expiry_date = $3,
          used_data = 0,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = $4
    `, [planId, dataLimit, expiryDate, userId]);

    res.json({
      success: true,
      message: 'Subscription updated successfully',
      expiryDate: expiryDate.toISOString()
    });
  } catch (err) {
    logger.error('Error updating user subscription:', err);
    res.status(500).json({
      success: false,
      error: 'Failed to update subscription'
    });
  }
});

module.exports = router;
