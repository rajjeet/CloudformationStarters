aws cloudformation create-stack `
  --stack-name gateway-endpoints `
  --template-body file://template.yml `
  --region us-east-1 `
  --capabilities CAPABILITY_NAMED_IAM `
  --parameters `
    ParameterKey=KeyPairNameParam,ParameterValue=KeyPairTest `
    ParameterKey=ImageAmiParam,ParameterValue=ami-04169656fea786776 `
    ParameterKey=MyIpAddress,ParameterValue=99.99.99.99/32 `
    ParameterKey=MyVpcPrefix,ParameterValue=10.0

aws cloudformation update-stack `
  --stack-name gateway-endpoints `
  --template-body file://template.yml `
  --region us-east-1 `
  --capabilities CAPABILITY_NAMED_IAM `
  --parameters `
    ParameterKey=KeyPairNameParam,ParameterValue=KeyPairTest `
    ParameterKey=ImageAmiParam,ParameterValue=ami-04169656fea786776 `
    ParameterKey=MyIpAddress,ParameterValue=99.99.99.99/32 `
    ParameterKey=MyVpcPrefix,ParameterValue=10.0

aws cloudformation delete-stack  `
  --stack-name gateway-endpoints `
  --region us-east-1