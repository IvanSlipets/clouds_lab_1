# Sports Nutrition API — AWS Flask / Terraform

Контейнеризований REST API застосунок на Flask, розгорнутий у хмарі AWS з використанням Docker, Terraform та CI/CD.

**Публічна адреса останнього розгортання (може змінитися після `terraform destroy` / `apply`):**
`http://clouds-lab-alb-132014376.eu-north-1.elb.amazonaws.com`

**Health:**
`http://clouds-lab-alb-132014376.eu-north-1.elb.amazonaws.com/health`


## Структура проекту

```text
bd_lab_4/
├── .github/workflows/deploy.yml        # CI/CD GitHub Actions
├── app.py                               # Flask application factory
├── compose.yaml                        # Локальний Flask + MySQL
├── Dockerfile                           # Контейнер API
├── db/01_schema.sql                     # SQL-схема
├── project/
│   ├── config/app.yml
│   └── my_project/
│       ├── auth/
│       │   ├── dao/                     # Робота з даними
│       │   ├── domain/                  # Моделі і DTO
│       │   ├── route/                   # HTTP маршрути, JWT
│       │   └── service/                 # Бізнес-логіка
│       └── utils/
│           ├── db_init.py
│           └── sports_cache.py          # Cache-aside
├── terraform/
│   ├── autoscaling.tf                   # ECS 1–3 Tasks, CPU target 60%
│   ├── monitoring.tf                    # CloudWatch dashboard, SNS alerts
│   ├── ecs.tf                           # ECS Fargate
│   ├── alb.tf                           # Application Load Balancer
│   ├── database.tf                      # Amazon RDS MySQL
│   └── ...                              # Мережі, IAM, ECR, secrets, GitHub
├── loadtest/
│   ├── loadtest.js                      # Сценарій k6
│   └── results/
│       ├── baseline.json
│       └── with_cache.json
├── docs/
│   ├── AUTOSCALING.md
│   ├── LOADTEST.md
│   ├── ALERTS.md
│   ├── CACHE.md
│   └── *.png                            # Знімки k6 / CloudWatch / SNS
├── requirements.txt
└── README.md
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

## Лабораторна робота №2 — масштабування, моніторинг та кешування

Реалізовані обов'язкові завдання:

- **Auto Scaling:** ECS Fargate від 1 до 3 Tasks, CPU target tracking 60%, cooldown 60/180 с (`terraform/autoscaling.tf`).
- **Навантажувальний сценарій:** Grafana k6, 20 VU, 10 хв (3 хв наростання, 5 хв сталого навантаження, 2 хв спад); у кожній ітерації 1 POST та 9 GET (`loadtest/loadtest.js`).
- **Моніторинг:** CloudWatch dashboard з п'ятьма графіками (`terraform/monitoring.tf`).
- **Сповіщення:** SNS email при CPU > 70% протягом двох хвилин і поверненні до норми (`terraform/monitoring.tf`).
- **Кеш:** локальний cache-aside для `GET /api/sports/`, TTL 45 секунд, заголовок `X-Cache`, інвалідація при зміні видів спорту.

### Результати порівняння

| Показник | Без кешу | З кешем |
|---|---:|---:|
| HTTP-запити | 19 511 | 21 781 |
| RPS | 32,41 | 36,07 |
| p50 | 313,91 мс | 134,73 мс |
| p95 | 903,39 мс | 1107,07 мс |
| p99 | 1282,20 мс | 1726,13 мс |
| HTTP-помилки | 0% | 0% |

Під час тестів кількість ECS Tasks зростала **1 → 3** і поверталася до **1**. Для кешованого маршруту частка влучань становила **80,87%**. Кеш покращив типову затримку й RPS, але p95/p99 погіршилися.

Повна документація: [AUTOSCALING](docs/AUTOSCALING.md), [LOADTEST](docs/LOADTEST.md), [ALERTS](docs/ALERTS.md), [CACHE](docs/CACHE.md).
