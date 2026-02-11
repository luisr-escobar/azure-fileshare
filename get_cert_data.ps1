$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -eq "CN=P2SRootCert" } | Select-Object -First 1
if ($cert) {
    [System.Convert]::ToBase64String($cert.RawData)
}
else {
    Write-Error "Certificate P2SRootCert not found in CurrentUser\My"
}
