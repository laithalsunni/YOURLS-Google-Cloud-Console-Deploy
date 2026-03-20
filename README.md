# YOURLS-Google-Cloud-Console-Deploy
Deploy YOURLS on Google Cloud Console
This is a complete, end-to-end guide to deploying a professional, secure URL shortener on Google Cloud using Cloudflare for 2026.


## Phase 1: The Cloud Infrastructure (Google Cloud)

1.  **Create your Virtual Machine:**
    
    -   Go to **Google Cloud Console** > **Compute Engine** > **VM Instances**.
        
    -   Click **Create Instance**.
        
    -   **Name:** `yourls-server`
        
    -   **Region:** Select a Free Tier region (e.g., `us-central1` (Iowa), `us-west1` (Oregon), or `us-east1` (South Carolina)).
        
    -   **Machine Type:** `e2-micro` (This is eligible for the Google Cloud Free Tier).
        
    -   **Boot Disk:** Change to **Debian 12 (Bookworm)**.
        
    -   **Firewall:** Check both **Allow HTTP traffic** and **Allow HTTPS traffic**.
        
2.  **Make your IP Static:**
    
    -   Go to **VPC Network** > **IP Addresses**.
        
    -   Find your instance's External IP, click the three dots, and select **Reserve static external IP address**. Name it `yourls-static-ip`.
        
    -   **Note this IP address down.**
        

----------

## Phase 2: Security & DNS (Cloudflare)

1.  **Point your domain:**
    
    -   In Cloudflare, go to **DNS** > **Records**.
        
    -   Add an **A Record**. Name: `qr` (or your root domain), Content: `[Your-VM-Static-IP]`.
        
    -   Ensure **Proxy Status** is **On (Orange Cloud)**.
        
2.  **Encryption Mode:**
    
    -   Go to **SSL/TLS** > **Overview**.
        
    -   Set the encryption mode to **Full (Strict)**.
        
3.  **Origin Certificate:**
    
    -   Go to **SSL/TLS** > **Origin Server** > **Create Certificate**.
        
    -   Keep the defaults (valid for 15 years) and click **Create**.
        
    -   **Keep this window open.** You will need to copy the **Origin Certificate** and **Private Key** into your server shortly.
        

----------

## Phase 3: The Deployment Script

**🚀 The Quick Deployment Command**

Open your GCP SSH terminal and paste this command:

Bash
```
curl -sSL https://raw.githubusercontent.com/laithalsunni/YOURLS-Google-Cloud-Console-Deploy/main/setup_yourls.sh -o setup.sh && chmod +x setup.sh && ./setup.sh
```

**manual Deployment Commands**

Open the **SSH** terminal on your Google Cloud VM and follow these exact steps to run your custom, interactive script.

1.  **Create the script file:**
    
    Bash
    
    ```
    nano setup_yourls.sh
    
    ```
    
2.  **Paste the following code:** _(I have optimized this for any domain, including standard alphanumeric and length validation)_.
    
