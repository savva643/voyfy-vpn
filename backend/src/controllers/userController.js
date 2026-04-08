const { query } = require('../db');
const logger = require('../utils/logger');

/**
 * Get current user profile
 * GET /api/user/profile
 */
const getProfile = async (req, res) => {
  try {
    const userId = req.user.id;
    
    const result = await query(
      `SELECT id, email, uuid, data_limit, used_data, expiry_date, 
              is_active, created_at, updated_at 
       FROM users WHERE id = $1`,
      [userId]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    const user = result.rows[0];
    
    res.json({
      success: true,
      data: {
        user: {
          id: user.id,
          email: user.email,
          uuid: user.uuid,
          dataLimit: parseInt(user.data_limit),
          usedData: parseInt(user.used_data),
          remainingData: parseInt(user.data_limit) - parseInt(user.used_data),
          expiryDate: user.expiry_date,
          isActive: user.is_active,
          createdAt: user.created_at,
          updatedAt: user.updated_at,
        }
      }
    });
  } catch (err) {
    logger.error('Get profile error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to get profile'
    });
  }
};

/**
 * Get all users (Admin only)
 * GET /api/admin/users
 */
const getAllUsers = async (req, res) => {
  try {
    const result = await query(
      `SELECT id, email, uuid, data_limit, used_data, expiry_date, 
              is_active, is_admin, created_at 
       FROM users ORDER BY created_at DESC`,
      []
    );
    
    res.json({
      success: true,
      data: {
        users: result.rows.map(user => ({
          id: user.id,
          email: user.email,
          uuid: user.uuid,
          dataLimit: parseInt(user.data_limit),
          usedData: parseInt(user.used_data),
          expiryDate: user.expiry_date,
          isActive: user.is_active,
          isAdmin: user.is_admin,
          createdAt: user.created_at,
        }))
      }
    });
  } catch (err) {
    logger.error('Get all users error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to get users'
    });
  }
};

/**
 * Update user (Admin only)
 * PUT /api/admin/users/:id
 */
const updateUser = async (req, res) => {
  try {
    const { id } = req.params;
    const { dataLimit, expiryDate, isActive, isAdmin } = req.body;
    
    const result = await query(
      `UPDATE users 
       SET data_limit = COALESCE($1, data_limit),
           expiry_date = COALESCE($2, expiry_date),
           is_active = COALESCE($3, is_active),
           is_admin = COALESCE($4, is_admin),
           updated_at = NOW()
       WHERE id = $5
       RETURNING *`,
      [dataLimit, expiryDate, isActive, isAdmin, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    logger.info(`User updated: ${id}`);
    
    res.json({
      success: true,
      message: 'User updated successfully',
      data: { user: result.rows[0] }
    });
  } catch (err) {
    logger.error('Update user error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to update user'
    });
  }
};

/**
 * Reset user data usage (Admin only)
 * POST /api/admin/users/:id/reset-usage
 */
const resetUsage = async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await query(
      'UPDATE users SET used_data = 0, updated_at = NOW() WHERE id = $1 RETURNING id',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    logger.info(`User usage reset: ${id}`);
    
    res.json({
      success: true,
      message: 'Usage reset successfully'
    });
  } catch (err) {
    logger.error('Reset usage error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to reset usage'
    });
  }
};

/**
 * Delete user (Admin only)
 * DELETE /api/admin/users/:id
 */
const deleteUser = async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await query(
      'DELETE FROM users WHERE id = $1 RETURNING id',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    logger.info(`User deleted: ${id}`);
    
    res.json({
      success: true,
      message: 'User deleted successfully'
    });
  } catch (err) {
    logger.error('Delete user error', err);
    res.status(500).json({
      success: false,
      message: 'Failed to delete user'
    });
  }
};

module.exports = {
  getProfile,
  getAllUsers,
  updateUser,
  resetUsage,
  deleteUser,
};
