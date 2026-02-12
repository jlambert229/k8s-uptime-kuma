# k8s-uptime-kuma

![pre-commit](https://github.com/jlambert229/k8s-uptime-kuma/actions/workflows/pre-commit.yml/badge.svg)
![GitHub last commit](https://img.shields.io/github/last-commit/jlambert229/k8s-uptime-kuma)

Self-hosted uptime monitoring for your homelab using [Uptime Kuma](https://github.com/louislam/uptime-kuma) on Kubernetes.

**Blog post:** [Network Monitoring with Uptime Kuma on Kubernetes](https://foggyclouds.io/post/k8s-uptime-kuma/)

## Features

- **HTTP/HTTPS monitoring** - Track web UIs (Plex, Sonarr, Radarr, Proxmox)
- **Ping checks** - Verify network connectivity to switches, NAS, VMs
- **TCP port monitoring** - Ensure services are listening (SSH, DNS, HTTPS)
- **SSL certificate tracking** - Get notified before certs expire
- **Push notifications** - Discord, Slack, Telegram, SMTP, webhooks
- **Status pages** - Public uptime dashboards
- **Single container** - SQLite database, no external dependencies

## Prerequisites

- Kubernetes cluster (tested on Talos)
- Helm 3.x
- Traefik ingress controller
- NFS CSI driver with `nfs-appdata` StorageClass
- DNS entry: `uptime.media.lan → <TRAEFIK_IP>`

## Quick Start

```bash
# Clone the repo
git clone https://github.com/YOUR-USERNAME/k8s-uptime-kuma.git
cd k8s-uptime-kuma

# Deploy
./deploy.sh

# Access the web UI
open http://uptime.media.lan
```

## Configuration

### values.yaml

Edit `values.yaml` to customize:

- **Image version** - Update `tag` to pin a specific version
- **Ingress hostname** - Change `uptime.media.lan` to your domain
- **Storage size** - Adjust PVC size (default 2Gi)
- **Resources** - Tune CPU/memory requests and limits
- **Timezone** - Set `TZ` environment variable

### Import Monitors

Pre-configured monitors for common homelab services:

```bash
# After first login:
# 1. Settings → Backup → Import
# 2. Upload examples/monitors.json
# 3. Edit monitors to match your IPs/hostnames
```

Included monitors:
- Plex, Sonarr, Radarr, Prowlarr, qBittorrent
- Pi-hole (web UI + DNS port)
- Synology NAS, EdgeRouter (ping)
- Kubernetes API, Traefik ingress
- Proxmox Web UI

### Notifications

Configure in web UI: **Settings → Notifications**

**Discord webhook (recommended):**
1. Create webhook in Discord server settings
2. Add notification: Type = Discord, paste webhook URL
3. Set as default for all monitors

**SMTP email:**
- Type: SMTP
- Hostname: `smtp.gmail.com` (or your SMTP server)
- Port: 587
- TLS: Yes
- Username/password: Your email credentials

## Backups

Automated SQLite backup:

```bash
./backup.sh
```

Backups stored in `./backups/` with timestamp. Keeps last 30 backups.

**Automate with cron:**

```bash
# Daily backup at 4am
0 4 * * * /path/to/k8s-uptime-kuma/backup.sh 2>&1 | logger -t uptime-kuma-backup
```

**Restore:**

```bash
kubectl scale -n monitoring deploy/uptime-kuma --replicas=0
kubectl cp ./backups/kuma-20260208_040000.db monitoring/<pod>:/app/data/kuma.db
kubectl scale -n monitoring deploy/uptime-kuma --replicas=1
```

## Status Pages

Create public status pages:

1. Settings → Status Pages → Add
2. Configure slug (e.g., `homelab`)
3. Select monitors to include
4. Public or password-protected

Access: `http://uptime.media.lan/status/homelab`

## Troubleshooting

### Pod won't start

```bash
kubectl describe pod -n monitoring -l app.kubernetes.io/name=uptime-kuma
kubectl logs -n monitoring -l app.kubernetes.io/name=uptime-kuma
```

Common issues:
- PVC not bound (check NFS CSI driver)
- Resource limits too low

### Browser extension won't connect

Uptime Kuma requires HTTPS for browser extensions.

**Options:**
1. Use cert-manager to issue real TLS cert
2. Access via IP: `http://192.168.2.244` (if Traefik has external IP)
3. Trust self-signed cert in browser

### Monitors show "Down" but service works

**DNS issue** - Uptime Kuma can't resolve hostnames.

Fix: Update deployment to use your Pi-hole for DNS:

```yaml
# values.yaml
controllers:
  uptime-kuma:
    pod:
      dnsConfig:
        nameservers:
          - 192.168.2.53  # Your Pi-hole
```

Redeploy: `./deploy.sh`

## Resource Usage

Tested on 2-worker cluster (2 vCPU, 4 GB RAM per worker):

- **CPU:** <1% idle, ~5% during checks (50 monitors)
- **Memory:** ~120 MB
- **Storage:** 500 MB (SQLite + assets)

## Teardown

```bash
helm uninstall uptime-kuma -n monitoring
kubectl delete namespace monitoring
```

## References

- [Uptime Kuma GitHub](https://github.com/louislam/uptime-kuma)
- [Uptime Kuma Wiki](https://github.com/louislam/uptime-kuma/wiki)
- [bjw-s app-template docs](https://bjw-s-labs.github.io/helm-charts/docs/app-template/)
- [Blog post: Network Monitoring with Uptime Kuma](https://foggyclouds.io/post/k8s-uptime-kuma/)

## License

MIT
