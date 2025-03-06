# 1. Создание KMS-ключа для бакета
# Этот ресурс создает симметричный ключ KMS, который будет использоваться для шифрования содержимого бакета.
resource "yandex_kms_symmetric_key" "bucket_key" {
  name              = "bucket-encryption-key"
  description       = "KMS key for encrypting bucket content"
  default_algorithm = "AES_256"
  rotation_period   = "8760h" # 365 дней
}

# 2. Создание статического ключа доступа
# Этот ресурс создает статический ключ доступа для сервисного аккаунта, который будет использоваться для доступа к объектному хранилищу.
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = var.service_account_id
  description        = "static access key for object storage"
}

# 3. Сеть и подсети
# Этот ресурс создает виртуальную частную сеть (VPC) и подсети в разных зонах доступности.
resource "yandex_vpc_network" "network" {
  name = "network"
}

# Создание публичных подсетей в трех зонах доступности.
resource "yandex_vpc_subnet" "public_subnets" {
  count = 3

  name           = "public-subnet-${count.index}"
  zone           = "ru-central1-${element(["a", "b", "d"], count.index)}"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = [cidrsubnet("10.1.0.0/16", 8, count.index)]
}

# Создание приватных подсетей в трех зонах доступности.
resource "yandex_vpc_subnet" "private_subnets" {
  count = 3

  name           = "private-subnet-${count.index}"
  zone           = "ru-central1-${element(["a", "b", "d"], count.index)}"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = [cidrsubnet("10.2.0.0/16", 8, count.index)]
}

# 7. Сервисный аккаунт для Kubernetes
# Этот ресурс создает сервисный аккаунт для Kubernetes и назначает ему необходимые роли.
resource "yandex_iam_service_account" "k8s_sa" {
  name        = "k8s-service-account"
  description = "Service account for Kubernetes cluster"
}

# Назначение роли "editor" сервисному аккаунту.
resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = var.folder_id
  role      = "editor"
  members   = ["serviceAccount:${yandex_iam_service_account.k8s_sa.id}"]
}

# Назначение роли "k8s.clusters.agent" сервисному аккаунту.
resource "yandex_resourcemanager_folder_iam_binding" "k8s_agent" {
  folder_id = var.folder_id
  role      = "k8s.clusters.agent"
  members   = ["serviceAccount:${yandex_iam_service_account.k8s_sa.id}"]
}

# Назначение роли "vpc.publicAdmin" сервисному аккаунту.
resource "yandex_resourcemanager_folder_iam_binding" "vpc_admin" {
  folder_id = var.folder_id
  role      = "vpc.publicAdmin"
  members   = ["serviceAccount:${yandex_iam_service_account.k8s_sa.id}"]
}

# Назначение роли "kms.keys.encrypterDecrypter" сервисному аккаунту.
resource "yandex_resourcemanager_folder_iam_binding" "kms_access" {
  folder_id = var.folder_id
  role      = "kms.keys.encrypterDecrypter"
  members   = ["serviceAccount:${yandex_iam_service_account.k8s_sa.id}"]
}

# Назначение роли "k8s.admin" сервисному аккаунту.
resource "yandex_resourcemanager_folder_iam_binding" "k8s_admin" {
  folder_id = var.folder_id
  role      = "k8s.admin"
  members   = [
    "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
  ]
}

# 8. Создаем ключ сервисного аккаунта
# Этот ресурс создает ключ для сервисного аккаунта, который будет использоваться для аутентификации в Kubernetes.
resource "yandex_iam_service_account_key" "k8s_sa_key" {
  service_account_id = yandex_iam_service_account.k8s_sa.id
  description        = "K8S SA key for Terraform"
  key_algorithm      = "RSA_4096"
}

# 9. Кластер Kubernetes
# Этот ресурс создает региональный кластер Kubernetes с мастер-узлами в разных зонах доступности.
resource "yandex_kubernetes_cluster" "regional_cluster" {
  name        = "regional-k8s-cluster"
  description = "Regional Kubernetes cluster"
  network_id  = yandex_vpc_network.network.id

  master {
    regional {
      region = "ru-central1"
      dynamic "location" {
        for_each = yandex_vpc_subnet.public_subnets
        content {
          zone      = location.value.zone
          subnet_id = location.value.id
        }
      }
    }
    version   = "1.31"
    public_ip = true

    maintenance_policy {
      auto_upgrade = true
      maintenance_window {
        start_time = "03:00"
        duration   = "3h"
      }
    }
  }

  service_account_id      = yandex_iam_service_account.k8s_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_sa.id
  kms_provider {
    key_id = yandex_kms_symmetric_key.bucket_key.id
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_binding.editor,
    yandex_resourcemanager_folder_iam_binding.k8s_agent,
    yandex_resourcemanager_folder_iam_binding.vpc_admin,
    yandex_resourcemanager_folder_iam_binding.kms_access
  ]
}

