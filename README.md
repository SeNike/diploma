# Дипломная работа
---
## Цели:

1. Подготовить облачную инфраструктуру на базе облачного провайдера Яндекс.Облако.
2. Запустить и сконфигурировать Kubernetes кластер.
3. Установить и настроить систему мониторинга.
4. Настроить и автоматизировать сборку тестового приложения с использованием Docker-контейнеров.
5. Настроить CI для автоматической сборки и тестирования.
6. Настроить CD для автоматического развёртывания приложения.
---
## Этапы выполнения:

1. Создаем сервисный аккаунт, который будет в дальнейшем использоваться Terraform для работы с инфраструктурой с необходимыми и достаточными правами. 
   Подготавливаем для Terraform:  S3 bucket в созданном ЯО аккаунте(создание бакета через TF)

 - Создаем сервисный аккаунт (tf-sa) "Service account for Terraform".
 - Назначаем роли IAM для этого аккаунта:
      Роль editor для управления ресурсами в папке.
      Роль storage.admin для управления объектным хранилищем.
 - Создаем статический ключ доступа для сервисного аккаунта, который используется для аутентификации при работе с Yandex Object Storage.
 - Создаем бакет Object Storage (tf-state-bucket) для хранения состояния Terraform. Ключи доступа (access_key и secret_key) используются для доступа к бакету.
 - Создаем реестр контейнеров (my-nginx-registry) для хранения Docker-образов [Yandex Container Registry](https://cloud.yandex.ru/services/container-registry).

[Код Terraform](https://github.com/SeNike/diploma/tree/main/init-bucket)

2. Подготавливаем облачную инфраструктуру в ЯО при помощи Terraform.
Особенности выполнения:
Для облачного k8s использован региональный мастер(неотказоустойчивый). Для self-hosted k8s минимизированы ресурсы ВМ и долю ЦПУ. Используются прерываемые ВМ для worker nodes.
Предварительная подготовка к установке и запуску Kubernetes кластера.

 - Создаем KMS-ключ для шифрования содержимого бакета.
 - Создаем статический ключ доступа для сервисного аккаунта.
 - Создаем сети и подсетей в трех зонах доступности.
 - Создаем сервисный аккаунта для Kubernetes и назначаем ему роли (editor, k8s.admin, vpc.publicAdmin, kms.encrypterDecrypter).
 - Создаем ключ сервисного аккаунта, который будет использоваться для аутентификации в Kubernetes.
 - Создаем региональный Kubernetes-кластер с мастер-узлами в разных зонах доступности.
 - Создаем группы узлов Kubernetes с автоматическим масштабированием.
 - Генерируем kubeconfig файл для управления кластером через kubectl.
Ресурсы созданы с учетом безопасности, масштабируемости и отказоустойчивости для работы в облачной среде Yandex Cloud.

[Код Terraform](https://github.com/SeNike/diploma/tree/main/main-infra)

Результаты:

 - Terraform сконфигурирован и создание инфраструктуры посредством Terraform возможно без дополнительных ручных действий, стейт основной конфигурации сохраняется в бакете или Terraform Cloud

3. Тестовое приложение.

[Тестовое приложение](https://github.com/SeNike/nginx-static-app)

4. Автоматизированное развертывание инфраструктуры, системы мониторинга и тестового приложения.

Создаем bash-скрипт предназначенный для автоматической инициализации и развертывания инфраструктуры в Yandex Cloud с использованием Terraform, HashiCorp Vault и Kubernetes.

Основные шаги скрипта:
- Получение данных из Terraform state:
   Извлекает ключи доступа (access_key, secret_key), идентификаторы (service_account_id, registry_id, bucket_name) из terraform.tfstate.
- Сохранение секретов в HashiCorp Vault:
   Сохраняет извлеченные значения в Vault для безопасного хранения.
- Чтение значений из файла personal.auto.tfvars:
   Получает значения токена, облака и каталога из переменных token, cloud_id, folder_id.
- Обновление Terraform переменных:
   Обновляет или создает файл personal.auto.tfvars, добавляя или заменяя service_account_id и registry_id.
- Обновление Docker-образа в Kubernetes манифестах:
   Заменяет идентификатор реестра в файле nginx-app.yaml и Jenkinsfile.
- Обновление конфигурации бэкенда Terraform для S3-совместимого хранилища:
   Заменяет имя бакета в backend.tf.
- Инициализация и применение Terraform:
   Выполняет terraform init и terraform apply.
- Развертывание компонентов Kubernetes:
   Устанавливает Grafana, Prometheus, а также приложение nginx из манифеста nginx-app.yaml.
   Ждет создания Custom Resource Definitions (CRD).
- Получение внешних адресов сервисов:
   Получает URL Grafana и nginx-сервиса.

[Скрипт](https://github.com/SeNike/diploma/tree/main/main-infra/init.sh)   

Результат:

1. Работоспособный Kubernetes кластер.
2. В файле `~/.kube/config` находятся данные для доступа к кластеру.
3. Команда `kubectl get pods --all-namespaces` отрабатывает без ошибок.

![Image](https://github.com/SeNike/Study_24/blob/main/Diploma/get_pods.png)

4. Собранный docker image в региcтри [Yandex Container Registry](https://cloud.yandex.ru/services/container-registry).

![Image](https://github.com/SeNike/Study_24/blob/main/Diploma/registry.png)

5. Настроена система мониторинга.  В кластер задеплоины [prometheus](https://prometheus.io/), [grafana](https://grafana.com/), [alertmanager](https://github.com/prometheus/alertmanager), [экспортер](https://github.com/prometheus/node_exporter) основных метрик Kubernetes. Интерфейс Grafana доступен по адресу [http://158.160.176.181](http://158.160.176.181)

![Image](https://github.com/SeNike/Study_24/blob/main/Diploma/kube_grafana.png)

![Image](https://github.com/SeNike/Study_24/blob/main/Diploma/node_grafana.png)

6. Развернуто тестовое приложение. Интерфейс приложения доступен по адресу [http://158.160.171.205](http://158.160.171.205)

![Image](https://github.com/SeNike/Study_24/blob/main/Diploma/app.png)

### Установка и настройка CI/CD

Ожидаемый результат:

1. Интерфейс ci/cd [jenkins](https://www.jenkins.io/) сервиса доступен по http [http://95.161.12.39:8080](http://95.161.12.39:8080).
2. При любом коммите в репозиторие с тестовым приложением происходит сборка и отправка в регистр Docker образа.
3. При создании тега (например, v1.0.0) происходит сборка и отправка с соответствующим label в регистри, а также деплой соответствующего Docker образа в кластер Kubernetes([Jenkinsfile](https://github.com/SeNike/nginx-static-app/blob/main/Jenkinsfile)).

![Image](https://github.com/SeNike/Study_24/blob/main/Diploma/registry.png)

4. Автоматический запуск и применение конфигурации terraform из git-репозитория при любом комите в main ветку ([Jenkinsfile](https://github.com/SeNike/diploma/blob/main/Jenkinsfile)).

![Image](https://github.com/SeNike/Study_24/blob/main/Diploma/jenkins0.png)

## Задание на доработку:

Привести логику работы пайплайна в соответствие с заданием. При запуске для git-тега должна происходить сборка с тегом образа, соответствующим git-тегу, с последующим деплоем, а при запуске пайплайна не из git-тега, просто сборка и отправка в registry latest-образа.

### Доработка

Выполнена доработка файла [Jenkinsfile](https://github.com/SeNike/nginx-static-app/blob/main/Jenkinsfile).

При коммите в refs/tags/* происходит сборка с тегом образа, соответствующим git-тегу, с последующим деплоем.

![Image](https://github.com/SeNike/Study_24/blob/main/Diploma/tag.png)

При коммите в ветку main происходит просто сборка и отправка в registry latest-образа
![Image](https://github.com/SeNike/Study_24/blob/main/Diploma/no-tag.png)

Образы в registry:

![Image](https://github.com/SeNike/Study_24/blob/main/Diploma/registry-latest.png)
