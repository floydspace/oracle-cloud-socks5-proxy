# Usage Guide - Oracle Cloud SOCKS5 Proxy

## Quick Reference

After deploying with `terraform apply`, your SOCKS5 proxy will be available on **port 443**.

### Get Connection Info

```bash
# Get instance IP
terraform output instance_public_ip

# Get full SOCKS5 connection string
terraform output socks5_connection
```

## Configuration Details

### Infrastructure
- **Instance Type**: VM.Standard.E2.1.Micro (Always Free tier)
  - 1 OCPU (AMD EPYC 7551)
  - 1 GB RAM
  - 45 GB boot volume
- **Operating System**: Ubuntu 22.04 LTS (Canonical)
- **Network**: VCN with public IP address
- **Region**: Configurable (default: eu-amsterdam-1)

### Services
- **SOCKS5 Proxy**: Microsocks on port 443
- **SSH**: OpenSSH on ports 22 and 2222
- **Default Credentials**: ubuntu / Oracle123!

### Security Configuration
- **Open Ports**: 22 (SSH), 443 (SOCKS5), 2222 (SSH alternate)
- **Security List**: Configured in Oracle Cloud VCN
- **Firewall**: iptables configured to allow all services
- **Authentication**: None (anonymous SOCKS5 proxy)

## Key Implementation Details

### Oracle Cloud iptables Fix

Oracle Cloud instances come with pre-configured iptables rules that block all ports except SSH. This configuration includes a critical fix:

```bash
# Insert rules BEFORE the default REJECT rule (at position 5)
iptables -I INPUT 5 -p tcp --dport 443 -j ACCEPT
iptables -I INPUT 5 -p tcp --dport 2222 -j ACCEPT
netfilter-persistent save
```

Without this fix, the SOCKS5 proxy would not be accessible even though the security list allows it.

### Cloud-Init Process

The instance uses cloud-init for automated setup:
1. Updates system packages
2. Installs dependencies (git, gcc, make)
3. Builds microsocks from source
4. Configures iptables rules
5. Sets up SSH on dual ports
6. Creates and starts systemd service for microsocks

This process takes 2-3 minutes after the Terraform apply completes.

## Testing Your Proxy

### Basic Connectivity Test

```bash
# Get instance IP
INSTANCE_IP=$(terraform output -raw instance_public_ip)

# Test SOCKS5 proxy
curl --socks5 $INSTANCE_IP:443 https://ipinfo.io

# Test with IPv4 only
curl -4 --socks5 $INSTANCE_IP:443 https://api.ipify.org

# Test HTTPS through proxy
curl --socks5 $INSTANCE_IP:443 https://www.google.com
```

### Verbose Testing

```bash
# Verbose curl to see connection details
curl -v --socks5 $INSTANCE_IP:443 https://ipinfo.io

# Test with timeout
timeout 10 curl --socks5 $INSTANCE_IP:443 https://ipinfo.io
```

### Testing from Different Tools

```bash
# Using netcat to test port
nc -zv $INSTANCE_IP 443

# Using telnet
telnet $INSTANCE_IP 443

# Using nmap
nmap -p 443 $INSTANCE_IP
```

## Troubleshooting

### Initial Connection Issues

If the proxy doesn't work immediately after `terraform apply`:

1. **Wait for cloud-init to complete** (2-3 minutes)
2. **Check cloud-init status via SSH:**

```bash
ssh -i ~/.ssh/oracle_vm ubuntu@$INSTANCE_IP

# Check cloud-init status
cloud-init status

# View cloud-init output log
sudo cat /var/log/cloud-init-output.log

# Check for errors
sudo tail -50 /var/log/cloud-init-output.log
```

### Service Status Checks

```bash
# SSH into instance
ssh -i ~/.ssh/oracle_vm ubuntu@$INSTANCE_IP

# Check if microsocks is running
sudo systemctl status microsocks

# View microsocks logs
sudo journalctl -u microsocks -f

# Check if process is listening on port 443
sudo ss -tlnp | grep 443
sudo netstat -tlnp | grep 443

# Check all listening ports
sudo ss -tlnp
```

### Network and Firewall Checks

