# timein — Horilla HRMS (Philippine Deployment)

> **Epic 1 — Infrastructure & Core Engine Setup**
> Kubernetes-native deployment of [Horilla HRMS](https://github.com/horilla-opensource/horilla)
> tailored for Philippine compliance (DOLE / BIR).

---

## 📁 Repository Structure

```
.
├── Dockerfile              # Multi-stage Docker image for Horilla
├── docker-compose.yml      # Local development stack
└── helm/
    └── horilla-ph/         # Helm chart
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── _helpers.tpl
            ├── configmap.yaml
            ├── deployment.yaml
            ├── hpa.yaml
            ├── ingress.yaml
            ├── secret.yaml
            ├── service.yaml
            ├── serviceaccount.yaml
            └── postgresql/
                ├── secret.yaml
                ├── service.yaml
                └── statefulset.yaml
```

---

## 🐳 Local Development (Docker Compose)

```bash
# Copy and edit the environment file
cp .env.example .env   # adjust secrets as needed

# Start the full stack (Horilla + PostgreSQL)
docker compose up --build

# Apply migrations manually (first run)
docker compose exec web python manage.py migrate
docker compose exec web python manage.py createsuperuser
```

Application will be available at <http://localhost:8000>.

---

## ☸️ Kubernetes Deployment (Helm)

### Prerequisites

| Tool | Minimum Version |
|------|----------------|
| Kubernetes | 1.25+ |
| Helm | 3.10+ |
| kubectl | 1.25+ |

### Quick Start

```bash
# 1. Add the chart (from this repo)
cd helm/horilla-ph

# 2. Install with default values (bundled PostgreSQL, ClusterIP service)
helm install horilla-ph . \
  --namespace horilla \
  --create-namespace \
  --set appSecrets.secretKey="$(openssl rand -hex 32)" \
  --set postgresql.auth.password="$(openssl rand -hex 16)"
```

### Production Install

Create a `values-prod.yaml` that overrides sensitive defaults:

```yaml
# values-prod.yaml
replicaCount: 3

image:
  repository: ghcr.io/hlechuga/timein
  tag: "1.0.0"

app:
  debug: "false"
  allowedHosts: "hrms.company.ph"

appSecrets:
  # Use Sealed Secrets or Vault in production — never commit plaintext here
  secretKey: "REPLACE_WITH_SEALED_SECRET"

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: hrms.company.ph
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: horilla-tls
      hosts:
        - hrms.company.ph

postgresql:
  auth:
    password: "REPLACE_WITH_SEALED_SECRET"
  primary:
    persistence:
      size: 50Gi
      storageClass: "standard-rwo"
```

```bash
helm upgrade --install horilla-ph . \
  --namespace horilla \
  --create-namespace \
  -f values-prod.yaml
```

### Verify the Deployment

```bash
# Check all pods are Running
kubectl get pods -n horilla

# Follow application logs
kubectl logs -n horilla -l app.kubernetes.io/name=horilla-ph -f

# Check HPA status
kubectl get hpa -n horilla
```

---

## 🗄️ PostgreSQL Data Persistence

The bundled PostgreSQL runs as a **StatefulSet** with a
`volumeClaimTemplates` entry that automatically provisions a
**PersistentVolumeClaim (PVC)** for each replica.

```
PVC name: data-<release>-horilla-ph-postgresql-0
Size:     10 Gi (default, override via postgresql.primary.persistence.size)
Mode:     ReadWriteOnce
```

Data survives pod restarts and rescheduling as long as the PVC is not
manually deleted.

### Using an External Database

Set `postgresql.enabled=false` and provide external coordinates:

```yaml
postgresql:
  enabled: false

externalDatabase:
  host: "pg.rds.amazonaws.com"
  port: 5432
  database: horilla
  username: horilla
  existingSecret: "horilla-db-secret"
  existingSecretPasswordKey: "postgresql-password"
```

---

## 🔒 Security Considerations

- Application and PostgreSQL passwords are stored in Kubernetes **Secrets**
  (base64-encoded). For production, use
  [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) or
  [HashiCorp Vault](https://www.vaultproject.io/) to encrypt secrets at rest.
- All containers run as **non-root** users (`runAsNonRoot: true`).
- `allowPrivilegeEscalation: false` is set on every container.
- HPA ensures the application scales horizontally under load, improving
  resilience and availability.

---

## 📋 Roadmap

- [x] Epic 1 — Containerized Deployment (Helm chart, Dockerfile)
- [x] Epic 1 — Database Persistence (PostgreSQL StatefulSet + PVC)
- [ ] Epic 2 — Philippine Payroll Engine (DOLE / BIR compliance)
- [ ] Epic 3 — Monitoring & Alerting (Prometheus / Grafana)
- [ ] Epic 4 — CI/CD Pipeline (GitHub Actions → container registry → Helm)