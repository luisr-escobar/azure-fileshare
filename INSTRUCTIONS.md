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

# 1. List your subscriptions to find the "Subscription ID"
az account list --output table

# 2. Set the active subscription (Replace xxxxx with your ID)
az account set --subscription "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# 3. Verify it is set
az account show

terraform init
terraform apply
```


> **Troubleshooting**: If you still see `Error: building account`, run this in PowerShell to force Terraform to use your subscription:
> ```powershell
> $env:ARM_SUBSCRIPTION_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
> # (Replace x's with your ID from 'az account list')
> ```

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

## 7. Setup for Additional Devices
Once the initial infrastructure is deployed, you do not need to run Terraform again. To connect a new PC or employee laptop to the file share, follow these steps:

1. **Install the Client Certificate**:
    * Securely transfer the `P2SChildCert.pfx` file (generated earlier in Step 1) to the new device.
    * Double-click the file to install it into the **Current User** certificate store.
2. **Download and Install the VPN Client**:
    * An Azure Administrator must log into the Azure Portal.
    * Navigate to the **Virtual Network Gateway** -> **Point-to-site configuration** and click **Download VPN client**.
    * Install the downloaded VPN client on the new device.
3. **Configure DNS (Hosts File)**:
    * Copy the `configure_dns.ps1` script to the new device and run it as **Administrator**, OR manually add the mapping to `C:\Windows\System32\drivers\etc\hosts`:
      `10.0.x.x <storage_account_name>.file.core.windows.net`
4. **Connect and Map the Drive**:
    * Connect to the VPN from the Windows taskbar.
    * Map the network drive using your Storage Account name:
      ```powershell
      net use Z: \\<storage_account_name>.file.core.windows.net\cad-projects /persistent:yes
      ```

## 8. Cleanup / Uninstall
To completely remove everything (stop billing and clean your PC):

### A. Destroy Azure Resources
This stops all billing.
```powershell
terraform destroy
```
*   Type `yes` when prompted.

### B. Remove Local Configs
1.  **VPN Client**: Go to **Settings** -> **Network & Internet** -> **VPN** -> Remove "vnet-fileshare".
2.  **Certificates**:
    *   Open Start -> Run -> `certmgr.msc`.
    *   Go to **Personal** -> **Certificates**.
    *   Delete `P2SChildCert`.
    *   (If you installed the Root) Go to **Trusted Root Certification Authorities** -> **Certificates** -> Delete `P2SRootCert`.
3.  **Hosts File**:
    *   Open `C:\Windows\System32\drivers\etc\hosts` as Admin.
    *   Remove the line: `10.0.x.x <storage>.file.core.windows.net`.
4.  **Files**: Delete the folder where you cloned this repo (unless you want to keep the code).
    