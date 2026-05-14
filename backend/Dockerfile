FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (only production)
RUN npm ci --only=production

# Copy all source code
COPY . .

# Cloud Run sets PORT env var automatically (default 8080)
EXPOSE 8080

# Start the application
CMD ["node", "server.js"]
