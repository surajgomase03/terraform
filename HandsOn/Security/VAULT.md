# HashiCorp Vault Interview Guide

## Q1: What is HashiCorp Vault and why use it with Terraform?

**Answer:**
HashiCorp Vault is a centralized secrets management and encryption service that secures, stores, and tightly controls access to tokens, passwords, certificates, and encryption keys.

**Why with Terraform:**
- **Dynamic Secrets:** Generate temporary credentials that expire
- **Centralized Management:** Single source of truth for all secrets
- **Audit Trail:** CloudTrail-like logging for compliance (HIPAA, PCI-DSS)
- **Multi-Auth Methods:** AppRole, AWS, Kubernetes, LDAP, etc.
- **Automatic Rotation:** Credentials rotate without re-deployment
- **Encryption:** Transit encryption and data encryption as a service
- **Secret Versions:** Rotate without losing old values

**Example use cases:**
- Database credentials (static and dynamic)
- API keys management
- PKI certificate generation
- Temporary AWS credentials
- Encryption key management
- Compliance auditing

---

## Q2: Vault vs AWS Secrets Manager - Which should I use?

**Comparison Table:**

| Aspect | Vault | AWS Secrets Manager |
|--------|-------|-------------------|
| **Hosting** | Self-hosted or Cloud | AWS managed |
| **Cost** | Infrastructure costs | Pay per secret + rotations |
| **Dynamic Secrets** | ✓ Yes (databases, AWS) | Limited (database only) |
| **Multi-Cloud** | ✓ Yes (AWS, Azure, GCP) | AWS only |
| **Setup Complexity** | Complex (HA, storage, unsealing) | Simple (click and go) |
| **Auth Methods** | 20+ methods | IAM only |
| **Certificate/PKI** | ✓ Yes | No |
| **Encryption Service** | ✓ Transit engine | No |
| **Audit Logging** | Detailed (syslog, file) | CloudTrail |
| **TTL/Expiration** | Custom per secret | 30+ days minimum |
| **Learning Curve** | Steep | Shallow |

**When to use Vault:**
- ✓ Multi-cloud infrastructure
- ✓ Complex secret rotation policies
- ✓ Needs dynamic credentials
- ✓ Requires PKI/certificate management
- ✓ Custom audit requirements
- ✓ On-premises infrastructure
- ✓ Encryption service needed

**When to use Secrets Manager:**
- ✓ AWS-only infrastructure
- ✓ Simple password management
- ✓ Built-in database rotation
- ✓ Minimal operational overhead
- ✓ CloudTrail integration sufficient
- ✓ Cost optimization priority
- ✓ Standard compliance needs

---

## Q3: What are Vault secret engines?

**Answer:**
Secret engines are components that store, generate, or encrypt data. Different engines serve different purposes.

**Common Secret Engines:**

| Engine | Purpose | Data Type | Use Case |
|--------|---------|-----------|----------|
| **KV (Key-Value)** | Store arbitrary secrets | JSON | API keys, passwords |
| **Database** | Generate database credentials | Dynamic | PostgreSQL, MySQL, MongoDB |
| **AWS** | Generate AWS credentials | Dynamic | STS credentials, IAM users |
| **PKI** | Issue certificates | Dynamic | TLS, mTLS, client certs |
| **SSH** | Issue SSH certificates | Dynamic | SSH key signing |
| **Transit** | Encryption as a service | Encrypt/Decrypt | Data protection |
| **LDAP** | LDAP authentication | Dynamic | Directory sync |
| **Consul** | Service mesh integration | Dynamic | Consul token management |

**Example KV usage:**
```hcl
# Store static secrets
resource "vault_kv_secret_v2" "api_key" {
  mount = "kv"
  name  = "prod/stripe-key"
  data_json = jsonencode({
    api_key = "sk_live_xyz..."
  })
}

# Retrieve secrets
data "vault_kv_secret_v2" "api_key" {
  mount = "kv"
  name  = "prod/stripe-key"
}
```

**Example Database engine:**
```hcl
resource "vault_database_secret_backend" "postgres" {
  path = "database"
}

resource "vault_database_secret_backend_role" "readonly" {
  backend = vault_database_secret_backend.postgres.path
  name    = "readonly"
  # Vault creates temporary users automatically
}

# Get ephemeral credentials
data "vault_database_secret_backend_static_account_credentials" "creds" {
  backend = vault_database_secret_backend.postgres.path
  role    = vault_database_secret_backend_role.readonly.name
}
# Credentials expire after TTL
```

---

## Q4: What are dynamic secrets and why are they better than static secrets?

