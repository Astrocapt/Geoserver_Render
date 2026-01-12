# Use an official Tomcat 9 JDK17 base image
FROM tomcat:9.0-jre17

# Set environment variables for GeoServer version and workspace
ENV GEOSERVER_VERSION=2.28.1
ENV WORKSPACE_ZIP=Sample_Area.zip

# Set working directory
WORKDIR /usr/local/tomcat/webapps/

# Remove default Tomcat apps
RUN rm -rf /usr/local/tomcat/webapps/*

# Download GeoServer WAR directly from GitHub release
ADD https://github.com/Astrocapt/Geoserver/releases/download/v2.28.1/geoserver.war \
    /usr/local/tomcat/webapps/geoserver.war

# Download Sample_Area workspace zip directly from your repo
ADD https://github.com/Astrocapt/hello-test/raw/main/Sample_Area.zip \
    /tmp/${WORKSPACE_ZIP}

# Install unzip, extract workspace, and clean up
RUN apt-get update && apt-get install -y unzip \
    && mkdir -p /usr/local/tomcat/data_dir \
    && unzip /tmp/${WORKSPACE_ZIP} -d /usr/local/tomcat/data_dir/workspaces/ \
    && rm /tmp/${WORKSPACE_ZIP} \
    && apt-get remove -y unzip \
    && apt-get clean \
    && echo "GeoServer workspace deployed successfully"

# Set GeoServer data directory environment variable
ENV GEOSERVER_DATA_DIR=/usr/local/tomcat/data_dir

# Optional: expose port 8080
EXPOSE 8080

# Start Tomcat with correct environment
CMD ["catalina.sh", "run"]
