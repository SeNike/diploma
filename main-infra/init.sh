#!/bin/bash

set -e

TFSTATE_FILE="../init-bucket/terraform.tfstate"  # Путь относительно main-infra/
TFVARS_FILE="personal.auto.tfvars"

# Извлекаем значения из tfstate
access_key=$(jq -r '.outputs.access_key.value' "$TFSTATE_FILE")
secret_key=$(jq -r '.outputs.secret_key.value' "$TFSTATE_FILE")
bucket_name=$(jq -r '.outputs.bucket_name.value' "$TFSTATE_FILE")
service_account_id=$(jq -r '.outputs.service_account_id.value' "$TFSTATE_FILE")
registry_id=$(jq -r '.outputs.registry_id.value' "$TFSTATE_FILE")

docker run --network=host -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="education" vault:1.13.3 sh -c "vault kv put secret/access_key value=$access_key"
docker run --network=host -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="education" vault:1.13.3 sh -c "vault kv put secret/secret_key value=$secret_key"

docker run --network=host -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="education" vault:1.13.3 sh -c "vault kv put secret/service_account_id value=$service_account_id"
docker run --network=host -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="education" vault:1.13.3 sh -c "vault kv put secret/registry_id value=$registry_id"

# Функция для извлечения значения по ключу из файла
get_key_value() {
    local key_name="$1"
    grep -E "^[[:space:]]*${key_name}[[:space:]]*=" personal.auto.tfvars | \
    sed -E 's/^[^=]*=[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/' | \
    head -n 1
}
# Извлекаем значения
token=$(get_key_value "token")
cloud_id=$(get_key_value "cloud_id")
folder_id=$(get_key_value "folder_id")

docker run --network=host -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="education" vault:1.13.3 sh -c "vault kv put secret/token value=$token"
docker run --network=host -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="education" vault:1.13.3 sh -c "vault kv put secret/cloud_id value=$cloud_id"
docker run --network=host -e VAULT_ADDR="http://127.0.0.1:8200" -e VAULT_TOKEN="education" vault:1.13.3 sh -c "vault kv put secret/folder_id value=$folder_id"

# Проверяем наличие всех значений
declare -A required_vars=(
  ["access_key"]=$access_key
  ["secret_key"]=$secret_key
  ["bucket_name"]=$bucket_name
  ["service_account_id"]=$service_account_id
  ["registry_id"]=$registry_id
)

for var in "${!required_vars[@]}"; do
  if [[ -z "${required_vars[$var]}" ]]; then
    echo "Error: Missing $var in Terraform state"
    exit 1
  fi
done

# Обновляем personal.auto.tfvars
if [[ -f "$TFVARS_FILE" ]]; then
  # Обновляем существующее значение
  sed -i.bak \
    -E "s/(service_account_id[[:space:]]*=[[:space:]]*).*/\1\"${service_account_id}\"/" \
    "$TFVARS_FILE"
  rm -f "${TFVARS_FILE}.bak"
else
  # Создаём новый файл если не существует
  echo "service_account_id = \"${service_account_id}\"" > "$TFVARS_FILE"
fi

# Обновляем personal.auto.tfvars
if [[ -f "$TFVARS_FILE" ]]; then
  # Обновляем существующее значение
  sed -i.bak \
    -E "s/(registry_id[[:space:]]*=[[:space:]]*).*/\1\"${registry_id}\"/" \
    "$TFVARS_FILE"
  rm -f "${TFVARS_FILE}.bak"
else
  # Создаём новый файл если не существует
  echo "registry_id = \"${registry_id}\"" > "$TFVARS_FILE"
fi

sed -i.bak "s|image: cr\.yandex/[^/]*/nginx-static-app:latest|image: cr.yandex/${registry_id}/nginx-static-app:latest|" ../../Diploma_dep/nginx-static-app/nginx-app.yaml

sed -i -E "/REGISTRY[[:space:]]*=[[:space:]]*\"cr\.yandex\//s/\/[^\"]*/\/$registry_id/" ../../Diploma_dep/nginx-static-app/Jenkinsfile

sed -i -E "s/(bucket[[:space:]]*=[[:space:]]*).*/\1\"${bucket_name}\"/" backend.tf

# Формируем параметры для terraform init
declare -a backend_config=(-backend-config="access_key=$access_key" -backend-config="secret_key=$secret_key")
# Выполняем terraform init
terraform init "${backend_config[@]}"
terraform apply -auto-approve
kubectl apply --server-side -f ../kube-prometheus/manifests/setup
kubectl wait --for condition=Established --all CustomResourceDefinition --namespace=monitoring
kubectl apply -f ../kube-prometheus/manifests/
kubectl apply -f ../apps/grafana-service.yaml
kubectl apply -f ../../Diploma_dep/nginx-static-app/nginx-app.yaml

kubectl create -f https://github.com/grafana/grafana-operator/releases/latest/download/kustomize-namespace_scoped.yaml
kubectl apply -f ../apps/manifests/sample.yaml 
# Получить внешние адреса
sleep 20
kubectl get svc -n monitoring grafana-external
kubectl get svc nginx-service
