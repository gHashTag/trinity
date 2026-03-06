# TRINITY CLI - Simple Demo
FROM ubuntu:22.04
RUN apt-get update && \
    apt-get install -y ca-certificates libglib2.0-0 python3 && \
    useradd -m -u 1000 trinity && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /home/trinity/.trinity
COPY tri-demo.py /usr/local/bin/tri-demo
RUN chmod +x /usr/local/bin/tri-demo
USER trinity
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/tri-demo"]
