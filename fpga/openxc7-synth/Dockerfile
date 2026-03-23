# FPGA Synthesis Tools — Trinity Project
# Contains Yosys synthesis pipeline

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    wget python3 python3-pip make git \
    libffi-dev libreadline-dev bison flex \
    tcl-dev libboost-all-dev clang lld \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install Yosys (open source)
RUN cd /opt && \
    git clone --recurse-submodules https://github.com/YosysHQ/yosys.git && \
    cd yosys && \
    make -j$(nproc) && \
    make install

# Verify installation
RUN which yosys

# Create workspace
WORKDIR /workspace

# Copy design files
COPY *.v *.xdc /workspace/

CMD ["/bin/bash", "-l"]
