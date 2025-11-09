#!/bin/sh

SITE_NAME=${SITE_NAME:-erplocal}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin}
DB_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-admin}

# Créer le site si inexistant
if [ ! -d "/home/frappe/frappe-bench/sites/$SITE_NAME" ]; then
    bench new-site $SITE_NAME \
        --admin-password $ADMIN_PASSWORD \
        --db-root-password $DB_ROOT_PASSWORD \
        --install-app erpnext
fi

# Lancer Frappe / ERPNext
bench start
