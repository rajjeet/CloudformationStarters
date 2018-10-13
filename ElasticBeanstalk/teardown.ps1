$ErrorActionPreference = "Stop"
Import-Module AWSPowershell 
Set-DefaultAWSRegion -Region us-east-1

# Load Helper Functions
. ..\CFN-Helper-Functions.ps1

$keyPairName = "elastic-beanstalk-keypair"
$s3BucketName = "elastic-beanstalk-phullr2"

try {
  $keypair = Get-EC2KeyPair -KeyName $keyPairName -Verbose
  Remove-EC2KeyPair -KeyName $keyPair.KeyName -Force
} catch {}

if (Test-S3Bucket -BucketName $s3BucketName) {
  Remove-S3Bucket -BucketName $s3BucketName -DeleteBucketContent -Force
}

Uninstall-CFNStack -StackName "elastic-beanstalk-app" 
Uninstall-CFNStack -StackName "elastic-beanstalk-security" 
Uninstall-CFNStack -StackName "elastic-beanstalk-network" 
Uninstall-CFNStack -StackName "elastic-beanstalk-storage"





