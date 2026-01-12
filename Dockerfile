# Use official Tomcat
FROM tomcat:9.0-jre17

# Clean default apps
RUN rm -rf /usr/local/tomcat/webapps/*

# Deploy GeoServer WAR
ADD https://github.com/Astrocapt/Geoserver/releases/download/v2.28.1/geoserver.war \
    /usr/local/tomcat/webapps/geoserver.war

# Create data directory (LET GEOSERVER INITIALIZE IT)
ENV GEOSERVER_DATA_DIR=/usr/local/tomcat/data_dir

# Download ONLY Study_Area workspace
ADD https://github.com/Astrocapt/hello-test/raw/main/Study_Area.zip /tmp/Study_Area.zip

# Install unzip & deploy workspace AFTER data_dir exists
RUN apt-get update && apt-get install -y unzip \
    && mkdir -p /usr/local/tomcat/data_dir/workspaces \
    && unzip /tmp/Study_Area.zip -d /usr/local/tomcat/data_dir/workspaces/ \
    && rm /tmp/Study_Area.zip \
    && apt-get remove -y unzip \
    && apt-get clean

EXPOSE 8080
CMD ["catalina.sh", "run"]
