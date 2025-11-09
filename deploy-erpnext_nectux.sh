#!/bin/bash

# Chargement de .env
set -a
source .env
set +a

# Étape 1 : Arrêter des services et libération d'espace
echo "Arrêt des services ..."
docker compose down --volumes --remove-orphans

# echo "Libérer de l'espace ..."
# docker system prune -a --volumes -f

# Étape 2 : Lancer des services
echo "Lancement des services ..."
docker compose up -d
if [ $? -ne 0 ]; then
  echo "Échec de lancement des services."
  exit 1
fi

# Étape 3 : Installer Frappe
echo "Installation de Frappe ..."
timeout=${TIMEOUT_BEFORE_EXIT}
elapsed=0
interval=${SLEEP_INTERVAL}

while [ $elapsed -lt $timeout ]; do
  output=$(docker compose logs create-site 2>&1)
  echo "$output"

  if echo "$output" | grep -qi "Current Site set to frontend"; then
    echo "Installation Frappe terminée."
    break
  fi

  sleep $interval
  elapsed=$((elapsed + interval))
done

if [ $elapsed -ge $timeout ]; then
  echo "Échec de l'installation de Frappe. Abandon."
  exit 1
fi

echo "Activation mode developpeur ..."
sudo docker compose exec backend bash -c "sed -i '\#}#i \  ,\"developer_mode\": 1' sites/frontend/site_config.json"
if [ $? -ne 0 ]; then
  echo "Échec activation mode developpeur. Abandon."
  exit 1
fi

# Étape 4 : Installer Erpnext_Softia_Fr
echo "Récupération de Erpnext_Softia_Fr ..."
sudo docker compose exec backend bench get-app ${APP_NAME} ${GIT_URL}
if [ $? -ne 0 ]; then
  echo "Échec de l'installation de Erpnext_Softia_Fr. Abandon."
  exit 1
fi

echo "Installation de Erpnext_Softia_Fr ..."
sudo docker compose exec backend bench --site frontend install-app ${APP_NAME}
if [ $? -ne 0 ]; then
  echo "Échec de l'installation de Erpnext_Softia_Fr. Abandon."
  exit 1
fi

echo "Migration ..."
sudo docker compose exec backend bench --site frontend migrate
if [ $? -ne 0 ]; then
  echo "Échec migration. Abandon."
  exit 1
fi

# Étape 5 : Redémarrer les services
echo "Redémarrage des services ..."
sudo docker compose restart

echo "Enregistrement de ${APP_NAME} ..."
sudo docker compose exec backend bash -c "echo '${APP_NAME}' >> sites/apps.txt"
if [ $? -ne 0 ]; then
  echo "Échec enregistrement de ${APP_NAME}. Abandon."
  exit 1
fi

echo "Copie des traductions ..."
sudo docker compose exec backend bash -c "cp -f apps/erpnext_softia_fr/locale/frappe_fr.po apps/frappe/frappe/locale/fr.po; bench build --app frappe;"
if [ $? -ne 0 ]; then
  echo "Échec copie traductions frappe. Abandon."
  exit 1
fi

sudo docker compose exec backend bash -c "mkdir apps/erpnext/erpnext/locale; cp -f apps/erpnext_softia_fr/locale/erpnext_fr.po apps/erpnext/erpnext/locale/fr.po; bench build --app erpnext;"
if [ $? -ne 0 ]; then
  echo "Échec copie traductions erpnext. Abandon."
  exit 1
fi

echo "clear-cache ..."
sudo docker compose exec backend bench --site frontend clear-cache
if [ $? -ne 0 ]; then
  echo "Échec clear-cache. Abandon."
  exit 1
fi

echo "clear-website-cache ..."
sudo docker compose exec backend bench --site frontend clear-website-cache
if [ $? -ne 0 ]; then
  echo "Échec clear-website-cache. Abandon."
  exit 1
fi

