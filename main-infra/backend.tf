terraform {
  backend "s3" {
    endpoints = { s3 = "https://storage.yandexcloud.net" }
    key        = "main-infra/terraform.tfstate"
    region     = "ru-central1"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true   
    skip_s3_checksum            = true  
    use_path_style            = true  
    bucket = "tf-state-bucket-b1g5vo8nokkkedn2241j"
  }
}

