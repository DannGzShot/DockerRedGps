# Autor: DannGzShot
# Fecha de creacion: 16/03/2026
# Descripcion: Construye la imagen PHP/Apache usada por el entorno Docker local de REDGPS.

FROM php:7.3-apache

ARG UID=1000
ARG GID=1000

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    curl \
    libicu-dev \
    libzip-dev \
    zlib1g-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    libmemcached-dev \
    libsasl2-dev \
    libc-client-dev \
    libkrb5-dev \
    libmagickwand-dev \
    libssh2-1-dev \
    libxslt1-dev \
    liblzf-dev \
    libzstd-dev \
    liblz4-dev \
    pkg-config \
    ssl-cert \
    libmcrypt-dev \
 && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl

RUN docker-php-ext-install -j$(nproc) \
    bcmath \
    calendar \
    gettext \
    imap \
    mysqli \
    pdo \
    pdo_mysql \
    mbstring \
    intl \
    zip \
    soap \
    gd \
    exif \
    pcntl \
    shmop \
    sockets \
    sysvmsg \
    sysvsem \
    sysvshm \
    wddx \
    xmlrpc \
    xsl \
    opcache

RUN a2enmod rewrite headers alias proxy proxy_http proxy_wstunnel setenvif

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN groupmod -g ${GID} www-data && usermod -u ${UID} www-data

RUN mkdir -p /var/www/html/web \
    /var/www/html/empty \
    /home/redgps/autoloads \
    /var/cache/files/autoloads

RUN chown -R www-data:www-data /var/cache/files /home/redgps && \
    chmod -R 775 /var/cache/files /home/redgps

COPY ./docker/apache/redgps.local.conf /etc/apache2/sites-available/redgps.local.conf

RUN a2dissite 000-default && a2ensite redgps.local.conf

WORKDIR /home/git/repositorios

RUN touch /var/log/log_sql_queries.log && \
    chown www-data:www-data /var/log/log_sql_queries.log && \
    chmod 664 /var/log/log_sql_queries.log

RUN a2enmod rewrite headers alias ssl proxy proxy_http proxy_wstunnel setenvif

RUN sed -i 's/^Listen 80$/Listen 18080/' /etc/apache2/ports.conf && \
    sed -i 's/^Listen 443$/Listen 8001/' /etc/apache2/ports.conf

RUN pecl channel-update pecl.php.net \
 && pecl install apcu-5.1.24 \
 && pecl install igbinary-3.2.6 \
 && pecl install msgpack-2.1.2 \
 && pecl install imagick-3.6.0 \
 && pecl install ssh2-1.3.1 \
 && pecl install -D 'enable-memcached-igbinary="yes" enable-memcached-msgpack="yes" enable-memcached-json="yes" enable-memcached-sasl="yes" enable-memcached-session="yes"' memcached-3.1.5 \
 && pecl install mcrypt-1.0.4 \
 && pecl install mongodb-1.12.0 \
 && mkdir -p /tmp/redis-build \
 && cd /tmp/redis-build \
 && pecl download redis-5.3.5 \
 && tar -xzf redis-5.3.5.tgz \
 && cd redis-5.3.5 \
 && phpize \
 && ./configure --with-php-config=/usr/local/bin/php-config --enable-redis-igbinary --enable-redis-lzf --enable-redis-zstd --enable-redis-lz4 --with-liblz4=yes \
 && make -j$(nproc) \
 && make install \
 && cd / \
 && rm -rf /tmp/redis-build \
 && docker-php-ext-enable apcu igbinary msgpack imagick ssh2 memcached mcrypt mongodb redis