**Answer:**
Dynamic secrets are generated on-demand with a limited lifetime and automatically expire or revoke.

**Comparison Table:**

| Aspect | Static Secrets | Dynamic Secrets |
|--------|----------------|-----------------|
| **Creation** | Created once, reused | Created per request |
| **Lifetime** | Indefinite | Hours to minutes (TTL) |
| **Rotation** | Manual or scheduled | Automatic |
| **Revocation** | All or nothing | Individual credentials |
| **Audit Trail** | Limited | Every creation/use |
| **Blast Radius** | High (one key everywhere) | Low (one key per session) |
| **Compliance** | Basic | HIPAA, PCI-DSS ready |

**Dynamic Secret Example:**
```hcl
# Vault creates temp DB user automatically
data "vault_database_static_account_credentials" "app" {
  backend = "database"
  role    = "readonly"
  # Returns: username, password, lease_id
  # Password expires in 1 hour (default)
}

# If credential is compromised:
# - Only that one credential is exposed
# - Expires automatically
# - New request creates new credential
```

**Benefits:**
- ✓ Reduced blast radius
- ✓ Automatic rotation
- ✓ Detailed audit trail
- ✓ No manual credential rotation
- ✓ Fewer credentials in rotation

---

## Q5: How do you set up Vault in production?

**Answer:**
Production Vault requires careful setup for high availability, security, and compliance.

**Production Architecture:**
```
┌─────────────────────────────────────────┐
│         Vault HA Cluster                │
├─────────────────────────────────────────┤
│  Vault 1 (Active)  │  Vault 2 (Standby) │
│  Vault 3 (Standby) │                    │
├─────────────────────────────────────────┤
│  Consul Storage Backend (HA)            │
├─────────────────────────────────────────┤
│  AWS KMS (Auto-Unseal)                  │
├─────────────────────────────────────────┤
│  TLS Certificates                       │
│  CloudTrail/Audit Logging               │
└─────────────────────────────────────────┘
```

**Key production components:**

1. **High Availability:**
   ```hcl
   # Use Consul as backend
   storage "consul" {
     address = "consul.example.com:8500"
     path    = "vault/"
     ha_enabled = true
   }
   ```

2. **Auto-Unseal with KMS:**
   ```hcl
   seal "awskms" {
     region     = "us-east-1"
     kms_key_id = "arn:aws:kms:..."
   }
   ```

3. **TLS Configuration:**
   ```hcl
   listener "tcp" {
     address            = "0.0.0.0:8200"
     tls_cert_file      = "/etc/vault/certs/vault.crt"
     tls_key_file       = "/etc/vault/certs/vault.key"
     tls_min_version    = "tls12"
     tls_client_ca_file = "/etc/vault/certs/ca.crt"
   }
   ```

4. **Audit Logging:**
   ```hcl
   audit {
     file {
       path = "/var/log/vault/audit.log"
     }
   }
   ```

**Production Checklist:**
- [ ] HA setup (3+ nodes)
- [ ] Auto-unseal configured
- [ ] TLS certificates
- [ ] Audit logging enabled
- [ ] Backup policy (Consul snapshots)
- [ ] Monitoring and alerting
- [ ] Regular disaster recovery tests
- [ ] Access policies locked down
- [ ] Network security (private subnets)
- [ ] Secrets rotation policies

---

## Q6: What are Vault authentication methods?

**Answer:**
Auth methods determine how users/applications authenticate to Vault.

**Common Auth Methods:**

| Method | Use Case | Best For | Complexity |
|--------|----------|----------|-----------|
| **Token** | Manual authentication | Development | Low |
| **AppRole** | Applications, CI/CD | Terraform CI/CD | Medium |
| **AWS IAM** | AWS EC2 instances | AWS-only apps | Medium |
| **Kubernetes** | K8s pods | Kubernetes | High |
| **LDAP** | Directory integration | Enterprise | High |
| **GitHub** | GitHub users | DevOps teams | Low |
| **OIDC** | SSO providers | Enterprise SSO | High |

**AppRole (for Terraform CI/CD):**
```hcl
# Create AppRole
resource "vault_approle_auth_backend_role" "terraform" {
  backend   = "approle"
  role_name = "terraform-ci"
  policies  = ["default", "terraform"]
  
  token_ttl   = "1h"
  token_max_ttl = "24h"
}

# Generate credentials
resource "vault_approle_auth_backend_role_secret_id" "terraform" {
  backend   = "approle"
  role_name = vault_approle_auth_backend_role.terraform.role_name
}

# Use in CI/CD:
# VAULT_TOKEN=$(vault write -field=client_token auth/approle/login \
#   role_id=<role_id> \
#   secret_id=<secret_id>)
```

