$ErrorActionPreference = "Stop"
Import-Module AWSPowershell 
Set-DefaultAWSRegion -Region us-east-1

# Load Helper Functions
. ..\CFN-Helper-Functions.ps1

$keyPairName = "ssm-basics-keypair"
$keyPairBucketName = "ssm-basics-keypair"

try {
  $keypair = Get-EC2KeyPair -KeyName $keyPairName -Verbose
  Remove-EC2KeyPair -KeyName $keyPair.KeyName -Force
} catch {}

if (Test-S3Bucket -BucketName $keyPairBucketName) {
  Remove-S3Bucket -BucketName $keyPairBucketName -DeleteBucketContent -Force
}

Uninstall-CFNStack -StackName "ssm-basics-inventory"
Uninstall-CFNStack -StackName "ssm-basics-state-manager" 
Uninstall-CFNStack -StackName "ssm-basics-patch-manager" 
Uninstall-CFNStack -StackName "ssm-basics-automation" 
Uninstall-CFNStack -StackName "ssm-basics-servers" 
Uninstall-CFNStack -StackName "ssm-basics-storage"
Uninstall-CFNStack -StackName "ssm-basics-security" 
Uninstall-CFNStack -StackName "ssm-basics-network" 



