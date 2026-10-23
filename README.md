Контейнеризований REST API застосунок на Flask, розгорнутий у хмарі AWS з використанням Docker, Terraform та CI/CD.

**Public Address:**
`http://clouds-lab-alb-132014376.eu-north-1.elb.amazonaws.com`

**Health:**
`http://clouds-lab-alb-132014376.eu-north-1.elb.amazonaws.com/health`


## Структура проекту

```text
bd_lab_4/
│
├── .github/
│   └── workflows/
│       └── deploy.yml               # CI/CD: GitHub Actions → ECR → ECS
│
├── db/
│   └── 01_schema.sql                # SQL-схема локальної MySQL
│
├── project/
│   ├── config/
│   │   └── app.yml                  # Конфігурація Flask-застосунку
│   │
│   └── my_project/
│       ├── __init__.py
│       │
│       ├── auth/
│       │   ├── dao/                 # Доступ до бази даних
│       │   │   ├── athlete_dao.py
│       │   │   ├── competition_dao.py
│       │   │   ├── procedure_dao.py
│       │   │   └── sport_dao.py
│       │   │
│       │   ├── domain/              # Моделі SQLAlchemy та DTO
│       │   │   ├── athlete.py
│       │   │   ├── athlete_dto.py
│       │   │   ├── competition.py
│       │   │   ├── competition_dto.py
│       │   │   ├── procedure_dto.py
│       │   │   ├── sport.py
│       │   │   └── sport_dto.py
│       │   │
│       │   ├── route/               # REST API та JWT-автентифікація
│       │   │   ├── athlete_route.py
│       │   │   ├── auth_route.py
│       │   │   ├── competition_route.py
│       │   │   ├── procedure_route.py
│       │   │   └── sport_route.py
│       │   │
│       │   └── service/             # Бізнес-логіка застосунку
│       │       ├── athlete_service.py
│       │       ├── competition_service.py
│       │       ├── procedure_service.py
│       │       └── sport_service.py
│       │
│       └── utils/
│           └── db_init.py           # Ініціалізація Flask-SQLAlchemy
│
├── terraform/                       # Інфраструктура AWS (IaC)
│   ├── .terraform.lock.hcl          # Зафіксовані версії провайдерів
│   ├── alb.tf                       # Application Load Balancer
│   ├── database.tf                  # Amazon RDS MySQL
│   ├── ecr.tf                       # Elastic Container Registry
│   ├── ecs.tf                       # ECS Fargate, задачі та сервіси
│   ├── github.tf                    # GitHub OIDC та IAM-роль CI/CD
│   ├── iam.tf                       # IAM-ролі та політики доступу
│   ├── monitoring.tf                # CloudWatch, SNS та AWS Budget
│   ├── network.tf                   # VPC, Subnets, NAT Gateway, Routes
│   ├── outputs.tf                   # Адреси та ідентифікатори AWS
│   ├── secrets.tf                   # AWS Secrets Manager
│   ├── security.tf                  # Security Groups і правила доступу
│   ├── terraform.tfvars.example     # Приклад параметрів AWS
│   ├── variables.tf                 # Вхідні змінні Terraform
│   └── versions.tf                  # Версії Terraform та провайдерів
│
├── .dockerignore                    # Файли, виключені з Docker-образу
├── .env.example                     # Приклад змінних середовища
├── .gitignore                       # Файли, виключені з Git
├── app.py                           # Flask Application Factory
├── compose.yaml                     # Локальні контейнери API + MySQL
├── Dockerfile                       # Docker-образ Flask API
├── README.md                        # Документація проєкту
├── requirements.txt                 # Python-залежності
└── test.http                        # Тестові HTTP-запити до API
```

### Організація застосунку

Flask API використовує багатошарову архітектуру:

- **Route** — обробка HTTP-запитів, маршрути REST API та JWT-автентифікація.
- **Service** — бізнес-логіка і виконання операцій застосунку.
- **DAO** — взаємодія з MySQL через SQLAlchemy.
- **Domain** — моделі даних та DTO для передавання й серіалізації даних.
- **Utils** — допоміжні компоненти, зокрема налаштування підключення до бази.

### Інфраструктура AWS

Terraform керує створенням таких компонентів:

- **Amazon VPC** — мережева інфраструктура з публічними та приватними підмережами.
- **Amazon ECS Fargate** — запуск контейнеризованого Flask API.
- **Amazon ECR** — зберігання Docker-образів.
- **Amazon RDS MySQL** — база даних у приватній підмережі.
- **Application Load Balancer** — публічна точка доступу до API.
- **AWS IAM та Secrets Manager** — керування дозволами й секретами.
- **Amazon CloudWatch та SNS** — моніторинг, журнали, alarms і email-сповіщення.
- **GitHub Actions** — автоматизоване збирання Docker-образів і розгортання в ECS з автентифікацією через OIDC.

### Примітки

Локальне середовище використовує `compose.yaml` та `db/01_schema.sql`. У хмарному середовищі таблиці застосунку ініціалізуються через SQLAlchemy, а підключення здійснюється до Amazon RDS.

Файли `.env`, `terraform.tfvars`, Terraform state, плани розгортання та каталог `.terraform/` не включаються до Git-репозиторію. Вони містять локальні конфігурації, конфіденційні дані або автоматично згенеровані файли.

Поточний публічний ALB використовує HTTP для лабораторної демонстрації; для передавання облікових даних і JWT через інтернет необхідно налаштувати HTTPS.