```bash
# Check iptables rules
sudo iptables -L -n -v

# Verify port 443 is allowed
sudo iptables -L INPUT -n -v | grep 443

# Check if netfilter-persistent is active
sudo systemctl status netfilter-persistent
```

### Restart Services

```bash
# Restart microsocks
sudo systemctl restart microsocks

# Check status after restart
sudo systemctl status microsocks

# Enable if not enabled
sudo systemctl enable microsocks
```

### SSH Connection Issues

If port 22 is blocked by your network:

```bash
# Try alternate SSH port
ssh -i ~/.ssh/oracle_vm -p 2222 ubuntu@$INSTANCE_IP

# Test port 2222 availability
nc -zv $INSTANCE_IP 2222
```

### Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Connection refused | Cloud-init still running | Wait 2-3 minutes |
| Timeout | Firewall blocking | Check iptables and security list |
| Service not found | Build failed | Check cloud-init logs |
| Port closed | iptables rule not saved | Re-run iptables commands manually |

## Using the Proxy

### Application Configuration

Configure your applications with these SOCKS5 proxy settings:
- **Proxy Type**: SOCKS5
- **Host/Server**: Your instance IP
- **Port**: 443
- **Authentication**: None (no username/password)

### Web Browsers

**Mozilla Firefox:**
1. Preferences → General → Network Settings → Settings
2. Select "Manual proxy configuration"
3. SOCKS Host: `<instance_ip>`
4. Port: `443`
5. Select "SOCKS v5"
6. Check "Proxy DNS when using SOCKS v5"

**Google Chrome (Linux/macOS):**
```bash
google-chrome --proxy-server="socks5://<instance_ip>:443"
```

**Google Chrome (Windows):**
```cmd
chrome.exe --proxy-server="socks5://<instance_ip>:443"
```

**Brave Browser:**
```bash
brave --proxy-server="socks5://<instance_ip>:443"
```

### Command-Line Tools

**curl:**
```bash
curl --socks5 <instance_ip>:443 https://example.com

# With SOCKS5 hostname resolution
curl --socks5-hostname <instance_ip>:443 https://example.com
```

**wget:**
```bash
# Add to ~/.wgetrc or use command line
export http_proxy=socks5://<instance_ip>:443
export https_proxy=socks5://<instance_ip>:443
wget https://example.com
```

**git:**
```bash
# Global configuration
git config --global http.proxy socks5://<instance_ip>:443

# Per-repository
git config http.proxy socks5://<instance_ip>:443

# Unset when done
git config --global --unset http.proxy
```

**ssh with dynamic forwarding:**
```bash
# Create SOCKS5 proxy on local port 8080
ssh -D 8080 -i ~/.ssh/oracle_vm ubuntu@<instance_ip>

# Use in another terminal
curl --socks5 localhost:8080 https://example.com
```

### System-Wide Proxy

**macOS:**
1. System Preferences → Network
2. Select your network interface → Advanced
3. Proxies tab → Check "SOCKS Proxy"
4. SOCKS Proxy Server: `<instance_ip>:443`

**Linux (GNOME):**
1. Settings → Network → Network Proxy
2. Method: Manual
3. Socks Host: `<instance_ip>`, Port: `443`

**Linux (Environment Variables):**
```bash
export ALL_PROXY=socks5://<instance_ip>:443
export all_proxy=socks5://<instance_ip>:443
```

## Performance and Limitations

### Expected Performance
- **Bandwidth**: Limited by instance network (Always Free: ~50 Mbps)
- **Latency**: Depends on region (typically 50-200ms from Europe/US)
- **Concurrent Connections**: Microsocks is lightweight, handles multiple connections well

### Limitations
- **CPU**: 1 OCPU may limit throughput for very high traffic
- **RAM**: 1GB is sufficient for SOCKS5 proxy
- **Data Transfer**: Oracle Free Tier includes 10TB/month outbound
- **No authentication**: Anyone with the IP can use the proxy

## Cost Breakdown

| Service | Oracle Cloud (This Setup) | AWS | DigitalOcean | Linode |
|---------|---------------------------|-----|--------------|--------|
| Instance | $0/month (Free tier) | ~$3.50/month | $6/month | $5/month |
| Network | $0/month (10TB included) | ~$0.90/GB | Included | Included |
| Storage | $0/month (45GB included) | Included | Included | Included |
| **Total** | **$0/month** | **$3.50+/month** | **$6/month** | **$5/month** |

