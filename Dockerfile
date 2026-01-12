FROM tomcat:9-jdk17

# Remove default Tomcat webapps
RUN rm -rf /usr/local/tomcat/webapps/*

# Download GeoServer WAR
ADD https://github.com/Astrocapt/Geoserver/releases/download/v2.28.1/geoserver.war /usr/local/tomcat/webapps/geoserver.war

# Set GeoServer data directory environment variable
ENV GEOSERVER_DATA_DIR=/var/geoserver_data

# Create data directory with proper permissions
RUN mkdir -p ${GEOSERVER_DATA_DIR} && \
    chmod 777 ${GEOSERVER_DATA_DIR}

# Copy your workspace ZIP
COPY Study_Area.zip /tmp/Study_Area.zip

# Create startup script for two-stage initialization
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Starting Tomcat to initialize GeoServer..."\n\
catalina.sh start\n\
\n\
echo "Waiting for GeoServer to initialize (120 seconds)..."\n\
sleep 120\n\
\n\
echo "Checking if GeoServer data directory was created..."\n\
if [ -d "${GEOSERVER_DATA_DIR}/security" ]; then\n\
  echo "GeoServer initialized successfully. Security directory found."\n\
  \n\
  echo "Stopping Tomcat..."\n\
  catalina.sh stop\n\
  sleep 10\n\
  \n\
  echo "Extracting Study_Area workspace..."\n\
  cd ${GEOSERVER_DATA_DIR}/workspaces\n\
  unzip -o /tmp/Study_Area.zip\n\
  \n\
  echo "Workspace injected. Cleaning up..."\n\
  rm /tmp/Study_Area.zip\n\
  \n\
  echo "Starting Tomcat in foreground..."\n\
  catalina.sh run\n\
else\n\
  echo "ERROR: GeoServer did not initialize properly!"\n\
  echo "Starting anyway for debugging..."\n\
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
