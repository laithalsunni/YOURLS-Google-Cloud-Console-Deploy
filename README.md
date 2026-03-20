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
curl -sSL https://raw.githubusercontent.com/laithalsunni/YOURLS-Google-Cloud-Console-Deploy/main/setup_yourls.sh | tr -d '\r' > setup.sh && chmod +x setup.sh && ./setup.sh

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
