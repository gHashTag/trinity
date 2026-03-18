# TRINITY OMEGA — Pre-compiled statically-linked binary
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
RUN useradd -m -u 1000 trinity
WORKDIR /home/trinity/.trinity
COPY zig-out/bin/tri /usr/local/bin/tri
COPY zig-out/bin/vibee /usr/local/bin/vibee
USER trinity
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/tri"]
CMD ["serve", "--port", "8080"]
