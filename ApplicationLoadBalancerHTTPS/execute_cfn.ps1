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

# Network
$networkingOutput = Install-CFNStack -stackName "alb-https-networking" `
  -templateBody (Get-Content (Join-Path $invocationDir "alb-https-networking.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="VpcPrefix"; ParameterValue=$vpcPrefix } `
  ) 

# Security
$securityOutput = Install-CFNStack -stackName "alb-https-security" `
  -templateBody (Get-Content (Join-Path $invocationDir "alb-https-security.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="Vpc"; ParameterValue=($networkingOutput | Where-Object {$_.OutputKey -eq "Vpc"}).OutputValue }, `
    @{ ParameterKey="IpAddress"; ParameterValue=$myIpAddress}, `
    @{ ParameterKey="VpcPrefix"; ParameterValue=$vpcPrefix } `
  ) 

# Web servers
$serversOutput = Install-CFNStack -stackName "alb-https-servers" `
  -templateBody (Get-Content (Join-Path $invocationDir "alb-https-servers.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="KeyPair"; ParameterValue="KeyPairTest" }, `
    @{ ParameterKey="ImageAmi"; ParameterValue=$ami }, `
    @{ ParameterKey="SecurityGroup"; ParameterValue=($securityOutput | Where-Object {$_.OutputKey -eq "Ec2SecurityGroup"}).OutputValue }, `
    @{ ParameterKey="Subnet1"; ParameterValue=($networkingOutput | Where-Object {$_.OutputKey -eq "Subnet1"}).OutputValue }, `
    @{ ParameterKey="Subnet2"; ParameterValue=($networkingOutput | Where-Object {$_.OutputKey -eq "Subnet2"}).OutputValue }, `
    @{ ParameterKey="InstanceProfile"; ParameterValue=($securityOutput | Where-Object {$_.OutputKey -eq "InstanceProfile"}).OutputValue } `
  ) 

# Route53
$domainOutput = Install-CFNStack -stackName "alb-https-domain" `
  -templateBody (Get-Content (Join-Path $invocationDir "alb-https-domain.yml") -Raw) `  
  -parameterList @( `
    @{ ParameterKey="DomainName"; ParameterValue=$domainName } `
  ) 
$hostedZoneId = ($domainOutput | Where-Object {$_.OutputKey -eq "HostedZoneId"}).OutputValue
$nameServersStr = ($domainOutput | Where-Object {$_.OutputKey -eq "NameServers"}).OutputValue

# Update Name Servers of Registered Domain 
$nameServers = @()
$nameServersStr.Split(",").ForEach{
  $ns = New-Object Amazon.Route53Domains.Model.Nameserver
  $ns.Name = $_
  $nameServers += $ns
}
Update-R53DDomainNameserver -DomainName $domainName -Nameserver $nameServers

# ACM Certificate
$certificateOutput = Install-CFNStack -stackName "alb-https-certificate" `
  -templateBody (Get-Content (Join-Path $invocationDir "alb-https-certificate.yml") -Raw) `
  -timeout 7200 `
  -parameterList @( `
    @{ ParameterKey="DomainName"; ParameterValue=$domainName } `
  ) 

# HTTPS Application Load Balancer (ALB)
$albOutput = Install-CFNStack -stackName "alb-https-loadbalancer" `
  -templateBody (Get-Content (Join-Path $invocationDir "alb-https-loadbalancer.yml") -Raw) `
  -parameterList @( `
    @{ ParameterKey="Vpc"; ParameterValue=($networkingOutput | Where-Object {$_.OutputKey -eq "Vpc"}).OutputValue }, `
    @{ ParameterKey="AlbName"; ParameterValue="alb-https-alb" }, `
    @{ ParameterKey="TargetGroupName"; ParameterValue="alb-https-targetGroup" }, `
    @{ ParameterKey="SecurityGroup"; ParameterValue=($securityOutput | Where-Object {$_.OutputKey -eq "AlbSecurityGroup"}).OutputValue }, `
    @{ ParameterKey="Subnet1"; ParameterValue=($networkingOutput | Where-Object {$_.OutputKey -eq "Subnet1"}).OutputValue }, `
    @{ ParameterKey="Subnet2"; ParameterValue=($networkingOutput | Where-Object {$_.OutputKey -eq "Subnet2"}).OutputValue }, `
    @{ ParameterKey="Instance1"; ParameterValue=($serversOutput | Where-Object {$_.OutputKey -eq "Instance1"}).OutputValue }, `
    @{ ParameterKey="Instance2"; ParameterValue=($serversOutput | Where-Object {$_.OutputKey -eq "Instance2"}).OutputValue }, `
    @{ ParameterKey="CertificateArn"; ParameterValue=($certificateOutput | Where-Object {$_.OutputKey -eq "CertificateArn"}).OutputValue } `
  ) 
$albDnsName = ($albOutput | Where-Object {$_.OutputKey -eq "AlbDnsName"}).OutputValue

# Route53 Add A Record for Load Balancer
$AResourceRecords = (Get-R53ResourceRecordSet -HostedZoneId $hostedZoneId).ResourceRecordSets.Where{$_.Type -eq 'A'}
if ($AResourceRecords.Where{$_.AliasTarget.DNSName -match $albDnsName }.Count -eq 0) {

    $change = New-Object Amazon.Route53.Model.Change
    $change.Action = "CREATE"
    $change.ResourceRecordSet = New-Object Amazon.Route53.Model.ResourceRecordSet
    $change.ResourceRecordSet.Name = $domainName
    $change.ResourceRecordSet.Type = "A"
    $change.ResourceRecordSet.AliasTarget = New-Object Amazon.Route53.Model.AliasTarget
    $change.ResourceRecordSet.AliasTarget.HostedZoneId = "Z35SXDOTRQ7X7K"
    $change.ResourceRecordSet.AliasTarget.DNSName = "${albDnsName}."
    $change.ResourceRecordSet.AliasTarget.EvaluateTargetHealth = $false

    Edit-R53ResourceRecordSet -HostedZoneId $hostedZoneId -ChangeBatch_Change $change
}

# Finished
Write-Host "SUCCESS" -BackgroundColor Green -ForegroundColor Black
