FROM debian:bookworm-slim

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg2 \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    librtlsdr-dev \
    rtl-sdr \
    python3 \
    python3-pip \
    python3-venv \
    git \
    build-essential \
    debhelper \
    libncurses-dev \
    pkg-config \
    libusb-1.0-0-dev \
    libzstd-dev \
    zlib1g-dev \
    supervisor \
    procps \
    net-tools \
    usbutils \
    nginx \
    collectd \
    librrd-dev \
    rrdtool \
    && rm -rf /var/lib/apt/lists/*

# Create a fake systemctl to handle install scripts that try to use systemd
RUN printf '#!/bin/bash\necho "systemctl $@"\nexit 0\n' > /usr/bin/systemctl && \
    chmod +x /usr/bin/systemctl

# Create necessary directories
RUN mkdir -p /etc/wingbits \
    /var/log/wingbits \
    /var/globe_history \
    /run/readsb \
    /run/collectd

# Install readsb (ignore systemd errors during build)
RUN curl -sL https://github.com/wiedehopf/adsb-scripts/raw/master/readsb-install.sh -o /tmp/readsb-install.sh && \
    chmod +x /tmp/readsb-install.sh && \
    bash /tmp/readsb-install.sh || true && \
    rm /tmp/readsb-install.sh

# Install graphs1090 (ignore systemd errors during build)
RUN curl -sL https://github.com/wiedehopf/graphs1090/raw/master/install.sh -o /tmp/graphs1090-install.sh && \
    chmod +x /tmp/graphs1090-install.sh && \
    bash /tmp/graphs1090-install.sh || true && \
    rm /tmp/graphs1090-install.sh

# Remove fake systemctl
RUN rm /usr/bin/systemctl

# Install wingbits client
RUN GOOS="linux" && \
    GOARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/;s/armv7l/arm/') && \
    WINGBITS_PATH="/usr/local/bin" && \
    BINARY_NAME="wingbits" && \
    mkdir -p "$WINGBITS_PATH" && \
    curl -s -o /tmp/latest.json "https://install.wingbits.com/$GOOS-$GOARCH.json" && \
    version=$(grep -o '"Version": "[^"]*"' /tmp/latest.json | cut -d'"' -f4) && \
    curl -s -o "$WINGBITS_PATH/$BINARY_NAME.gz" "https://install.wingbits.com/$version/$GOOS-$GOARCH.gz" && \
    gunzip "$WINGBITS_PATH/$BINARY_NAME.gz" && \
    chmod +x "$WINGBITS_PATH/$BINARY_NAME" && \
    rm /tmp/latest.json

# Configure readsb for wingbits
RUN if ! grep -q -- "--net-connector localhost,30006,json_out" /etc/default/readsb 2>/dev/null; then \
        echo 'NET_OPTIONS="--net --net-heartbeat 60 --net-ro-size 1280 --net-ro-interval 0.2 --net-ro-port 30002 --net-sbs-port 30003 --net-bi-port 30004,30104 --net-bo-port 30005 --net-connector localhost,30006,json_out"' >> /etc/default/readsb; \
    fi

# Change readsb service restart to 60sec (if file exists)
RUN if [ -f /lib/systemd/system/readsb.service ]; then \
        sed -i 's/RestartSec=15/RestartSec=60/' /lib/systemd/system/readsb.service; \
    fi

# Create supervisor configuration
RUN mkdir -p /etc/supervisor/conf.d

# Copy configuration files
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose ports
# 8080 - tar1090 web interface
# 30001-30005 - readsb ports
# 80 - graphs1090 web interface
EXPOSE 8080 30001 30002 30003 30004 30005 80

# Set working directory
WORKDIR /etc/wingbits

# Use entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

