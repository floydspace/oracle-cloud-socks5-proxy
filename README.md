# Oracle Cloud SOCKS5 Proxy - Terraform Setup

A free SOCKS5 proxy server deployed on Oracle Cloud's Always Free tier using Terraform.

## Features

- **100% Free**: Uses Oracle Cloud's Always Free tier (VM.Standard.E2.1.Micro)
- **Port 443**: Bypasses most corporate firewalls by using HTTPS port
- **Ubuntu 22.04**: Modern, stable operating system
- **Microsocks**: Lightweight, fast SOCKS5 proxy
- **Dual SSH Access**: SSH available on both port 22 and 2222
- **Automatic Setup**: Cloud-init handles all installation and configuration

## What's Deployed

- **Compute Instance**: VM.Standard.E2.1.Micro (1 OCPU, 1GB RAM)
- **Network**: VCN with public subnet and internet gateway
- **Security**: Ports 22, 443, and 2222 opened
- **Services**: Microsocks SOCKS5 proxy on port 443, SSH on ports 22 and 2222
- **Cost**: $0/month (Always Free tier)

## Prerequisites

1. **Oracle Cloud Account**: Sign up at https://oracle.com/cloud/free
2. **Terraform**: Install with `brew install terraform` (macOS) or download from terraform.io
3. **OpenSSL**: Pre-installed on macOS/Linux

## Quick Start

### 1. Generate OCI API Keys

```bash
# Create .oci directory
mkdir -p ~/.oci

# Generate API key pair (2048-bit RSA)
openssl genrsa -out ~/.oci/oci_api_key.pem 2048
chmod 600 ~/.oci/oci_api_key.pem
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem

# Display public key for Oracle Cloud
cat ~/.oci/oci_api_key_public.pem
```

### 2. Add API Key to Oracle Cloud