# 10. Группы узлов Kubernetes
# Этот ресурс создает группы узлов Kubernetes с автоматическим масштабированием в разных зонах доступности.
resource "yandex_kubernetes_node_group" "node_groups" {
  for_each = {
    a = 0
    b = 1
    d = 2 
  }

  cluster_id = yandex_kubernetes_cluster.regional_cluster.id
  name       = "autoscaling-node-group-${each.key}"

  instance_template {
    platform_id = "standard-v2"
    resources {
      cores  = 2
      memory = 4
    }

    boot_disk {
      type = "network-ssd"
      size = 64
    }

    network_interface {
      subnet_ids = [yandex_vpc_subnet.public_subnets[each.value].id]
      nat        = true
    }
  }

  scale_policy {
    auto_scale {
      min     = 1
      max     = 2
      initial = 1
    }
  }

  allocation_policy {
    location {
      zone = yandex_vpc_subnet.public_subnets[each.value].zone
    }
  }

  depends_on = [yandex_kubernetes_cluster.regional_cluster]
}

# 11. Настройка kubectl
# Этот ресурс создает директорию для конфигурации kubectl и генерирует kubeconfig файл.
resource "null_resource" "create_kube_dir" {
  provisioner "local-exec" {
    command = "mkdir -p /home/se/.kube && chmod 700 /home/se/.kube"
  }
}

provider "local" {}

resource "local_file" "kubeconfig" {
  filename        = "/home/se/.kube/config"
  content         = templatefile("${path.module}/kubeconfig.tpl", {
    endpoint       = yandex_kubernetes_cluster.regional_cluster.master[0].external_v4_endpoint
    cluster_ca     = base64encode(yandex_kubernetes_cluster.regional_cluster.master[0].cluster_ca_certificate)
    k8s_cluster_id = yandex_kubernetes_cluster.regional_cluster.id
  })
  file_permission = "0644"  # Права на чтение для всех, запись для владельца
}

locals {
  kubeconfig = {
    apiVersion      = "v1"
    kind           = "Config"
    current-context = "yandex-cloud"
    contexts = [{
      name = "yandex-cloud"
      context = {
        cluster = "yc-cluster"
        user    = "yc-user"
      }
    }]
    clusters = [{
      name = "yc-cluster"
      cluster = {
        server                   = yandex_kubernetes_cluster.regional_cluster.master[0].external_v4_endpoint
        certificate-authority-data = base64encode(yandex_kubernetes_cluster.regional_cluster.master[0].cluster_ca_certificate)
      }
    }]
    users = [{
      name = "yc-user"
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "yc"
          args = [
            "k8s",
            "create-token",
            "--profile=default",
            "--format=json"
          ]
        }
      }
    }]
  }
}

# 12. Настраиваем провайдер Kubernetes
# Этот блок настраивает провайдер Kubernetes для работы с созданным кластером.
provider "kubernetes" {
  host = yandex_kubernetes_cluster.regional_cluster.master[0].external_v4_endpoint
  cluster_ca_certificate = yandex_kubernetes_cluster.regional_cluster.master[0].cluster_ca_certificate
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "yc"
    args = [
      "k8s",
      "create-token",
      "--profile=default",
      "--format=json"
    ]
  }
}

resource "time_sleep" "wait_for_cluster" {
  create_duration = "300s" # Увеличено время ожидания
  depends_on      = [yandex_kubernetes_cluster.regional_cluster]
}

# 13. Приложение nginx-static-app
# Этот ресурс создает deployment и service для приложения nginx-static-app, которое подключается к кластеру MySQL.
resource "kubernetes_deployment" "nginx-static-app" {
  depends_on = [
    time_sleep.wait_for_cluster,
    #yandex_mdb_mysql_cluster.mysql_cluster,
    yandex_kubernetes_node_group.node_groups["a"]
  ]

  metadata {
    name = "nginx-static-app"
    labels = {
      app = "nginx-static-app"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginx-static-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-static-app"
        }
      }

      spec {
        container {
          name  = "nginx-static-app"
          image = "cr.yandex/${var.registry_id}/nginx-static-app:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx-static-app" {
  metadata {
    name = "nginx-static-app-service"
  }

  spec {
    selector = {
      app = kubernetes_deployment.nginx-static-app.metadata[0].labels.app
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }

  depends_on = [kubernetes_deployment.nginx-static-app]
}