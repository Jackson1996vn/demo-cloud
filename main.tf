terraform {
  cloud {
    organization = "jackson291096"

    workspaces {
      name = "tf-typescript-example"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

variable "region" {
  type = string
  default = "ap-southeast-1"
}

variable "account_id" {
  type = string
  default = "364489674724"
}

resource "aws_iam_role" "lambda_role" {
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Action : "sts:AssumeRole",
        Principal : {
          Service : "lambda.amazonaws.com"
        },
        Effect : "Allow",
        Sid : ""
      }
    ]
  })
}
output "output_lambda_role" {
  value = aws_iam_role.lambda_role.arn
}

resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  name       = "lambda_policy_attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  roles      = [
    aws_iam_role.lambda_role.name
  ]
}

data "archive_file" "lambda_function_zip" {
  output_path = "${path.module}/demo_function.zip"
  type        = "zip"
  source_dir = "${path.module}/backend-code/build"
}

resource "aws_lambda_function" "lambda_function" {
  function_name                  = "demo_function"
  role                           = aws_iam_role.lambda_role.arn
  handler                        = "index.handler"
  runtime                        = "nodejs16.x"
  timeout                        = 10
  reserved_concurrent_executions = -1
  filename                       = "demo_function.zip"
}

resource "aws_api_gateway_rest_api" "demo_api_gateway" {
  name           = "demo_api_gateway"
  api_key_source = "HEADER"
}

resource "aws_api_gateway_resource" "root_resource" {
  parent_id   = aws_api_gateway_rest_api.demo_api_gateway.root_resource_id
  path_part   = "{proxy+}"
  rest_api_id = aws_api_gateway_rest_api.demo_api_gateway.id
}

resource "aws_api_gateway_method" "demo_method" {
  authorization      = "NONE"
  http_method        = "ANY"
  resource_id        = aws_api_gateway_resource.root_resource.id
  rest_api_id        = aws_api_gateway_rest_api.demo_api_gateway.id
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "demo_integrate" {
  http_method = aws_api_gateway_method.demo_method.http_method
  resource_id = aws_api_gateway_resource.root_resource.id
  rest_api_id = aws_api_gateway_rest_api.demo_api_gateway.id
  type        = "AWS_PROXY"
  uri = aws_lambda_function.lambda_function.invoke_arn
  integration_http_method = "POST"
}

resource "aws_api_gateway_deployment" "demo_apigw_deployment" {
  rest_api_id = aws_api_gateway_rest_api.demo_api_gateway.id
}

resource "aws_api_gateway_stage" "demo_apigw_stage" {
  deployment_id = aws_api_gateway_deployment.demo_apigw_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.demo_api_gateway.id
  stage_name    = "dev"
}

resource "aws_lambda_permission" "apigw_lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "arn:aws:execute-api:${var.region}:${var.account_id}:${aws_api_gateway_rest_api.demo_api_gateway.id}/*/${aws_api_gateway_method.demo_method.http_method}${aws_api_gateway_resource.root_resource.path}"
}

output "apigw_url" {
  value = aws_api_gateway_stage.demo_apigw_stage.invoke_url
}
