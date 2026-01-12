FROM tomcat:9-jdk17

# Install dependencies
RUN apt-get update && apt-get install -y unzip curl && rm -rf /var/lib/apt/lists/*

# Remove default webapps
RUN rm -rf /usr/local/tomcat/webapps/*

# Download GeoServer WAR
ADD https://github.com/Astrocapt/Geoserver/releases/download/v2.28.1/geoserver.war /usr/local/tomcat/webapps/geoserver.war

# Set environment variables
ENV GEOSERVER_DATA_DIR=/var/geoserver_data
ENV CATALINA_OPTS="-Xms512M -Xmx2G -Djava.awt.headless=true -DGEOSERVER_DATA_DIR=/var/geoserver_data"

# Create data directory
RUN mkdir -p ${GEOSERVER_DATA_DIR} && chmod 777 ${GEOSERVER_DATA_DIR}

# Download workspace
RUN curl -L -o /tmp/Sample_Area.zip https://github.com/Astrocapt/hello-test/raw/main/Sample_Area.zip

# Create a simple health check webapp
RUN mkdir -p /usr/local/tomcat/webapps/ROOT && \
    echo '<%@ page contentType="text/plain" %>OK<% \
    java.io.File geoserverCheck = new java.io.File("/usr/local/tomcat/webapps/geoserver"); \
    if (geoserverCheck.exists()) { \
        out.print(" - GeoServer deployed"); \
    } else { \
        out.print(" - GeoServer deploying..."); \
    } \
    %>' > /usr/local/tomcat/webapps/ROOT/health.jsp

# Create server.xml with FIXED port 8080 (ignore Render PORT variable)
RUN cat > /usr/local/tomcat/conf/server.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Server port="-1" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />
  <Service name="Catalina">
    <Connector port="8080" protocol="HTTP/1.1"
               connectionTimeout="20000"
               address="0.0.0.0"
               redirectPort="8443"
               maxThreads="200" />
    <Engine name="Catalina" defaultHost="localhost">
      <Host name="localhost" appBase="webapps"
            unpackWARs="true" autoDeploy="true">
      </Host>
    </Engine>
  </Service>
</Server>
EOF

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "========================================"\n\
echo "GeoServer Starting"\n\
echo "========================================"\n\
echo "Port: 8080 (FIXED)"\n\
echo "Binding to: 0.0.0.0:8080"\n\
echo "Data directory: ${GEOSERVER_DATA_DIR}"\n\
echo "Render PORT variable: ${PORT} (IGNORED)"\n\
echo ""\n\
echo "NOTE: GeoServer takes 3-5 minutes to deploy on first start"\n\
echo "Health check available at: /health.jsp"\n\
echo ""\n\
\n\
# Function to inject workspace after GeoServer initializes\n\
inject_workspace() {\n\
  echo "Background: Waiting for GeoServer data directory to initialize..."\n\
  COUNTER=0\n\
  while [ ! -d "${GEOSERVER_DATA_DIR}/security" ] && [ $COUNTER -lt 600 ]; do\n\
    sleep 10\n\
    COUNTER=$((COUNTER + 10))\n\
    if [ $((COUNTER % 60)) -eq 0 ]; then\n\
      echo "Background: Still waiting for GeoServer... ($COUNTER seconds)"\n\
    fi\n\
  done\n\
  \n\
  if [ -d "${GEOSERVER_DATA_DIR}/security" ]; then\n\
    echo "Background: GeoServer data directory initialized!"\n\
    if [ ! -f "${GEOSERVER_DATA_DIR}/.workspace_injected" ]; then\n\
      echo "Background: Injecting Sample_Area workspace..."\n\
      mkdir -p ${GEOSERVER_DATA_DIR}/workspaces\n\
      cd ${GEOSERVER_DATA_DIR}/workspaces\n\
      if unzip -q /tmp/Sample_Area.zip 2>/dev/null; then\n\
        touch ${GEOSERVER_DATA_DIR}/.workspace_injected\n\
        echo "Background: ✓ Workspace injected successfully!"\n\
        echo "Background: Workspace contents:"\n\
        ls -la ${GEOSERVER_DATA_DIR}/workspaces/\n\
      else\n\
        echo "Background: ✗ Failed to extract workspace"\n\
      fi\n\
    else\n\
      echo "Background: Workspace already injected, skipping"\n\
    fi\n\
  else\n\
    echo "Background: ✗ GeoServer data directory never initialized"\n\
  fi\n\
}\n\
\n\
# Start workspace injection in background\n\
inject_workspace &\n\
\n\
echo "Starting Tomcat on port 8080..."\n\
echo ""\n\
\n\
# Start Tomcat in foreground\n\
exec catalina.sh run\n\
' > /usr/local/bin/start.sh && chmod +x /usr/local/bin/start.sh

EXPOSE 8080

CMD ["/usr/local/bin/start.sh"]FROM tomcat:9-jdk17

# Install dependencies
RUN apt-get update && apt-get install -y unzip curl xmlstarlet && rm -rf /var/lib/apt/lists/*

# Remove default webapps
RUN rm -rf /usr/local/tomcat/webapps/*

# Download GeoServer WAR
ADD https://github.com/Astrocapt/Geoserver/releases/download/v2.28.1/geoserver.war /usr/local/tomcat/webapps/geoserver.war

# Set environment variables
ENV GEOSERVER_DATA_DIR=/var/geoserver_data
ENV CATALINA_OPTS="-Xms512M -Xmx2G -Djava.awt.headless=true -DGEOSERVER_DATA_DIR=/var/geoserver_data"

# Create data directory
RUN mkdir -p ${GEOSERVER_DATA_DIR} && chmod 777 ${GEOSERVER_DATA_DIR}

# Download workspace
RUN curl -L -o /tmp/Sample_Area.zip https://github.com/Astrocapt/hello-test/raw/main/Sample_Area.zip

# Create startup script that properly configures the port
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
export PORT=${PORT:-8080}\n\
\n\
echo "========================================"\n\
echo "GeoServer Starting"\n\
echo "========================================"\n\
echo "Port: ${PORT}"\n\
echo "Binding to: 0.0.0.0:${PORT}"\n\
echo "Data directory: ${GEOSERVER_DATA_DIR}"\n\
echo ""\n\
\n\
# Create a new server.xml with correct port binding\n\
cat > /usr/local/tomcat/conf/server.xml << EOF\n\
<?xml version="1.0" encoding="UTF-8"?>\n\
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
echo "Server.xml configured with port ${PORT} on 0.0.0.0"\n\
echo ""\n\
\n\
# Function to inject workspace after GeoServer initializes\n\
inject_workspace() {\n\
  sleep 90\n\
  if [ -d "${GEOSERVER_DATA_DIR}/workspaces/Sample_Area" ]; then\n\
    echo "Workspace already exists"\n\
  elif [ -d "${GEOSERVER_DATA_DIR}/security" ]; then\n\
    echo "Injecting Sample_Area workspace..."\n\
    mkdir -p ${GEOSERVER_DATA_DIR}/workspaces\n\
    cd ${GEOSERVER_DATA_DIR}/workspaces\n\
    unzip -q /tmp/Sample_Area.zip 2>/dev/null || true\n\
    echo "Workspace injected"\n\
  fi\n\
}\n\
\n\
# Start workspace injection in background\n\
inject_workspace &\n\
\n\
echo "Starting Tomcat..."\n\
echo ""\n\
\n\
# Start Tomcat in foreground\n\
exec catalina.sh run\n\
' > /usr/local/bin/start.sh && chmod +x /usr/local/bin/start.sh

EXPOSE 8080

CMD ["/usr/local/bin/start.sh"]
