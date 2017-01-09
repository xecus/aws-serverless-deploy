#!/bin/bash

function prepare_zip_for_lambda () {
  local zip_path=$1
  rm $zip_path
  zip -r $zip_path *
}

function list_lambda () {
  aws lambda list-functions | jq -r ".Functions[].FunctionName"
}

function get_lambda () {
  local function_name=$1
  local query=$2
  aws lambda get-function --function-name $function_name | jq -r "${query}"
}

function create_lambda () {
  local function_name=$1
  local role=$2
  local zip_file_path=$3
  aws lambda create-function \
  --function-name $function_name \
  --runtime       python2.7 \
  --role          $role \
  --handler       lambda_function.lambda_handler \
  --zip-file      fileb://$zip_file_path
  if [ $? -ne 0 ]; then
    echo "Error: create_lambda returns non-zero"
    exit 1
  fi
}

function update_lambda () {
  lambda app_name=$1
  local zip_file_path=$2
  aws lambda update-function-code \
  --function-name $app_name \
  --zip-file fileb://$zip_file_path
  if [ $? -ne 0 ]; then
    echo "Error: update_lambda returns non-zero"
    exit 1
  fi
}

function delete_lambda () {
  local function_name=$1
  aws lambda delete-function --function-name $function_name
  if [ $? -ne 0 ]; then
    echo "Error: delete_lambda returns non-zero"
    exit 1
  fi
}

function delete_all_lambda () {
  for func in $(list_lambda); do
    delete_lambda $func
  done
}


# API

function list_api() {
  JSON_RESPONCE=$(aws apigateway get-rest-apis)
  echo $JSON_RESPONCE | jq -r ".items[].id"
}

function create_api () {
  local app_name=$1
  JSON_RESPONCE=$(aws apigateway create-rest-api --name $app_name)
  echo $JSON_RESPONCE | jq -r ".id"
}

function delete_api () {
  local app_id=$1
  aws apigateway delete-rest-api --rest-api-id $app_id
  if [ $? -ne 0 ]; then
    echo "Error: delete_api returns non-zero"
    exit 1
  fi
}

function delete_all_api () {
  for api_id in $(list_api); do
    delete_api $api_id
  done
}

# Resoruce

function list_resources () {
  local app_id=$1
  aws apigateway get-resources --rest-api-id $app_id
}

function get_resource_id () {
  local app_id=$1
  local resource_path=$2
  local query=".items | map(select(.path == \"${resource_path}\")) | .[].id"
  list_resources $app_id | jq -r "${query}"
}

function create_resource () {
  local app_id=$1
  local resource_id=$2
  local path=$3
  aws apigateway create-resource \
  --rest-api-id $app_id \
  --parent-id $resource_id \
  --path-part $path
}

# Method

function create_method () {
  local app_id=$1
  local resource_id=$2
  local method=$3
  aws apigateway put-method \
  --rest-api-id $app_id \
  --resource-id $resource_id \
  --http-method $method \
  --authorization-type NONE
}

function get_method () {
  local app_id=$1
  local resource_id=$2
  local method=$3
  aws apigateway get-method \
  --rest-api-id $app_id \
  --resource-id $resource_id \
  --http-method $method
  if [ $? -ne 0 ]; then
    echo "Error: get_method returns non-zero"
    exit 1
  fi
}

