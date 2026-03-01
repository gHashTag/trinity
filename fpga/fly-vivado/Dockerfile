FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install dependencies for Vivado (including pixman and other runtime libs)
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
    expect \
    libpixman-1-0 \
    libglib2.0-0 \
    libsm6 \
    libice6 \
    libxft2 \
    libxrandr2 \
    libxcursor1 \
    libxinerama1 \
    libfontconfig1 \
    libcairo2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgtk2.0-0 \
    libnss3 \
    libatk1.0-0 \
    libdbus-1-3 \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

# Create workspace
RUN mkdir -p /workspace/verilog /workspace/output /vivado

# Copy expect automation script (for auth token gen only)
COPY setup_and_synth.exp /opt/setup_and_synth.exp
RUN chmod +x /opt/setup_and_synth.exp

# Copy install config
COPY install_config.txt /opt/install_config.txt

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
