# Use an official Tomcat 9 JDK17 base image
FROM tomcat:9.0-jre17

# Set working directory
WORKDIR /usr/local/tomcat/webapps/

# Remove default Tomcat apps
RUN rm -rf /usr/local/tomcat/webapps/*

# Download GeoServer WAR directly from GitHub release
ADD https://github.com/Astrocapt/Geoserver/releases/download/v2.28.1/geoserver.war \
    /usr/local/tomcat/webapps/geoserver.war

# Download full GeoServer data directory (includes Sample_Area workspace and security)
ADD https://github.com/Astrocapt/hello-test/raw/main/data_dir.zip /tmp/data_dir.zip

# Unzip data_dir and clean up
RUN apt-get update && apt-get install -y unzip \
    && unzip /tmp/data_dir.zip -d /usr/local/tomcat/data_dir/ \
    && rm /tmp/data_dir.zip \
    && apt-get remove -y unzip \
    && apt-get clean

# Set GeoServer data directory environment variable
ENV GEOSERVER_DATA_DIR=/usr/local/tomcat/data_dir

# Expose Tomcat port
EXPOSE 8080

# Start Tomcat
CMD ["catalina.sh", "run"]
