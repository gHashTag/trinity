# FPGA Synthesis Tools — Trinity Project
# Contains Yosys, nextpnr-xilinx, fasm2frames, xc7patch

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    wget python3 python3-pip make git \
    libffi-dev libreadline-dev bison flex \
    tcl-dev libboost-all-dev clang lld \
    && rm -rf /var/lib/apt/lists/*

# Install Yosys (open source)
RUN cd /opt && \
    git clone --recurse-submodules https://github.com/YosysHQ/yosys.git && \
    cd yosys && \
    make -j$(nproc) && \
    make install

# Install FPGA synthesis tools from pip
RUN pip3 install --break-system-packages \
    nextpnr-xilinx \
    fasm2frames \
    xc7patch

# Verify installation
RUN which yosys nextpnr-xilinx fasm2frames xc7patch

# Create workspace
WORKDIR /workspace

# Copy design files
COPY *.v *.xdc /workspace/

CMD ["/bin/bash", "-l"]
