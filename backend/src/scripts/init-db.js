const { initDatabase } = require('./db');
const logger = require('./utils/logger');

const initialize = async () => {
  try {
    logger.info('Initializing database...');
    await initDatabase();
    logger.info('Database initialized successfully');
    process.exit(0);
  } catch (err) {
    logger.error('Failed to initialize database', err);
    process.exit(1);
  }
};

initialize();
