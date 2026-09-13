# docker-fansly-scraper

Docker image for agnosto/fansly-scraper.

## Docker Compose

After the image is published to Docker Hub, use this `compose.yaml` (adapt the
host paths to your NAS):

```yaml
services:
  fansly-scraper:
    image: cypherpol3/docker-fansly-scraper:latest
    container_name: fansly-scraper
    volumes:
      - /mnt/tank/appdata/fansly-scraper:/config
      - /mnt/tank/downloads/fansly:/data
    stdin_open: true
    tty: true
    restart: unless-stopped
```

Create both host directories. You can place your personal `config.toml` in
`/mnt/tank/appdata/fansly-scraper` before starting; it will not be replaced by
the startup script. In that file, use:

```toml
[options]
save_location = "/data"

[live_settings]
save_location = ""
```

Update these fields in the existing sections; keep your other settings.
The empty live path uses `/data/<creator>/lives/`.
Keep `config.toml` out of `/data`.

If no configuration exists, the image copies a template into `/config/config.toml`
and starts the scraper. The template is based on the upstream
[example](https://github.com/agnosto/fansly-scraper/blob/main/example-config.toml),
with downloads under `/data`.

The interactive setup can still ask for a save path:
choose a custom path of `/data`. Alternatively, stop the container, fill in
`auth_token` and `user_agent` in the generated file, then start it again.
The template alone does not provide a working authenticated configuration.

```sh
docker compose up -d
docker attach fansly-scraper
```

Detach from the menu with `Ctrl+P`, then `Ctrl+Q`, leaving the container running.
Restarting the container does not itself select monitoring actions in the menu.

`/config` persists configuration and state; `/data` persists downloads.
To edit configuration externally, stop the service with `docker compose stop`,
edit the host file, then run `docker compose up -d` again.

The image currently runs as root; `PUID` and `PGID` are not implemented yet.
