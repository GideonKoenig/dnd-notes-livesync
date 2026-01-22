# Use CouchDB as the base image
FROM couchdb:3.4.2

# Set environment variables
ENV COUCHDB_USER=admin
ENV COUCHDB_PASSWORD=admin

# Create necessary directories
RUN mkdir -p /opt/couchdb/data /opt/couchdb/etc

# Copy configuration files
COPY local.ini /opt/couchdb/etc/local.ini

# Copy and set up the initialization entrypoint
COPY docker-entrypoint-init.sh /usr/local/bin/docker-entrypoint-init.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-init.sh

# Set ownership
RUN chown -R couchdb:couchdb /opt/couchdb/data /opt/couchdb/etc

# Expose port
EXPOSE 5984

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f -u ${COUCHDB_USER}:${COUCHDB_PASSWORD} http://localhost:5984/_up || exit 1

# Use custom entrypoint that initializes single-node mode
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-init.sh"]
CMD ["/opt/couchdb/bin/couchdb"]