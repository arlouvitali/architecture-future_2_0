# Диаграмма автоматизации развёртывания

## Описание

Диаграмма показывает все компоненты инфраструктуры «Будущее 2.0» в Yandex Cloud и способ их управления. Компоненты, управляемые Terraform, отмечены зелёным. Компоненты, разворачиваемые вручную или через CI/CD поверх инфраструктуры, отмечены оранжевым.

## Компонентная схема

📎 **[deployment_diagram.drawio](deployment_diagram.drawio)** 

Диаграмма содержит две основные зоны:

- **🟢 Управляется Terraform** — ресурсы, декларативно описанные в `main.tf`
- **🟠 Разворачивается вручную / CI/CD** — приложения, контейнеры и пайплайны

Связи между зонами:
- **Оранжевые пунктирные стрелки** — развёртывание приложения на VM (Docker / CI/CD)
- **Синие пунктирные стрелки** — доступ к данным (приложение → managed-сервис)
- **Сплошные стрелки** — структурные зависимости ресурсов (Kafka → Topics)

## Сводная таблица компонентов

### Компоненты, управляемые Terraform (IaC)

| Компонент | Ресурс Terraform | Назначение |
|---|---|---|
| VPC Network | `yandex_vpc_network` | Изолированная сеть для всей инфраструктуры |
| Подсети (4 шт.) | `yandex_vpc_subnet` | Сегментация: публичная, приложения, данные (2 зоны) |
| NAT Gateway | `yandex_vpc_gateway` | Выход в интернет для приватных подсетей |
| Route Table | `yandex_vpc_route_table` | Маршрутизация трафика через NAT |
| Security Groups (3 шт.) | `yandex_vpc_security_group` | Правила файрвола для каждого сегмента |
| VM: Bastion (2 vCPU / 2 GB / 10 GB HDD) | `yandex_compute_instance` | SSH-доступ к приватным ресурсам |
| VM: API Gateway (2 vCPU / 4 GB / 15 GB HDD) | `yandex_compute_instance` | Reverse proxy, маршрутизация запросов |
| VM: Portal + BI (2 vCPU / 4 GB / 15 GB HDD) | `yandex_compute_instance` | Портал самообслуживания и Superset |
| VM: Keycloak (2 vCPU / 2 GB / 10 GB HDD) | `yandex_compute_instance` | IAM/SSO сервер |
| VM: Airflow (2 vCPU / 4 GB / 20 GB HDD) | `yandex_compute_instance` | Оркестрация ETL-пайплайнов |
| PostgreSQL Клиники (2 хоста, 50 GB SSD) | `yandex_mdb_postgresql_cluster` | Операционная БД домена клиник |
| PostgreSQL Финтех (2 хоста, 50 GB SSD) | `yandex_mdb_postgresql_cluster` | Операционная БД домена финтех |
| ClickHouse (1 хост, 32 GB HDD) | `yandex_mdb_clickhouse_cluster` | Аналитическое хранилище |
| Kafka (1 брокер, 32 GB HDD, v3.7) | `yandex_mdb_kafka_cluster` | Событийная шина |
| Kafka Topics (3 шт.) | `yandex_mdb_kafka_topic` | Топики для доменных событий |
| S3 Buckets (2 шт.) | `yandex_storage_bucket` | Data Lake (raw + curated) |
| Service Account | `yandex_iam_service_account` | Аутентификация для S3 |

### Компоненты, разворачиваемые вручную / через CI/CD

| Компонент | Среда выполнения | Способ развёртывания |
|---|---|---|
| Kong API Gateway | Docker на VM api-gateway | Docker Compose / CI/CD |
| Keycloak Application | Docker на VM keycloak | Docker Compose / CI/CD |
| Apache Superset | Docker на VM portal-server | Docker Compose / CI/CD |
| React Portal App | Docker на VM portal-server | CI/CD (GitLab CI) |
| Apache Airflow | Docker на VM airflow | Docker Compose / CI/CD |
| dbt Models | Airflow scheduler | CI/CD (GitLab CI) |
| Clinic Services | Docker на VM (или K8s в будущем) | CI/CD |
| FinTech Services | Docker на VM (или K8s в будущем) | CI/CD |
| AI Services | Docker на GPU VM | CI/CD |
