# Portr Helm Chart - Quick Start

## TL;DR

```bash
# 1. Generate secrets
openssl rand -hex 32  # Encryption key
openssl rand -base64 32  # PostgreSQL password

# 2. Create values file
cat > my-values.yaml <<EOF
global:
  domain: webhooks.run

config:
  github:
    clientId: "your-github-client-id"
    clientSecret: "your-github-client-secret"
  encryptionKey: "your-encryption-key"
  serverUrl: "webhooks.run"
  sshUrl: "webhooks.run:2222"

postgresql:
  auth:
    password: "your-strong-password"
EOF

# 3. Install
helm install portr ./portr-chart -n portr --create-namespace -f my-values.yaml

# 4. Check status
kubectl get pods -n portr
kubectl get svc -n portr
kubectl get ingress -n portr
```

## Access

- **Admin UI**: https://admin.webhooks.run
- **Tunnel Endpoint**: *.webhooks.run
- **SSH Port**: 2222

## Client Setup

```bash
# Install client (see https://portr.dev/client/installation/)

# Configure
portr config set --server webhooks.run

# Create tunnel
portr http 3000
```

## Common Commands

```bash
# View logs
kubectl logs -n portr -l app.kubernetes.io/component=admin -f

# Scale admin
kubectl scale deployment -n portr portr-admin --replicas=3

# Port forward (if no ingress)
kubectl port-forward -n portr svc/portr-admin 8000:8000

# Get LoadBalancer IP
kubectl get svc -n portr portr-tunnel

# Upgrade
helm upgrade portr ./portr-chart -n portr -f my-values.yaml

# Uninstall
helm uninstall portr -n portr
```

## Minimal Values (Development)

```yaml
global:
  domain: localhost

admin:
  replicaCount: 1
  ingress:
    enabled: false

tunnel:
  service:
    type: NodePort
  ingress:
    enabled: false

postgresql:
  persistence:
    enabled: false
  auth:
    password: "postgres"

config:
  github:
    clientId: ""
    clientSecret: ""
  encryptionKey: "dev-key-not-secure"
  serverUrl: "localhost"
  sshUrl: "localhost:2222"
```

## Production Values (Minimum Required Changes)

```yaml
# Change these for production!
postgresql:
  auth:
    password: "CHANGE-ME"  # Strong password

config:
  github:
    clientId: "CHANGE-ME"  # GitHub OAuth
    clientSecret: "CHANGE-ME"
  encryptionKey: "CHANGE-ME"  # openssl rand -hex 32
```

## Troubleshooting

```bash
# Pods not ready
kubectl describe pod -n portr <pod-name>

# Check init containers
kubectl logs -n portr <pod-name> -c wait-for-postgresql

# Database connection
kubectl get secret -n portr portr-secret -o jsonpath='{.data.PORTR_DB_URL}' | base64 -d

# Certificate issues
kubectl get certificate -n portr
kubectl describe certificate -n portr

# LoadBalancer not getting IP
kubectl get svc -n portr portr-tunnel -o wide
```

## Architecture

```
┌─────────────────────────────────────────┐
│           Ingress (nginx)               │
│  *.webhooks.run  │  admin.webhooks.run  │
└────────┬─────────┴──────────────────────┘
         │
    ┌────▼────────┐        ┌──────────────┐
    │   Tunnel    │        │    Admin     │
    │   Service   │◄───────┤   Service    │
    │ (LoadBalancer)        │  (2 replicas)│
    └─────────────┘        └──────┬───────┘
                                   │
                            ┌──────▼───────┐
                            │  PostgreSQL  │
                            │ (StatefulSet)│
                            └──────────────┘
```

## Links

- **Chart**: /home/mark/claude/portr-chart/
- **Docs**: https://portr.dev/docs
- **GitHub**: https://github.com/amalshaji/portr
