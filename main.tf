terraform {
  required_version = ">= 1.0.7"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.15.0"
    }

    vault = {
      version = "3.0.1"
    }
  }
}

provider "vault" {
  address = "http://localhost:8201"
  token   = "f23612cf-824d-4206-9e94-e31a6dc8ee8d"
}

provider "vault" {
  alias   = "vault_dev"
  address = "http://localhost:8201"
  token   = "f23612cf-824d-4206-9e94-e31a6dc8ee8d"
}

provider "vault" {
  alias   = "vault_prod"
  address = "http://localhost:8301"
  token   = "083672fc-4471-4ec4-9b59-a285e463a973"
}

provider "vault" {
  alias   = "vault_staging"
  address = "http://localhost:8401"
  token   = "a1f5b3c2-91a1-45e2-a07b-7770ecfbe4f9"
}

resource "vault_audit" "audit_staging" {
  provider = vault.vault_staging
  type     = "file"

  options = {
    file_path = "/vault/logs/audit"
  }
}

resource "vault_auth_backend" "userpass_staging" {
  provider = vault.vault_staging
  type     = "userpass"
}

# Add vault_generic_secret, vault_policy, vault_generic_endpoint, and docker_container for each microservice in staging
# Example for account service:

resource "vault_generic_secret" "account_staging" {
  provider = vault.vault_staging
  path     = "secret/staging/account"

  data_json = <<EOT
{
  "db_user":   "account",
  "db_password": "staging-account-password"
}
EOT
}

resource "vault_policy" "account_staging" {
  provider = vault.vault_staging
  name     = "account-staging"

  policy = <<EOT
path "secret/data/staging/account" {
    capabilities = ["list", "read"]
}
EOT
}

resource "vault_generic_endpoint" "account_staging" {
  provider             = vault.vault_staging
  depends_on           = [vault_auth_backend.userpass_staging]
  path                 = "auth/userpass/users/account-staging"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "policies": ["account-staging"],
  "password": "123-account-staging"
}
EOT
}

resource "docker_container" "account_staging" {
  image = "form3tech-oss/platformtest-account"
  name  = "account_staging"

  env = [
    "VAULT_ADDR=http://vault-staging:8200",
    "VAULT_USERNAME=account-staging",
    "VAULT_PASSWORD=123-account-staging",
    "ENVIRONMENT=staging"
  ]

  networks_advanced {
    name = "vagrant_staging"
  }

  lifecycle {
    ignore_changes = all
  }

  depends_on = [vault_generic_endpoint.account_staging]
}

# Repeat above block for gateway and payment services for staging environment



