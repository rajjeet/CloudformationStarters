function Install-CFNStack ($stackName, $templateBody, $parameterList, $region, $timeout = 600) {
  $ErrorActionPreference = "Stop"  
  Import-Module AWSPowershell
  Set-DefaultAWSRegion -Region $region
  try {    
    Update-CFNStack -Stackname $stackName -TemplateBody $templateBody -Parameter $parameterList -Capability CAPABILITY_NAMED_IAM
    Write-Host "Updating stack [${stackName}]..."
    Wait-CFNStack -StackName $stackName -Timeout $timeout
    return (Get-CFNStack -StackName $stackName).Outputs
  } catch [InvalidOperationException] {
    if( $PSItem.Exception.Message -eq "Stack [$stackName] does not exist") {
      New-CFNStack -Stackname $stackName -TemplateBody $templateBody -Parameter $parameterList -Capability CAPABILITY_NAMED_IAM
      Write-Host "Creating stack [${stackName}]..."
      Wait-CFNStack -StackName $stackName -Timeout $timeout
      return (Get-CFNStack -StackName $stackName).Outputs
      
    } elseif ($PSItem.Exception.Message -eq "No updates are to be performed.") {
      Write-Host "No updates are to be performed on Stack [$stackName]"
      return (Get-CFNStack -StackName $stackName).Outputs
    } elseif ($PSItem.Exception.Message -match "Stack:arn:aws:cloudformation:${region}.*stack/${stackName}/.* is in ROLLBACK_COMPLETE state and can not be updated.") {
        Write-Host "Deleting and recreating stack [${stackName}]..."
        Remove-CFNStack -StackName $stackName -Force
        Wait-CFNStack -StackName $stackName -Timeout $timeout -Status DELETE_COMPLETE
        New-CFNStack -StackName $stackName -TemplateBody $templateBody -Parameter $parameterList -Capability CAPABILITY_NAMED_IAM
        Wait-CFNStack -StackName $stackName -Timeout $timeout
        return (Get-CFNStack -StackName $stackName).Outputs
    }
     else {
      Throw "[$stackName] $PSItem.Exception"
    }  
  }  
}
function Uninstall-CFNStack ($StackName) {
  If ((Get-CFNStack).StackName.Contains($StackName)) {
    Write-Host "Removing stack [${StackName}]."
    Remove-CFNStack -StackName $StackName -Force
    Wait-CFNStack -StackName $StackName -Status DELETE_COMPLETE -Timeout 1200
    Write-Host "Stack [${StackName}] removed."
  }  
}

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

