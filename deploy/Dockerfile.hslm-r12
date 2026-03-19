# hslm-r12 canary service — use prebuilt image from ghcr.io
# Bypasses Railway snapshot issues

FROM ghcr.io/ghashtag/trinity-hslm:latest

WORKDIR /data
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/hslm-entrypoint"]
