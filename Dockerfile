# GeoServer on Render - Fixed Version
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

# Configure Tomcat to use PORT environment variable and bind to 0.0.0.0
RUN echo '<?xml version="1.0" encoding="UTF-8"?>\n\
<Server port="-1" shutdown="SHUTDOWN">\n\
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />\n\
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />\n\
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />\n\
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />\n\
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />\n\
  <Service name="Catalina">\n\
    <Connector port="${PORT}" protocol="HTTP/1.1"\n\
               connectionTimeout="20000"\n\
               address="0.0.0.0"\n\
               redirectPort="8443" />\n\
    <Engine name="Catalina" defaultHost="localhost">\n\
      <Host name="localhost" appBase="webapps"\n\
            unpackWARs="true" autoDeploy="true">\n\
      </Host>\n\
    </Engine>\n\
  </Service>\n\
</Server>' > /usr/local/tomcat/conf/server.xml

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Use PORT from environment or default to 8080\n\
export PORT=${PORT:-8080}\n\
\n\
echo "========================================"\n\
echo "GeoServer Initialization Starting"\n\
echo "========================================"\n\
echo "Port: ${PORT}"\n\
echo "Data directory: ${GEOSERVER_DATA_DIR}"\n\
echo "Java version: $(java -version 2>&1 | head -n 1)"\n\
echo "Memory: $(free -h | grep Mem)"\n\
echo ""\n\
\n\
check_geoserver() {\n\
  curl -s http://localhost:${PORT}/geoserver/web/ > /dev/null 2>&1\n\
  return $?\n\
}\n\
\n\
echo "[$(date +"%H:%M:%S")] Starting Tomcat on port ${PORT}..."\n\
catalina.sh start\n\
\n\
echo "[$(date +"%H:%M:%S")] Waiting for GeoServer to respond..."\n\
COUNTER=0\n\
MAX_WAIT=300\n\
while [ $COUNTER -lt $MAX_WAIT ]; do\n\
  if check_geoserver; then\n\
    echo "[$(date +"%H:%M:%S")] ✓ GeoServer is responding!"\n\
    break\n\
  fi\n\
  if [ $((COUNTER % 30)) -eq 0 ]; then\n\
    echo "[$(date +"%H:%M:%S")] Still waiting... ($COUNTER seconds elapsed)"\n\
  fi\n\
  sleep 10\n\
  COUNTER=$((COUNTER + 10))\n\
done\n\
\n\
if [ $COUNTER -ge $MAX_WAIT ]; then\n\
  echo "[$(date +"%H:%M:%S")] ✗ ERROR: GeoServer did not start within $MAX_WAIT seconds"\n\
  echo "Tomcat logs:"\n\
  tail -100 /usr/local/tomcat/logs/catalina.out\n\
  exit 1\n\
fi\n\
\n\
if [ -d "${GEOSERVER_DATA_DIR}/security" ]; then\n\
  echo "[$(date +"%H:%M:%S")] ✓ Security directory found"\n\
  \n\
  if [ -d "${GEOSERVER_DATA_DIR}/workspaces/Sample_Area" ]; then\n\
    echo "[$(date +"%H:%M:%S")] Workspace already exists, skipping injection"\n\
  else\n\
    echo "[$(date +"%H:%M:%S")] Injecting Sample_Area workspace..."\n\
    \n\
    catalina.sh stop\n\
    sleep 10\n\
    \n\
    mkdir -p ${GEOSERVER_DATA_DIR}/workspaces\n\
    cd ${GEOSERVER_DATA_DIR}/workspaces\n\
    unzip -o /tmp/Sample_Area.zip\n\
    \n\
    echo "[$(date +"%H:%M:%S")] ✓ Workspace extracted"\n\
    \n\
    echo "[$(date +"%H:%M:%S")] Restarting Tomcat..."\n\
    catalina.sh start\n\
    \n\
    sleep 30\n\
    if check_geoserver; then\n\
      echo "[$(date +"%H:%M:%S")] ✓ GeoServer restarted successfully"\n\
    fi\n\
  fi\n\
fi\n\
\n\
echo "========================================"\n\
echo "[$(date +"%H:%M:%S")] GeoServer Ready!"\n\
echo "========================================"\n\
echo "Access URL: https://geoserver-render-ycu3.onrender.com/geoserver/web/"\n\
echo ""\n\
\n\
tail -f /usr/local/tomcat/logs/catalina.out\n\
' > /usr/local/bin/geoserver-init.sh && \
    chmod +x /usr/local/bin/geoserver-init.sh

EXPOSE 8080

CMD ["/usr/local/bin/geoserver-init.sh"]
