#!/bin/sh
# Run ONLY in a disposable container, with no personal /config or /data mounts.
set -eu
entrypoint=/usr/local/bin/docker-entrypoint.sh
passed=0

reset_fixture() {
    rm -rf /config /data /tmp/mock-bin
    mkdir -p /config /data
    chown 1000:1000 /config /data
}

expect_error() {
    label=$1
    expected=$2
    shift 2
    if "$@" >/tmp/result 2>&1; then
        echo "FAIL: $label unexpectedly succeeded"; exit 1
    else
        status=$?
    fi
    if [ "$status" -ne 1 ] || ! grep -Fq "$expected" /tmp/result; then
        echo "FAIL: $label (exit $status)"; cat /tmp/result; exit 1
    fi
    passed=$((passed + 1))
    echo "PASS: $label"
}

sh -n "$entrypoint"
for variable in PUID PGID; do
    for value in '' abc -1 0 2147483648 999999999999999999999999999; do
        expect_error "$variable=$value" 'must be integers between 1 and 2147483647' env "$variable=$value" "$entrypoint" --help
    done
done

for directory in /config /data; do
    reset_fixture
    chown 0:0 "$directory"
    # Simulate chown failure while leaving the other preparation steps real.
    mkdir /tmp/mock-bin
    printf '#!/bin/sh\nexit 1\n' >/tmp/mock-bin/chown
    chmod 755 /tmp/mock-bin/chown
    expect_error "cannot prepare $directory" "Cannot prepare $directory" env PATH=/tmp/mock-bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin "$entrypoint" --help
done

reset_fixture
expect_error 'UID mismatch' 'Container user does not match' su-exec 2000:1000 "$entrypoint" --help
expect_error 'GID mismatch' 'Container user does not match' su-exec 1000:2000 "$entrypoint" --help

for directory in /config /data; do
    reset_fixture
    chmod 500 "$directory"
    expect_error "unwritable $directory" "$directory is not writable" su-exec 1000:1000 "$entrypoint" --help
done

reset_fixture
ln -s /tmp/elsewhere /config/.container.lock
expect_error 'instance lock symlink' '.container.lock must not be a symbolic link' "$entrypoint" --help

reset_fixture
touch /config/.container.lock
chown 1000:1000 /config/.container.lock
flock --no-fork /config/.container.lock sh -c 'touch /tmp/lock-ready; exec sleep 30' &
holder=$!
while [ ! -f /tmp/lock-ready ]; do sleep 0.1; done
printf '1' >/config/monitor.pid
expect_error 'exclusive lock conflict' 'Another instance is using /config' "$entrypoint" --help
test "$(cat /config/monitor.pid)" = 1
kill "$holder"
wait "$holder" 2>/dev/null || true

reset_fixture
mkdir /tmp/mock-bin
printf '#!/bin/sh\nexit 70\n' >/tmp/mock-bin/flock
chmod 755 /tmp/mock-bin/flock
expect_error 'flock technical failure' 'Cannot lock /config (flock exit 70)' env PATH=/tmp/mock-bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin "$entrypoint" --help

reset_fixture
ln -s /missing /config/config.toml
expect_error 'broken configuration symlink' 'config.toml is a broken symbolic link' "$entrypoint" --help

for mode in 200 400; do
    reset_fixture
    cp /defaults/config.toml /config/config.toml
    chown 1000:1000 /config/config.toml
    chmod "$mode" /config/config.toml
    expect_error "configuration permissions $mode" 'must be a readable and writable file' "$entrypoint" --help
done
reset_fixture
mkdir /config/config.toml
expect_error 'configuration is a directory' 'must be a readable and writable file' "$entrypoint" --help

reset_fixture
ln -s /tmp /config/active_recordings
expect_error 'recording directory symlink' 'active_recordings must not be a symbolic link' "$entrypoint" --help

for marker in /config/monitor.pid /config/active_recordings/test.lock; do
    reset_fixture
    mkdir -p "$marker"
    expect_error "marker is directory: $marker" 'Expected a runtime file, found a directory' "$entrypoint" --help
done

reset_fixture
mkdir /config/active_recordings
printf '1' >/config/active_recordings/test.lock
chmod 555 /config/active_recordings
expect_error 'marker deletion denied' 'Cannot remove stale runtime file' "$entrypoint" --help

reset_fixture
chown 0:0 /config
chmod 1777 /config
printf '1' >/config/monitor.pid
expect_error 'PID deletion denied (sticky directory)' 'Cannot remove stale runtime file: /config/monitor.pid' "$entrypoint" --help

reset_fixture
"$entrypoint" --help >/tmp/help 2>&1
test "$(stat -c %u:%g /config/config.toml)" = 1000:1000
cmp /defaults/config.toml /config/config.toml
cp /config/config.toml /tmp/original
printf '{}' >/config/monitoring_state.json
printf 'keep' >/data/keep.txt
mkdir /config/active_recordings
chown 1000:1000 /config/active_recordings
printf '1' >/config/monitor.pid
printf '1' >/config/active_recordings/test.lock
"$entrypoint" --help >/tmp/help 2>&1
test ! -e /config/monitor.pid
test ! -e /config/active_recordings/test.lock
cmp /tmp/original /config/config.toml
test "$(cat /config/monitoring_state.json)" = '{}'
test "$(cat /data/keep.txt)" = keep
echo "PASS: successful startup, ownership, cleanup and persistent files preserved"
echo "$passed expected errors verified (exit code and message)."
