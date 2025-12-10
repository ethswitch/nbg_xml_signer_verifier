# ============================================================
# Stage: Tomcat container with WAR deployment
# ============================================================
FROM tomcat:10.1.20-jdk21-temurin
WORKDIR /usr/local/tomcat

# ------------------------------
# Environment variables
# ------------------------------
ENV TZ=UTC \
    CATALINA_OPTS="-Xms512m -Xmx1024m -Djava.security.egd=file:/dev/./urandom"

# ------------------------------
# Remove default ROOT app
# ------------------------------
RUN rm -rf webapps/*

# ------------------------------
# Copy WAR into Tomcat
# ------------------------------
COPY build/libs/*.war webapps/ROOT.war

# ------------------------------
# Change Tomcat HTTP connector port
# ------------------------------
RUN sed -i 's/port="8080"/port="9494"/' /usr/local/tomcat/conf/server.xml

# ------------------------------
# Expose and healthcheck
# ------------------------------
EXPOSE 9494

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:9494/actuator/health || exit 1

# ------------------------------
# Start Tomcat
# ------------------------------
CMD ["catalina.sh", "run"]
