FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install openXC7 toolchain via snap-like installer
RUN apt-get update && apt-get install -y \
    wget bash git python3 python3-pip make \
    libffi-dev libreadline-dev bison flex \
    tcl-dev libboost-all-dev clang lld \
    && rm -rf /var/lib/apt/lists/*

# Install pre-built openXC7 from snap
RUN wget -qO - https://raw.githubusercontent.com/openXC7/toolchain-installer/main/toolchain-installer.sh | bash || true

# Create workspace
RUN mkdir -p /workspace/output

WORKDIR /workspace
