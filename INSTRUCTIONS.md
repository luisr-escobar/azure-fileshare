## Setup Instructions

### 1. Generate VPN Certificates
This project uses Certificate-based authentication for the VPN. You need to generate a self-signed Root and Client certificate.

Run the helper script:
```powershell
.\generate_certs.ps1
```
*   This will create a `P2SChildCert.pfx` in your folder.
*   **Action**: Double-click `P2SChildCert.pfx` and install it to "Current User".
*   *Note*: The script automatically configures Terraform to use the generated Root Certificate.

### 2. (Optional) Configure Cloud State Backend
By default, Terraform saves your infrastructure "state" to a file on your laptop (`terraform.tfstate`). If you lose this file, you lose control of the infrastructure. To save it safely in Azure, do this **before** deploying.

**A. Create a "State" Storage Account**
Run this one-time command in PowerShell to create a tiny storage account just for the state file:

```powershell
# 1. Variables
$RG = "rg-tfstate-fileshare"
$Location = "EastUS"
$SA_Name = "tfstate" + (Get-Random -Minimum 1000 -Maximum 9999) + "cad"

# 2. Create Resources
az group create --name $RG --location $Location
az storage account create --name $SA_Name --resource-group $RG --location $Location --sku Standard_LRS
az storage container create --name "tfstate" --account-name $SA_Name

# 3. Print the Storage Name (You need this!)
Write-Host "Your State Storage Name is: $SA_Name" -ForegroundColor Cyan
```

**B. Configure Terraform**
1.  Copy `backend.tf.example` to `backend.tf`.
2.  Edit `backend.tf` and replace `<unique_storage_name>` with the name printed above (e.g., `tfstate4829cad`).
3.  Initialize Terraform with the backend:
    ```powershell
    terraform init
    ```
    *(If you already have a local `terraform.tfstate`, it will ask to copy it to the cloud. Types `yes`.)*

### 3. Deploy Infrastructure
Login to Azure and deploy:

```powershell
az login
terraform init
terraform apply
```

> ⚠️ **IMPORTANT: The "Coffee Break" Warning** ☕
> The creation of the **VPN Gateway** (`azurerm_virtual_network_gateway`) takes **45 to 60 minutes** to complete.
> *   Terraform will look like it is "stuck" creating web_client_configuration. **This is normal.**
> *   **DO NOT** close the terminal or cancel the operation.
> *   Go grab lunch or attend a meeting while this runs.

### 4. Grant Permissions
Once deployed, you must explicitly grant access to the file share in the Azure Portal.

1.  Go to the **Storage Account** -> **IAM**.
2.  Add Role Assignment -> **Storage File Data SMB Share Contributor**.
3.  Assign to your Office 365 Users/Groups.

### 5. Client Configuration (DNS)
Since this solution uses a Private Endpoint without a Private DNS Server (to save cost), you must map the hostname on your client machine.

1.  Open PowerShell as **Administrator**.
2.  Run the included script:
    ```powershell
    .\configure_dns.ps1
    ```
3.  This maps the Storage Account Name to the Private IP (10.0.x.x) in your hosts file.

### 6. Connect & Map
1.  **Download VPN Client**: Azure Portal -> Virtual Network Gateway -> Point-to-site configuration -> Download VPN client.
2.  **Connect**: Connect to the VPN from your taskbar.
3.  **Map Drive**:
    ```powershell
    # Get the storage account name from terraform output
    $saName = terraform output -raw storage_account_name
    net use Z: \\$saName.file.core.windows.net\cad-projects /persistent:yes
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
