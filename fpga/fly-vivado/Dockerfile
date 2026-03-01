FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install dependencies for Vivado + expect for auth
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    wget \
    xz-utils \
    libncurses5 \
    libtinfo5 \
    libx11-6 \
    libxext6 \
    libxrender1 \
    libxtst6 \
    libxi6 \
    libfreetype6 \
    fontconfig \
    locales \
    python3 \
    openssh-server \
    sudo \
    net-tools \
    expect \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

# Generate SSH host keys and configure
RUN mkdir -p /run/sshd && \
    ssh-keygen -A && \
    echo 'root:vivado' | chpasswd && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Create workspace
RUN mkdir -p /workspace/verilog /workspace/output /vivado

# Copy Vivado web installer
COPY FPGAs_AdaptiveSoCs_Unified_SDI_2025.2_1114_2157_Lin64.bin /opt/vivado_install.bin
RUN chmod +x /opt/vivado_install.bin

# Copy expect automation script
COPY setup_and_synth.exp /opt/setup_and_synth.exp
RUN chmod +x /opt/setup_and_synth.exp

# Copy startup script
COPY startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh

# Copy project files
COPY verilog/ /workspace/verilog/
COPY tcl/ /workspace/tcl/
COPY constraints/ /workspace/constraints/

# Working directory
WORKDIR /workspace

CMD ["/opt/startup.sh"]
