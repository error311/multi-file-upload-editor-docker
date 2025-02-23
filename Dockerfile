FROM ubuntu:22.04
LABEL by=error311

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/root \
    LC_ALL=C.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    TERM=xterm \
    UPLOAD_MAX_FILESIZE=5G \
    POST_MAX_SIZE=5G

# Default Unraid UID and GID (99:100)
ARG PUID=99
ARG PGID=100

# Ensure UID/GID are only changed if different
RUN set -eux; \
    if [ "$(id -u www-data)" != "${PUID}" ]; then \
        usermod -u ${PUID} www-data || echo "UID already set"; \
    fi; \
    if [ "$(id -g www-data)" != "${PGID}" ]; then \
        groupmod -g ${PGID} www-data || echo "GID already set"; \
    fi; \
    usermod -g ${PGID} www-data

# Install Apache, PHP, and required packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    apache2 \
    php \
    php-json \
    php-curl \
    ca-certificates \
    unzip \
    openssl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy web app source code (bypass GitHub dependency)
WORKDIR /var/www/html

# Download web app as ZIP if GitHub clone fails
RUN curl -L https://github.com/error311/multi-file-upload-editor/archive/refs/heads/main.zip -o /tmp/app.zip && \
    unzip /tmp/app.zip -d /var/www/html && \
    mv /var/www/html/multi-file-upload-editor-main/* /var/www/html && \
    rm -rf /tmp/app.zip /var/www/html/multi-file-upload-editor-main

# Ensure startup script copies the web app if missing
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Apache site configuration
RUN echo '<VirtualHost *:80>' > /etc/apache2/sites-available/000-default.conf && \
    echo '    ServerAdmin webmaster@localhost' >> /etc/apache2/sites-available/000-default.conf && \
    echo '    DocumentRoot /web' >> /etc/apache2/sites-available/000-default.conf && \
    echo '    <Directory "/web">' >> /etc/apache2/sites-available/000-default.conf && \
    echo '        AllowOverride All' >> /etc/apache2/sites-available/000-default.conf && \
    echo '        Require all granted' >> /etc/apache2/sites-available/000-default.conf && \
    echo '        DirectoryIndex index.php index.html' >> /etc/apache2/sites-available/000-default.conf && \
    echo '    </Directory>' >> /etc/apache2/sites-available/000-default.conf && \
    echo '    ErrorLog ${APACHE_LOG_DIR}/error.log' >> /etc/apache2/sites-available/000-default.conf && \
    echo '    CustomLog ${APACHE_LOG_DIR}/access.log combined' >> /etc/apache2/sites-available/000-default.conf && \
    echo '</VirtualHost>' >> /etc/apache2/sites-available/000-default.conf

# Expose ports
EXPOSE 80 443

# Run startup script
CMD ["/usr/local/bin/start.sh"]
