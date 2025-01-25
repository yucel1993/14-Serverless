provider "aws" {
  region = "us-east-1"
}

# DynamoDB Table
resource "aws_dynamodb_table" "users" {
  name         = "Users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "username"

  attribute {
    name = "username"
    type = "S"
  }

  tags = {
    Name = "Users"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Role Policies
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "dynamodb_policy_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"
}

# Lambda Function
resource "aws_lambda_function" "auth_function" {
  filename         = "lambda/lambda_function_payload.zip"
  function_name    = "auth_function"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.8"
  environment {
    variables = {
      USERS_TABLE = aws_dynamodb_table.users.name
    }
  }
}

# Add items to DynamoDB table
resource "aws_dynamodb_table_item" "user1" {
  table_name = aws_dynamodb_table.users.name

  hash_key = "username"

  item = jsonencode({
    "username": {"S": "testuser"},
    "password": {"S": "testpassword"}
  })
}

# API Gateway
resource "aws_api_gateway_rest_api" "auth_api" {
  name        = "AuthAPI"
  description = "API for user authentication"
}

resource "aws_api_gateway_resource" "auth_resource" {
  rest_api_id = aws_api_gateway_rest_api.auth_api.id
  parent_id   = aws_api_gateway_rest_api.auth_api.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_method" "auth_method" {
  rest_api_id   = aws_api_gateway_rest_api.auth_api.id
  resource_id   = aws_api_gateway_resource.auth_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_integration" {
  rest_api_id             = aws_api_gateway_rest_api.auth_api.id
  resource_id             = aws_api_gateway_resource.auth_resource.id
  http_method             = aws_api_gateway_method.auth_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.auth_function.invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.auth_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "auth_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.auth_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.auth_api.id
  stage_name  = "dev"
}

output "api_endpoint" {
  value = "https://${aws_api_gateway_rest_api.auth_api.id}.execute-api.us-east-1.amazonaws.com/dev/auth"
}
