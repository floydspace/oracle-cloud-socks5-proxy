#cloud-config
package_update: true
package_upgrade: true
packages:
  - git
  - gcc
  - make

# Set password for ubuntu user
chpasswd:
  list: |
    ubuntu:${ubuntu_password}
  expire: false

# Enable password authentication
ssh_pwauth: true

runcmd:
  # Install microsocks
  - cd /tmp
  - git clone https://github.com/rofl0r/microsocks.git
  - cd microsocks
  - make
  - cp microsocks /usr/local/bin/
  - chmod +x /usr/local/bin/microsocks

  # Fix Oracle's iptables rules - add SOCKS5 port BEFORE the REJECT rule
  - iptables -I INPUT 5 -p tcp --dport ${socks5_port} -j ACCEPT
  - netfilter-persistent save

  # Create systemd service
  - |
    cat > /etc/systemd/system/microsocks.service <<'EOL'
    [Unit]
    Description=Microsocks SOCKS5 Proxy
    After=network.target

    [Service]
    Type=simple
    ExecStart=/usr/local/bin/microsocks -i 0.0.0.0 -p ${socks5_port}
    Restart=always

    [Install]
    WantedBy=multi-user.target
    EOL

  # Start service
  - systemctl daemon-reload
  - systemctl enable microsocks
  - systemctl start microsocks
