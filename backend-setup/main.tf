resource "yandex_iam_service_account" "tf_sa" {
  name        = "tf-sa"
  description = "Service account for Terraform"
}

resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = var.yc_folder_id
  role      = "editor"
  members   = [
    "serviceAccount:${yandex_iam_service_account.tf_sa.id}"
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "storage_admin" {
  folder_id = var.yc_folder_id
  role      = "storage.admin"
  members   = [
    "serviceAccount:${yandex_iam_service_account.tf_sa.id}"
  ]
}

resource "yandex_iam_service_account_static_access_key" "sa_key" {
  service_account_id = yandex_iam_service_account.tf_sa.id
}

resource "yandex_storage_bucket" "tf_state" {
  bucket     = "tf-state-bucket-${var.yc_folder_id}"
  access_key = yandex_iam_service_account_static_access_key.sa_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa_key.secret_key
}

resource "yandex_container_registry" "my_registry" {
  name = "my-nginx-registry"
}

output "registry_id" {
  value = yandex_container_registry.my_registry.id
}

output "bucket_name" {
  value = yandex_storage_bucket.tf_state.bucket
}

output "access_key" {
  value = yandex_iam_service_account_static_access_key.sa_key.access_key
}

output "secret_key" {
  value     = yandex_iam_service_account_static_access_key.sa_key.secret_key
  sensitive = true
}

output "service_account_id" {
  value = yandex_iam_service_account.tf_sa.id
}