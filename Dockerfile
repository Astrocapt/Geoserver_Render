FROM tomcat:9-jdk17

# Install dependencies
RUN apt-get update && apt-get install -y unzip curl && rm -rf /var/lib/apt/lists/*

# Remove default webapps
RUN rm -rf /usr/local/tomcat/webapps/*

# Download GeoServer WAR
ADD https://github.com/Astrocapt/Geoserver/releases/download/v2.28.1/geoserver.war /usr/local/tomcat/webapps/geoserver.war

# Set environment variables - REMOVED MaxPermSize
ENV GEOSERVER_DATA_DIR=/var/geoserver_data
ENV CATALINA_OPTS="-Xms512M -Xmx2G -Djava.awt.headless=true -DGEOSERVER_DATA_DIR=/var/geoserver_data"

# Create data directory
RUN mkdir -p ${GEOSERVER_DATA_DIR} && chmod 777 ${GEOSERVER_DATA_DIR}

# Download workspace
RUN curl -L -o /tmp/Sample_Area.zip https://github.com/Astrocapt/hello-test/raw/main/Sample_Area.zip

# Modify Tomcat server.xml to bind to 0.0.0.0 and use PORT variable
RUN sed -i 's/port="8080"/port="${PORT}"/g' /usr/local/tomcat/conf/server.xml && \
    sed -i 's/<Connector port="${PORT}"/<Connector address="0.0.0.0" port="${PORT}"/g' /usr/local/tomcat/conf/server.xml

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
export PORT=${PORT:-8080}\n\
\n\
echo "========================================"\n\
echo "GeoServer Starting"\n\
echo "========================================"\n\
echo "Port: ${PORT}"\n\
echo "Data directory: ${GEOSERVER_DATA_DIR}"\n\
echo "Java version: $(java -version 2>&1 | head -n 1)"\n\
echo ""\n\
\n\
# Function to inject workspace after GeoServer initializes\n\
inject_workspace() {\n\
  echo "Checking for workspace..."\n\
  if [ -d "${GEOSERVER_DATA_DIR}/workspaces/Sample_Area" ]; then\n\
    echo "Workspace already exists"\n\
  elif [ -d "${GEOSERVER_DATA_DIR}/security" ]; then\n\
    echo "Injecting Sample_Area workspace..."\n\
    mkdir -p ${GEOSERVER_DATA_DIR}/workspaces\n\
    cd ${GEOSERVER_DATA_DIR}/workspaces\n\
    unzip -q /tmp/Sample_Area.zip\n\
    echo "Workspace injected successfully"\n\
  fi\n\
}\n\
\n\
# Start workspace injection in background\n\
(sleep 60 && inject_workspace) &\n\
\n\
echo "Starting Tomcat..."\n\
echo ""\n\
\n\
# Start Tomcat in foreground\n\
exec catalina.sh run\n\
' > /usr/local/bin/start.sh && chmod +x /usr/local/bin/start.sh

EXPOSE 8080

CMD ["/usr/local/bin/start.sh"]
