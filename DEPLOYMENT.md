# Portr Deployment Guide for microk8s

This guide provides step-by-step instructions for deploying Portr on microk8s with MetalLB and nginx ingress.

## Prerequisites Setup

### 1. Enable Required microk8s Addons

```bash
# Enable required addons
microk8s enable dns
microk8s enable storage
microk8s enable metallb
microk8s enable ingress
microk8s enable cert-manager
```

### 2. Configure MetalLB IP Range

When enabling MetalLB, you'll be prompted for an IP range. Example:

```bash
# Example IP range (adjust to your network)
192.168.1.240-192.168.1.250
```

### 3. Configure DNS

Add DNS records for your domain (webhooks.run):

```
admin.webhooks.run    A    <METALLB-IP>
*.webhooks.run        A    <METALLB-IP>
```

Or update your `/etc/hosts` for local testing:

```
<METALLB-IP>  admin.webhooks.run
<METALLB-IP>  test.webhooks.run
```

## Step 1: Prepare Configuration

### Generate Required Secrets

```bash
# Generate encryption key
ENCRYPTION_KEY=$(openssl rand -hex 32)
echo "Encryption Key: $ENCRYPTION_KEY"

# Generate strong PostgreSQL password
PG_PASSWORD=$(openssl rand -base64 32)
echo "PostgreSQL Password: $PG_PASSWORD"
```

### Setup GitHub OAuth (Optional but Recommended)

1. Go to GitHub Settings > Developer settings > OAuth Apps
2. Create new OAuth App:
   - Application name: `Portr - webhooks.run`
   - Homepage URL: `https://admin.webhooks.run`
   - Authorization callback URL: `https://admin.webhooks.run/api/v1/auth/github/callback`
3. Note down Client ID and Client Secret

## Step 2: Create Values File

Create `portr-values.yaml`:

```yaml
global:
  domain: webhooks.run
  ingressClassName: nginx

admin:
  replicaCount: 2

  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    hosts:
      - host: admin.webhooks.run
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: portr-admin-tls
        hosts:
          - admin.webhooks.run

  resources:
    limits:
      cpu: 1000m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi

tunnel:
  replicaCount: 1

  service:
    type: LoadBalancer
    annotations:
      metallb.universe.tf/allow-shared-ip: portr-tunnel

  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    hosts:
      - host: "*.webhooks.run"
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: portr-tunnel-wildcard-tls
        hosts:
          - "*.webhooks.run"

  resources:
    limits:
      cpu: 2000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi

postgresql:
  persistence:
    enabled: true
    size: 10Gi

  auth:
    username: postgres
    password: "YOUR-PG-PASSWORD-HERE"
    database: portr

config:
  github:
    clientId: "YOUR-GITHUB-CLIENT-ID"
    clientSecret: "YOUR-GITHUB-CLIENT-SECRET"

  encryptionKey: "YOUR-ENCRYPTION-KEY-HERE"

  serverUrl: "webhooks.run"
  sshUrl: "webhooks.run:2222"
```

## Step 3: Create cert-manager ClusterIssuer

Create `letsencrypt-issuer.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # Change this
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

Apply it:

```bash
microk8s kubectl apply -f letsencrypt-issuer.yaml
```

## Step 4: Install Portr

### Create Namespace

```bash
microk8s kubectl create namespace portr
```

### Install the Helm Chart

```bash
# Using microk8s helm3
microk8s helm3 install portr ./portr-chart \
  --namespace portr \
  -f portr-values.yaml

# Or if using standalone Helm
helm install portr ./portr-chart \
  --namespace portr \
  -f portr-values.yaml \
  --kube-context microk8s
```

### Verify Installation

```bash
# Check pods
microk8s kubectl get pods -n portr

# Check services
microk8s kubectl get svc -n portr

# Check ingress
microk8s kubectl get ingress -n portr

# Check certificates
microk8s kubectl get certificate -n portr
```

## Step 5: Verify Deployment

### Check Pod Status

```bash
# All pods should be Running
microk8s kubectl get pods -n portr -w
```

Expected output:
```
NAME                            READY   STATUS    RESTARTS   AGE
portr-admin-xxx-xxx            1/1     Running   0          2m
portr-admin-xxx-yyy            1/1     Running   0          2m
portr-tunnel-xxx-xxx           1/1     Running   0          2m
portr-postgresql-0             1/1     Running   0          2m
```

### Check LoadBalancer IP

```bash
microk8s kubectl get svc -n portr portr-tunnel
```

Note the EXTERNAL-IP assigned by MetalLB.

### Check Ingress and Certificates

```bash
# Check ingress
microk8s kubectl get ingress -n portr

