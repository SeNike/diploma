#!/bin/bash

set -e

TFSTATE_FILE="../backend-setup/terraform.tfstate"  # Путь относительно main-infra/
TFVARS_FILE="personal.auto.tfvars"

# Извлекаем значения из tfstate
access_key=$(jq -r '.outputs.access_key.value' "$TFSTATE_FILE")
secret_key=$(jq -r '.outputs.secret_key.value' "$TFSTATE_FILE")
bucket_name=$(jq -r '.outputs.bucket_name.value' "$TFSTATE_FILE")
service_account_id=$(jq -r '.outputs.service_account_id.value' "$TFSTATE_FILE")

# Проверяем наличие всех значений
declare -A required_vars=(
  ["access_key"]=$access_key
  ["secret_key"]=$secret_key
  ["bucket_name"]=$bucket_name
  ["service_account_id"]=$service_account_id
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

# Формируем параметры для terraform init
declare -a backend_config=(
  -backend-config="access_key=$access_key"
  -backend-config="secret_key=$secret_key"
  -backend-config="bucket=$bucket_name"
  #-backend-config="service_account_id=$service_account_id"
)

# Выполняем terraform init
#echo "Initializing Terraform with:"
#printf "  %s\n" "${backend_config[@]}"
terraform init "${backend_config[@]}"
terraform apply -auto-approve