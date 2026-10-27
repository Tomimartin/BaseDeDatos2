#!/usr/bin/env bash

set -u
set -o pipefail

DB_NAME="${PGDATABASE:-foodstorecopia}"
DB_HOST="${PGHOST:-localhost}"
DB_PORT="${PGPORT:-5432}"
DB_USER="${PGUSER:-postgres}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$BASE_DIR/backups}"
LOG_DIR="${LOG_DIR:-$BASE_DIR/logs}"
LOG_FILE="$LOG_DIR/backup.log"

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    printf '[%s] %s\n' "$(timestamp)" "$*" >> "$LOG_FILE"
}

if ! mkdir -p "$BACKUP_DIR" "$LOG_DIR"; then
    printf 'ERROR: no se pudieron crear los directorios %s o %s\n' "$BACKUP_DIR" "$LOG_DIR" >&2
    exit 1
fi

if ! touch "$LOG_FILE"; then
    printf 'ERROR: no se pudo escribir el archivo de log %s\n' "$LOG_FILE" >&2
    exit 1
fi

if ! command -v pg_dump >/dev/null 2>&1; then
    log "FALLA: pg_dump no está disponible en PATH"
    exit 127
fi

STAMP="$(date '+%Y%m%d_%H%M%S')"
BACKUP_FILE="$BACKUP_DIR/foodstore_${STAMP}.dump"

log "INICIO respaldo base=$DB_NAME host=$DB_HOST puerto=$DB_PORT usuario=$DB_USER archivo=$BACKUP_FILE"

pg_dump \
    --format=custom \
    --file="$BACKUP_FILE" \
    --dbname="$DB_NAME" \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --username="$DB_USER" \
    --no-password \
    >>"$LOG_FILE" 2>&1

status=$?

if [ "$status" -ne 0 ]; then
    log "FALLA respaldo base=$DB_NAME archivo=$BACKUP_FILE codigo=$status"
    rm -f -- "$BACKUP_FILE"
    exit "$status"
fi

if [ ! -s "$BACKUP_FILE" ]; then
    log "FALLA respaldo base=$DB_NAME archivo=$BACKUP_FILE motivo=archivo_vacio codigo=1"
    rm -f -- "$BACKUP_FILE"
    exit 1
fi

SIZE_BYTES="$(wc -c < "$BACKUP_FILE" | tr -d ' ')"
log "ÉXITO respaldo base=$DB_NAME archivo=$BACKUP_FILE bytes=$SIZE_BYTES codigo=0"

exit 0
