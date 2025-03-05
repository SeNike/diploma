terraform {
  backend "s3" {
    endpoints = { s3 = "https://storage.yandexcloud.net" }
    #bucket     = ""
    key        = "main-infra/terraform.tfstate"
    region     = "ru-central1"
    #access_key = ""
    #secret_key = ""
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true   
    skip_s3_checksum            = true  
    force_path_style            = true  
  }
}

