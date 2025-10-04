# Portr Helm Chart

Production-ready Helm chart for deploying [Portr](https://github.com/amalshaji/portr) - a self-hosted ngrok alternative with traffic inspection.

## About Portr

Portr is an open-source tunneling solution developed by [Amal Shaji](https://github.com/amalshaji). It allows you to expose local HTTP, TCP, and WebSocket connections to the public internet with a web-based dashboard for team management and HTTP request inspection.

**Official Portr Resources:**
- GitHub: https://github.com/amalshaji/portr
- Documentation: https://portr.dev/docs
- Website: https://portr.dev

## Architecture

Portr consists of three main components:

### 1. Admin Service
- Web UI for team management and traffic inspection
- Exposes API on port 8000
- Requires PostgreSQL for metadata storage
- Supports GitHub OAuth authentication

### 2. Tunnel Service
- Handles all tunnel traffic routing
- Listens on:
  - Port 8001: HTTP/HTTPS proxy server
  - Port 2222: SSH server for client connections
- nginx ingress handles TLS termination

### 3. PostgreSQL Database
- Stores tunnel configurations, user data, and request logs

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- cert-manager (for automatic TLS certificates)
- Ingress controller (nginx recommended)

## Installation

### 1. Add custom values

Create a custom values file (e.g., `my-values.yaml`):

```yaml
global:
  domain: example.com

admin:
  ingress:
    hosts:
      - host: example.com
    tls:
      - secretName: portr-admin-tls
        hosts:
          - example.com

tunnel:
  service:
    type: LoadBalancer
  ingress:
    hosts:
      - host: "*.example.com"
    tls:
      - secretName: portr-tunnel-wildcard-tls
        hosts:
          - "*.example.com"

config:
  serverUrl: "example.com"
  sshUrl: "example.com:2222"
  encryptionKey: "<generate-with-python3 -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'>"
  github:
    clientId: "your-github-oauth-client-id"
    clientSecret: "your-github-oauth-client-secret"

postgresql:
  auth:
    password: "<secure-password>"
  persistence:
    enabled: true
    size: 10Gi
```

### 2. Install the chart

```bash
helm install portr ./portr-chart -f my-values.yaml -n portr --create-namespace
```

### 3. Get the LoadBalancer IP

```bash
kubectl get svc -n portr portr-tunnel
```

### 4. Configure your DNS

Point your domain DNS records to:
- `example.com` → Ingress controller IP
- `*.example.com` → Ingress controller IP (wildcard)

### 5. Configure the client

On your local machine, install the Portr client:

```bash
# Download from https://github.com/amalshaji/portr/releases
# Or use your package manager

# Configure
cat > ~/.portr/config.yaml <<EOC
server_url: example.com
ssh_url: <loadbalancer-ip>:2222
secret_key: <get-from-dashboard>
disable_tui: true
tunnels:
  - name: myapp
    subdomain: myapp
    port: 3000
EOC

# Start tunnel
portr start
```

Your local service will now be available at `https://myapp.example.com`

## Configuration

See `values.yaml` for detailed configuration options.

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.domain` | Base domain for Portr | `example.com` |
| `admin.replicaCount` | Number of admin replicas | `2` |
| `tunnel.replicaCount` | Number of tunnel replicas | `1` |
| `tunnel.service.type` | Tunnel service type | `LoadBalancer` |
| `config.encryptionKey` | Fernet encryption key | `""` |
| `config.github.clientId` | GitHub OAuth client ID | `""` |
| `config.github.clientSecret` | GitHub OAuth client secret | `""` |
| `postgresql.auth.password` | PostgreSQL password | `""` |

## Upgrading

```bash
helm upgrade portr ./portr-chart -f my-values.yaml -n portr
```

## Uninstalling

```bash
helm uninstall portr -n portr
```

**Note:** This will not delete PersistentVolumeClaims. Delete them manually if needed:

```bash
kubectl delete pvc -n portr -l app.kubernetes.io/instance=portr
```

## Troubleshooting

### Check pod status
```bash
kubectl get pods -n portr
```

### View logs
```bash
# Admin service
kubectl logs -n portr -l app.kubernetes.io/component=admin -f

# Tunnel service
kubectl logs -n portr -l app.kubernetes.io/component=tunnel -f

# PostgreSQL
kubectl logs -n portr -l app.kubernetes.io/component=postgresql -f
```

### Check certificates
```bash
kubectl get certificate -n portr
kubectl describe certificate portr-admin-tls -n portr
```

## Contributing

This is an unofficial Helm chart for Portr. For issues with Portr itself, please report them to the [official Portr repository](https://github.com/amalshaji/portr/issues).

For issues with this Helm chart, please open an issue in this repository.

## License

This Helm chart is licensed under the MIT License. See [LICENSE](LICENSE) for details.

Portr itself is licensed under the AGPL-3.0 license. See the [official Portr repository](https://github.com/amalshaji/portr) for details.

## Credits

- **Portr** developed by [Amal Shaji](https://github.com/amalshaji)
- **Helm Chart** created by [Mark Rawson](https://github.com/rawsonm88)
