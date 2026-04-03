terraform {
  required_version = ">= 1.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.95"
    }
  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_default_zone
}

# ============================================================
# Сеть (VPC)
# ============================================================

resource "yandex_vpc_network" "main" {
  name        = "future20-network"
  description = "Основная сеть экосистемы «Будущее 2.0»"
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name = "future20-nat-gw"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "private_rt" {
  name       = "private-route-table"
  network_id = yandex_vpc_network.main.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

# Публичная подсеть — API Gateway, балансировщики, бастион
resource "yandex_vpc_subnet" "public" {
  name           = "public-subnet"
  zone           = var.yc_default_zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.1.0.0/24"]
}

# Приватная подсеть — доменные сервисы
resource "yandex_vpc_subnet" "private_apps" {
  name           = "private-apps-subnet"
  zone           = var.yc_default_zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.2.0.0/24"]
  route_table_id = yandex_vpc_route_table.private_rt.id
}

# Приватная подсеть — базы данных и хранилища
resource "yandex_vpc_subnet" "private_data" {
  name           = "private-data-subnet"
  zone           = var.yc_default_zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.3.0.0/24"]
  route_table_id = yandex_vpc_route_table.private_rt.id
}

# Дополнительная подсеть в другой зоне для отказоустойчивости
resource "yandex_vpc_subnet" "private_data_b" {
  name           = "private-data-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.4.0.0/24"]
  route_table_id = yandex_vpc_route_table.private_rt.id
}

# ============================================================
# Security Groups
# ============================================================

resource "yandex_vpc_security_group" "public_sg" {
  name       = "public-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "HTTPS from internet"
  }

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "HTTP from internet (redirect to HTTPS)"
  }

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.admin_cidr]
    description    = "SSH from admin network"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow all outbound"
  }
}

resource "yandex_vpc_security_group" "apps_sg" {
  name       = "apps-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol          = "TCP"
    port              = 8080
    predefined_target = "self_security_group"
    description       = "App-to-app communication"
  }

  ingress {
    protocol       = "TCP"
    port           = 8080
    v4_cidr_blocks = ["10.1.0.0/24"]
    description    = "From public subnet (API Gateway)"
  }

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["10.1.0.0/24"]
    description    = "SSH from bastion"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow all outbound"
  }
}

resource "yandex_vpc_security_group" "data_sg" {
  name       = "data-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 5432
    v4_cidr_blocks = ["10.2.0.0/24"]
    description    = "PostgreSQL from apps subnet"
  }

  ingress {
    protocol       = "TCP"
    port           = 8443
    v4_cidr_blocks = ["10.2.0.0/24"]
    description    = "ClickHouse from apps subnet"
  }

  ingress {
    protocol       = "TCP"
    port           = 9091
    v4_cidr_blocks = ["10.2.0.0/24"]
    description    = "Kafka from apps subnet"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow all outbound"
  }
}

# ============================================================
# Сервисный аккаунт
# ============================================================

resource "yandex_iam_service_account" "sa" {
  name        = "future20-sa"
  description = "Сервисный аккаунт для управления ресурсами"
}

resource "yandex_resourcemanager_folder_iam_member" "sa_editor" {
  folder_id = var.yc_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa_storage_admin" {
  folder_id = var.yc_folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "sa_key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "Static access key for S3"
}

# ============================================================
# Object Storage (Data Lake)
# ============================================================

resource "yandex_storage_bucket" "datalake_raw" {
  bucket     = "${var.project_prefix}-datalake-raw"
  access_key = yandex_iam_service_account_static_access_key.sa_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa_key.secret_key

  versioning {
    enabled = true
  }

  lifecycle_rule {
    enabled = true
    transition {
      days          = 90
      storage_class = "COLD"
    }
  }

  depends_on = [yandex_resourcemanager_folder_iam_member.sa_storage_admin]
}

resource "yandex_storage_bucket" "datalake_curated" {
  bucket     = "${var.project_prefix}-datalake-curated"
  access_key = yandex_iam_service_account_static_access_key.sa_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa_key.secret_key

  versioning {
    enabled = true
  }

  depends_on = [yandex_resourcemanager_folder_iam_member.sa_storage_admin]
}

