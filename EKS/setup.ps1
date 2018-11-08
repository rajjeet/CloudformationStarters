$ErrorActionPreference = "Stop"
Set-DefaultAWSRegion -Region us-east-1
$invocationDir = Split-Path (Get-Item $MyInvocation.MyCommand.Definition) -Parent

# Load Helper Functions
. ..\CFN-Helper-Functions.ps1

# Parameters 
$vpcPrefix = "172.16"
$keyPairName = "eks-keypair"
$bucketName = "eks-phullr2"

# Storage
$storageStack = Install-CFNStack -stackName "eks-storage" `
  -templateBody (Get-Content (Join-Path $invocationDir "storage.yml") -Raw) `
  -parameterList @( `
  @{ ParameterKey = "BucketName"; ParameterValue = $bucketName } `
) 

Invoke-EC2KeyPairCreation -KeyPairName $keyPairName -BucketName $bucketName

# Network
$networkStack = Install-CFNStack -stackName "eks-network" `
  -templateBody (Get-Content (Join-Path $invocationDir "network.yml") -Raw) `
  -timeout 1200 `
  -parameterList @( `
  @{ ParameterKey = "VpcPrefix"; ParameterValue = $vpcPrefix } `
) 
$vpc = ($networkStack | Where-Object {$_.OutputKey -eq "Vpc"}).OutputValue
$publicSubnetAz1 = ($networkStack | Where-Object {$_.OutputKey -eq "PublicSubnetAz1"}).OutputValue
$publicSubnetAz2 = ($networkStack | Where-Object {$_.OutputKey -eq "PublicSubnetAz2"}).OutputValue
$privateSubnetAz1 = ($networkStack | Where-Object {$_.OutputKey -eq "PrivateSubnetAz1"}).OutputValue
$privateSubnetAz2 = ($networkStack | Where-Object {$_.OutputKey -eq "PrivateSubnetAz2"}).OutputValue

# Security
$securityStack = Install-CFNStack -stackName "eks-security" `
  -templateBody (Get-Content (Join-Path $invocationDir "security.yml") -Raw) `
  -capabilityIAM `
  -parameterList @( `
  @{ ParameterKey = "VpcId"; ParameterValue = $vpc}
) 
$clusterControlPlaneServiceRole = ($securityStack | Where-Object {$_.OutputKey -eq "ClusterControlPlaneServiceRole"}).OutputValue
$nodeInstanceProfile = ($securityStack | Where-Object {$_.OutputKey -eq "NodeInstanceProfile"}).OutputValue
$clusterControlPlaneSecurityGroup = ($securityStack | Where-Object {$_.OutputKey -eq "ClusterControlPlaneSecurityGroup"}).OutputValue
$nodeSecurityGroup = ($securityStack | Where-Object {$_.OutputKey -eq "NodeSecurityGroup"}).OutputValue

$clusterStack = Install-CFNStack -stackName "eks-cluster" `
  -templateBody (Get-Content (Join-Path $invocationDir "cluster.yml") -Raw) `
  -parameterList @( `
  @{ ParameterKey = "SecurityGroupId"; ParameterValue = $clusterControlPlaneSecurityGroup}, `
  @{ ParameterKey = "SubnetId1"; ParameterValue = $publicSubnetAz1 }, `
  @{ ParameterKey = "SubnetId2"; ParameterValue = $publicSubnetAz2 }, `
  @{ ParameterKey = "EksClusterRole"; ParameterValue = $clusterControlPlaneServiceRole } `
)
$clusterControlPlane = ($clusterStack | Where-Object {$_.OutputKey -eq "ClusterControlPlane"}).OutputValue

# $nodeStack = Install-CFNStack -stackName "eks-nodes" `
#   -templateBody (Get-Content (Join-Path $invocationDir "nodes.yml") -Raw) `
#   -parameterList @( `
#   @{ ParameterKey = "NodeInstanceProfile"; ParameterValue = $nodeInstanceProfile }, `
#   @{ ParameterKey = "NodeSecurityGroup"; ParameterValue = $nodeSecurityGroup }, `
#   @{ ParameterKey = "KeyName"; ParameterValue = $keyPairName }, `
#   @{ ParameterKey = "ClusterName"; ParameterValue = $clusterControlPlane }, `
#   @{ ParameterKey = "BootstrapArguments"; ParameterValue = "" }, `
#   @{ ParameterKey = "Subnet1Id"; ParameterValue = $publicSubnetAz1 }, `
#   @{ ParameterKey = "Subnet2Id"; ParameterValue = $publicSubnetAz2 } `
# )