```
#!/bin/bash
clear
echo "=========================================================="
echo "   YOURLS 2026 - FULL STACK DEPLOYMENT (Alsunni Edition)  "
echo "=========================================================="

# 1. Interactive Input
read -p "Enter your Domain (e.g. qr.alsunniNet.com): " DOMAIN
read -p "Enter Database Name [yourls_db]: " DB_NAME
DB_NAME=${DB_NAME:-yourls_db}
read -p "Enter Database User [yourls_user]: " DB_USER
DB_USER=${DB_USER:-yourls_user}
read -sp "Enter Database Password: " DB_PASS
echo ""
read -p "Enter YOURLS Admin Username: " ADMIN_USER
read -sp "Enter YOURLS Admin Password: " ADMIN_PASS
echo -e "\n==========================================================\n"

# 2. System Update & Stack Install
echo "📦 Installing Apache, MariaDB, and PHP 8.3..."
sudo apt update && sudo apt upgrade -y
sudo apt install apache2 mariadb-server php php-mysql php-curl php-gd php-xml php-mbstring git unzip -y
sudo a2enmod rewrite ssl remoteip

# 3. Database Configuration
echo "🗄️  Setting up Database..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# 4. SSL & Cloudflare Certificates
sudo mkdir -p /etc/apache2/ssl
echo "📜 PASTE your Cloudflare ORIGIN CERTIFICATE (PEM) then press Ctrl+D:"
cat | sudo tee /etc/apache2/ssl/yourls.pem > /dev/null
echo "🔑 PASTE your Cloudflare PRIVATE KEY then press Ctrl+D:"
cat | sudo tee /etc/apache2/ssl/yourls.key > /dev/null

# 5. Apache Virtual Host
echo "🌐 Configuring Web Server..."
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

sudo a2ensite yourls.conf
sudo a2dissite 000-default.conf
echo "AllowEncodedSlashes On" | sudo tee -a /etc/apache2/apache2.conf

# 6. Deploy YOURLS Core
echo "📥 Downloading YOURLS Core..."
cd /var/www/html
sudo rm -rf *
sudo git clone https://github.com/YOURLS/YOURLS.git .

# 7. Generate Secure config.php
echo "🛠️  Building config.php from scratch..."
COOKIE_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

cat <<EOF | sudo tee /var/www/html/user/config.php > /dev/null
<?php
/** YOURLS Config Generated by Alsunni One-Click Deploy **/

// Cloudflare HTTPS Fix
if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https') {
    \$_SERVER['HTTPS'] = 'on';
}

define( 'YOURLS_DB_USER', '$DB_USER' );
define( 'YOURLS_DB_PASS', '$DB_PASS' );
define( 'YOURLS_DB_NAME', '$DB_NAME' );
define( 'YOURLS_DB_HOST', 'localhost' );
define( 'YOURLS_DB_PREFIX', 'yourls_' );
define( 'YOURLS_SITE', 'https://$DOMAIN' );
define( 'YOURLS_HOURS_OFFSET', 0 ); 
define( 'YOURLS_UNIQUE_URLS', true );
define( 'YOURLS_PRIVATE', true );
define( 'YOURLS_COOKIEKEY', '$COOKIE_KEY' );

\$yourls_user_passwords = array(
    '$ADMIN_USER' => '$ADMIN_PASS'
);

// Character Set: Base 62 (Supports Hyphens)
define( 'YOURLS_URL_CONVERT', 62 );
\$yourls_reserved_URL = array( 'admin', 'about', 'contact' );
EOF

# 8. Install Add-ons (Plugins)
echo "🔌 Installing Expanded Plugin Suite..."
cd /var/www/html/user/plugins

# Previous Plugins
sudo git clone https://github.com/YOURLS/sample-qrcode.git qrcode
sudo git clone https://github.com/williambargentball/YOURLS-Forward-Slash-In-Urls.git slashes
sudo git clone https://github.com/ozh/yourls-fallback-url.git fallback
sudo git clone https://github.com/gioxx/YOURLS-LogoSuite.git logosuite

# New Plugins
sudo git clone https://github.com/GautamGupta/YOURLS-Import-Export.git import-export
sudo git clone https://github.com/timcrockford/302-instead.git redirect-302
sudo git clone https://github.com/josheby/yourls-additional-charsets.git additional-charsets

# 9. Final Permissions & Clean-up
echo "🔑 Hardening Permissions..."
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
sudo systemctl restart apache2

echo "=========================================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "Site: https://$DOMAIN/admin/"
echo "New Add-ons installed: Import/Export, 302 Redirects, and Charsets."
echo "=========================================================="
```

3.  **Run the script:**
    
    Bash
    
    ```
    chmod +x setup_yourls.sh
    ./setup_yourls.sh
    
    ```
    

----------

## Phase 4: Final Activation

1.  **Visit your URL:** Go to `https://yourdomain.com/admin/install.php`.
    
2.  **Install:** Click the "Install YOURLS" button.
    
3.  **Activate Plugins:** Go to the **Plugins** tab and activate:
    
    -   **QR Code**
        
    -   **Allow Forward Slashes**
        
    -   **Fallback URL** (Set your main site as the fallback in the settings).
        
    -   **LogoSuite** (Set your custom title and logo here).
        

----------

## 🛡️ Authenticity & Disinformation Check

To ensure your link shortener is a source of truth:

-   **Branding:** Use **LogoSuite** to match your main site's design. A consistent look prevents users from feeling they've landed on a "fake" site.
    
-   **SSL:** By using **Full (Strict)**, you guarantee that traffic is encrypted from the user all the way to your GCP server, preventing "Man-in-the-Middle" attacks that could alter your links.
