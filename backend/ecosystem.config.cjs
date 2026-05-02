// PM2 Configuration for VL-Garments Backend
// Used on Oracle Cloud VM to keep the server running 24/7
module.exports = {
  apps: [
    {
      name: 'vl-garments',
      script: 'server.js',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '500M',
      env: {
        NODE_ENV: 'production',
        PORT: 5000,
      },
      // Restart if app uses too much memory
      // Log management
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      error_file: './logs/error.log',
      out_file: './logs/output.log',
      merge_logs: true,
      // Graceful restart
      kill_timeout: 5000,
      listen_timeout: 10000,
    },
  ],
};
