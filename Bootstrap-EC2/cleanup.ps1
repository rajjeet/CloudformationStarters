$ErrorActionPreference = "Stop"
Import-Module AWSPowershell 
Set-DefaultAWSRegion -Region us-east-1

# Load Helper Functions
. ..\CFN-Helper-Functions.ps1

$keyPairName = "bootstrap-ec2-keypair"
$keyPairBucketName = "bootstrap-ec2-keypair"

try {
  $keypair = Get-EC2KeyPair -KeyName $keyPairName -Verbose
  Remove-EC2KeyPair -KeyName $keyPair.KeyName -Force
} catch {}

if (Test-S3Bucket -BucketName $keyPairBucketName) {
  Remove-S3Bucket -BucketName $keyPairBucketName -DeleteBucketContent -Force
}

Uninstall-CFNStack -StackName "bootstrap-ec2-servers" 
Uninstall-CFNStack -StackName "bootstrap-ec2-parameter" 
Uninstall-CFNStack -StackName "bootstrap-ec2-security" 
Uninstall-CFNStack -StackName "bootstrap-ec2-network" 
Uninstall-CFNStack -StackName "bootstrap-ec2-storage"





