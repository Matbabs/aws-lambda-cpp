#!/bin/bash
# https://aws.amazon.com/fr/blogs/compute/introducing-the-c-lambda-runtime/

helpFunction()
{
   echo ""
   echo "Usage: $0 -l lambda-name -p profile"
   echo -e "\t-l lambda-name"
   echo -e "\t-p profile"
   exit 1
}

getAwsAccount()
{
    account=$(aws sts get-caller-identity --query "Account" --output text)
}

deployCloudFormationTemplate()
{
    aws cloudformation deploy \
    --stack-name $lambda-stack \
    --template-file template.yml \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
    --parameter-overrides LambdaName=$lambda \
    --no-fail-on-empty-changeset \
    --output text

    status=$(aws cloudformation describe-stacks \
    --stack-name $lambda-stack \
    --query "Stacks[0].StackStatus")
    if [ $status != '"CREATE_COMPLETE"' ] && [ $status != '"UPDATE_COMPLETE"' ]; then
        aws cloudformation wait stack-update-complete \
        --stack-name $lambda-stack \
        --output text
    fi

    role=$(aws cloudformation describe-stacks \
    --stack-name $lambda-stack \
    --query "Stacks[0].Outputs[?OutputKey=='LambdaRoleArn'].OutputValue"\
    --output text)
}

prepareCMakeLists()
{
    cp CMakeLists-template.txt CMakeLists.txt
    sed -i "s/##LAMBDA##/${lambda}/g;" CMakeLists.txt
}

buildCppToZip()
{
    mkdir build
    cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=~/install
    make
    make aws-lambda-package-$lambda
    cd ..
}

linkApiGatewayWithLambda()
{
    apiId=$(aws apigateway get-rest-apis \
    --query "items[?name=='$lambda-stack']" \
    --output text \
    | awk '{print $4}' \
    | head -n 1)

    originResourceId=$(aws apigateway get-resources \
    --rest-api-id $apiId \
    --query "items[?path=='/']" \
    --output text \
    | awk '{print $1}')

    aws apigateway create-resource \
    --rest-api-id $apiId \
    --parent-id $originResourceId \
    --path-part "process" \
    --output text \
    | awk '{print $1}'

    resourceId=$(aws apigateway get-resources \
    --rest-api-id $apiId \
    --query "items[?path=='/process']" \
    --output text \
    | awk '{print $1}')

    region=$(aws configure get region --profile $profile)
    lambdaArn="arn:aws:apigateway:$region:lambda:path/2015-03-31/functions/arn:aws:lambda:$region:$account:function:$lambda/invocations"
    
    aws apigateway put-method \
    --rest-api-id $apiId \
    --resource-id $resourceId \
    --http-method POST \
    --authorization-type NONE
    aws apigateway put-integration \
    --rest-api-id $apiId \
    --resource-id $resourceId \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri $lambdaArn
    aws lambda add-permission \
    --function-name $lambda \
    --source-arn "arn:aws:execute-api:$region:$account:$apiId/*/POST/process" \
    --principal apigateway.amazonaws.com \
    --statement-id "$lambda-invokeRule" \
    --action lambda:InvokeFunction

    aws apigateway put-method \
    --rest-api-id $apiId \
    --resource-id $resourceId \
    --http-method OPTIONS \
    --authorization-type NONE
    aws apigateway put-integration \
    --rest-api-id $apiId \
    --resource-id $resourceId \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{ "application/json": "{\"statusCode\": 200}" }'
    aws apigateway put-method-response \
    --rest-api-id $apiId \
    --resource-id $resourceId \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters "method.response.header.Access-Control-Allow-Origin=true,method.response.header.Access-Control-Allow-Headers=true,method.response.header.Access-Control-Allow-Methods=true"
    aws apigateway put-integration-response \
    --rest-api-id $apiId \
    --resource-id $resourceId \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Origin": "'"'"'*'"'"'","method.response.header.Access-Control-Allow-Headers": "'"'"'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"'"'","method.response.header.Access-Control-Allow-Methods": "'"'"'OPTIONS,POST'"'"'"}'
    
    aws apigateway create-deployment --rest-api-id $apiId --stage-name v1
}

deployLambda()
{
    aws lambda get-function --function-name $lambda --output text
    if [ 0 -eq $? ]; then
        aws lambda update-function-code \
        --function-name $lambda \
        --zip-file fileb://build/$lambda.zip \
        --output text \
        --profile $profile
    else
        aws lambda create-function \
        --function-name $lambda \
        --role $role \
        --runtime provided \
        --timeout 15 \
        --memory-size 128 \
        --handler $lambda \
        --zip-file fileb://build/$lambda.zip \
        --environment Variables={BUCKET_NAME=$account-$lambda-files} \
        --output text \
        --profile $profile

        linkApiGatewayWithLambda
    fi
}

while getopts "l:p:" opt
do
    case "$opt" in
        l ) lambda="$OPTARG" ;;
        p ) profile="$OPTARG" ;;
        ? ) helpFunction ;;
    esac
done

if  [ -z "$lambda" ] || [ -z "$profile" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

getAwsAccount
deployCloudFormationTemplate
prepareCMakeLists
buildCppToZip
deployLambda