#!/usr/bin/env sh
set -e

COMPOSE_FILE="docker-compose.prod.yml"

echo "=========================================="
echo "Starting Zero-Downtime Blue-Green Deploy..."
echo "=========================================="

# 1. Determine currently active and inactive upstream
if grep -q "app-blue" nginx/upstream.conf; then
    ACTIVE="blue"
    TARGET="green"
    ACTIVE_SERVICE="app-blue"
    TARGET_SERVICE="app-green"
    ACTIVE_CONTAINER="fastapi_app_blue"
    TARGET_CONTAINER="fastapi_app_green"
else
    ACTIVE="green"
    TARGET="blue"
    ACTIVE_SERVICE="app-green"
    TARGET_SERVICE="app-blue"
    ACTIVE_CONTAINER="fastapi_app_green"
    TARGET_CONTAINER="fastapi_app_blue"
fi

echo "Active environment: $ACTIVE (container: $ACTIVE_CONTAINER)"
echo "Target environment: $TARGET (container: $TARGET_CONTAINER)"

# 2. Build and start target service
echo "Building target service: $TARGET_SERVICE..."
docker compose -f $COMPOSE_FILE build $TARGET_SERVICE

echo "Starting target container..."
docker compose -f $COMPOSE_FILE up -d --no-deps $TARGET_SERVICE

# 3. Wait for the new container to become healthy
echo "Polling health status of $TARGET_CONTAINER..."
MAX_ATTEMPTS=30
ATTEMPT=1
HEALTHY=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    STATUS=$(docker inspect -f '{{.State.Health.Status}}' "$TARGET_CONTAINER" 2>/dev/null || echo "starting")
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Health Status = '$STATUS'"
    
    if [ "$STATUS" = "healthy" ]; then
        HEALTHY=true
        break
    fi
    sleep 2
    ATTEMPT=$((ATTEMPT + 1))
done

if [ "$HEALTHY" = false ]; then
    echo "Error: Target container failed to become healthy. Aborting deployment!"
    docker compose -f $COMPOSE_FILE stop $TARGET_SERVICE
    exit 1
fi

# 4. Swap Nginx upstream configurations
echo "Switching traffic to $TARGET_SERVICE..."
cat <<EOF > nginx/upstream.conf
upstream fastapi_upstream {
    server $TARGET_SERVICE:8000;
}
EOF

# 5. Reload Nginx gracefully
echo "Reloading Nginx proxy..."
docker exec nginx_proxy nginx -s reload

# 6. Stop old container
echo "Stopping old service: $ACTIVE_SERVICE..."
docker compose -f $COMPOSE_FILE stop $ACTIVE_SERVICE

echo "=========================================="
echo "Zero-Downtime Deployment SUCCESSFUL!"
echo "=========================================="
