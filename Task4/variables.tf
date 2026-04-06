# ============================================================
# Yandex Cloud — общие параметры
# ============================================================

variable "yc_token" {
  description = "OAuth-токен или IAM-токен для Yandex Cloud"
  type        = string
  sensitive   = true
}

variable "yc_cloud_id" {
  description = "ID облака в Yandex Cloud"
  type        = string
}

variable "yc_folder_id" {
  description = "ID каталога (folder) в Yandex Cloud"
  type        = string
}

variable "yc_default_zone" {
  description = "Зона доступности по умолчанию"
  type        = string
  default     = "ru-central1-a"
}

variable "project_prefix" {
  description = "Префикс для именования ресурсов"
  type        = string
  default     = "future20"
}

# ============================================================
# SSH и доступ
# ============================================================

variable "ssh_public_key" {
  description = "Публичный SSH-ключ для доступа к VM"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR-блок для SSH-доступа к бастиону (IP администратора)"
  type        = string
  default     = "0.0.0.0/0"
}

# ============================================================
# PostgreSQL
# ============================================================

variable "pg_resource_preset" {
  description = "Класс ресурсов для PostgreSQL (CPU + RAM)"
  type        = string
  default     = "s2.micro"
}

variable "pg_disk_size" {
  description = "Размер диска PostgreSQL (ГБ)"
  type        = number
  default     = 50
}

variable "pg_password" {
  description = "Пароль пользователя БД PostgreSQL"
  type        = string
  sensitive   = true
}

# ============================================================
# Kafka
# ============================================================

variable "kafka_brokers_count" {
  description = "Количество брокеров Kafka"
  type        = number
  default     = 1
}

variable "kafka_resource_preset" {
  description = "Класс ресурсов для Kafka-брокеров"
  type        = string
  default     = "s2.micro"
}

variable "kafka_disk_size" {
  description = "Размер диска каждого Kafka-брокера (ГБ)"
  type        = number
  default     = 32
}

# ============================================================
# ClickHouse
# ============================================================

variable "ch_resource_preset" {
  description = "Класс ресурсов для ClickHouse"
  type        = string
  default     = "s2.micro"
}

variable "ch_disk_size" {
  description = "Размер диска ClickHouse (ГБ)"
  type        = number
  default     = 32
}

variable "ch_password" {
  description = "Пароль пользователя ClickHouse"
  type        = string
  sensitive   = true
}