**AWS IAM Auth (for EC2):**
```hcl
# Automatically authenticates EC2 instance to Vault
# via IAM metadata

# In Terraform:
provider "vault" {
  auth_login {
    path = "auth/aws/login"
    parameters = {
      role = "ec2-role"
      iam_http_request_method = "POST"
      iam_request_url = base64encode("https://sts.amazonaws.com/")
      iam_request_body = base64encode("Action=GetCallerIdentity&Version=2011-06-15")
      iam_request_headers = base64encode("...")
    }
  }
}
```

---

## Q7: How do you rotate database credentials in Vault?

**Answer:**
Vault automatically generates and rotates database credentials.

**Rotation Process:**
```hcl
resource "vault_database_secret_backend_role" "app" {
  backend                     = vault_database_secret_backend.postgres.path
  name                        = "app"
  db_name                     = vault_database_secret_backend_connection.postgres.name
  default_ttl                 = "1h"      # Credential lifetime
  max_ttl                     = "24h"     # Max lifetime
  
  creation_statements = [
    "CREATE USER \"{{name}}\" WITH PASSWORD '{{password}}';"
  ]
  rotation_statements = [
    "ALTER USER \"{{name}}\" WITH PASSWORD '{{password}}';"
  ]
}

# Credential flow:
# 1. Application requests creds: GET /database/creds/app
# 2. Vault creates temp user with random password
# 3. Returns username, password, lease_id, lease_duration
# 4. After TTL expires, credential auto-revokes
# 5. Application must request new credentials
```

**Rotation Parameters:**
| Parameter | Meaning | Example |
|-----------|---------|---------|
| `default_ttl` | Standard credential lifetime | 1h (1 hour) |
| `max_ttl` | Maximum lifetime possible | 24h (1 day) |
| `rotation_statements` | SQL to rotate password | ALTER USER ... |

**Application considerations:**
- Request fresh credentials periodically (before expiry)
- Implement retry logic when credentials expire
- Log credential expiration events
- Test failure scenarios

---

## Q8: How do you use Vault for PKI/Certificate management?

**Answer:**
Vault's PKI engine can act as your own Certificate Authority (CA).

**Setup:**
```hcl
# Create CA
resource "vault_pki_secret_backend" "root_ca" {
  path                    = "pki"
  max_lease_ttl_seconds   = 315360000  # 10 years
  default_lease_ttl_seconds = 2592000  # 30 days
}

# Self-sign root certificate
resource "vault_pki_secret_backend_self_signed_cert" "root" {
  backend              = vault_pki_secret_backend.root_ca.path
  type                 = "root"
  common_name          = "example.com"
  organization         = "Example Corp"
  ttl                  = "87600h"  # 10 years
}

# Create role for issuing certificates
resource "vault_pki_secret_backend_role" "cert" {
  backend           = vault_pki_secret_backend.root_ca.path
  name              = "example.com"
  ttl               = "8760h"  # 1 year
  max_ttl           = "17520h"  # 2 years
  allowed_domains   = ["example.com", "*.example.com"]
  allow_subdomains  = true
  require_cn        = true
  generate_lease    = true
}

# Issue certificate
data "vault_pki_secret_backend_sign" "cert" {
  backend = vault_pki_secret_backend.root_ca.path
  name    = vault_pki_secret_backend_role.cert.name
  
  common_name = "api.example.com"
  ttl         = "8760h"
}

# Output: private_key, certificate, ca_chain
```

**Benefits:**
- ✓ No need for external CA
- ✓ Automatic certificate rotation
- ✓ Intermediate CA support
- ✓ CRL management
- ✓ OCSP stapling support

---

## Q9: How do you handle Vault secrets in Terraform outputs?

**Answer:**
Mark sensitive outputs to prevent accidental exposure.

```hcl
# ✓ GOOD: Mark as sensitive
output "database_password" {
  value       = data.vault_kv_secret_v2.db.data["password"]
  sensitive   = true
  description = "Database password from Vault"
}

# ✗ BAD: No sensitive flag
output "api_key" {
  value = data.vault_kv_secret_v2.api.data["key"]  # Exposed in logs!
}
```

**Sensitive output behavior:**
- Terraform won't log value to console
- Won't show in plan output
- Value still stored in state file (encrypted if using encrypted backend)
- Applications can read via output
- Use state file encryption with KMS

**Production best practice:**
1. Store secrets in Vault
2. Use Vault outputs (marked sensitive)
3. Applications read outputs at deploy time
4. Never store in state (except encrypted)
5. Rotate credentials via Vault policies

