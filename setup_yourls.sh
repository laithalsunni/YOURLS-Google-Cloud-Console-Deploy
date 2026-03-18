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
sudo a2enmod rewrite ssl remoteip headers

# 4. DATABASE SETUP
sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME; CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'; GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"

# 5. SSL SETUP
sudo mkdir -p /etc/apache2/ssl
echo "📜 PASTE Cloudflare ORIGIN CERTIFICATE (PEM) then press Ctrl+D:"
cat | sudo tee /etc/apache2/ssl/yourls.pem
echo "🔑 PASTE Cloudflare PRIVATE KEY then press Ctrl+D:"
cat | sudo tee /etc/apache2/ssl/yourls.key

# 6. SECURE APACHE CONFIG
# This section has been modified to block public file listings and sensitive files
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

    # --- SECURITY FIXES ---
    # Disable directory browsing (prevents listing all files)
    Options -Indexes +FollowSymLinks
    
    # Block access to sensitive deployment files and scripts
    <FilesMatch "\.(sh|sql|pem|key|git|md|log|conf)$">
        Require all denied
    </FilesMatch>

    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>

    # Protect the user directory from being listed
    <Directory /var/www/html/user>
        Options -Indexes
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

# 8. ROOT REDIRECT
# This prevents the public from seeing a blank directory by sending them to the admin login
echo "<?php header('Location: /admin/'); exit; ?>" | sudo tee /var/www/html/index.php

# 9. PLUGINS
cd user/plugins
sudo git clone https://github.com/YOURLS/sample-qrcode.git qrcode
sudo git clone https://github.com/williambargentball/YOURLS-Forward-Slash-In-Urls.git slashes
sudo git clone https://github.com/ozh/yourls-fallback-url.git fallback
sudo git clone https://github.com/gioxx/YOURLS-LogoSuite.git logosuite

# 10. FINAL PERMISSIONS & CLEANUP
sudo chown -R www-data:www-data /var/www/html
sudo chmod 600 /var/www/html/user/config.php
sudo systemctl restart apache2

echo "✅ Deployment Complete & Secured! Visit https://$DOMAIN/admin/ to install."
