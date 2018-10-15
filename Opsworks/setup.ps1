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
$keyPairName = "opsworks-keypair"
$bucketName = "opsworks-phullr2"
$cookbook = "opsworks_cookbook_demo"

# Storage
$storageStack = Install-CFNStack -stackName "opsworks-storage" `
  -templateBody (Get-Content (Join-Path $invocationDir "storage.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="BucketName"; ParameterValue=$bucketName } `
  ) 

Invoke-EC2KeyPairCreation -KeyPairName $keyPairName -BucketName $bucketName

# Network
$networkStack = Install-CFNStack -stackName "opsworks-network" `
  -templateBody (Get-Content (Join-Path $invocationDir "network.yml") -Raw) `
  -timeout 1200 `
  -parameterList @( `
    @{ ParameterKey="VpcPrefix"; ParameterValue=$vpcPrefix } `
  ) 
$vpc              = ($networkStack | Where-Object {$_.OutputKey -eq "Vpc"}).OutputValue
$publicSubnetAz1  = ($networkStack | Where-Object {$_.OutputKey -eq "PublicSubnetAz1"}).OutputValue
$publicSubnetAz2  = ($networkStack | Where-Object {$_.OutputKey -eq "PublicSubnetAz2"}).OutputValue
$appSubnetAz1     = ($networkStack | Where-Object {$_.OutputKey -eq "AppSubnetAz1"}).OutputValue
$appSubnetAz2     = ($networkStack | Where-Object {$_.OutputKey -eq "AppSubnetAz2"}).OutputValue

# Security
$securityStack = Install-CFNStack -stackName "opsworks-security" `
  -templateBody (Get-Content (Join-Path $invocationDir "security.yml") -Raw) `
  -capabilityIAM `
  -parameterList @( `
    @{ ParameterKey="Vpc"; ParameterValue=$vpc}, `
    @{ ParameterKey="VpcPrefix"; ParameterValue=$vpcPrefix } `
  ) 
$iamInstanceProfileArn  = ($securityStack | Where-Object {$_.OutputKey -eq "IamInstanceProfileArn"}).OutputValue
$publicSecurityGroup    = ($securityStack | Where-Object {$_.OutputKey -eq "PublicSecurityGroup"}).OutputValue
$appSecurityGroup       = ($securityStack | Where-Object {$_.OutputKey -eq "AppSecurityGroup"}).OutputValue
$sshSecurityGroup       = ($securityStack | Where-Object {$_.OutputKey -eq "SshSecurityGroup"}).OutputValue

# if (Test-Path "$cookbookArtifact.tar.gz") {
#   Remove-Item "$cookbookArtifact.tar.gz" -Force
# }
# 7z a -ttar -so "$cookbookArtifact.tar" "$cookbookArtifact/" | 7z a -si -aoa "$cookbookArtifact.tar.gz" 
# Start-Sleep -Seconds 3
# berks install -b ".\opsworks_cookbook_demo\Berksfile"

# berks package -b ".\opsworks_cookbook_demo\Berksfile"

# Get-ChildItem cookbooks-*.tar.gz | `
#   Sort-Object LastWriteTime -Descending | `
#   Select-Object -First 1 | `
#   Copy-Item -Destination opsworks_cookbook_demo.tar.gz -Force -Verbose
Write-S3Object -BucketName $bucketName -File "$cookbook.tar.gz" -Force -Verbose

$loadbalancerStack = Install-CFNStack -stackName "opsworks-loadbalancer" `
  -templateBody (Get-Content (Join-Path $invocationDir "loadbalancer.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="SecurityGroup"; ParameterValue=$publicSecurityGroup }, `
    @{ ParameterKey="Subnet1"; ParameterValue=$publicSubnetAz1 }, `
    @{ ParameterKey="Subnet2"; ParameterValue=$publicSubnetAz2 } `
  ) 
$loadBalancer   = ($loadbalancerStack | Where-Object {$_.OutputKey -eq "LoadBalancer"}).OutputValue
  
$stackLayerStack = Install-CFNStack -stackName "opsworks-stack-layer" `
  -templateBody (Get-Content (Join-Path $invocationDir "stack-layer.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="IamInstanceProfileArn"; ParameterValue=$iamInstanceProfileArn }, `
    @{ ParameterKey="DefaultSubnet"; ParameterValue=$appSubnetAz1 }, `
    @{ ParameterKey="Vpc"; ParameterValue=$vpc }, `
    @{ ParameterKey="KeyName"; ParameterValue=$keyPairName }, `
    @{ ParameterKey="BucketName"; ParameterValue=$bucketName }, `
    @{ ParameterKey="Cookbook"; ParameterValue=$cookbook }, `
    @{ ParameterKey="AppSecurityGroup"; ParameterValue=$appSecurityGroup }, `
    @{ ParameterKey="PublicSecurityGroup"; ParameterValue=$publicSecurityGroup }, `
    @{ ParameterKey="SshSecurityGroup"; ParameterValue=$sshSecurityGroup }, `
    @{ ParameterKey="LoadBalancer"; ParameterValue=$loadBalancer } `
)
$stack                = ($stackLayerStack | Where-Object {$_.OutputKey -eq "MyCookbooksDemoStack"}).OutputValue
$webAppLayer          = ($stackLayerStack | Where-Object {$_.OutputKey -eq "WebAppLayer"}).OutputValue
$loadbalancingLayer   = ($stackLayerStack | Where-Object {$_.OutputKey -eq "LoadbalancingLayer"}).OutputValue
$bastionHostLayer     = ($stackLayerStack | Where-Object {$_.OutputKey -eq "BastionHostLayer"}).OutputValue

$instanceStack = Install-CFNStack -stackName "opsworks-instance" `
  -templateBody (Get-Content (Join-Path $invocationDir "instance.yml") -Raw) `
  -timeout 1200 `
  -parameterList @( `
    @{ ParameterKey="StackId"; ParameterValue=$stack }, `
    @{ ParameterKey="WebAppLayer"; ParameterValue=$webAppLayer }, `
    @{ ParameterKey="BastionHostLayer"; ParameterValue=$bastionHostLayer }, `
    @{ ParameterKey="LoadbalancingLayer"; ParameterValue=$loadbalancingLayer }, `
    @{ ParameterKey="AppSubnetAz1"; ParameterValue=$appSubnetAz1 }, `
    @{ ParameterKey="AppSubnetAz2"; ParameterValue=$appSubnetAz2 }, `
    @{ ParameterKey="PublicSubnetAz1"; ParameterValue=$publicSubnetAz1 } `
 ) 
  
