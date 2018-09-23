aws cloudformation create-stack `
  --stack-name interface-endpoints `
  --template-body file://template.yml `
  --region us-east-1 `
  --capabilities CAPABILITY_NAMED_IAM `
  --parameters `
    ParameterKey=KeyPairNameParam,ParameterValue=KeyPairTest `
    ParameterKey=ImageAmiParam,ParameterValue=ami-04169656fea786776 `
    ParameterKey=MyIpAddress,ParameterValue=99.234.19.94/32 `
    ParameterKey=VpcPrefix,ParameterValue=10.0

aws cloudformation update-stack `
  --stack-name interface-endpoints `
  --template-body file://template.yml `
  --region us-east-1 `
  --capabilities CAPABILITY_NAMED_IAM `
  --parameters `
    ParameterKey=KeyPairNameParam,ParameterValue=KeyPairTest `
    ParameterKey=ImageAmiParam,ParameterValue=ami-04169656fea786776 `
    ParameterKey=MyIpAddress,ParameterValue=99.234.19.94/32 `
    ParameterKey=MyVpcPrefix,ParameterValue=10.0

aws cloudformation delete-stack  `
  --stack-name interface-endpoints `
  --region us-east-1