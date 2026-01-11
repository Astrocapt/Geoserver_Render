FROM tomcat:9-jdk17-temurin

# Remove default Tomcat apps
RUN rm -rf /usr/local/tomcat/webapps/*

# Download GeoServer WAR and deploy it
ADD https://github.com/Astrocapt/Geoserver/releases/download/v2.28.1/geoserver.war \
    /usr/local/tomcat/webapps/geoserver.war

# Expose Tomcat port
EXPOSE 8080

# Start Tomcat
CMD ["catalina.sh", "run"]