function create_method_response () {
  local app_id=$1
  local resource_id=$2
  local method=$3
  aws apigateway put-method-response \
  --rest-api-id $app_id \
  --resource-id $resource_id \
  --http-method $method \
  --status-code 200 \
  --response-models {\"application/json\":\"Empty\"}
}

# Integration

function create_integration () {
  local account_id=$1
  local aws_region=$2
  local app_id=$3
  local resource_id=$4
  local function_name=$5
  local method=$6
  local arn1="arn:aws:apigateway:$aws_region:lambda:path/2015-03-31/functions"
  local arn2="arn:aws:lambda:$aws_region:$account_id:function:$function_name/invocations"
  aws apigateway put-integration \
	  --rest-api-id $app_id \
	  --resource-id $resource_id \
	  --http-method $method \
	  --type AWS \
	  --integration-http-method $method \
	  --uri "${arn1}/${arn2}"
}

function get_integration () {
  local app_id=$1
  local resource_id=$2
  local method=$3
  aws apigateway get-integration \
  --rest-api-id $app_id \
  --resource-id $resource_id \
  --http-method $method
}

function create_integration_response () {
  local app_id=$1
  local resource_id=$2
  local method=$3
  aws apigateway put-integration-response \
  --rest-api-id $app_id \
  --resource-id $resource_id \
  --http-method $method \
  --status-code 200 \
  --response-templates {\"application/json\":\"\"}
}

function get_integration_response () {
  local app_id=$1
  local resource_id=$2
  local method=$3
  aws apigateway get-integration-response \
  --rest-api-id $app_id \
  --resource-id $resource_id \
  --http-method $method \
  --status-code 200
}

# Policy

function create_policy () {
  local aws_accound_id=$1
  local aws_region=$2
  local function_name=$3
  local app_id=$4
  local path=$5
  local method=$6
  local stage_name=$7
  local src_arn="arn:aws:execute-api:${aws_region}:${aws_accound_id}:${app_id}/${stage_name}/${method}${path}"
  aws lambda add-permission \
  --function-name $function_name\
  --statement-id 12345678901234567890123456789012 \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn $src_arn
}

function get_policy () {
  local function_name=$1
  aws lambda get-policy --function-name $function_name
}

# Deploy

function create_deploy () {
  local app_id=$1
  local stage_name=$2
  aws apigateway create-deployment \
  --rest-api-id $app_id \
  --stage-name $stage_name \
  --stage-description "This is a test" \
  --description "Calling Lambda functions walkthroug" 
}

function get_deploy () {
  local app_id=$1
  aws apigateway get-deployments \
  --rest-api-id $app_id
}

function list_stages () {
  local app_id=$1
  aws apigateway get-stages \
  --rest-api-id $app_id
}

# Main

function init () {
  ### DELETE ###
  delete_all_api
  delete_all_lambda
}

function main () {


  echo "たぐろデプロイツール!!!"

  local lambda_func_name="taguroSlackSystem"
  local aws_account_id=""
  local aws_iam_arn="arn:aws:iam::${aws_account_id}:role/service-role/myRole"
  local aws_region="us-east-1"
  local stage_name="test"

  init

  ### Lambda ###
  echo "☆☆☆スクリプトをS3にアップロード中☆☆☆☆"
  prepare_zip_for_lambda "./upload.zip"
  create_lambda $lambda_func_name $aws_iam_arn "./upload.zip"
  FUNC_NAME=$(list_lambda)
  if [ -z $FUNC_NAME ]; then
    echo "* Not found func ($FUNC_NAME)"
    exit
  fi

  ### APP ###
  echo "☆☆☆API作成中☆☆☆☆"
  APP_ID=$(create_api "taguroSlackSystem")
  #APP_ID=$(list_api)
  echo "APP_ID=$APP_ID"
  if [ -z $APP_ID ]; then
    echo "* Not found rest-api ($APP_ID)"
    exit
  fi

  ### RESOURCE ###
  echo "☆☆☆リソース定義中☆☆☆☆"
  ROOT_RESOURCE_ID=$(get_resource_id $APP_ID "/")
  echo "ROOT_RESOURCE_ID=$ROOT_RESOURCE_ID"
  create_resource $APP_ID $ROOT_RESOURCE_ID "cliApiSample"
  RESOURCE_ID=$(get_resource_id $APP_ID "/cliApiSample")
  echo "RESOURCE_ID=$RESOURCE_ID"
  if [ -z $RESOURCE_ID ]; then
    echo "* Not found resource ($RESOURCE_ID)"
    exit
  fi

  ### METHOD ###
  echo "☆☆☆メソッド作成中☆☆☆☆"
  create_method $APP_ID $RESOURCE_ID "POST"
  get_method $APP_ID $RESOURCE_ID "POST"

  ### Integration ###
  echo "☆☆☆Lambdaと統合中☆☆☆☆"
  create_integration $aws_account_id $aws_region $APP_ID $RESOURCE_ID $FUNC_NAME "POST"
  get_integration $APP_ID $RESOURCE_ID "POST"

  ### Integration Response ###
  echo "☆☆☆統合レスポンス定義☆☆☆☆"
  create_integration_response $APP_ID $RESOURCE_ID "POST"
  get_integration_response $APP_ID $RESOURCE_ID "POST"

  ### Policy ###
  echo "☆☆☆ポリシー設定中☆☆☆☆"
  create_policy $aws_account_id $aws_region $FUNC_NAME $APP_ID "/cliApiSample" "POST" $stage_name
  get_policy $FUNC_NAME
 
  ### METHOD RESPONSE ###
  echo "☆☆☆メソッドレスポンス定義☆☆☆☆"
  create_method_response $APP_ID $RESOURCE_ID "POST"
  get_method $APP_ID $RESOURCE_ID "POST"

  ### DEPLOY ###
  echo "☆☆☆デプロイ☆☆☆☆"
  create_deploy $APP_ID $stage_name
  get_deploy $APP_ID
  list_stages $APP_ID

  echo "------------------------------------------------------------------------"
  echo "https://${APP_ID}.execute-api.us-east-1.amazonaws.com/test/cliApiSample"
  echo "------------------------------------------------------------------------"

}
main
