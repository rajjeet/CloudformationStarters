$ErrorActionPreference = "Stop"
Import-Module AWSPowershell 
Set-DefaultAWSRegion -Region us-east-1

# Load Helper Functions
. ..\CFN-Helper-Functions.ps1

$keyPairName = "robust-wp-keypair"
$keyPairBucketName = "robust-wp-keypair"
$domainName = "ortmesh.com"

# try {
#   $keypair = Get-EC2KeyPair -KeyName $keyPairName -Verbose
#   Remove-EC2KeyPair -KeyName $keyPair.KeyName -Force
# } catch {}

# if (Test-S3Bucket -BucketName $keyPairBucketName) {
#   Remove-S3Bucket -BucketName $keyPairBucketName -DeleteBucketContent -Force
# }

Uninstall-CFNStack -StackName "robust-wp-bastion-host" 
Uninstall-CFNStack -StackName "robust-wp-web-servers" 
# Uninstall-CFNStack -StackName "robust-wp-certificate" 
# Uninstall-Route53HostedZone -DomainName $domainName
# Uninstall-CFNStack -StackName "robust-wp-domain" 
Uninstall-CFNStack -StackName "robust-wp-data" 
# Uninstall-CFNStack -StackName "robust-wp-storage"
Uninstall-CFNStack -StackName "robust-wp-security" 
Uninstall-CFNStack -StackName "robust-wp-network" 