### Oracle Cloud Always Free Tier Includes:
- 2 VMs (VM.Standard.E2.1.Micro)
- 10TB outbound data transfer per month
- 200GB total block volume storage
- 2 load balancers
- No credit card charges (ever)

## Maintenance

### Updating the System

```bash
# SSH into instance
ssh -i ~/.ssh/oracle_vm ubuntu@$INSTANCE_IP

# Update packages
sudo apt update && sudo apt upgrade -y

# Reboot if kernel updated
sudo reboot
```

### Updating Microsocks

```bash
# SSH into instance
ssh -i ~/.ssh/oracle_vm ubuntu@$INSTANCE_IP

# Stop service
sudo systemctl stop microsocks

# Update from source
cd /tmp
rm -rf microsocks
git clone https://github.com/rofl0r/microsocks.git
cd microsocks
make
sudo cp microsocks /usr/local/bin/
sudo chmod +x /usr/local/bin/microsocks

# Start service
sudo systemctl start microsocks
```

### Monitoring

```bash
# View real-time logs
sudo journalctl -u microsocks -f

# Check system resources
htop
# or
top

# Check network connections
sudo ss -tn | grep :443
```

## Security Recommendations

### Change Default Password

```bash
# SSH into instance
ssh -i ~/.ssh/oracle_vm ubuntu@$INSTANCE_IP

# Change password
sudo passwd ubuntu

# Or disable password authentication entirely
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### Add SOCKS5 Authentication

Edit the microsocks systemd service to require authentication:

```bash
sudo nano /etc/systemd/system/microsocks.service

# Change ExecStart line to:
ExecStart=/usr/local/bin/microsocks -i 0.0.0.0 -p 443 -u myuser -P mypassword

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart microsocks
```

### Restrict Source IPs

Modify the security list in Terraform to allow only your IP:

```hcl
ingress_security_rules {
  protocol = "6"
  source   = "YOUR.PUBLIC.IP.ADDRESS/32"  # Your IP only
  
  tcp_options {
    min = 443
    max = 443
  }
}
```

### Enable Firewall Logging

```bash
# Log dropped packets
sudo iptables -I INPUT -j LOG --log-prefix "IPTABLES-DROP: "

# View logs
sudo tail -f /var/log/syslog | grep IPTABLES
```

## Advanced Usage

### Using as SSH Jump Host

```bash
# Add to ~/.ssh/config
Host oracle-jump
    HostName <instance_ip>
    User ubuntu
    IdentityFile ~/.ssh/oracle_vm
    
Host internal-server
    HostName 10.0.0.100
    ProxyJump oracle-jump
```

### Multiple Proxy Instances

Deploy to different regions:

```bash
# Deploy to Amsterdam
terraform workspace new amsterdam
terraform apply

# Deploy to Tokyo
terraform workspace new tokyo
terraform apply -var="region=ap-tokyo-1"
```

### Custom Microsocks Configuration

Modify the cloud-init script in main.tf to customize microsocks:

```bash
# Bind to specific IP
ExecStart=/usr/local/bin/microsocks -i 10.0.1.10 -p 443

# Add authentication
ExecStart=/usr/local/bin/microsocks -i 0.0.0.0 -p 443 -u user -P pass

# Increase verbosity
ExecStart=/usr/local/bin/microsocks -i 0.0.0.0 -p 443 -v
```

## Cleanup and Teardown

### Temporary Shutdown

```bash
# Stop instance (preserves data, no charges on Free Tier)
oci compute instance action --instance-id <id> --action STOP

# Or via Oracle Console: Compute → Instances → Stop
```

### Complete Removal

```bash
# Destroy all Terraform resources
terraform destroy

# Confirm with 'yes'

# Remove Terraform state
rm -rf .terraform terraform.tfstate*
```

### Backup Before Destroying

```bash
# Export Terraform state
terraform state pull > backup.tfstate

# Backup configuration
tar -czf oracle-socks5-backup.tar.gz *.tf *.tfvars .terraform/
```
