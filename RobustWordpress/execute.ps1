$ErrorActionPreference = "Stop"
Set-DefaultAWSRegion -Region us-east-1
$invocationDir = Split-Path (Get-Item $MyInvocation.MyCommand.Definition) -Parent

# Amis
$amiFilter = New-Object Amazon.EC2.Model.Filter
$amiFilter.Name = "name"
$amiFilter.Value = "amzn2-ami-hvm-2.0.2018*-x86_64-gp2"
$ami = (Get-EC2Image -Filter @($amiFilter) -Region us-east-1 | `
  Where-Object {$_.Public -eq $true} | `
  Sort-Object CreationDate -Descending | `
  Select-Object -First 1).ImageId

#ip addresses / networking parameters
$myHomeIpAddress = (Get-SSMParameter -Name MyHomeIpAddressCidr).Value
$myMobileIpAddress = "72.139.198.156/32"
$vpcPrefix = "172.16"
$domainName = "ortmesh.com"

# database parameters
$dbPassword = "V3rYStr0ngPass_"
$rootDBUser = "rajadmin"
# $rootDBUser = "root"
$dbName = "wordpress"

# Key pair
$keyPairName = "robust-wp-keypair"

# Storage parameter
$keyPairBucketName = "robust-wp-keypair"

# Load Helper Functions
. ..\CFN-Helper-Functions.ps1

# Storage
$storageStack = Install-CFNStack -stackName "robust-wp-storage" `
  -templateBody (Get-Content (Join-Path $invocationDir "robust-wp-storage.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="BucketName"; ParameterValue=$keyPairBucketName } `
  ) 

Invoke-EC2KeyPairCreation -KeyPairName $keyPairName $keyPairBucketName

# Network
$networkStack = Install-CFNStack -stackName "robust-wp-network" `
  -templateBody (Get-Content (Join-Path $invocationDir "robust-wp-network.yml") -Raw) `
  -timeout 1200 `
  -parameterList @( `
    @{ ParameterKey="VpcPrefix"; ParameterValue=$vpcPrefix } `
  ) 

$vpc = ($networkStack | Where-Object {$_.OutputKey -eq "Vpc"}).OutputValue

# Security
$securityStack = Install-CFNStack -stackName "robust-wp-security" `
  -templateBody (Get-Content (Join-Path $invocationDir "robust-wp-security.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="Vpc"; ParameterValue=$vpc}, `
    @{ ParameterKey="HomeIpAddress"; ParameterValue=$myHomeIpAddress}, `
    @{ ParameterKey="MobileIpAddress"; ParameterValue=$myMobileIpAddress}, `
    @{ ParameterKey="VpcPrefix"; ParameterValue=$vpcPrefix }, `
    @{ ParameterKey="BucketName"; ParameterValue=$keyPairBucketName } `
  ) 

$dataSecurityGroup = ($securityStack | Where-Object {$_.OutputKey -eq "DataSecurityGroup"}).OutputValue
$efsSecurityGroup = ($securityStack | Where-Object {$_.OutputKey -eq "EfsSecurityGroup"}).OutputValue
$sshSecurityGroup = ($securityStack | Where-Object {$_.OutputKey -eq "SshSecurityGroup"}).OutputValue
$appSecurityGroup = ($securityStack | Where-Object {$_.OutputKey -eq "AppSecurityGroup"}).OutputValue
$publicSecurityGroup = ($securityStack | Where-Object {$_.OutputKey -eq "PublicSecurityGroup"}).OutputValue

$publicSubnetAz1 = ($networkStack | Where-Object {$_.OutputKey -eq "PublicSubnetAz1"}).OutputValue
$publicSubnetAz2 = ($networkStack | Where-Object {$_.OutputKey -eq "PublicSubnetAz2"}).OutputValue
$appSubnetAz1 = ($networkStack | Where-Object {$_.OutputKey -eq "AppSubnetAz1"}).OutputValue
$appSubnetAz2 = ($networkStack | Where-Object {$_.OutputKey -eq "AppSubnetAz2"}).OutputValue
$dataSubnetAz1 = ($networkStack | Where-Object {$_.OutputKey -eq "DataSubnetAz1"}).OutputValue
$dataSubnetAz2 = ($networkStack | Where-Object {$_.OutputKey -eq "DataSubnetAz2"}).OutputValue

$instanceProfile = ($securityStack | Where-Object {$_.OutputKey -eq "InstanceProfile"}).OutputValue

$dataStack = Install-CFNStack -stackName "robust-wp-data" `
  -templateBody (Get-Content (Join-Path $invocationDir "robust-wp-data.yml") -Raw) `
  -timeout 3000 `
  -parameterList @( `
    @{ ParameterKey="DataSecurityGroup"; ParameterValue=$dataSecurityGroup}, `
    @{ ParameterKey="EfsSecurityGroup"; ParameterValue=$efsSecurityGroup}, `
    @{ ParameterKey="DataSubnetAz1"; ParameterValue=$dataSubnetAz1}, `
    @{ ParameterKey="DataSubnetAz2"; ParameterValue=$dataSubnetAz2 }, `
    @{ ParameterKey="DBName"; ParameterValue=$dbName }, `
    @{ ParameterKey="RootDBUser"; ParameterValue=$rootDBUser }, `
    @{ ParameterKey="DBPassword"; ParameterValue=$dbPassword } `
  ) 

$efs = ($dataStack | Where-Object {$_.OutputKey -eq "Efs"}).OutputValue
$rdsEndpoint = ($dataStack | Where-Object {$_.OutputKey -eq "RdsCluster"}).OutputValue
# $rdsEndpoint = 'localhost'

# Route53
# $domainStack = Install-CFNStack -stackName "robust-wp-domain" `
#   -templateBody (Get-Content (Join-Path $invocationDir "robust-wp-domain.yml") -Raw) `
#   -parameterList @( `
#     @{ ParameterKey="DomainName"; ParameterValue=$domainName } `
#   ) 
# $hostedZoneId = ($domainStack | Where-Object {$_.OutputKey -eq "HostedZoneId"}).OutputValue
# $nameServersStr = ($domainStack | Where-Object {$_.OutputKey -eq "NameServers"}).OutputValue

# # Update Name Servers of Registered Domain 
# Confirm-RegisteredDomainNameServers -DomainName $domainName -NameServerList $nameServersStr

# # ACM Certificate
# $certificateStack = Install-CFNStack -stackName "robust-wp-certificate" `
#   -templateBody (Get-Content (Join-Path $invocationDir "robust-wp-certificate.yml") -Raw) `
#   -timeout 7200 `
#   -parameterList @( `
#     @{ ParameterKey="DomainName"; ParameterValue=$domainName } `
#   ) 
  
# $certificateArn = ($certificateStack | Where-Object {$_.OutputKey -eq "CertificateArn"}).OutputValue

# Web servers
$webServerStack = Install-CFNStack -stackName "robust-wp-web-servers" `
  -templateBody (Get-Content (Join-Path $invocationDir "robust-wp-web-servers.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="KeyPair"; ParameterValue=$keyPairName }, `
    @{ ParameterKey="Vpc"; ParameterValue=$vpc}, `
    @{ ParameterKey="ImageAmi"; ParameterValue=$ami }, `
    @{ ParameterKey="PublicSecurityGroup"; ParameterValue=$publicSecurityGroup }, `
    @{ ParameterKey="AppSecurityGroup"; ParameterValue=$appSecurityGroup }, `
    @{ ParameterKey="SshSecurityGroup"; ParameterValue=$sshSecurityGroup }, `
    @{ ParameterKey="EfsSecurityGroup"; ParameterValue=$efsSecurityGroup }, `
    @{ ParameterKey="PublicSubnetAz1"; ParameterValue=$publicSubnetAz1 }, `
    @{ ParameterKey="PublicSubnetAz2"; ParameterValue=$publicSubnetAz2 }, `
    @{ ParameterKey="AppSubnetAz1"; ParameterValue=$appSubnetAz1 }, `
    @{ ParameterKey="AppSubnetAz2"; ParameterValue=$appSubnetAz2 }, `
    @{ ParameterKey="InstanceProfile"; ParameterValue=$instanceProfile }, `
    @{ ParameterKey="Efs"; ParameterValue=$efs }, `
    @{ ParameterKey="DBName"; ParameterValue=$dbName }, `
    @{ ParameterKey="RootDBUser"; ParameterValue=$rootDBUser }, `
    @{ ParameterKey="DBPassword"; ParameterValue=$dbPassword }, `
    @{ ParameterKey="DatabaseEndpoint"; ParameterValue=$rdsEndpoint }, `
    @{ ParameterKey="CertificateArn"; ParameterValue="" }, `
    @{ ParameterKey="S3LoggingBucket"; ParameterValue=$keyPairBucketName } `
  ) 

# Web servers
$bastionHostStack = Install-CFNStack -stackName "robust-wp-bastion-host" `
  -templateBody (Get-Content (Join-Path $invocationDir "robust-wp-bastion-host.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="KeyPair"; ParameterValue=$keyPairName }, `
    @{ ParameterKey="ImageAmi"; ParameterValue=$ami }, `
    @{ ParameterKey="SshSecurityGroup"; ParameterValue=$sshSecurityGroup }, `
    @{ ParameterKey="EfsSecurityGroup"; ParameterValue=$efsSecurityGroup }, `
    @{ ParameterKey="SubnetAz1"; ParameterValue=$publicSubnetAz1 }, `
    @{ ParameterKey="InstanceProfile"; ParameterValue=$instanceProfile }, `
    @{ ParameterKey="Efs"; ParameterValue=$efs } `
  ) 

# $albDnsName = ($serverStack | Where-Object {$_.OutputKey -eq "AlbDnsName"}).OutputValue

#   # Route53 Add A Record for Load Balancer
# $change1 = New-Object Amazon.Route53.Model.Change
# $change1.Action = "UPSERT"
# $change1.ResourceRecordSet = New-Object Amazon.Route53.Model.ResourceRecordSet
# $change1.ResourceRecordSet.Name = $domainName
# $change1.ResourceRecordSet.Type = "A"
# $change1.ResourceRecordSet.AliasTarget = New-Object Amazon.Route53.Model.AliasTarget
# $change1.ResourceRecordSet.AliasTarget.HostedZoneId = "Z35SXDOTRQ7X7K"
# $change1.ResourceRecordSet.AliasTarget.DNSName = "${albDnsName}."
# $change1.ResourceRecordSet.AliasTarget.EvaluateTargetHealth = $false

# $change2 = New-Object Amazon.Route53.Model.Change
# $change2.Action = "UPSERT"
# $change2.ResourceRecordSet = New-Object Amazon.Route53.Model.ResourceRecordSet
# $change2.ResourceRecordSet.Name = "*.${domainName}"
# $change2.ResourceRecordSet.Type = "A"
# $change2.ResourceRecordSet.AliasTarget = New-Object Amazon.Route53.Model.AliasTarget
# $change2.ResourceRecordSet.AliasTarget.DNSName = "${domainName}"
# $change2.ResourceRecordSet.AliasTarget.HostedZoneId = $hostedZoneId
# $change2.ResourceRecordSet.AliasTarget.EvaluateTargetHealth = $false

# Edit-R53ResourceRecordSet -HostedZoneId $hostedZoneId -ChangeBatch_Change $change1,$change2

# Finished 
Write-Host "SUCCESS" -BackgroundColor Green -ForegroundColor Black
