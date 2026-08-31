FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        apache2 \
        ca-certificates \
        curl \
        gettext-base \
        git \
        python-is-python3 \
        python3 \
        python3-pip \
        python3-venv \
    && a2enmod headers rewrite \
    && printf '%s\n' 'ServerName localhost' >> /etc/apache2/apache2.conf \
    && mkdir -p /opt/venvs \
    && rm -rf /var/lib/apt/lists/*

COPY apache-site.conf.template /opt/university-dev/apache-site.conf.template
COPY entrypoint.sh /usr/local/bin/web-entrypoint

RUN chmod 0755 /usr/local/bin/web-entrypoint

ENV WEB_CONTAINER_WEB_ROOT=/var/www/html

EXPOSE 80

ENTRYPOINT ["web-entrypoint"]
CMD ["apachectl", "-D", "FOREGROUND"]
