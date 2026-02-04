FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install Zig compiler (0.13.0)
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        curl \
        xz-utils \
    && curl -L https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz -o /tmp/zig.tar.xz \
    && tar -xf /tmp/zig.tar.xz -C /opt \
    && ln -s /opt/zig-linux-x86_64-0.13.0/zig /usr/local/bin/zig \
    && rm /tmp/zig.tar.xz \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Verify Zig installation
RUN zig version

# Install Node.js for Playwright bridge (WebArena agent)
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        nodejs \
        npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Verify Node.js installation
RUN node --version && npm --version