# ============================================================
# Виртуальные машины
# ============================================================

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# Бастион-хост (публичная подсеть)
resource "yandex_compute_instance" "bastion" {
  name        = "bastion"
  platform_id = "standard-v3"
  zone        = var.yc_default_zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.public_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# API Gateway / Reverse Proxy
resource "yandex_compute_instance" "api_gateway" {
  name        = "api-gateway"
  platform_id = "standard-v3"
  zone        = var.yc_default_zone

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 15
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.public_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# Портал самообслуживания + BI
resource "yandex_compute_instance" "portal" {
  name        = "portal-server"
  platform_id = "standard-v3"
  zone        = var.yc_default_zone

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 15
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_apps.id
    security_group_ids = [yandex_vpc_security_group.apps_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# Сервер Keycloak (IAM/SSO)
resource "yandex_compute_instance" "keycloak" {
  name        = "keycloak"
  platform_id = "standard-v3"
  zone        = var.yc_default_zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_apps.id
    security_group_ids = [yandex_vpc_security_group.apps_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# Сервер ETL (Airflow)
resource "yandex_compute_instance" "airflow" {
  name        = "airflow"
  platform_id = "standard-v3"
  zone        = var.yc_default_zone

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_apps.id
    security_group_ids = [yandex_vpc_security_group.apps_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# ============================================================
# Managed PostgreSQL (домен Клиники)
# ============================================================

resource "yandex_mdb_postgresql_cluster" "clinic_db" {
  name        = "clinic-pg-cluster"
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.main.id

  config {
    version = 16
    resources {
      resource_preset_id = var.pg_resource_preset
      disk_type_id       = "network-ssd"
      disk_size          = var.pg_disk_size
    }
  }

  host {
    zone             = var.yc_default_zone
    subnet_id        = yandex_vpc_subnet.private_data.id
    assign_public_ip = false
  }

  host {
    zone             = "ru-central1-b"
    subnet_id        = yandex_vpc_subnet.private_data_b.id
    assign_public_ip = false
  }

  security_group_ids = [yandex_vpc_security_group.data_sg.id]
}

resource "yandex_mdb_postgresql_database" "clinic_database" {
  cluster_id = yandex_mdb_postgresql_cluster.clinic_db.id
  name       = "clinic"
  owner      = yandex_mdb_postgresql_user.clinic_user.name
}

resource "yandex_mdb_postgresql_user" "clinic_user" {
  cluster_id = yandex_mdb_postgresql_cluster.clinic_db.id
  name       = "clinic_app"
  password   = var.pg_password
}

# ============================================================
# Managed PostgreSQL (домен Финтех)
# ============================================================

resource "yandex_mdb_postgresql_cluster" "fintech_db" {
  name        = "fintech-pg-cluster"
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.main.id

  config {
    version = 16
    resources {
      resource_preset_id = var.pg_resource_preset
      disk_type_id       = "network-ssd"
      disk_size          = var.pg_disk_size
    }
  }

  host {
    zone             = var.yc_default_zone
    subnet_id        = yandex_vpc_subnet.private_data.id
    assign_public_ip = false
  }

  host {
    zone             = "ru-central1-b"
    subnet_id        = yandex_vpc_subnet.private_data_b.id
    assign_public_ip = false
  }

  security_group_ids = [yandex_vpc_security_group.data_sg.id]
}

resource "yandex_mdb_postgresql_database" "fintech_database" {
  cluster_id = yandex_mdb_postgresql_cluster.fintech_db.id
  name       = "fintech"
  owner      = yandex_mdb_postgresql_user.fintech_user.name
}

resource "yandex_mdb_postgresql_user" "fintech_user" {
  cluster_id = yandex_mdb_postgresql_cluster.fintech_db.id
  name       = "fintech_app"
  password   = var.pg_password
}

# ============================================================
# Managed Kafka (событийная шина)
# ============================================================

resource "yandex_mdb_kafka_cluster" "events" {
  name        = "future20-kafka"
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.main.id

  config {
    version          = "3.7"
    brokers_count    = 1
    zones            = [var.yc_default_zone]
    assign_public_ip = false

    kafka {
      resources {
        resource_preset_id = var.kafka_resource_preset
        disk_type_id       = "network-hdd"
        disk_size          = var.kafka_disk_size
      }
    }
  }

  subnet_ids         = [yandex_vpc_subnet.private_data.id]
  security_group_ids = [yandex_vpc_security_group.data_sg.id]
}

resource "yandex_mdb_kafka_topic" "clinic_events" {
  cluster_id         = yandex_mdb_kafka_cluster.events.id
  name               = "clinic.events"
  partitions         = 3
  replication_factor = 1
}

resource "yandex_mdb_kafka_topic" "fintech_events" {
  cluster_id         = yandex_mdb_kafka_cluster.events.id
  name               = "fintech.events"
  partitions         = 3
  replication_factor = 1
}

resource "yandex_mdb_kafka_topic" "ai_events" {
  cluster_id         = yandex_mdb_kafka_cluster.events.id
  name               = "ai.events"
  partitions         = 3
  replication_factor = 1
}

# ============================================================
# Managed ClickHouse (аналитическое хранилище)
# ============================================================

resource "yandex_mdb_clickhouse_cluster" "analytics" {
  name        = "future20-clickhouse"
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.main.id

  clickhouse {
    resources {
      resource_preset_id = var.ch_resource_preset
      disk_type_id       = "network-hdd"
      disk_size          = var.ch_disk_size
    }
  }

  host {
    type      = "CLICKHOUSE"
    zone      = var.yc_default_zone
    subnet_id = yandex_vpc_subnet.private_data.id
  }

  security_group_ids = [yandex_vpc_security_group.data_sg.id]
}

resource "yandex_mdb_clickhouse_database" "analytics" {
  cluster_id = yandex_mdb_clickhouse_cluster.analytics.id
  name       = "analytics"
}

resource "yandex_mdb_clickhouse_user" "analytics_app" {
  cluster_id = yandex_mdb_clickhouse_cluster.analytics.id
  name       = "analytics_app"
  password   = var.ch_password

  permission {
    database_name = yandex_mdb_clickhouse_database.analytics.name
  }
}
