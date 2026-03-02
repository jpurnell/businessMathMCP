# BusinessMath MCP Server - Unix/Linux Production Deployment Guide

Complete guide for deploying the BusinessMath library and MCP server on a generic Unix/Linux system for production use.

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Swift Installation](#swift-installation)
3. [Installing Dependencies](#installing-dependencies)
4. [Building BusinessMath Library](#building-businessmath-library)
5. [Building MCP Server](#building-mcp-server)
6. [Running as a System Service](#running-as-a-system-service)
7. [Security Considerations](#security-considerations)
8. [Monitoring and Logging](#monitoring-and-logging)
9. [Troubleshooting](#troubleshooting)
10. [Performance Tuning](#performance-tuning)

## System Requirements

### Minimum Requirements

- **OS**: Linux (Ubuntu 20.04+, Debian 11+, RHEL 8+, or compatible)
- **CPU**: x86_64 or ARM64 (aarch64)
- **RAM**: 4GB minimum, 8GB recommended
- **Disk**: 2GB for Swift toolchain + 500MB for build artifacts
- **Permissions**: sudo access for initial setup

### Supported Platforms

Tested on:
- Ubuntu 22.04 LTS (x86_64, ARM64)
- Debian 12 (x86_64)
- Red Hat Enterprise Linux 9 (x86_64)
- Amazon Linux 2023 (x86_64, ARM64)
- macOS 13+ (development reference)

## Swift Installation

### Ubuntu/Debian

```bash
# Update package lists
sudo apt-get update

# Install dependencies
sudo apt-get install -y \
  binutils \
  git \
  gnupg2 \
  libc6-dev \
  libcurl4-openssl-dev \
  libedit2 \
  libgcc-9-dev \
  libpython3.8 \
  libsqlite3-0 \
  libstdc++-9-dev \
  libxml2-dev \
  libz3-dev \
  pkg-config \
  tzdata \
  unzip \
  zlib1g-dev

# Download Swift 6.0 (update URL for latest version)
cd /tmp
wget https://download.swift.org/swift-6.0-release/ubuntu2204/swift-6.0-RELEASE/swift-6.0-RELEASE-ubuntu22.04.tar.gz

# Verify signature (recommended)
wget https://download.swift.org/swift-6.0-release/ubuntu2204/swift-6.0-RELEASE/swift-6.0-RELEASE-ubuntu22.04.tar.gz.sig
wget -q -O - https://swift.org/keys/all-keys.asc | gpg --import -
gpg --verify swift-6.0-RELEASE-ubuntu22.04.tar.gz.sig

# Extract to /opt
sudo tar xzf swift-6.0-RELEASE-ubuntu22.04.tar.gz -C /opt

# Add to PATH
echo 'export PATH=/opt/swift-6.0-RELEASE-ubuntu22.04/usr/bin:$PATH' | sudo tee /etc/profile.d/swift.sh
source /etc/profile.d/swift.sh

# Verify installation
swift --version
```

### Red Hat Enterprise Linux / CentOS / Rocky Linux

```bash
# Install dependencies
sudo dnf install -y \
  binutils \
  gcc \
  git \
  glibc-static \
  libbsd-devel \
  libedit-devel \
  libicu-devel \
  libstdc++-static \
  pkg-config \
  python3 \
  sqlite \
  zlib-devel

# Download and install Swift (using RHEL 9 packages)
cd /tmp
wget https://download.swift.org/swift-6.0-release/rhel9/swift-6.0-RELEASE/swift-6.0-RELEASE-rhel9.tar.gz

# Extract
sudo tar xzf swift-6.0-RELEASE-rhel9.tar.gz -C /opt

# Add to PATH
echo 'export PATH=/opt/swift-6.0-RELEASE-rhel9/usr/bin:$PATH' | sudo tee /etc/profile.d/swift.sh
source /etc/profile.d/swift.sh

# Verify
swift --version
```

### Amazon Linux 2023

```bash
# Install dependencies
sudo dnf install -y \
  binutils \
  gcc \
  git \
  glibc-devel \
  glibc-static \
  libbsd-devel \
  libedit-devel \
  libicu-devel \
  libstdc++-devel \
  libstdc++-static \
  libxml2-devel \
  pkg-config \
  python3 \
  sqlite-devel \
  tar \
  tzdata \
  unzip \
  zip \
  zlib-devel

# Use RHEL 9 packages (Amazon Linux 2023 is compatible)
cd /tmp
wget https://download.swift.org/swift-6.0-release/rhel9/swift-6.0-RELEASE/swift-6.0-RELEASE-rhel9.tar.gz
sudo tar xzf swift-6.0-RELEASE-rhel9.tar.gz -C /opt

# Configure PATH
echo 'export PATH=/opt/swift-6.0-RELEASE-rhel9/usr/bin:$PATH' | sudo tee /etc/profile.d/swift.sh
source /etc/profile.d/swift.sh

swift --version
```

## Installing Dependencies

The BusinessMath library requires Swift Numerics. The Swift Package Manager will automatically download and build dependencies during the build process.

### Optional: Install Build Tools

For faster builds and better performance:

```bash
# Install ccache for faster rebuilds
sudo apt-get install -y ccache  # Ubuntu/Debian
sudo dnf install -y ccache      # RHEL/Amazon Linux

# Configure Swift to use ccache
export CC="ccache clang"
export CXX="ccache clang++"
```

## Building BusinessMath Library

### Clone the Repository

```bash
# Create deployment directory
sudo mkdir -p /opt/businessmath
sudo chown $USER:$USER /opt/businessmath
cd /opt/businessmath

# Clone repository
git clone https://github.com/yourusername/BusinessMath.git
cd BusinessMath

# Or if deploying from a specific release
wget https://github.com/yourusername/BusinessMath/archive/refs/tags/v2.1.0.tar.gz
tar xzf v2.1.0.tar.gz
cd BusinessMath-2.1.0
```

### Build in Release Mode

```bash
# Build the library and MCP server in release mode
swift build -c release

# This will:
# 1. Download dependencies (Swift Numerics, MCP SDK)
# 2. Compile BusinessMath library
# 3. Compile MCP server
# 4. Create optimized binaries in .build/release/

# Verify build
ls -lh .build/release/businessmath-mcp-server

# Test execution
.build/release/businessmath-mcp-server --version
```

**Build time**: 5-15 minutes depending on CPU (first build only)

### Alternative: Build with Optimizations

For production environments, you can enable additional optimizations:

```bash
# Build with link-time optimization (slower build, faster runtime)
swift build -c release -Xswiftc -cross-module-optimization

# Build with all optimizations
swift build -c release \
  -Xswiftc -cross-module-optimization \
  -Xswiftc -enforce-exclusivity=unchecked
```

## Building MCP Server

The MCP server is built as part of the main build process. To build only the server:

```bash
# Build specific target
swift build -c release --product businessmath-mcp-server

# The executable will be at:
# .build/release/businessmath-mcp-server
```

### Create System Installation

```bash
# Copy executable to system location
sudo cp .build/release/businessmath-mcp-server /usr/local/bin/

# Make executable
sudo chmod +x /usr/local/bin/businessmath-mcp-server

# Create dedicated user (recommended for security)
sudo useradd -r -s /bin/false -d /var/lib/businessmath businessmath

# Create directories
sudo mkdir -p /var/lib/businessmath
sudo mkdir -p /var/log/businessmath
sudo chown businessmath:businessmath /var/lib/businessmath
sudo chown businessmath:businessmath /var/log/businessmath
```

## Running as a System Service

### systemd Service (Ubuntu, Debian, RHEL, Amazon Linux)

Create a systemd service file:

```bash
sudo tee /etc/systemd/system/businessmath-mcp.service > /dev/null <<'EOF'
[Unit]
Description=BusinessMath MCP Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=businessmath
Group=businessmath
WorkingDirectory=/var/lib/businessmath

# Run in stdio mode (default)
ExecStart=/usr/local/bin/businessmath-mcp-server

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/businessmath

# Restart policy
Restart=on-failure
RestartSec=5s

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=businessmath-mcp

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable businessmath-mcp

# Start service
sudo systemctl start businessmath-mcp

# Check status
sudo systemctl status businessmath-mcp

# View logs
sudo journalctl -u businessmath-mcp -f
```

### Alternative: Running in HTTP Mode

If you need to expose the server over HTTP (not recommended for production without reverse proxy):

```bash
# Create HTTP service
sudo tee /etc/systemd/system/businessmath-mcp-http.service > /dev/null <<'EOF'
[Unit]
Description=BusinessMath MCP Server (HTTP)
After=network.target

[Service]
Type=simple
User=businessmath
Group=businessmath
WorkingDirectory=/var/lib/businessmath

# Run in HTTP mode on port 8080
ExecStart=/usr/local/bin/businessmath-mcp-server --http 8080

# Bind to specific interface (recommended)
# ExecStart=/usr/local/bin/businessmath-mcp-server --http 8080 --host 127.0.0.1

Restart=on-failure
RestartSec=5s

StandardOutput=journal
StandardError=journal
SyslogIdentifier=businessmath-mcp-http

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable businessmath-mcp-http
sudo systemctl start businessmath-mcp-http
```

### Nginx Reverse Proxy (for HTTP mode)

If running in HTTP mode, use nginx as a reverse proxy:

```bash
sudo apt-get install -y nginx  # or: sudo dnf install -y nginx

# Create nginx configuration
sudo tee /etc/nginx/sites-available/businessmath-mcp > /dev/null <<'EOF'
upstream businessmath_backend {
    server 127.0.0.1:8080;
}

server {
    listen 80;
    server_name businessmath.yourdomain.com;

    # SSL configuration (recommended)
    # listen 443 ssl;
    # ssl_certificate /etc/letsencrypt/live/businessmath.yourdomain.com/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/businessmath.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://businessmath_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/businessmath-mcp /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx
```

## Security Considerations

### File Permissions

```bash
# Ensure proper ownership
sudo chown root:root /usr/local/bin/businessmath-mcp-server
sudo chmod 755 /usr/local/bin/businessmath-mcp-server

# Protect configuration files
sudo chmod 600 /etc/systemd/system/businessmath-mcp*.service

# Secure log directory
sudo chmod 750 /var/log/businessmath
```

### Firewall Configuration

If running in HTTP mode:

```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# RHEL/CentOS (firewalld)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### SELinux Configuration (RHEL/CentOS)

```bash
# Check SELinux status
sestatus

# If enforcing, create policy for MCP server
sudo semanage fcontext -a -t bin_t "/usr/local/bin/businessmath-mcp-server"
sudo restorecon -v /usr/local/bin/businessmath-mcp-server

# Allow network binding (if using HTTP mode)
sudo setsebool -P httpd_can_network_connect 1
```

### AppArmor Configuration (Ubuntu/Debian)

```bash
# Create AppArmor profile
sudo tee /etc/apparmor.d/usr.local.bin.businessmath-mcp-server > /dev/null <<'EOF'
#include <tunables/global>

/usr/local/bin/businessmath-mcp-server {
  #include <abstractions/base>

  /usr/local/bin/businessmath-mcp-server mr,
  /var/lib/businessmath/ r,
  /var/lib/businessmath/** rw,
  /var/log/businessmath/ r,
  /var/log/businessmath/** rw,

  # Deny network access in stdio mode
  deny network,
}
EOF

# Load profile
sudo apparmor_parser -r /etc/apparmor.d/usr.local.bin.businessmath-mcp-server
```

## Monitoring and Logging

### Log Rotation

```bash
# Create logrotate configuration
sudo tee /etc/logrotate.d/businessmath-mcp > /dev/null <<'EOF'
/var/log/businessmath/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    missingok
    create 0640 businessmath businessmath
    sharedscripts
    postrotate
        systemctl reload businessmath-mcp > /dev/null 2>&1 || true
    endscript
}
EOF
```

### Health Monitoring

Create a health check script:

```bash
sudo tee /usr/local/bin/businessmath-healthcheck > /dev/null <<'EOF'
#!/bin/bash
# Health check for BusinessMath MCP Server

if systemctl is-active --quiet businessmath-mcp; then
    echo "OK: BusinessMath MCP Server is running"
    exit 0
else
    echo "CRITICAL: BusinessMath MCP Server is not running"
    exit 2
fi
EOF

sudo chmod +x /usr/local/bin/businessmath-healthcheck

# Test health check
/usr/local/bin/businessmath-healthcheck
```

### Prometheus Metrics (Optional)

If you want to export metrics:

```bash
# Install node_exporter for system metrics
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xzf node_exporter-1.7.0.linux-amd64.tar.gz
sudo cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/

# Create systemd service
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

sudo useradd -r -s /bin/false node_exporter
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
```

## Troubleshooting

### Common Issues

#### 1. Swift Not Found

```bash
# Verify PATH
echo $PATH | grep swift

# Add to current session
export PATH=/opt/swift-6.0-RELEASE-ubuntu22.04/usr/bin:$PATH

# Add permanently
echo 'export PATH=/opt/swift-6.0-RELEASE-ubuntu22.04/usr/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

#### 2. Build Failures

```bash
# Clean build
swift package clean
rm -rf .build

# Update dependencies
swift package update

# Rebuild
swift build -c release
```

#### 3. Missing Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y libcurl4-openssl-dev libxml2-dev

# RHEL/CentOS
sudo dnf install -y libcurl-devel libxml2-devel
```

#### 4. Service Won't Start

```bash
# Check logs
sudo journalctl -u businessmath-mcp -n 50

# Check permissions
ls -l /usr/local/bin/businessmath-mcp-server
ls -ld /var/lib/businessmath

# Test manually
sudo -u businessmath /usr/local/bin/businessmath-mcp-server
```

#### 5. High Memory Usage

```bash
# Check memory usage
ps aux | grep businessmath

# Limit memory in systemd service
sudo systemctl edit businessmath-mcp

# Add:
[Service]
MemoryMax=1G
MemoryHigh=800M
```

### Debug Mode

Run server manually to see detailed output:

```bash
# Stop service
sudo systemctl stop businessmath-mcp

# Run manually as businessmath user
sudo -u businessmath /usr/local/bin/businessmath-mcp-server

# Or with environment variables for debugging
sudo -u businessmath \
  SWIFT_BACKTRACE=enable \
  /usr/local/bin/businessmath-mcp-server
```

## Performance Tuning

### Build Optimizations

```bash
# Use link-time optimization
swift build -c release -Xswiftc -cross-module-optimization

# Enable whole-module optimization (default in release)
swift build -c release -Xswiftc -whole-module-optimization

# Use -Onone for debug builds (faster compilation)
swift build -c debug -Xswiftc -Onone
```

### Runtime Optimizations

```bash
# Increase file descriptor limits
sudo tee -a /etc/security/limits.conf > /dev/null <<'EOF'
businessmath soft nofile 65536
businessmath hard nofile 65536
EOF

# Increase systemd limits
sudo mkdir -p /etc/systemd/system/businessmath-mcp.service.d
sudo tee /etc/systemd/system/businessmath-mcp.service.d/limits.conf > /dev/null <<'EOF'
[Service]
LimitNOFILE=65536
LimitNPROC=4096
EOF

sudo systemctl daemon-reload
sudo systemctl restart businessmath-mcp
```

### System Tuning

```bash
# Increase TCP connection limits (for HTTP mode)
sudo tee -a /etc/sysctl.conf > /dev/null <<'EOF'
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.ip_local_port_range = 1024 65535
EOF

sudo sysctl -p
```

## Backup and Disaster Recovery

### Backup Script

```bash
sudo tee /usr/local/bin/businessmath-backup > /dev/null <<'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/businessmath"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup executable
cp /usr/local/bin/businessmath-mcp-server $BACKUP_DIR/businessmath-mcp-server.$DATE

# Backup configuration
cp /etc/systemd/system/businessmath-mcp*.service $BACKUP_DIR/

# Backup logs
tar czf $BACKUP_DIR/logs.$DATE.tar.gz /var/log/businessmath/

# Keep only last 7 days
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "businessmath-mcp-server.*" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR"
EOF

sudo chmod +x /usr/local/bin/businessmath-backup

# Schedule daily backup
echo "0 2 * * * root /usr/local/bin/businessmath-backup" | sudo tee -a /etc/crontab
```

## Updates and Maintenance

### Updating the Server

```bash
# Stop service
sudo systemctl stop businessmath-mcp

# Pull latest changes
cd /opt/businessmath/BusinessMath
git pull

# Rebuild
swift build -c release

# Update binary
sudo cp .build/release/businessmath-mcp-server /usr/local/bin/

# Restart service
sudo systemctl start businessmath-mcp

# Verify
sudo systemctl status businessmath-mcp
```

### Automated Updates

Create update script:

```bash
sudo tee /usr/local/bin/businessmath-update > /dev/null <<'EOF'
#!/bin/bash
set -e

echo "Updating BusinessMath MCP Server..."

# Backup current version
/usr/local/bin/businessmath-backup

# Stop service
systemctl stop businessmath-mcp

# Update code
cd /opt/businessmath/BusinessMath
git pull

# Build
swift build -c release

# Install
cp .build/release/businessmath-mcp-server /usr/local/bin/

# Start service
systemctl start businessmath-mcp

# Check status
systemctl status businessmath-mcp

echo "Update completed successfully"
EOF

sudo chmod +x /usr/local/bin/businessmath-update
```

## Production Checklist

Before deploying to production:

- [ ] Swift 6.0+ installed and verified
- [ ] BusinessMath library builds successfully in release mode
- [ ] MCP server executable created and tested
- [ ] System user created (businessmath)
- [ ] Directories created with proper permissions
- [ ] systemd service configured and enabled
- [ ] Log rotation configured
- [ ] Firewall rules configured (if using HTTP mode)
- [ ] SELinux/AppArmor policies configured
- [ ] Health monitoring script installed
- [ ] Backup script configured and tested
- [ ] Documentation updated with server-specific details

## Support and Resources

- **BusinessMath Repository**: https://github.com/yourusername/BusinessMath
- **MCP Protocol Documentation**: https://modelcontextprotocol.io
- **Swift on Linux**: https://swift.org/download/
- **System Issues**: Check system logs with `journalctl -xe`

---

**Version**: 2.1.0
**Last Updated**: February 12, 2026
**Maintained by**: BusinessMath Team