---

## Q10: How do you troubleshoot Vault integration issues?

**Common Issues:**

| Issue | Cause | Solution |
|-------|-------|----------|
| `permission denied` | Auth token lacks permissions | Check policy: `vault policy read role-name` |
| `secret not found` | Path incorrect | Verify path: `vault kv list secret/prod/` |
| `lease expired` | Credential TTL exceeded | Implement refresh in application |
| `connection refused` | Vault unreachable | Check address, TLS cert, network |
| `unseal required` | Vault is sealed | Unseal with key: `vault unseal` |
| `auth method not found` | Backend not enabled | Enable: `vault auth enable approle` |

**Debugging commands:**
```bash
# Check Vault status
vault status

# List secret engines
vault secrets list

# List auth methods
vault auth list

# Check policy
vault policy read <policy-name>

# Test AppRole auth
vault write -field=client_token auth/approle/login \
  role_id=<role_id> \
  secret_id=<secret_id>

# Read secret with logging
VAULT_LOG_LEVEL=debug terraform apply

# Check Vault audit logs
tail -f /var/log/vault/audit.log | jq .
```

---

## Q11: Vault vs Terraform Cloud Secrets - When to use each?

**Comparison:**

| Aspect | Vault | Terraform Cloud |
|--------|-------|-----------------|
| **Purpose** | General secrets mgmt | Terraform-specific |
| **Multi-Tool** | Works with any tool | Terraform only |
| **Hosted** | Self or cloud | Hashicorp Cloud |
| **Cost** | Infrastructure | Per secret/month |
| **Learning Curve** | Steep | Shallow |
| **Features** | Advanced (PKI, transit) | Basic (API, environment) |
| **Auth Methods** | 20+ | Limited |

**Use Vault when:**
- ✓ Multi-tool environment (Ansible, Kubernetes, etc.)
- ✓ Complex secret workflows
- ✓ Multi-cloud
- ✓ Self-hosted requirement
- ✓ Advanced features needed (PKI, transit)

**Use Terraform Cloud secrets when:**
- ✓ Only Terraform is used
- ✓ Simple environment variable storage
- ✓ Minimal operational overhead
- ✓ Team collaboration needed

---

## Q12: Vault Best Practices Checklist

**✓ Do:**
- [ ] Enable audit logging
- [ ] Use auto-unseal in production
- [ ] Implement HA setup
- [ ] Rotate root token regularly
- [ ] Use AppRole for applications
- [ ] Set appropriate TTLs
- [ ] Use least privilege policies
- [ ] Implement network segmentation
- [ ] Monitor Vault metrics
- [ ] Regular disaster recovery tests
- [ ] Backup Consul snapshots
- [ ] Use TLS for all connections
- [ ] Enable MFA for humans
- [ ] Rotate encryption keys

**✗ Don't:**
- [ ] Run Vault in dev mode (production)
- [ ] Hardcode tokens in code
- [ ] Use root token for applications
- [ ] Share AppRole credentials insecurely
- [ ] Disable audit logging
- [ ] Run single-node cluster
- [ ] Use self-signed certs (production)
- [ ] Store secrets in state files unencrypted
- [ ] Forget to implement secret rotation
- [ ] Ignore audit logs
- [ ] Use weak seal key
- [ ] Keep root token active permanently

---

## Quick Reference Commands

```bash
# Start Vault (development only)
vault server -dev

# Unseal Vault (interactive)
vault operator unseal

# Enable secret engine
vault secrets enable -path=kv kv-v2

# Write secret
vault kv put kv/secret username=admin password=secret

# Read secret
vault kv get kv/secret

# List secrets
vault kv list kv/

# Delete secret
vault kv delete kv/secret

# Enable auth method
vault auth enable approle

# Generate AppRole credentials
vault write -f auth/approle/role/my-role

# Test auth
vault login -method=approle \
  role_id=<role_id> \
  secret_id=<secret_id>

# Enable PKI
vault secrets enable pki

# Rotate root token
vault token renew

# Audit logs
vault audit list

# Policy management
vault policy write my-policy -<<EOF
path "kv/data/*" {
  capabilities = ["read", "list"]
}
EOF
```

---

## Further Learning

- Official Vault Documentation: https://www.vaultproject.io/docs
- Vault Learning Path: https://learn.hashicorp.com/vault
- Terraform Vault Provider: https://registry.terraform.io/providers/hashicorp/vault/latest/docs
- Vault Production Hardening: https://learn.hashicorp.com/vault/secrets-store/production-hardening

