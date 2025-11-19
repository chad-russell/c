#!/usr/bin/env bash
# ------------------------------------------------------------
# docker-backup.sh – backup or restore Docker volumes
#
# Usage:
#   docker-backup.sh backup  <container> <volume1> [<volume2> ...]
#   docker-backup.sh restore <container> <archive-dir>
#
#   * backup  – stops the container, tars each volume into
#               $BACKUP_ROOT/<container>/<timestamp>-<vol>.tar.gz,
#               then starts the container again.
#   * restore – runs a temporary Alpine container that untars the
#               archives back into the Docker volumes (container
#               must already be running or you can start it first).
# ------------------------------------------------------------

set -euo pipefail

# ----------------------------------------------------------------
# Configurable paths – adjust if you mount the NFS share elsewhere
# ----------------------------------------------------------------
BACKUP_ROOT="/mnt/backups/containers"   # <-- same path used by containerBackup
# ----------------------------------------------------------------

cmd="${1:-}"
shift || true

if [[ "$cmd" == "backup" ]]; then
    CONTAINER="${1}"
    shift
    VOLUMES=("$@")
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    DEST="${BACKUP_ROOT}/${CONTAINER}"
    mkdir -p "$DEST"

    echo "🔴 Stopping container ${CONTAINER} ..."
    docker stop "$CONTAINER"

    for vol in "${VOLUMES[@]}"; do
        echo "📦 Backing up volume ${vol} ..."
        docker run --rm \
            -v "${vol}":/data:ro \
            -v "$DEST":/backup \
            alpine:latest \
            tar czf "/backup/${TIMESTAMP}-${vol}.tar.gz" -C /data .
    done

    echo "🟢 Starting container ${CONTAINER} ..."
    docker start "$CONTAINER"

    echo "✅ Backup of ${CONTAINER} finished. Files are in $DEST"
    exit 0
fi

if [[ "$cmd" == "restore" ]]; then
    CONTAINER="${1}"
    ARCHIVE_DIR="${2}"
    if [[ ! -d "$ARCHIVE_DIR" ]]; then
        echo "❌ Archive directory $ARCHIVE_DIR does not exist"
        exit 1
    fi

    echo "🔄 Restoring volumes for ${CONTAINER} from $ARCHIVE_DIR ..."
    for archive in "$ARCHIVE_DIR"/*.tar.gz; do
        vol=$(basename "$archive" | sed -E "s/^[0-9-]+-//;s/\.tar\.gz$//")
        echo "   ↳ Restoring $vol from $(basename "$archive")"
        docker run --rm \
            -v "${vol}":/data \
            -v "$ARCHIVE_DIR":/restore \
            alpine:latest \
            sh -c "cd /data && tar xzf /restore/$(basename "$archive")"
    done

    echo "✅ Restore complete."
    exit 0
fi

echo "Usage: $0 {backup|restore} ..."
exit 2
