$ErrorActionPreference = "Stop"
Import-Module AWSPowershell 
Set-DefaultAWSRegion -Region us-east-1

# Load Helper Functions
. ..\CFN-Helper-Functions.ps1

$domainName = (Get-SSMParameter -Name MyWebsiteDomainName).Value

Uninstall-CFNStack -StackName "alb-https-loadbalancer" 
Uninstall-CFNStack -StackName "alb-https-certificate" 

Uninstall-Route53HostedZone -DomainName $domainName
Uninstall-CFNStack -StackName "alb-https-domain" 

Uninstall-CFNStack -StackName "alb-https-servers" 
Uninstall-CFNStack -StackName "alb-https-security" 
Uninstall-CFNStack -StackName "alb-https-networking" 

