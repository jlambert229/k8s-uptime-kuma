#!/bin/bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-monitoring}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Backing up Uptime Kuma ==="

# Get pod name
POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=uptime-kuma -o jsonpath='{.items[0].metadata.name}')

if [[ -z "$POD" ]]; then
    echo "❌ No Uptime Kuma pod found in namespace $NAMESPACE"
    exit 1
fi

echo "Pod: $POD"
echo "Backup directory: $BACKUP_DIR"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup database using SQLite .backup command (proper way)
echo "Backing up database..."
kubectl exec -n "$NAMESPACE" "$POD" -- sqlite3 /app/data/kuma.db ".backup /tmp/kuma-backup.db"
kubectl cp -n "$NAMESPACE" "$POD:/tmp/kuma-backup.db" "$BACKUP_DIR/kuma-${TIMESTAMP}.db"
kubectl exec -n "$NAMESPACE" "$POD" -- rm /tmp/kuma-backup.db

echo "✅ Database backup saved: $BACKUP_DIR/kuma-${TIMESTAMP}.db"

# Get backup size
SIZE=$(du -h "$BACKUP_DIR/kuma-${TIMESTAMP}.db" | cut -f1)
echo "   Size: $SIZE"
echo ""

# Keep last 30 backups
echo "Cleaning old backups (keeping last 30)..."
ls -t "$BACKUP_DIR"/kuma-*.db | tail -n +31 | xargs -r rm
REMAINING=$(ls -1 "$BACKUP_DIR"/kuma-*.db 2>/dev/null | wc -l)
echo "✅ Backups remaining: $REMAINING"
echo ""

echo "=== Backup complete ==="
echo ""
echo "To restore:"
echo "  1. Scale down: kubectl scale -n $NAMESPACE deploy/uptime-kuma --replicas=0"
echo "  2. Copy backup: kubectl cp $BACKUP_DIR/kuma-${TIMESTAMP}.db $NAMESPACE/<pod>:/app/data/kuma.db"
echo "  3. Scale up: kubectl scale -n $NAMESPACE deploy/uptime-kuma --replicas=1"
