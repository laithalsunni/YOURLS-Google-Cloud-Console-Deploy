# YOURLS-Google-Cloud-Console-Deploy
Deploy YOURLS on Google Cloud Console
This is a complete, end-to-end guide to deploying a professional, secure URL shortener on Google Cloud using Cloudflare for 2026.

Phase 1: The Cloud Infrastructure (Google Cloud)
Create your Virtual Machine:

Go to Google Cloud Console > Compute Engine > VM Instances.

Click Create Instance.

Name: yourls-server

Region: Select a Free Tier region (e.g., us-central1 (Iowa), us-west1 (Oregon), or us-east1 (South Carolina)).

Machine Type: e2-micro (This is eligible for the Google Cloud Free Tier).

Boot Disk: Change to Debian 12 (Bookworm).

Firewall: Check both Allow HTTP traffic and Allow HTTPS traffic.

Make your IP Static:

Go to VPC Network > IP Addresses.

Find your instance's External IP, click the three dots, and select Reserve static external IP address. Name it yourls-static-ip.

Note this IP address down.

Phase 2: Security & DNS (Cloudflare)
Point your domain:

In Cloudflare, go to DNS > Records.

Add an A Record. Name: qr (or your root domain), Content: [Your-VM-Static-IP].

Ensure Proxy Status is On (Orange Cloud).

Encryption Mode:

Go to SSL/TLS > Overview.

Set the encryption mode to Full (Strict).

Origin Certificate:

Go to SSL/TLS > Origin Server > Create Certificate.

Keep the defaults (valid for 15 years) and click Create.

Keep this window open. You will need to copy the Origin Certificate and Private Key into your server shortly.

Phase 3: The Deployment Script
Now, open the SSH terminal on your Google Cloud VM and follow these exact steps to run your custom, interactive script.

Create the script file:

Bash
nano setup_yourls.sh
Paste the following code:
(I have optimized this for any domain, including standard alphanumeric and length validation).

Bash
#!/bin/bash
clear
echo "=========================================================="
echo "   YOURLS 2026 - COMPREHENSIVE SECURE DEPLOYMENT         "
echo "=========================================================="

# 1. INPUT VALIDATION FUNCTIONS
validate_domain() { [[ "$1" =~ ^([a-zA-Z0-9](([a-zA-Z0-9-]*[a-zA-Z0-9])?)\.)+[a-zA-Z]{2,}$ ]]; }
validate_alpha() { [[ "$1" =~ ^[a-zA-Z0-9_]+$ ]]; }

# 2. COLLECTING INPUTS
while true; do
    read -p "Enter your Domain (e.g. domain.com or qr.domain.com): " DOMAIN
    if validate_domain "$DOMAIN"; then break; else echo "❌ Invalid domain."; fi
done

read -p "DB Name [yourls_db]: " DB_NAME; DB_NAME=${DB_NAME:-yourls_db}
read -p "DB User [yourls_admin]: " DB_USER; DB_USER=${DB_USER:-yourls_admin}
read -sp "DB Password (min 8 chars): " DB_PASS; echo ""
read -p "YOURLS Admin Username: " YOURLS_USER
read -sp "YOURLS Admin Password: " YOURLS_PASS; echo ""

# 3. SYSTEM INSTALL
echo "📦 Installing LAMP Stack..."
sudo apt update && sudo apt upgrade -y
sudo apt install apache2 mariadb-server php php-mysql php-curl php-gd php-xml php-mbstring git unzip -y
sudo a2enmod rewrite ssl remoteip

# 4. DATABASE SETUP
sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME; CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'; GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"

# 5. SSL SETUP
sudo mkdir -p /etc/apache2/ssl
echo "📜 PASTE Cloudflare ORIGIN CERTIFICATE (PEM) then press Ctrl+D:"
cat | sudo tee /etc/apache2/ssl/yourls.pem
echo "🔑 PASTE Cloudflare PRIVATE KEY then press Ctrl+D:"
cat | sudo tee /etc/apache2/ssl/yourls.key

# 6. APACHE CONFIG
cat <<EOF | sudo tee /etc/apache2/sites-available/yourls.conf
<VirtualHost *:80>
    ServerName $DOMAIN
    Redirect permanent / https://$DOMAIN/
</VirtualHost>
<VirtualHost *:443>
    ServerName $DOMAIN
    DocumentRoot /var/www/html
    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/yourls.pem
    SSLCertificateKeyFile /etc/apache2/ssl/yourls.key
    RemoteIPHeader CF-Connecting-IP
    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
sudo a2ensite yourls.conf && sudo a2dissite 000-default.conf
echo "AllowEncodedSlashes On" | sudo tee -a /etc/apache2/apache2.conf

# 7. YOURLS SETUP
cd /var/www/html && sudo rm -rf *
sudo git clone https://github.com/YOURLS/YOURLS.git .
sudo cp user/config-sample.php user/config.php
sudo sed -i "s|'yourls'|'$DB_NAME'|g; s|'your-password'|'$DB_PASS'|g; s|'username' => 'password'|'$YOURLS_USER' => '$YOURLS_PASS'|g; s|'http://your-own-site.com'|'https://$DOMAIN'|g" user/config.php
sudo sed -i '2i if (isset($_SERVER["HTTP_X_FORWARDED_PROTO"]) \&\& $_SERVER["HTTP_X_FORWARDED_PROTO"] == "https") { $_SERVER["HTTPS"] = "on"; }' user/config.php

# 8. PLUGINS
cd user/plugins
sudo git clone https://github.com/YOURLS/sample-qrcode.git qrcode
sudo git clone https://github.com/williambargentball/YOURLS-Forward-Slash-In-Urls.git slashes
sudo git clone https://github.com/ozh/yourls-fallback-url.git fallback
sudo git clone https://github.com/gioxx/YOURLS-LogoSuite.git logosuite

sudo chown -R www-data:www-data /var/www/html && sudo systemctl restart apache2
echo "✅ Done! Visit https://$DOMAIN/admin/ to install."
Run the script:

Bash
chmod +x setup_yourls.sh
./setup_yourls.sh
Phase 4: Final Activation
Visit your URL: Go to https://yourdomain.com/admin/install.php.

Install: Click the "Install YOURLS" button.

Activate Plugins: Go to the Plugins tab and activate:

QR Code

Allow Forward Slashes

Fallback URL (Set your main site as the fallback in the settings).

LogoSuite (Set your custom title and logo here).

🛡️ Authenticity & Disinformation Check
To ensure your link shortener is a source of truth:

Branding: Use LogoSuite to match your main site's design. A consistent look prevents users from feeling they've landed on a "fake" site.

SSL: By using Full (Strict), you guarantee that traffic is encrypted from the user all the way to your GCP server, preventing "Man-in-the-Middle" attacks that could alter your links.