# Check certificate status (should show Ready: True)
microk8s kubectl get certificate -n portr

# View certificate details
microk8s kubectl describe certificate -n portr
```

## Step 6: Access Portr

### Access Admin Dashboard

1. Open browser: `https://admin.webhooks.run`
2. You should see the Portr admin interface
3. Login with GitHub OAuth (if configured)

### Test Tunnel

On your local machine, install Portr client:

```bash
# Install client (see https://portr.dev/client/installation/)
# Configure server
portr config set --server webhooks.run

# Test HTTP tunnel
cd /tmp
python3 -m http.server 8888

# In another terminal
portr http 8888
```

You should receive a URL like: `https://random-subdomain.webhooks.run`

## Monitoring and Logs

### View Logs

```bash
# Admin service logs
microk8s kubectl logs -n portr -l app.kubernetes.io/component=admin -f

# Tunnel service logs
microk8s kubectl logs -n portr -l app.kubernetes.io/component=tunnel -f

# PostgreSQL logs
microk8s kubectl logs -n portr -l app.kubernetes.io/component=postgresql -f
```

### Monitor Resources

```bash
# Pod resources
microk8s kubectl top pods -n portr

# Node resources
microk8s kubectl top nodes
```

## Troubleshooting

### Pods Not Starting

```bash
# Describe pod for events
microk8s kubectl describe pod -n portr <pod-name>

# Check init containers
microk8s kubectl logs -n portr <pod-name> -c wait-for-postgresql
microk8s kubectl logs -n portr <pod-name> -c wait-for-admin
```

### Certificate Issues

```bash
# Check cert-manager logs
microk8s kubectl logs -n cert-manager -l app=cert-manager

# Check certificate request
microk8s kubectl get certificaterequest -n portr

# Check challenge
microk8s kubectl get challenge -n portr
```

### Database Connection Issues

```bash
# Test PostgreSQL connection
microk8s kubectl exec -n portr portr-postgresql-0 -- psql -U postgres -c '\l'

# Check database password secret
microk8s kubectl get secret -n portr portr-secret -o jsonpath='{.data.PORTR_DB_URL}' | base64 -d
```

### LoadBalancer Not Getting IP

```bash
# Check MetalLB status
microk8s kubectl get pods -n metallb-system

# Check MetalLB config
microk8s kubectl get ipaddresspool -n metallb-system -o yaml
```

## Upgrading

### Update Values

Edit `portr-values.yaml` with new configuration.

### Upgrade Release

```bash
microk8s helm3 upgrade portr ./portr-chart \
  --namespace portr \
  -f portr-values.yaml
```

### Rollback if Needed

```bash
# View history
microk8s helm3 history portr -n portr

# Rollback to previous version
microk8s helm3 rollback portr -n portr
```

## Scaling

### Scale Admin Service

```bash
# Manual scaling
microk8s kubectl scale deployment -n portr portr-admin --replicas=3

# Or enable HPA in values.yaml
admin:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
```

## Backup and Restore

### Backup PostgreSQL

```bash
# Backup database
microk8s kubectl exec -n portr portr-postgresql-0 -- \
  pg_dump -U postgres portr > portr-backup-$(date +%Y%m%d).sql

# Or backup PVC
microk8s kubectl get pvc -n portr
```

### Restore PostgreSQL

```bash
# Restore from backup
cat portr-backup-20231201.sql | \
  microk8s kubectl exec -i -n portr portr-postgresql-0 -- \
  psql -U postgres portr
```

## Uninstalling

### Remove Helm Release

```bash
microk8s helm3 uninstall portr -n portr
```

### Delete Namespace and PVCs

```bash
# This will delete all data!
microk8s kubectl delete namespace portr
```

## Production Checklist

- [ ] Changed default PostgreSQL password
- [ ] Generated strong encryption key
- [ ] Configured GitHub OAuth
- [ ] DNS records properly configured
- [ ] SSL certificates obtained (cert-manager)
- [ ] Resource limits reviewed and adjusted
- [ ] Backup strategy implemented
- [ ] Monitoring configured
- [ ] Security policies reviewed
- [ ] Network policies configured (optional)
- [ ] Tested tunnel functionality
- [ ] Documented configuration for team

## Support

- [Portr Documentation](https://portr.dev/docs)
- [GitHub Issues](https://github.com/amalshaji/portr/issues)
- [microk8s Documentation](https://microk8s.io/docs)
