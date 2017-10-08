# variables
### DEFINE YOUR OWN VALUES THERE
$RGName="SF"
$KeyVaultName="valdaSFKeyVault"
$ResourceGroupLocation="South Central US"
$dnsName="10.10.0.4"
$clusterName="valdasf"
$aadTenantId="00000000-0000-0000-0000-000000000000"
$certImportName="sfCert"
$certImportNameApp="sfCertApp"

Write-Output "#################### Starting script"

# Login to Azure
Login-AzureRmAccount

# Select your subscription if necessary
#Get-AzureRmSubscription
#Set-AzureRmContext -SubscriptionId <guid>

# create resource group
Write-Output ">>>>>> Creating Resource group"
$rg=New-AzureRmResourceGroup -Name $RGName -Location $ResourceGroupLocation

# setup key vault (unique name)
Write-Output ">>>>>> Creating Key vault"
$keyvault=New-AzureRmKeyVault -VaultName $KeyVaultName -ResourceGroupName $RGName -Location $ResourceGroupLocation -EnabledForDeployment

# Create new certificate
Write-Output ">>>>>> Generating certificates"
Import-Module .\New-SelfSignedCertificateEx.ps1
$securePassword = ConvertTo-SecureString -String "azure" -AsPlainText -Force

$cert=New-SelfsignedCertificateEx -Subject "CN=$($dnsName)" -EKU "Server Authentication", "Client authentication", "Document Encryption" -KeyUsage "KeyEncipherment, DigitalSignature, DataEncipherment" -Path "mycertkey.pfx" -Password $securePassword -Exportable
$certapp=New-SelfsignedCertificateEx -Subject "CN=$($dnsName)" -EKU "Server Authentication", "Client authentication", "Document Encryption" -KeyUsage "KeyEncipherment, DigitalSignature, DataEncipherment" -Path "mycertkeyapp.pfx" -Password $securePassword -Exportable

# import certificate to keyvalut
Write-Output ">>>>>> Importing certificates to keyvault"
Set-ExecutionPolicy Unrestricted -Scope Process

$loadedCert=Import-AzureKeyVaultCertificate -VaultName $KeyVaultName -Name $certImportName -FilePath "mycertkey.pfx" -Password $securePassword
$loadedCertApp=Import-AzureKeyVaultCertificate -VaultName $KeyVaultName -Name $certImportName -FilePath "mycertkeyapp.pfx" -Password $securePassword

# AAD staff
Write-Output ">>>>>> Create AAD application"
$aad=.\AADTool\SetupApplications.ps1 -TenantId $aadTenantId -ClusterName $clusterName -WebApplicationReplyUrl "https://$($dnsName):19080/Explorer/index.html"

# output

Write-Output "#################### OUTPUT values #######################"
Write-Output "##### AAD staff"
Write-Output ">>> aadTenantId: $($aad.TenantId)"
Write-Output ">>> aadClusterApplicationId: $($aad.WebAppId)"
Write-Output ">>> aadClientApplicationId: $($aad.NativeClientAppId)"

Write-Output "##### Certificate staff"
Write-Output ">>> clusterCertificateThumbprint: $($loadedCert.Certificate.Thumbprint)"
Write-Output ">>> clusterCertificateUrlValue: $($loadedCert.SecretId)"
Write-Output ">>> applicationCertificateUrlValue: $($loadedCertApp.SecretId)"
Write-Output ">>> sourceVaultvalue: $($keyvault.ResourceId)"

Write-Output "#################### OUTPUT assets #######################"
Write-Output "##### please collect files mycertkey.pfx (cluster certificate) and mycertkeyapp.pfx (application certificate)."

# provision template to Azure subscription
Write-Output ">>>>>> Provisioning of template ..."

### DEFINE YOUR OWN VALUES THERE
$secureClusterPassword = ConvertTo-SecureString -String "pwd123...pwd" -AsPlainText -Force
New-AzureRmResourceGroupDeployment -Name SFDeployment -ResourceGroupName $RGName `
  -TemplateFile azuredeploy.json `
  -clusterName $clusterName `
  -computeLocation $ResourceGroupLocation `
  -adminUserName "azureadmin" `
  -adminPassword $secureClusterPassword `
  -omsWorkspacename "valdasfoms" `
  -applicationInsightsName "valdasfappins" `
  -omsRegion "East US" `
  -appInsightsRegion "East US" `
  -clusterCertificateThumbprint $loadedCert.Certificate.Thumbprint `
  -clusterCertificateUrlValue $loadedCert.SecretId `
  -applicationCertificateUrlValue $loadedCertApp.SecretId `
  -sourceVaultvalue $keyvault.ResourceId `
  -aadTenantId $aad.TenantId `
  -aadClusterApplicationId $aad.WebAppId `
  -aadClientApplicationId $aad.NativeClientAppId `
  -clientRootCertName "RootCert1" `
  -clientRootCertData "MIIC5zCCAc+gAwIBAgIQE6mqUPntLbhI7xYn8FWGKzANBgkqhkiG9w0BAQsFADAWMRQwEgYDVQQDDAtQMlNSb290Q2VydDAeFw0xNzA5MTIwNjI3MzNaFw0xODA5MTIwNjQ3MzNaMBYxFDASBgNVBAMMC1AyU1Jvb3RDZXJ0MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1gBHkxhaJJnNyA3Gfku91Mk3hndXsgzRwIsHT3zMCiR1kvYmKD5mUkmAYieCnEstpuBm+5F0Z07yMWegc90umMZ5ih4AN2zEWtfteuHcVcrrvPWrodRPcVjVOEG3t1sWmd5wnedzqH+nTi8GWqDTpwyU+M8X7VMFbyfrDWP7VCgNyzYFUPrBSy3Q+Eg5iHZl4tieO4Lu8yTvtZNdesCMm1nwNJroL+04LA+umalNo0B7q6sKOAlUaJwTq2brAKOEaJJvmZff8r8QFwG+L6LoPXmBSxrBnmK5ZMOFSzw/XbpREQAeA4qzrQFXJfxJeXTbyRtDHCEC7WWEmJnBI6hxJQIDAQABozEwLzAOBgNVHQ8BAf8EBAMCAgQwHQYDVR0OBBYEFG5Vf1SQHH/jkaH9XSJeohKlAwITMA0GCSqGSIb3DQEBCwUAA4IBAQB+NZhdvuBCcBrvdLbHcZ9UjVLwRqHVVXTIgCx3jD5C4Vwo/dOfRsGC0xouAtZbOwTk4cOmjHZ74gW+I52Ply2Evh2ULeuJtwdltTU3VlRJKWMoCtk2ZzcmU2C0kwXtBPAgYYxmMN5qQDojxLy6U20XdY+HsZkzvtESsjiYV6k8hg3mxpE2mqFaQvAVbSjno/vnGjoY/znm5HgAoT+opcp5fwUWq3RlwtM8N/S9O2RnLsDng7OPE3NMkdm971DkWYOHAsrvrisf/P9MNwgXcWSt7GjAmXEz8Lj7FVsUUSgl2KTQn+J9zRfQb5RpbZhXZaajrRx4XWgyby+qpoYhPKcL" 










