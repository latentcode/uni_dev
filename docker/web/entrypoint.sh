#!/usr/bin/env bash
set -euo pipefail

if [[ "${WEB_CONTAINER_WEB_ROOT:-}" != /* ]]; then
    echo "WEB_CONTAINER_WEB_ROOT must be an absolute container path." >&2
    exit 1
fi

mkdir -p "${WEB_CONTAINER_WEB_ROOT}"
export WEB_CONTAINER_WEB_ROOT
envsubst '${WEB_CONTAINER_WEB_ROOT}' \
    < /opt/university-dev/apache-site.conf.template \
    > /etc/apache2/sites-available/000-default.conf

exec "$@"
