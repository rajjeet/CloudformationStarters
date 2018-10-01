function Install-CFNStack ($stackName, $templateBody, $parameterList, $region, $timeout = 600) {
  $ErrorActionPreference = "Stop"  
  Import-Module AWSPowershell
  Set-DefaultAWSRegion -Region $region
  try {    
    return Update-MyCFNStack -stackName $stackName -templateBody $templateBody -parameterList $parameterList -timeout $timeout
  } catch [InvalidOperationException] {
    if( $PSItem.Exception.Message -eq "Stack [$stackName] does not exist") {
      return New-MyCFNStack -stackName $stackName -templateBody $templateBody -parameterList $parameterList -timeout $timeout
    } elseif ($PSItem.Exception.Message -eq "No updates are to be performed.") {
      Write-Host "No updates are to be performed on Stack [$stackName]"
      return (Get-CFNStack -StackName $stackName).Outputs
    } elseif ($PSItem.Exception.Message -match "Stack:arn:aws:cloudformation:${region}.*stack/${stackName}/.* is in ROLLBACK_COMPLETE state and can not be updated.") {
        Write-Host "Stack [${stackName}] is in ROLLBACK_COMPLETE state and needs to be recreated..."
        Uninstall-CFNStack -StackName $stackName | Out-Null
        return New-MyCFNStack -stackName $stackName -templateBody $templateBody -parameterList $parameterList -timeout $timeout
    }
     else {
      Throw "[$stackName] $PSItem.Exception"
    }  
  }  
}

function Update-MyCFNStack ($stackName, $templateBody, $parameterList, $timeout) {
  Update-CFNStack -Stackname $stackName -TemplateBody $templateBody -Parameter $parameterList -Capability CAPABILITY_NAMED_IAM
  Write-Host "Updating stack [${stackName}]..."
  Wait-CFNStack -StackName $stackName -Timeout $timeout -Status UPDATE_COMPLETE,UPDATE_ROLLBACK_COMPLETE
  CheckCFNRollback -stackName $stackName
  Write-Host "Stack [${stackName}] Updated." -ForegroundColor Green
  return (Get-CFNStack -StackName $stackName).Outputs
}

function New-MyCFNStack ($stackName, $templateBody, $parameterList, $timeout){
  New-CFNStack -Stackname $stackName -TemplateBody $templateBody -Parameter $parameterList -Capability CAPABILITY_NAMED_IAM
  Write-Host "Creating stack [${stackName}]..."
  Wait-CFNStack -StackName $stackName -Timeout $timeout -Status CREATE_COMPLETE,ROLLBACK_COMPLETE
  CheckCFNRollback -stackName $stackName
  Write-Host "Stack [${stackName}] created."
  return (Get-CFNStack -StackName $stackName).Outputs
}

function CheckCFNRollback ($stackName) {
  if ((Get-CFNStack -StackName $stackName).StackStatus -in @("ROLLBACK_COMPLETE", "UPDATE_ROLLBACK_COMPLETE")){
    Write-Host ((Get-CFNStackEvents -StackName $stackName | Where-Object ResourceStatus -in @("CREATE_FAILED", "UPDATE_FAILED")).ResourceStatusReason  | `
      Select-Object -First 1) -ForegroundColor Red
    Throw "Stack [${stackName}] failed to update."
  }
}
function Uninstall-CFNStack ($StackName) {
  If ($StackName -in (Get-CFNStack).StackName) {
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

function Invoke-EC2KeyPairCreation ($KeyPairName, $BucketName) {
  try {
    Get-EC2KeyPair -KeyName $keyPairName | Out-Null
  } catch [InvalidOperationException] {
    if ($PSItem.Exception.Message -eq "The key pair '${keyPairName}' does not exist"){
      $keyPair = New-EC2KeyPair -KeyName $keyPairName
      $keyPair.KeyMaterial | Set-Content -Path ".\${keyPairName}.pem" -Force
      Write-S3Object -BucketName $keyPairBucketName -Key $keyPairName -File ".\${keyPairName}.pem" | Out-Null
      Write-Host "Keypair ${keyPairName} created." -ForegroundColor Green
    }
  }
}
