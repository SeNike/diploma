resource "yandex_kubernetes_cluster" "k8s_cluster" {
  name        = "my-k8s-cluster"
  description = "Non-HA K8s cluster"

  network_id = yandex_vpc_network.main.id

  master {
    zonal {
      zone      = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.subnets[0].id
    }
    public_ip = true
    version   = "1.31"
  }

  service_account_id      = var.service_account_id
  node_service_account_id = var.service_account_id
}

resource "yandex_kubernetes_node_group" "preemptible_nodes" {
  cluster_id = yandex_kubernetes_cluster.k8s_cluster.id
  name       = "preemptible-workers"

  instance_template {
    platform_id = "standard-v2"
    resources {
      cores  = 2
      memory = 2
    }

    scheduling_policy {
      preemptible = true
    }

    network_interface {
      subnet_ids = yandex_vpc_subnet.subnets[*].id
      nat        = true
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }
}