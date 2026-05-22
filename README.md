# Zabbix Docker

A fully automated deployment of [Zabbix 7.0](https://www.zabbix.com/) on AWS using Terraform and Docker Compose, with a GitHub Actions CI/CD pipeline for zero-touch deployments.

## Overview

This project provisions an AWS EC2 instance via Terraform and deploys a complete Zabbix monitoring stack using Docker Compose. The stack consists of three services:

- **PostgreSQL 15** — backend database for Zabbix
- **Zabbix Server 7.0** — the core monitoring engine (listens on port `10051`)
- **Zabbix Web (Nginx + PHP)** — the web UI accessible over HTTP/HTTPS

## Architecture

```
GitHub Actions (CI/CD)
        │
        ▼
  Terraform (AWS)
        │
        ▼
  EC2 t3.micro (Ubuntu 22.04)
        │
        ▼
  Docker Compose
  ┌─────────────────────────────────┐
  │  postgres-server  (PostgreSQL)  │
  │  zabbix-server    (port 10051)  │
  │  zabbix-web       (port 80/443) │
  └─────────────────────────────────┘
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.x
- An AWS account with appropriate IAM permissions
- An EC2 key pair named `cd-github` (or update `key_name` in `main.tf`)
- Docker & Docker Compose (auto-installed on the EC2 instance via user data)

## Configuration

### Environment Variables

The `docker-compose.yml` reads the following variables from the environment (or a `.env` file):

| Variable      | Description                        |
|---------------|------------------------------------|
| `DB_USER`     | PostgreSQL username                |
| `DB_PASSWORD` | PostgreSQL password                |
| `DB_NAME`     | PostgreSQL database name           |

Create a `.env` file in the project root before running Docker Compose:

```env
DB_USER=zabbix
DB_PASSWORD=your_secure_password
DB_NAME=zabbix
```

> **⚠️ Never commit `.env` to version control.** It is already listed in `.gitignore`.

### GitHub Secrets (for CI/CD)

Set these secrets in your GitHub repository settings:

| Secret          | Description                                  |
|-----------------|----------------------------------------------|
| `SERVER_HOST`   | Public IP of the EC2 instance (Terraform output) |
| `SSH_KEY`       | Private SSH key matching the `cd-github` key pair |
| `DB_USER`       | PostgreSQL username                          |
| `DB_PASSWORD`   | PostgreSQL password                          |
| `DB_NAME`       | PostgreSQL database name                     |

## Deployment

### 1. Provision Infrastructure with Terraform

```bash
terraform init
terraform plan
terraform apply
```

After a successful apply, Terraform will output the EC2 instance's public IP:

```
server_public_ip = "x.x.x.x"
```

Use this IP as the `SERVER_HOST` GitHub Secret and to access the Zabbix Web UI.

### 2. Deploy Zabbix with Docker Compose

The EC2 instance is provisioned with Docker and Docker Compose already installed via the Terraform `user_data` script. After SSHing into the instance, copy your project files and run:

```bash
cd /opt/zabbix
docker compose up -d
```

### 3. Automated Deployment via GitHub Actions

Push to the `main` branch to trigger the CI/CD pipeline. The workflow will SSH into the EC2 instance and deploy the latest version of the stack automatically.

## Accessing the Web UI

Once deployed, open your browser and navigate to:

```
http://<SERVER_HOST>
```

Default Zabbix credentials:

- **Username:** `Admin`
- **Password:** `zabbix`

> **⚠️ Change the default password immediately after first login.**

## Infrastructure Details

The Terraform configuration (`main.tf`) provisions:

- **Region:** `eu-central-1` (Frankfurt)
- **AMI:** Latest Ubuntu 22.04 LTS (Jammy)
- **Instance type:** `t3.micro`
- **Root volume:** Encrypted EBS
- **IMDSv2:** Enforced (`http_tokens = "required"`)

### Security Group Rules

| Port  | Protocol | Source    | Purpose              |
|-------|----------|-----------|----------------------|
| 22    | TCP      | 0.0.0.0/0 | SSH access           |
| 80    | TCP      | 0.0.0.0/0 | Zabbix Web (HTTP)    |
| 443   | TCP      | 0.0.0.0/0 | Zabbix Web (HTTPS)   |
| 10051 | TCP      | 0.0.0.0/0 | Zabbix Agent/Trapper |

> **Note:** SSH and Zabbix ports are currently open to the internet. For production use, restrict `cidr_blocks` to trusted IP ranges.

## Project Structure

```
.
├── .github/
│   └── workflows/        # GitHub Actions CI/CD pipeline
├── docker-compose.yml    # Zabbix stack definition
├── main.tf               # Terraform AWS infrastructure
├── .terraform.lock.hcl   # Terraform provider lock file
└── .gitignore
```

## Security Considerations

- The `.env` file containing database credentials is excluded from version control via `.gitignore`.
- Store all secrets (SSH keys, DB credentials) in GitHub Secrets — never hardcode them.
- The EC2 instance enforces IMDSv2 and encrypted root volumes.
- Consider tightening the security group ingress rules for `port 22` and `10051` to specific IP ranges in production.

## License

This project is unlicensed. See the repository for details.