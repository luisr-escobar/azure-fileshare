# Script to generate Self-Signed Root and Client Certificates for Azure P2S VPN
# Run this as Administrator

# Load .env file if it exists
if (Test-Path ".env") {
  Get-Content ".env" | ForEach-Object {
    if ($_ -match "^(?!#)(.+?)=(.+)$") {
      [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
    }
  }
}

$EnvPassword = $Env:PFX_PASSWORD
if (-not $EnvPassword) {
  $EnvPassword = "ChangeThisPassword123!"
  Write-Warning "PFX_PASSWORD not found in .env. Using default: $EnvPassword"
}

$CertPassword = ConvertTo-SecureString -String $EnvPassword -Force -AsPlainText
$SubjectName = "P2SRootCert"

Write-Host "Create Root Certificate..." -ForegroundColor Cyan
$rootCert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
  -Subject "CN=$SubjectName" -KeyExportPolicy Exportable `
  -HashAlgorithm sha256 -KeyLength 2048 `
  -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign

Write-Host "Create Client Certificate..." -ForegroundColor Cyan
$clientCert = New-SelfSignedCertificate -Type Custom -DnsName P2SChildCert -KeySpec Signature `
  -Subject "CN=P2SChildCert" -KeyExportPolicy Exportable `
  -HashAlgorithm sha256 -KeyLength 2048 `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -Signer $rootCert -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")

Write-Host "Exporting Root Certificate Public Key (Base64)..." -ForegroundColor Cyan
$rootCertData = [System.Convert]::ToBase64String($rootCert.RawData)

Write-Host "--------------------------------------------------------" -ForegroundColor Green
Write-Host "ROOT CERTIFICATE DATA (Copy this optionaly to Terraform var):" -ForegroundColor White
Write-Host $rootCertData -ForegroundColor Yellow
Write-Host "--------------------------------------------------------" -ForegroundColor Green

# Export Client Cert to PFX for distribution
$pwd = Get-Location
$clientPfxPath = "$pwd\P2SChildCert.pfx"
Export-PfxCertificate -Cert $clientCert -FilePath $clientPfxPath -Password $CertPassword

Write-Host "Client Certificate exported to: $clientPfxPath" -ForegroundColor Cyan
Write-Host "Password for PFX: P2SVal!dPl4ceh0ld3r" -ForegroundColor Magenta
Write-Host "Install this PFX on any client PC that needs to connect to the VPN." -ForegroundColor White
