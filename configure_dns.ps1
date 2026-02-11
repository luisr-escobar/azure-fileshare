# Script to configure the hosts file for Azure File Share access over VPN
# Must be run as Administrator

$ErrorActionPreference = "Stop"

Write-Host "Fetching Terraform outputs..." -ForegroundColor Cyan
try {
    $privateIp = terraform output -raw storage_account_private_ip
    $storageAccountName = terraform output -raw storage_account_name
}
catch {
    Write-Error "Failed to get Terraform outputs. Ensure 'terraform apply' has run successfully."
}

if (-not $privateIp -or -not $storageAccountName) {
    Write-Error "Could not retrieve IP or Hostname from Terraform."
}

$hostName = "$storageAccountName.file.core.windows.net"
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$entry = "$privateIp $hostName"

Write-Host "Configuring hosts file:" -ForegroundColor Cyan
Write-Host "  IP:   $privateIp"
Write-Host "  Host: $hostName"
Write-Host "  File: $hostsPath"

# Check if entry already exists
$content = Get-Content $hostsPath
if ($content -match [regex]::Escape($hostName)) {
    Write-Warning "Entry for $hostName already exists in hosts file."
    # Optional: Update it if IP matches? For now, just warn.
    if ($content -match [regex]::Escape($privateIp)) {
        Write-Host "  And the IP matches. No changes needed." -ForegroundColor Green
        exit
    }
    else {
        Write-Warning "  BUT the IP does not match! You might want to check the file manually."
    }
}
else {
    try {
        Add-Content -Path $hostsPath -Value "`r`n$entry" -ErrorAction Stop
        Write-Host "Successfully added entry to hosts file." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to write to hosts file. Ensure you are running as Administrator."
    }
}

Write-Host "`r`nVerifying DNS resolution..."
try {
    $mp = Resolve-DnsName -Name $hostName -ErrorAction SilentlyContinue
    if ($mp.IPAddress -contains $privateIp) {
        Write-Host "DNS Resolution Verified! $hostName -> $privateIp" -ForegroundColor Green
    }
    else {
        Write-Warning "Resolution verification failed. It resolved to: $($mp.IPAddress)"
    }
}
catch {
    Write-Warning "Could not test resolution."
}
