output "network_id" {
  description = "ID основной VPC-сети"
  value       = yandex_vpc_network.main.id
}

output "public_subnet_id" {
  description = "ID публичной подсети"
  value       = yandex_vpc_subnet.public.id
}

output "private_apps_subnet_id" {
  description = "ID приватной подсети приложений"
  value       = yandex_vpc_subnet.private_apps.id
}

output "private_data_subnet_id" {
  description = "ID приватной подсети данных"
  value       = yandex_vpc_subnet.private_data.id
}

output "bastion_public_ip" {
  description = "Публичный IP бастион-хоста для SSH-доступа"
  value       = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
}

output "api_gateway_public_ip" {
  description = "Публичный IP API Gateway"
  value       = yandex_compute_instance.api_gateway.network_interface[0].nat_ip_address
}

output "portal_internal_ip" {
  description = "Внутренний IP сервера портала самообслуживания"
  value       = yandex_compute_instance.portal.network_interface[0].ip_address
}

output "keycloak_internal_ip" {
  description = "Внутренний IP сервера Keycloak (IAM)"
  value       = yandex_compute_instance.keycloak.network_interface[0].ip_address
}

output "airflow_internal_ip" {
  description = "Внутренний IP сервера Airflow (ETL)"
  value       = yandex_compute_instance.airflow.network_interface[0].ip_address
}

output "clinic_pg_host" {
  description = "Хост кластера PostgreSQL домена Клиники"
  value       = yandex_mdb_postgresql_cluster.clinic_db.host[0].fqdn
}

output "fintech_pg_host" {
  description = "Хост кластера PostgreSQL домена Финтех"
  value       = yandex_mdb_postgresql_cluster.fintech_db.host[0].fqdn
}

output "kafka_cluster_id" {
  description = "ID кластера Managed Kafka"
  value       = yandex_mdb_kafka_cluster.events.id
}

output "clickhouse_host" {
  description = "Хост кластера ClickHouse (аналитическое хранилище)"
  value       = yandex_mdb_clickhouse_cluster.analytics.host[0].fqdn
}

output "datalake_raw_bucket" {
  description = "Имя S3-бакета Data Lake (сырые данные)"
  value       = yandex_storage_bucket.datalake_raw.bucket
}

output "datalake_curated_bucket" {
  description = "Имя S3-бакета Data Lake (обработанные данные)"
  value       = yandex_storage_bucket.datalake_curated.bucket
}