1. Log in to [Oracle Cloud Console](https://cloud.oracle.com)
2. Click your profile icon (top right) → **User Settings**
3. Under **Resources**, click **API Keys** → **Add API Key**
4. Select **Paste Public Key** and paste the content from above
5. Click **Add**
6. **Important**: Copy the **fingerprint** displayed in the confirmation dialog

### 3. Get Required OCIDs

You'll need two OCIDs:

**Tenancy OCID:**
1. Click your profile icon → **Tenancy: [name]**
2. Copy the **OCID** field

**User OCID:**
1. Click your profile icon → **User Settings**
2. Copy the **OCID** field from the User Information section

### 4. Generate SSH Key (if needed)

```bash
# Generate SSH key pair for VM access
ssh-keygen -t rsa -b 4096 -f ~/.ssh/oracle_vm -N ""

# Display public key
cat ~/.ssh/oracle_vm.pub
```

### 5. Configure Terraform

```bash
# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
nano terraform.tfvars
```

Fill in your values:
```hcl
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaaXXXXX"  # From step 3
user_ocid        = "ocid1.user.oc1..aaaaaaaaXXXXX"     # From step 3
fingerprint      = "xx:xx:xx:xx:..."                    # From step 2
private_key_path = "~/.oci/oci_api_key.pem"            # Default location
region           = "eu-amsterdam-1"                     # Or your preferred region
ssh_public_key   = "ssh-rsa AAAAB3NzaC1yc2..."         # From step 4
```

### 6. Deploy

```bash
# Initialize Terraform (downloads OCI provider)
terraform init

# Preview what will be created
terraform plan

# Deploy the infrastructure
terraform apply

# Get the connection details
terraform output socks5_connection
```

### 7. Test Your Proxy

Wait 2-3 minutes after deployment for cloud-init to complete setup, then test:

```bash
# Get the instance IP
INSTANCE_IP=$(terraform output -raw instance_public_ip)

# Test the SOCKS5 proxy
curl --socks5 $INSTANCE_IP:443 https://ipinfo.io

# Test SSH access
ssh -i ~/.ssh/oracle_vm ubuntu@$INSTANCE_IP

# Or use port 2222 if port 22 is blocked
ssh -i ~/.ssh/oracle_vm -p 2222 ubuntu@$INSTANCE_IP
```

Default password for ubuntu user: `Oracle123!`

## Using Your Proxy

Configure your applications with these settings:
- **Host**: Your instance IP (from `terraform output instance_public_ip`)
- **Port**: `443`
- **Protocol**: SOCKS5
- **Authentication**: None

### Browser Configuration

**Firefox:**
1. Settings → Network Settings → Manual proxy configuration
2. SOCKS Host: `<instance_ip>`, Port: `443`
3. Select "SOCKS v5"

**Chrome/Chromium:**
```bash
google-chrome --proxy-server="socks5://<instance_ip>:443"
```

**System-wide (macOS):**
1. System Preferences → Network → Advanced → Proxies
2. Check "SOCKS Proxy"
3. Server: `<instance_ip>`, Port: `443`

### Command-line Tools

```bash
# curl
curl --socks5 <instance_ip>:443 https://example.com

# git
git config --global http.proxy socks5://<instance_ip>:443

# ssh tunnel
ssh -D 8080 -i ~/.ssh/oracle_vm ubuntu@<instance_ip>
```

## Troubleshooting

If the proxy doesn't work immediately after deployment:

```bash
# SSH into the instance
ssh -i ~/.ssh/oracle_vm ubuntu@$(terraform output -raw instance_public_ip)

# Check if microsocks is running
sudo systemctl status microsocks

# Check if it's listening on port 443
sudo ss -tlnp | grep 443

# Verify iptables rules allow port 443
sudo iptables -L -n -v | grep 443

# View cloud-init logs for errors
sudo cat /var/log/cloud-init-output.log
tail -f /var/log/cloud-init-output.log

# Restart microsocks if needed
sudo systemctl restart microsocks
```

## Cleanup

When you're done with the proxy:

```bash
# Destroy all resources
terraform destroy

# Confirm with 'yes' when prompted
```

This will delete the instance, network, and all associated resources.

## Available Regions

Oracle Cloud Free Tier regions (change in terraform.tfvars):
- `eu-amsterdam-1` - Amsterdam, Netherlands
- `eu-frankfurt-1` - Frankfurt, Germany
- `eu-madrid-1` - Madrid, Spain
- `eu-marseille-1` - Marseille, France
- `eu-milan-1` - Milan, Italy
- `eu-paris-1` - Paris, France
- `eu-stockholm-1` - Stockholm, Sweden
- `eu-zurich-1` - Zurich, Switzerland
- `uk-london-1` - London, United Kingdom
- `uk-cardiff-1` - Cardiff, United Kingdom
- `us-ashburn-1` - Ashburn, Virginia
- `us-phoenix-1` - Phoenix, Arizona
- `us-sanjose-1` - San Jose, California
- `ca-toronto-1` - Toronto, Canada
- `ca-montreal-1` - Montreal, Canada
- `sa-saopaulo-1` - São Paulo, Brazil
- `sa-santiago-1` - Santiago, Chile
- `ap-tokyo-1` - Tokyo, Japan
- `ap-osaka-1` - Osaka, Japan
- `ap-seoul-1` - Seoul, South Korea
- `ap-mumbai-1` - Mumbai, India
- `ap-hyderabad-1` - Hyderabad, India
- `ap-sydney-1` - Sydney, Australia
- `ap-melbourne-1` - Melbourne, Australia
- `ap-singapore-1` - Singapore
- `me-jeddah-1` - Jeddah, Saudi Arabia
- `me-dubai-1` - Dubai, UAE

## Cost Comparison

- **Oracle Cloud (this setup)**: $0/month (Always Free)
- **AWS EC2**: ~$3-5/month (t2.micro)
- **DigitalOcean**: $6/month (smallest droplet)
- **Linode**: $5/month (Nanode)
- **Fly.io**: $2/month (dedicated IPv4 required)

## Security Notes

1. **No authentication**: This setup has no SOCKS5 authentication. Only share the IP with trusted users.
2. **Open ports**: Ports 22, 443, and 2222 are open to the internet.
3. **Default password**: The ubuntu user has password `Oracle123!` - change it or disable password auth.
4. **Firewall bypass**: Using port 443 may violate network policies in some environments.

To add SOCKS5 authentication, modify the microsocks service in main.tf:
```bash
ExecStart=/usr/local/bin/microsocks -i 0.0.0.0 -p 443 -u username -P password
```

## License

This project is provided as-is for educational purposes.
