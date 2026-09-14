#!/bin/sh
set -eu

fail() {
    echo "Error: $*" >&2
    exit 1
}

for value in "$PUID" "$PGID"; do
    case "$value" in
        ''|*[!0-9]*) fail "PUID and PGID must be integers between 1 and 2147483647." ;;
    esac
    [ "$value" -ge 1 ] 2>/dev/null && [ "$value" -le 2147483647 ] 2>/dev/null \
        || fail "PUID and PGID must be integers between 1 and 2147483647."
done

if [ "$(id -u)" -eq 0 ]; then
    mkdir -p /config /data
    for directory in /config /data; do
        # Only adjust the mount root if the selected user cannot write there.
        if ! su-exec "$PUID:$PGID" sh -c 'test -w "$1" && test -x "$1"' sh "$directory"; then
            chown "$PUID:$PGID" "$directory" \
                || fail "Cannot prepare $directory for $PUID:$PGID. Check host permissions or ACLs."
        fi
    done
    exec su-exec "$PUID:$PGID" env HOME=/config "$0" "$@"
fi

[ "$(id -u)" -eq "$PUID" ] && [ "$(id -g)" -eq "$PGID" ] \
    || fail "Container user does not match PUID:PGID ($PUID:$PGID). Remove user: or --user, or align the IDs."

for directory in /config /data; do
    [ -w "$directory" ] && [ -x "$directory" ] \
        || fail "$directory is not writable by $PUID:$PGID. Check host permissions or ACLs."
done

# Keep this descriptor open across exec: the kernel releases the lock on exit,
# including SIGKILL. Never delete this file: all instances must lock the same inode.
[ ! -L /config/.container.lock ] || fail "/config/.container.lock must not be a symbolic link."
exec 9>>/config/.container.lock
if flock -n -E 75 9; then
    :
else
    lock_status=$?
    if [ "$lock_status" -eq 75 ]; then
        fail "Another instance is using /config. Stop it before starting this container."
    fi
    fail "Cannot lock /config (flock exit $lock_status). Check filesystem locking support and permissions."
fi

if [ ! -e /config/config.toml ]; then
    [ ! -L /config/config.toml ] || fail "/config/config.toml is a broken symbolic link."
    (umask 077; cp /defaults/config.toml /config/config.toml)
    echo "Created /config/config.toml. Fill in your account settings before using fansly-scraper."
fi

[ -f /config/config.toml ] && [ -r /config/config.toml ] && [ -w /config/config.toml ] \
    || fail "/config/config.toml must be a readable and writable file for $PUID:$PGID. Check its host permissions."

# With exclusive access established, old process IDs cannot describe this run.
# Only remove runtime markers, never monitoring_state.json or recording data.
[ ! -L /config/active_recordings ] \
    || fail "/config/active_recordings must not be a symbolic link."
for marker in /config/monitor.pid /config/active_recordings/*.lock; do
    [ -e "$marker" ] || [ -L "$marker" ] || continue
    [ ! -d "$marker" ] || fail "Expected a runtime file, found a directory: $marker"
    rm -f -- "$marker" || fail "Cannot remove stale runtime file: $marker"
    echo "Removed stale runtime file: $marker"
done

exec /usr/local/bin/fansly-scraper "$@"
