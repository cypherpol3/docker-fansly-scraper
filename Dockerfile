# syntax=docker/dockerfile:1

FROM golang:1.25-alpine3.22 AS builder

RUN apk add --no-cache git ca-certificates

ARG FANSLY_SCRAPER_VERSION=latest

RUN CGO_ENABLED=0 GOPROXY=direct go install \
    github.com/agnosto/fansly-scraper/cmd/fansly-scraper@${FANSLY_SCRAPER_VERSION}


FROM alpine:3.22

LABEL org.opencontainers.image.title="docker-fansly-scraper" \
      org.opencontainers.image.description="Docker image for agnosto/fansly-scraper" \
      org.opencontainers.image.url="https://github.com/cypherpol3/docker-fansly-scraper" \
      org.opencontainers.image.source="https://github.com/cypherpol3/docker-fansly-scraper"

RUN apk add --no-cache \
    ca-certificates \
    ffmpeg \
    flock \
    nano \
    su-exec \
    tzdata

COPY --from=builder /go/bin/fansly-scraper /usr/local/bin/fansly-scraper
COPY defaults/config.toml /defaults/config.toml
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENV XDG_CONFIG_HOME=/var/lib
ENV EDITOR=nano
ENV PUID=1000 PGID=1000
ENV HOME=/config

# The scraper appends "fansly-scraper" to XDG_CONFIG_HOME.
RUN mkdir -p /config /data \
    && ln -s /config /var/lib/fansly-scraper

WORKDIR /data

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
