FROM tomcat:9-jdk17

# Install required utilities
RUN apt-get update && apt-get install -y unzip curl && rm -rf /var/lib/apt/lists/*

# Remove default Tomcat webapps
RUN rm -rf /usr/local/tomcat/webapps/*

# Download GeoServer WAR
ADD https://github.com/Astrocapt/Geoserver/releases/download/v2.28.1/geoserver.war /usr/local/tomcat/webapps/geoserver.war

# Set GeoServer data directory to persistent volume
ENV GEOSERVER_DATA_DIR=/var/geoserver_data

# Set JVM options
ENV CATALINA_OPTS="-Xms512M -Xmx2G -Djava.awt.headless=true -DGEOSERVER_DATA_DIR=/var/geoserver_data"

# Create data directory
RUN mkdir -p ${GEOSERVER_DATA_DIR} && chmod 777 ${GEOSERVER_DATA_DIR}

# Download Study_Area workspace ZIP
RUN curl -L -o /tmp/Study_Area.zip https://github.com/Astrocapt/hello-test/raw/main/Sample_Area.zip

# Create startup script that binds to Render's PORT
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Use Render PORT or default to 10000 for local testing\n\
TOMCAT_PORT=${PORT:-10000}\n\
\n\
echo "Configuring Tomcat for port ${TOMCAT_PORT}..."\n\
\n\
# Generate server.xml with correct port binding\n\
cat > /usr/local/tomcat/conf/server.xml << EOF\n\
<?xml version="1.0" encoding="UTF-8"?>\n\
<Server port="-1" shutdown="SHUTDOWN">\n\
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />\n\
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />\n\
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />\n\
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />\n\
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />\n\
  <Service name="Catalina">\n\
    <Connector port="${TOMCAT_PORT}" protocol="HTTP/1.1"\n\
               connectionTimeout="20000"\n\
               address="0.0.0.0"\n\
               redirectPort="8443"\n\
               maxThreads="200" />\n\
    <Engine name="Catalina" defaultHost="localhost">\n\
      <Host name="localhost" appBase="webapps"\n\
            unpackWARs="true" autoDeploy="true">\n\
      </Host>\n\
    </Engine>\n\
  </Service>\n\
</Server>\n\
EOF\n\
\n\
echo "Tomcat configured for port ${TOMCAT_PORT}"\n\
\n\
# Background process to inject workspace after initialization\n\
inject_workspace() {\n\
  echo "[Background] Waiting for GeoServer to initialize..."\n\
  \n\
  # Wait for security directory (indicates GeoServer initialized)\n\
  COUNTER=0\n\
  while [ ! -d "${GEOSERVER_DATA_DIR}/security" ] && [ $COUNTER -lt 600 ]; do\n\
    sleep 10\n\
    COUNTER=$((COUNTER + 10))\n\
  done\n\
  \n\
  if [ ! -d "${GEOSERVER_DATA_DIR}/security" ]; then\n\
    echo "[Background] ERROR: GeoServer did not initialize within 10 minutes"\n\
    return 1\n\
  fi\n\
  \n\
  echo "[Background] GeoServer initialized. Checking workspace..."\n\
  \n\
  # Only inject if not already present\n\
  if [ ! -f "${GEOSERVER_DATA_DIR}/.workspace_injected" ]; then\n\
    echo "[Background] Injecting Study_Area workspace..."\n\
    \n\
    mkdir -p ${GEOSERVER_DATA_DIR}/workspaces\n\
    cd ${GEOSERVER_DATA_DIR}/workspaces\n\
    \n\
    if unzip -o /tmp/Study_Area.zip; then\n\
      touch ${GEOSERVER_DATA_DIR}/.workspace_injected\n\
      echo "[Background] Workspace injected successfully"\n\
      ls -la ${GEOSERVER_DATA_DIR}/workspaces/\n\
    else\n\
      echo "[Background] ERROR: Failed to extract workspace"\n\
      return 1\n\
    fi\n\
  else\n\
    echo "[Background] Workspace already injected"\n\
  fi\n\
}\n\
\n\
# Start workspace injection in background\n\
inject_workspace &\n\
\n\
echo "Starting Tomcat..."\n\
exec catalina.sh run\n\
' > /usr/local/bin/start.sh && chmod +x /usr/local/bin/start.sh

# Expose the port (Render will override with PORT env var)
EXPOSE 10000

CMD ["/usr/local/bin/start.sh"]

