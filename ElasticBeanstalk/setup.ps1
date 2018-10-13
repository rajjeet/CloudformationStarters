# These set of cloudformation stacks demonstrate the use
# of cfn-init functions to bootstrap the ec2 during its initial launch. 
# The configuration also includes cfn-hup for processes to maintain the instance
# during subsequent updates. The ec2 instances are boostrapping CloudWatch Agent
# to send OS data to CloudWatch for continous monitoring of system state.

$ErrorActionPreference = "Stop"
Set-DefaultAWSRegion -Region us-east-1
$invocationDir = Split-Path (Get-Item $MyInvocation.MyCommand.Definition) -Parent

# Load Helper Functions
. ..\CFN-Helper-Functions.ps1

# Parameters 
$vpcPrefix = "172.16"
$keyPairName = "elastic-beanstalk-keypair"
$s3BucketName = "elastic-beanstalk-phullr2"

# Storage
$storageStack = Install-CFNStack -stackName "elastic-beanstalk-storage" `
  -templateBody (Get-Content (Join-Path $invocationDir "storage.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="BucketName"; ParameterValue=$s3BucketName } `
  ) 

Invoke-EC2KeyPairCreation -KeyPairName $keyPairName $s3BucketName

# Network 
$networkStack = Install-CFNStack -stackName "elastic-beanstalk-network" `
  -templateBody (Get-Content (Join-Path $invocationDir "network.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="VpcPrefix"; ParameterValue=$vpcPrefix } `
  ) 

$vpc = ($networkStack | Where-Object {$_.OutputKey -eq "Vpc"}).OutputValue
$publicSubnets = ($networkStack | Where-Object {$_.OutputKey -eq "PublicSubnets"}).OutputValue
$appSubnets = ($networkStack | Where-Object {$_.OutputKey -eq "AppSubnets"}).OutputValue
$dataSubnets = ($networkStack | Where-Object {$_.OutputKey -eq "DataSubnets"}).OutputValue

# Security
$securityStack = Install-CFNStack -stackName "elastic-beanstalk-security" `
  -templateBody (Get-Content (Join-Path $invocationDir "security.yml") -Raw) `
  -capabilityIAM `
  -parameterList @( `
    @{ ParameterKey="Vpc"; ParameterValue=$vpc} `
) 

$sshSecurityGroup = ($securityStack | Where-Object {$_.OutputKey -eq "SshSecurityGroup"}).OutputValue 
$publicSecurityGroup = ($securityStack | Where-Object {$_.OutputKey -eq "PublicSecurityGroup"}).OutputValue 
$appSecurityGroup = ($securityStack | Where-Object {$_.OutputKey -eq "AppSecurityGroup"}).OutputValue 
$iamInstanceProfile = ($securityStack | Where-Object {$_.OutputKey -eq "IamInstanceProfile"}).OutputValue 

Install-CFNStack -stackName "elastic-beanstalk-app" `
  -templateBody (Get-Content (Join-Path $invocationDir "app.yml") -Raw) `
  -timeout 1200 `
  -parameterList @( `
    @{ ParameterKey="BucketName"; ParameterValue=$s3BucketName }, `
    @{ ParameterKey="Vpc"; ParameterValue=$vpc }, `
    @{ ParameterKey="AppSubnets"; ParameterValue=$appSubnets }, `
    @{ ParameterKey="PublicSubnets"; ParameterValue=$publicSubnets }, `
    @{ ParameterKey="DataSubnets"; ParameterValue=$dataSubnets }, `
    @{ ParameterKey="KeyPairName"; ParameterValue=$keyPairName }, `
    @{ ParameterKey="IamInstanceProfile"; ParameterValue=$iamInstanceProfile }, `
    @{ ParameterKey="AppSecurityGroup"; ParameterValue="$appSecurityGroup"}, `
    @{ ParameterKey="PublicSecurityGroup"; ParameterValue="$publicSecurityGroup" }, `
    @{ ParameterKey="SshSecurityGroup"; ParameterValue="$sshSecurityGroup" } `
  ) 

