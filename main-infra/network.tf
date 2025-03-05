resource "yandex_vpc_network" "main" {
  name = "main-network"
}

resource "yandex_vpc_subnet" "subnets" {
  count          = 3
  name           = "subnet-${count.index}"
  zone           = "ru-central1-${element(["a", "b", "d"], count.index)}"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.${count.index}.0/24"]
}