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
$keyPairName = "bootstrap-ec2-keypair"
$s3BucketName = "bootstrap-ec2-phullr2"

# Storage
$storageStack = Install-CFNStack -stackName "bootstrap-ec2-storage" `
  -templateBody (Get-Content (Join-Path $invocationDir "storage.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="BucketName"; ParameterValue=$s3BucketName } `
  ) 

Invoke-EC2KeyPairCreation -KeyPairName $keyPairName $s3BucketName

# Network
$networkStack = Install-CFNStack -stackName "bootstrap-ec2-network" `
  -templateBody (Get-Content (Join-Path $invocationDir "network.yml") -Raw) `
  -timeout 1200 `
  -parameterList @( `
    @{ ParameterKey="VpcPrefix"; ParameterValue=$vpcPrefix } `
  ) 

$vpc = ($networkStack | Where-Object {$_.OutputKey -eq "Vpc"}).OutputValue
$publicSubnetAz1 = ($networkStack | Where-Object {$_.OutputKey -eq "PublicSubnetAz1"}).OutputValue

# Security
$securityStack = Install-CFNStack -stackName "bootstrap-ec2-security" `
  -templateBody (Get-Content (Join-Path $invocationDir "security.yml") -Raw) `
  -capabilityIAM `
  -parameterList @( `
    @{ ParameterKey="Vpc"; ParameterValue=$vpc}, `
    @{ ParameterKey="VpcPrefix"; ParameterValue=$vpcPrefix }, `
    @{ ParameterKey="BucketName"; ParameterValue=$s3BucketName } `
  ) 

$sshSecurityGroup = ($securityStack | Where-Object {$_.OutputKey -eq "SshSecurityGroup"}).OutputValue
$cloudwatchAgentServerInstanceRole = ($securityStack | Where-Object {$_.OutputKey -eq "CloudwatchAgentServerInstanceRole"}).OutputValue

$cwAgentConfigUbuntuContents = (Get-Content ./amazon-cloudwatch-agent-ubuntu.json) 
$cwAgentConfigWindowsContents = (Get-Content ./amazon-cloudwatch-agent-windows.json) 

$parameterStack = Install-CFNStack -stackName "bootstrap-ec2-parameter" `
  -templateBody (Get-Content (Join-Path $invocationDir "parameter.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="CWAgentConfigUbuntuContents"; ParameterValue=$cwAgentConfigUbuntuContents }, `
    @{ ParameterKey="CWAgentConfigWindowsContents"; ParameterValue=$cwAgentConfigWindowsContents } `
  ) 

$CWAgentConfigUbuntuParam = ($parameterStack | Where-Object {$_.OutputKey -eq "CWAgentConfigUbuntuParam"}).OutputValue
$CWAgentConfigWindowsParam = ($parameterStack | Where-Object {$_.OutputKey -eq "CWAgentConfigWindowsParam"}).OutputValue

$serverStack = Install-CFNStack -stackName "bootstrap-ec2-servers" `
  -timeout 1200 `
  -templateBody (Get-Content (Join-Path $invocationDir "server.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="KeyPair"; ParameterValue=$keyPairName}, `
    @{ ParameterKey="SecurityGroup1"; ParameterValue=$sshSecurityGroup}, `
    @{ ParameterKey="Subnet1"; ParameterValue=$publicSubnetAz1}, `
    @{ ParameterKey="InstanceProfile"; ParameterValue=$cloudwatchAgentServerInstanceRole }, `
    @{ ParameterKey="CwAgentConfigUbuntuParam"; ParameterValue=$CWAgentConfigUbuntuParam }, `
    @{ ParameterKey="CwAgentConfigWindowsParam"; ParameterValue=$CWAgentConfigWindowsParam } `
  ) 

$serverStack | select OutputKey, OutputValue | ft
$windowsInstanceId = ($serverStack | Where-Object {$_.OutputKey -eq "WindowsInstanceId"}).OutputValue
Get-EC2PasswordData -InstanceId $windowsInstanceId -PemFile './bootstrap-ec2-keypair.pem'

# Finished 
Write-Host "SUCCESS" -BackgroundColor Green -ForegroundColor Black

