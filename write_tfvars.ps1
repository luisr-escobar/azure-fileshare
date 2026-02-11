$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -eq "CN=P2SRootCert" } | Select-Object -First 1
if ($cert) {
    $b64 = [System.Convert]::ToBase64String($cert.RawData)
    $content = 'vpn_root_cert_data = "' + $b64 + '"'
    Set-Content -Path "terraform.tfvars" -Value $content
    Write-Host "terraform.tfvars created successfully."
}
else {
    Write-Error "Certificate P2SRootCert not found in CurrentUser\My"
}
