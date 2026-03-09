# Azure Native File Share (AutoCAD Ready)

This Terraform project deploys a secure Azure File Share optimized for small business use (e.g., AutoCAD), featuring:
1.  **Azure Files Premium**: High performance for CAD files.
2.  **P2S VPN Gateway**: Secure access from home/remote without exposing port 445 to the internet.
3.  **Entra ID Kerberos**: Native Office 365 identity integration (SSO) for authentication.

## Day 0: Setup for Business Owners (Start Here)
If you only have an **Office 365 Subscription**, you already have "Active Directory" (now called **Relict Entra ID**). You just need to activate an Azure Subscription to pay for the storage and VPN usage.

1.  **Log In**: Go to [portal.azure.com](https://portal.azure.com) and sign in with your **Office 365 Admin** account.
2.  **Activate Subscription**:
    *   Search for **"Subscriptions"** in the top bar.
    *   Click **Add**.
    *   Select **Pay-As-You-Go** (Recommended for businesses to avoid spending limits of free trials).
    *   Complete the billing profile (Credit Card).
3.  **Result**: You now have an Azure Subscription linked to your existing Office 365 users!

## Prerequisites
1.  **Azure Subscription**: (Created in step above).
2.  **Terraform**: [Install Terraform](https://developer.hashicorp.com/terraform/downloads).
3.  **Azure CLI**: [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli).
4.  **Git**: [Install Git](https://git-scm.com/downloads) or [GitHub Desktop](https://desktop.github.com/).

## Getting the Code
Before running any commands, you need to download this project to your local machine.

**Option 1: Using GitHub Desktop (Recommended for beginners)**
1. Open [GitHub Desktop](https://desktop.github.com/).
2. Go to **File** > **Clone repository...**
3. Select the **URL** tab and paste the URL of this repository.
4. Choose a local path and click **Clone**.

**Option 2: Using Git CLI**
Open PowerShell or your terminal and run:
```bash
git clone <REPOSITORY_URL>
cd fileshare
```

## Security & Authentication: How does it work?

### Layer 1: The Tunnel (Device Security)
The VPN uses **Certificate-Based Authentication**, not a username/password. This is stronger because it verifies the **Device**, not just the user.

1.  **The Server (Azure)**: Has the "Root Certificate" (Public Key). It only accepts connections from devices that can prove they have a valid "Client Certificate" signed by this root.
2.  **The Client (Your PC)**: Has the `P2SChildCert.pfx` installed. This act as a digital "Key Card".
3.  **Security**: If an employee leaves or loses their laptop, you can "Revoke" their certificate in Azure, instantly blocking their VPN access. A hacker cannot connect even with a username/password unless they steal this specific file.

### Layer 2: The File Share (User Identity)
Once the tunnel is established, the user is on the private network (`10.0.x.x`), but they still cannot access files.

1.  **Kerberos**: When you run `net use`, Windows silently sends your Office 365 "Ticket" to the storage account.
2.  **RBAC**: Azure checks if your specific user (e.g., `luis@company.com`) has the "SMB Contributor" role.
3.  **Result**: You get access based on *who you are*, controlled centrally in your Office 365 admin portal.

## Architecture
*   **VNet**: 10.0.0.0/16
*   **GatewaySubnet**: 10.0.1.0/24
*   **StorageSubnet**: 10.0.2.0/24
*   **VPN Clients**: 172.16.201.0/24

For next steps, see [INSTRUCTIONS.md](INSTRUCTIONS.md).

> **Note**: Before running Terraform, ensure you have selected your Azure Subscription:
> `az account set --subscription "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"`