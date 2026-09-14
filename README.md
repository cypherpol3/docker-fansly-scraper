# docker-fansly-scraper

Docker image for [agnosto/fansly-scraper](https://github.com/agnosto/fansly-scraper).

For account setup and scraper features, see the project's [documentation](https://github.com/agnosto/fansly-scraper#readme) and [configuration guide](https://github.com/agnosto/fansly-scraper/blob/main/config.md).

## Docker Compose

Save the following as `compose.yaml`, replacing the host paths with your configuration and download folders:

```yaml
services:
  fansly-scraper:
    image: cypherpol3/docker-fansly-scraper:latest
    container_name: fansly-scraper
    environment:
      PUID: "1000"
      PGID: "1000"
      TZ: "Etc/UTC"
    volumes:
      - /path/to/config:/config
      - /path/to/downloads:/data
    stdin_open: true
    tty: true
    restart: unless-stopped
    stop_grace_period: 30s
```

`PUID`/`PGID` default to `1000:1000`; adapt them to your folder permissions. Existing files must be readable and writable by that user. Set `TZ` to your timezone if desired.

Start and access the menu:

```sh
docker compose up -d
docker attach fansly-scraper
```

Detach with **Ctrl+P, then Ctrl+Q** to keep it running. This disconnects your terminal while the scraper and any active monitoring continue in the background. Run `docker attach fansly-scraper` again to return to the interface. See [Docker attach](https://docs.docker.com/reference/cli/docker/container/attach/) for details.

## Configuration

Mount your settings folder at `/config` and downloads at `/data`. An existing `/config/config.toml` is kept; otherwise, the image creates one from the [default template](defaults/config.toml).

In your configuration, use:

```toml
[options]
save_location = "/data"

[live_settings]
save_location = ""
```

The empty live path uses `/data/<creator>/lives/`. If the setup wizard asks for a folder, choose a custom path of `/data`.

Container-specific notes:

- Automatic browser capture is not supported in this setup. Enter your account details through the setup wizard, edit `/config/config.toml`, or reuse an existing configuration.
- To reuse saved monitoring selections, copy `monitoring_state.json` into `/config` as well.
- Application logs are stored at `/data/.logs/fansly-scraper.log`.

## Optional: automatic monitoring

The default mode opens the menu; it does **not** automatically resume recordings after a restart. For unattended monitoring, first configure your account and select creators, then add the following under the `fansly-scraper` service, at the same indentation level as `image`:

```yaml
command: ["monitor", "start"] # Resume saved monitoring whenever the container starts
```

Apply with `docker compose up -d`. This mode has no menu, even if `stdin_open` and `tty` are present; those two settings can be omitted.

To change selections while using this mode:

```sh
docker compose stop fansly-scraper
docker compose run --rm --no-deps --entrypoint /bin/sh fansly-scraper -c 'exec /usr/local/bin/docker-entrypoint.sh'
```

Quit the temporary menu instance, then run `docker compose up -d` to resume monitoring. See [Docker Compose run](https://docs.docker.com/reference/cli/docker/compose/run/) for one-off commands.

## Storage and restart notes

- Only one instance may use the same `/config` at a time. Do not bypass the startup script to run another scraper against that folder.
- Do not delete `/config/.container.lock` while running. Its presence after shutdown is normal. Storage must support file locking; some network shares have restrictions.
- Stale PID and recording markers are removed at startup. Settings and downloads are preserved; a recording interrupted by a forced stop may be incomplete.
- For permission errors, check host ownership/ACLs and existing files. The image does not recursively change ownership. Avoid `user:`/`--user` unless it matches `PUID:PGID`.

## Build and test

```sh
docker build -t fansly-scraper .
python tests/entrypoint_errors.py
```

For a local build, use `image: fansly-scraper` in Compose. Tests require Python 3 (`python3` on some systems); use `--image your-image:tag` for another image. They run without network or personal data mounts, and cover startup errors and file preservation. Some technical failures are simulated.
