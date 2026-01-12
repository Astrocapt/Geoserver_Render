FROM tomcat:9-jdk17

# Install unzip and curl
RUN apt-get update && apt-get install -y unzip curl && rm -rf /var/lib/apt/lists/*

# Remove default Tomcat webapps
RUN rm -rf /usr/local/tomcat/webapps/*

# Download GeoServer WAR directly from GitHub releases
ADD https://github.com/Astrocapt/Geoserver/releases/download/v2.28.1/geoserver.war /usr/local/tomcat/webapps/geoserver.war

# Set GeoServer data directory environment variable
ENV GEOSERVER_DATA_DIR=/var/geoserver_data

# Create data directory with proper permissions
RUN mkdir -p ${GEOSERVER_DATA_DIR} && \
    chmod 777 ${GEOSERVER_DATA_DIR}

# Download Sample_Area.zip from GitHub during build
RUN curl -L -o /tmp/Sample_Area.zip https://github.com/Astrocapt/hello-test/raw/main/Sample_Area.zip

# Create startup script for two-stage initialization
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "=== GeoServer Initialization Script ==="\n\
echo "Data directory: ${GEOSERVER_DATA_DIR}"\n\
\n\
# Start Tomcat to trigger GeoServer initialization\n\
echo "Starting Tomcat to initialize GeoServer..."\n\
catalina.sh start\n\
\n\
echo "Waiting for GeoServer to initialize (120 seconds)..."\n\
sleep 120\n\
\n\
# Check if GeoServer initialized properly\n\
if [ -d "${GEOSERVER_DATA_DIR}/security" ]; then\n\
  echo "✓ GeoServer initialized successfully!"\n\
  echo "✓ Security directory found"\n\
  \n\
  # Stop Tomcat before injecting workspace\n\
  echo "Stopping Tomcat temporarily..."\n\
  catalina.sh stop\n\
  sleep 10\n\
  \n\
  # Inject Sample_Area workspace\n\
  echo "Injecting Sample_Area workspace..."\n\
  echo "Checking Sample_Area.zip contents:"\n\
  unzip -l /tmp/Sample_Area.zip | head -20\n\
  \n\
  mkdir -p ${GEOSERVER_DATA_DIR}/workspaces\n\
  cd ${GEOSERVER_DATA_DIR}/workspaces\n\
  unzip -o /tmp/Sample_Area.zip\n\
  \n\
  echo "✓ Workspace injected successfully!"\n\
  echo "Workspace contents:"\n\
  ls -la ${GEOSERVER_DATA_DIR}/workspaces/\n\
  \n\
  # Clean up\n\
  rm /tmp/Sample_Area.zip\n\
  \n\
  # Restart Tomcat\n\
  echo "Starting Tomcat in foreground..."\n\
  catalina.sh run\n\
else\n\
  echo "✗ ERROR: GeoServer did not initialize properly!"\n\
  echo "Security directory not found at: ${GEOSERVER_DATA_DIR}/security"\n\
  echo "Contents of data directory:"\n\
  ls -la ${GEOSERVER_DATA_DIR}\n\
  echo "Starting Tomcat anyway for debugging..."\n\
  catalina.sh stop\n\
  sleep 5\n\
  catalina.sh run\n\
fi\n\
' > /usr/local/bin/geoserver-init.sh && \
    chmod +x /usr/local/bin/geoserver-init.sh

# Expose Tomcat port
EXPOSE 8080

# Use custom initialization script
CMD ["/usr/local/bin/geoserver-init.sh"]
