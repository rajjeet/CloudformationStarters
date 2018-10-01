$ErrorActionPreference = "Stop"
Set-DefaultAWSRegion -Region us-east-1

# Parameters
$ami = (aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server*" | ConvertFrom-Json).Images.ImageId[0]
$myIpAddress = (Get-SSMParameter -Name MyHomeIpAddressCidr -WithDecryption $true).Value
$domainName = (Get-SSMParameter -Name MyWebsiteDomainName).Value
$invocationDir = Split-Path (Get-Item $MyInvocation.MyCommand.Definition) -Parent
$vpcPrefix = "10.0"

# Load Helper Functions
. ..\CFN-Helper-Functions.ps1

$keyPairName = "ssm-basics-keypair"
$keyPairBucketName = "ssm-basics-keypair"
$ubuntuPatchGroupKey = "Ubuntu 18.04 AMD64 HMV SSD"

$storageCFNStack = Install-CFNStack -stackName "ssm-basics-storage" `
  -templateBody (Get-Content (Join-Path $invocationDir "ssm-basics-storage.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="BucketName"; ParameterValue=$keyPairBucketName } `
  ) 

Invoke-EC2KeyPairCreation -KeyPairName $keyPairName $keyPairBucketName

# Network
$networkCFNStack = Install-CFNStack -stackName "ssm-basics-network" `
  -templateBody (Get-Content (Join-Path $invocationDir "ssm-basics-network.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="VpcPrefix"; ParameterValue=$vpcPrefix } `
  ) 

$vpc = ($networkCFNStack | Where-Object {$_.OutputKey -eq "Vpc"}).OutputValue

# Security
$securityCFNStack = Install-CFNStack -stackName "ssm-basics-security" `
  -templateBody (Get-Content (Join-Path $invocationDir "ssm-basics-security.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="Vpc"; ParameterValue=$vpc}, `
    @{ ParameterKey="IpAddress"; ParameterValue=$myIpAddress}, `
    @{ ParameterKey="VpcPrefix"; ParameterValue=$vpcPrefix } `
  ) 

$securityGroup = ($securityCFNStack | Where-Object {$_.OutputKey -eq "Ec2SecurityGroup"}).OutputValue
$subnet1 = ($networkCFNStack | Where-Object {$_.OutputKey -eq "Subnet1"}).OutputValue
$instanceProfile = ($securityCFNStack | Where-Object {$_.OutputKey -eq "InstanceProfile"}).OutputValue

# Web servers
$serverCFNStack = Install-CFNStack -stackName "ssm-basics-servers" `
  -templateBody (Get-Content (Join-Path $invocationDir "ssm-basics-servers.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="KeyPair"; ParameterValue=$keyPairName }, `
    @{ ParameterKey="UbuntuImageAmi"; ParameterValue=$ami }, `
    @{ ParameterKey="SecurityGroup"; ParameterValue=$securityGroup }, `
    @{ ParameterKey="Subnet1"; ParameterValue=$subnet1 }, `
    @{ ParameterKey="InstanceProfile"; ParameterValue=$instanceProfile }, `
    @{ ParameterKey="UbuntuPatchGroupKey"; ParameterValue=$ubuntuPatchGroupKey }    
  ) 

$AutomationServiceRoleArn = ($securityCFNStack | Where-Object {$_.OutputKey -eq "AutomationServiceRoleArn"}).OutputValue

# Web servers
$automationCFNStack = Install-CFNStack -stackName "ssm-basics-automation" `
  -templateBody (Get-Content (Join-Path $invocationDir "ssm-basics-automation.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="AutomationServiceRoleArn"; ParameterValue=$AutomationServiceRoleArn } `
  ) 

$MaintenanceWindowRoleArn = ($securityCFNStack | Where-Object {$_.OutputKey -eq "MaintenanceWindowRoleArn"}).OutputValue
  
$patchCFNStack = Install-CFNStack -stackName "ssm-basics-patch-manager" `
  -templateBody (Get-Content (Join-Path $invocationDir "ssm-basics-patch-manager.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="UbuntuPatchGroupKey"; ParameterValue=$ubuntuPatchGroupKey }, `
    @{ ParameterKey="MaintenanceWindowRoleArn"; ParameterValue=$MaintenanceWindowRoleArn }, `
    @{ ParameterKey="BucketName"; ParameterValue=$keyPairBucketName } `
  ) 

$testDocument = ($automationCFNStack | Where-Object {$_.OutputKey -eq "CheckHostnameDocument"}).OutputValue

$stateManagerCFNStack = Install-CFNStack -stackName "ssm-basics-state-manager" `
  -templateBody (Get-Content (Join-Path $invocationDir "ssm-basics-state-manager.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="BucketName"; ParameterValue=$keyPairBucketName }, `
    @{ ParameterKey="SSMDocument"; ParameterValue=$testDocument } `
  ) 

$inventoryCFNStack = Install-CFNStack -stackName "ssm-basics-inventory" `
  -templateBody (Get-Content (Join-Path $invocationDir "ssm-basics-inventory.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="BucketName"; ParameterValue=$keyPairBucketName }    
  ) 

# Finished 
Write-Host "SUCCESS" -BackgroundColor Green -ForegroundColor Black
