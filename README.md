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

For more information, see [INSTRUCTIONS.md](INSTRUCTIONS.md).