$ErrorActionPreference = "Stop"
Import-Module AWSPowershell 
Set-DefaultAWSRegion -Region us-east-1

function Uninstall-Route53HostedZone ($DomainName) {
  $hostedZone = Get-R53HostedZoneList |  Where-Object {$_.Name -eq "${DomainName}."}
  if ($null -eq $hostedZone) {
    return
  }
  $recordSetsToRemove = (Get-R53ResourceRecordSet -HostedZoneId $hostedZone.Id).ResourceRecordSets.Where{$_.Type -notin @('NS','SOA')}
  
  foreach ($recordSet in $recordSetsToRemove) {
    $change = New-Object Amazon.Route53.Model.Change
    $change.Action = "DELETE"
    $change.ResourceRecordSet = $recordSet
    Edit-R53ResourceRecordSet -HostedZoneId $hostedZone.Id -ChangeBatch_Change $change
  }
  Remove-R53HostedZone -Id $hostedZone.Id -Force    
}
function Uninstall-ACMCertificate ($DomainName) {
  $certificateArn = (Get-ACMCertificateList | Where-Object {$_.DomainName -eq "ortmesh.com"} | Select-Object -first 1 ).CertificateArn
  if ($certificateArn){
    Remove-ACMCertificate -CertificateArn $certificateArn -Force
  }
}
function Uninstall-CFNStack ($StackName) {
  If ((Get-CFNStack).StackName.Contains($StackName)) {
    Remove-CFNStack -StackName $StackName -Force
    Wait-CFNStack -StackName $StackName -Status DELETE_COMPLETE -Timeout 1200
    Write-Host "Stack [${StackName}] removed."
  }  
}

$domainName = (Get-SSMParameter -Name MyWebsiteDomainName).Value

Uninstall-CFNStack -StackName "alb-https-loadbalancer" 
Uninstall-CFNStack -StackName "alb-https-certificate" 

Uninstall-Route53HostedZone -DomainName $domainName
Uninstall-CFNStack -StackName "alb-https-domain" 

Uninstall-CFNStack -StackName "alb-https-servers" 
Uninstall-CFNStack -StackName "alb-https-security" 
Uninstall-CFNStack -StackName "alb-https-networking" 

