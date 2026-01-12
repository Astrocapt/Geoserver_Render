# GeoServer on Render - Diagnostic Version
FROM tomcat:9-jdk17

# Install unzip and curl
RUN apt-get update && apt-get install -y unzip curl && rm -rf /var/lib/apt/lists/*

# Remove default Tomcat webapps
RUN rm -rf /usr/local/tomcat/webapps/*

# Download GeoServer WAR
ADD https://github.com/Astrocapt/Geoserver/releases/download/v2.28.1/geoserver.war /usr/local/tomcat/webapps/geoserver.war

# Set GeoServer data directory
ENV GEOSERVER_DATA_DIR=/var/geoserver_data
ENV CATALINA_OPTS="-Xms512M -Xmx2G -XX:MaxPermSize=512M"

# Create data directory
RUN mkdir -p ${GEOSERVER_DATA_DIR} && \
    chmod 777 ${GEOSERVER_DATA_DIR}

# Download Sample_Area.zip
RUN curl -L -o /tmp/Sample_Area.zip https://github.com/Astrocapt/hello-test/raw/main/Sample_Area.zip

# Create startup script with better logging and health checks
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "========================================"\n\
echo "GeoServer Initialization Starting"\n\
echo "========================================"\n\
echo "Data directory: ${GEOSERVER_DATA_DIR}"\n\
echo "Java version: $(java -version 2>&1 | head -n 1)"\n\
echo "Memory: $(free -h | grep Mem)"\n\
echo ""\n\
\n\
# Function to check if GeoServer is responding\n\
check_geoserver() {\n\
  curl -s http://localhost:8080/geoserver/web/ > /dev/null 2>&1\n\
  return $?\n\
}\n\
\n\
# Start Tomcat in background\n\
echo "[$(date +"%H:%M:%S")] Starting Tomcat..."\n\
catalina.sh start\n\
\n\
# Wait for Tomcat to start (check every 10 seconds, max 180 seconds)\n\
echo "[$(date +"%H:%M:%S")] Waiting for GeoServer to respond..."\n\
COUNTER=0\n\
MAX_WAIT=180\n\
while [ $COUNTER -lt $MAX_WAIT ]; do\n\
  if check_geoserver; then\n\
    echo "[$(date +"%H:%M:%S")] ✓ GeoServer is responding!"\n\
    break\n\
  fi\n\
  echo "[$(date +"%H:%M:%S")] Still waiting... ($COUNTER seconds elapsed)"\n\
  sleep 10\n\
  COUNTER=$((COUNTER + 10))\n\
done\n\
\n\
if [ $COUNTER -ge $MAX_WAIT ]; then\n\
  echo "[$(date +"%H:%M:%S")] ✗ ERROR: GeoServer did not start within $MAX_WAIT seconds"\n\
  echo "Tomcat logs:"\n\
  tail -50 /usr/local/tomcat/logs/catalina.out\n\
  exit 1\n\
fi\n\
\n\
# Check if data directory was initialized\n\
if [ -d "${GEOSERVER_DATA_DIR}/security" ]; then\n\
  echo "[$(date +"%H:%M:%S")] ✓ Security directory found"\n\
  \n\
  # Check if workspace already exists\n\
  if [ -d "${GEOSERVER_DATA_DIR}/workspaces/Sample_Area" ]; then\n\
    echo "[$(date +"%H:%M:%S")] Workspace already exists, skipping injection"\n\
  else\n\
    echo "[$(date +"%H:%M:%S")] Injecting Sample_Area workspace..."\n\
    \n\
    # Stop Tomcat\n\
    catalina.sh stop\n\
    sleep 10\n\
    \n\
    # Extract workspace\n\
    mkdir -p ${GEOSERVER_DATA_DIR}/workspaces\n\
    cd ${GEOSERVER_DATA_DIR}/workspaces\n\
    unzip -o /tmp/Sample_Area.zip\n\
    \n\
    echo "[$(date +"%H:%M:%S")] ✓ Workspace extracted"\n\
    echo "Contents:"\n\
    ls -la ${GEOSERVER_DATA_DIR}/workspaces/\n\
    \n\
    # Restart Tomcat\n\
    echo "[$(date +"%H:%M:%S")] Restarting Tomcat..."\n\
    catalina.sh start\n\
    \n\
    # Wait for restart\n\
    sleep 30\n\
    if check_geoserver; then\n\
      echo "[$(date +"%H:%M:%S")] ✓ GeoServer restarted successfully"\n\
    else\n\
      echo "[$(date +"%H:%M:%S")] ✗ WARNING: GeoServer may not have restarted properly"\n\
    fi\n\
  fi\n\
else\n\
  echo "[$(date +"%H:%M:%S")] ✗ WARNING: Security directory not found"\n\
  echo "Data directory contents:"\n\
  ls -la ${GEOSERVER_DATA_DIR}\n\
fi\n\
\n\
echo "========================================"\n\
echo "[$(date +"%H:%M:%S")] GeoServer Ready!"\n\
echo "========================================"\n\
echo "Access URL: http://localhost:8080/geoserver/web/"\n\
echo "Username: admin"\n\
echo "Password: geoserver"\n\
echo ""\n\
echo "Tailing logs..."\n\
\n\
# Keep container alive by tailing logs\n\
tail -f /usr/local/tomcat/logs/catalina.out\n\
' > /usr/local/bin/geoserver-init.sh && \
    chmod +x /usr/local/bin/geoserver-init.sh

EXPOSE 8080

CMD ["/usr/local/bin/geoserver-init.sh"]
