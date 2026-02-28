# TRINITY OMEGA — Multi-arch Docker Image
FROM ziglang/zig:ubuntu-latest AS builder
RUN apt-get update && apt-get install -y git pkg-config
WORKDIR /src
COPY . .
RUN zig build tri
RUN zig build vibee

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y ca-certificates libglib2.0-0 && rm -rf /var/lib/apt/lists/*
RUN useradd -m -u 1000 trinity
WORKDIR /home/trinity/.trinity
COPY --from=builder /src/zig-out/bin/tri /usr/local/bin/tri
COPY --from=builder /src/zig-out/bin/vibee /usr/local/bin/vibee
USER trinity
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/tri"]
CMD ["--help"]
