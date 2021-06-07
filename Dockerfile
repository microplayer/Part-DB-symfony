# Roger Zink, 06.06.2021 - Der Anfang bis "Install yarn" angepasst für neue Parameter ab PHP7.4 für die Integration des JPEG-formats für GD 
# R.Zink: Bei Problemen mit der Integration von "freetype2" gibt es Empfehlungen wie diese "FROM php:7.3-fpm-stretch" - funktioniert aber auch ohne
# Geht mit "-stretch" aber vielleicht auch eleganter? - Siehe: https://github.com/docker-library/php/issues/865
FROM php:7-apache

# R.Zink: "apt-get install -y" - answer Yes (y) to the subsequent prompt (typically whether or not to continue after displaying the additional disk space that will be used)
# Auf der Fehlersuche bis zur erfolgreichen Integration des JPEG-Formats für GD bzw. PHP für Part-DB1 wurden zahlreiche Webseiten besucht.
# https://github.com/docker-library/php/issues/912
# https://hub.docker.com/_/php
# https://github.com/docker-library/php/issues/225
# https://github.com/docker-library/php/issues/865
# https://gist.github.com/shov/f34541feae29afedd93208df4bf428f3
# https://www.php.net/manual/de/image.installation.php
# Dazu noch etliche andere, die Vermutungen bestätigt oder ausgeschlossen haben, die ich aber nicht gespeichert habe 

# Hier nun die initiale Installation von Packages in das Apache-Image hinein - hier erfolgen die ersten wichtigen Ergänzungen und Änderungen!!! 
# WICHTIG! Dies ist das Ergebnis von Lesen und Trial und Error! Gesichertes Knowhow als SW-Entwickler fehlt leider. 
# 1. In mehreren Artikeln wurde die Installation von "pkg-config" empfohlen: https://github.com/docker-library/php/issues/865
# 2. Beim Experiementieren mit "docker-compose" stößt man schnell auf die fehlende "libjpeg" Library - die aktuelle Version ist wohl "libjpeg-dev"  
# 3. Auf der Suche nach PHP, GD, JPEG stößt man schnell auf die "freetype" Library(?) - oder auch "freetype2" - der aktuelle Name lautet "libfreetype6-dev" 
# 4. Das Apache-Image hat keine Editor installiert, deshalb "vim" hinzugefügt - war bei Problemen mit der SQLite3-DB recht nützlich
# 5. Es fanden sich Hinweise im Web, dass das Löschen von "/var/lib/apt/lists/*" evt. Ärger mit der Installation von "gd" macht - wird getestet...
# 6. Zum Schluß noch die "apt-get" Installationsdateien entfernt - https://opensource.com/article/20/5/optimize-container-builds  
# Das neue Image ist damit nur noch 944MB groß
RUN apt-get update &&  apt-get install -y pkg-config curl libcurl4-openssl-dev libicu-dev \
    libpng-dev libjpeg-dev libfreetype6-dev gnupg zip libzip-dev libonig-dev libxslt-dev vim \
    && apt-get -y autoremove && apt-get clean autoclean && rm -rf /var/lib/apt/lists/*

# R.Zink: Dies sind die mit PHP7.4 nötigen geänderten Parameter für die Integration des JPEG-Formates
# Ein Stolperstelle besteht darin, dass ZUERST der Install "docker-php-ext-configure gd" erfolgen muss, und DANN ERST "docker-php-ext-install gd"
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && docker-php-ext-install gd
# Der Erfolg lässt sich im laufenden Container prüfen: "RUN php -r 'var_dump(gd_info());' " - oder auch mit: "php -r 'print_r(gd_info());' "
# Dort muss auch die Extension JPEG = 1 = true angezeigt werden.

# R.Zink: Nun folgt der Rest des Original-Dockerfiles - aus der nachfolgenden Zeile haben wir effektiv den "docker-php-ext-configure gd ..." VORGEZOGEN   
RUN docker-php-ext-install pdo_mysql curl intl mbstring bcmath zip xml xsl

# Install yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y yarn

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY --chown=www-data:www-data . .

# Setup apache2
RUN a2dissite 000-default.conf
COPY ./.docker/symfony.conf /etc/apache2/sites-available/symfony.conf
RUN a2ensite symfony.conf
RUN a2enmod rewrite

USER www-data
RUN composer install -a --no-dev && composer clear-cache
RUN yarn install && yarn build && yarn cache clean
RUN php bin/console --env=prod ckeditor:install --clear=skip

# Use demo env to output logs to stdout
ENV APP_ENV=demo
ENV DATABASE_URL="sqlite:///%kernel.project_dir%/uploads/app.db"

USER root

VOLUME ["/var/www/html/uploads", "/var/www/html/public/media"]
EXPOSE 80
