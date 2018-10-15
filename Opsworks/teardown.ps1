$ErrorActionPreference = "Stop"
Import-Module AWSPowershell 
Set-DefaultAWSRegion -Region us-east-1

# Load Helper Functions
. ..\CFN-Helper-Functions.ps1

$keyPairName = "opsworks-keypair"
$bucketName = "opsworks-phullr2"

try {
  $keypair = Get-EC2KeyPair -KeyName $keyPairName -Verbose
  Remove-EC2KeyPair -KeyName $keyPair.KeyName -Force
} catch {}

if (Test-S3Bucket -BucketName $bucketName) {
  Remove-S3Bucket -BucketName $bucketName -DeleteBucketContent -Force
}

Uninstall-CFNStack -StackName "opsworks-instance" 
Uninstall-CFNStack -StackName "opsworks-stack-layer" 
Uninstall-CFNStack -StackName "opsworks-loadbalancer" 
Uninstall-CFNStack -StackName "opsworks-security" 
Uninstall-CFNStack -StackName "opsworks-network" 
Uninstall-CFNStack -StackName "opsworks-storage"





