# AWS provider configuration specifying the region for the resources
provider "aws" {
  region = "us-east-1"
}

# Creates a DynamoDB table to store users' data
resource "aws_dynamodb_table" "users" {
  name           = "Users" # Table name
  billing_mode   = "PAY_PER_REQUEST" # Billing mode for DynamoDB (on-demand)
  hash_key       = "username" # Partition key for DynamoDB table

  # Define attributes (columns) for the table
  attribute {
    name = "username" # Attribute for username
    type = "S"        # String type for username
  }

  attribute {
    name = "refreshToken" # Attribute for refresh token
    type = "S"            # String type for refresh token
  }

  # Defines a Global Secondary Index (GSI) on the refresh token
  global_secondary_index {
    name               = "RefreshTokenIndex" # GSI name
    hash_key           = "refreshToken" # GSI hash key (refreshToken)
    projection_type    = "ALL" # Project all attributes to GSI
    read_capacity      = 5   # Read capacity units for the GSI
    write_capacity     = 5   # Write capacity units for the GSI
  }

  tags = {
    Name = "Users" # Tagging the table with the name 'Users'
  }
}

# Lambda function for authentication
resource "aws_lambda_function" "auth_function" {
  filename         = "./lambda/auth.zip" # Path to the zip file for the Lambda function
  function_name    = "auth_function" # Lambda function name
  role             = aws_iam_role.lambda_exec.arn # IAM role for the function
  handler          = "auth.handler" # Handler function for Lambda
  runtime          = "nodejs18.x" # Runtime environment (Node.js 18.x)
  
  # Lambda environment variables
  environment {
    variables = {
      USERS_TABLE         = var.USERS_TABLE # DynamoDB table name for users
      JWT_SECRET          = var.JWT_SECRET # JWT secret for authentication
      REFRESH_TOKEN_SECRET = var.REFRESH_TOKEN_SECRET # Refresh token secret
    }
  }
}

# Lambda function for data retrieval
resource "aws_lambda_function" "data_function" {
  filename         = "./lambda/data.zip" # Path to the zip file for the Lambda function
  function_name    = "data_function" # Lambda function name
  role             = aws_iam_role.lambda_exec.arn # IAM role for the function
  handler          = "data.handler" # Handler function for Lambda
  runtime          = "nodejs18.x" # Runtime environment (Node.js 18.x)
  
  # Lambda environment variables
  environment {
    variables = {
      USERS_TABLE         = var.USERS_TABLE # DynamoDB table name for users
      JWT_SECRET          = var.JWT_SECRET # JWT secret for authentication
      REFRESH_TOKEN_SECRET = var.REFRESH_TOKEN_SECRET # Refresh token secret
    }
  }
}

# IAM role for the Lambda functions to execute
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role" # Role name

  # Trust policy for assuming the role by AWS Lambda
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole", # Allow Lambda to assume this role
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com" # Principal service is AWS Lambda
        }
      }
    ]
  })
}

# Attaching the AWSLambdaBasicExecutionRole policy to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec.name # Role to attach the policy to
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" # Managed policy for basic Lambda execution permissions
}

# IAM policy for allowing DynamoDB operations
resource "aws_iam_role_policy" "dynamodb_policy" {
  name = "dynamodb_policy" # Policy name
  role = aws_iam_role.lambda_exec.id # Attach this policy to the Lambda role

  # Policy for accessing DynamoDB resources
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow" # Allow specified actions
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query" # Actions to interact with the DynamoDB table
        ]
        Resource = aws_dynamodb_table.users.arn # Restrict to the specific Users DynamoDB table
      }
    ]
  })
}

# Define the REST API for authentication and data retrieval
resource "aws_api_gateway_rest_api" "auth_api" {
  name        = "AuthAPI" # API name
  description = "API for user authentication and data retrieval" # API description
}

# API Gateway resource for handling any path (proxy pattern)
resource "aws_api_gateway_resource" "auth_resource" {
  rest_api_id = aws_api_gateway_rest_api.auth_api.id # API ID
  parent_id   = aws_api_gateway_rest_api.auth_api.root_resource_id # Parent resource is the root
  path_part   = "{proxy+}" # Define a catch-all path for the API
}

# API method for handling all HTTP methods on the auth resource
resource "aws_api_gateway_method" "auth_method" {
  rest_api_id   = aws_api_gateway_rest_api.auth_api.id # API ID
  resource_id   = aws_api_gateway_resource.auth_resource.id # Resource ID
  http_method   = "ANY" # Allow any HTTP method (GET, POST, etc.)
  authorization = "NONE" # No authorization for this method
}

# API Gateway integration for the auth function using AWS Lambda
resource "aws_api_gateway_integration" "auth_integration" {
  rest_api_id             = aws_api_gateway_rest_api.auth_api.id # API ID
  resource_id             = aws_api_gateway_resource.auth_resource.id # Resource ID
  http_method             = aws_api_gateway_method.auth_method.http_method # HTTP method (ANY)
  integration_http_method = "POST" # HTTP method for the Lambda integration
  type                    = "AWS_PROXY" # Lambda proxy integration type
  uri                     = aws_lambda_function.auth_function.invoke_arn # URI to invoke the Lambda function
}

# Lambda permission to allow API Gateway to invoke the auth Lambda function
resource "aws_lambda_permission" "apigw_lambda_auth" {
  statement_id  = "AllowAPIGatewayInvokeAuth" # Statement ID
  action        = "lambda:InvokeFunction" # Lambda invoke action
  function_name = aws_lambda_function.auth_function.function_name # Lambda function name
  principal     = "apigateway.amazonaws.com" # Principal service (API Gateway)
  source_arn    = "${aws_api_gateway_rest_api.auth_api.execution_arn}/*/*" # Source ARN (API Gateway execution ARN)
}

# API Gateway resource for the data endpoint
resource "aws_api_gateway_resource" "data_resource" {
  rest_api_id = aws_api_gateway_rest_api.auth_api.id # API ID
  parent_id   = aws_api_gateway_rest_api.auth_api.root_resource_id # Parent resource is the root
  path_part   = "data" # Define 'data' as the resource path
}

# API Gateway resource for handling any path under 'data' (proxy pattern)
resource "aws_api_gateway_resource" "data_proxy_resource" {
  rest_api_id = aws_api_gateway_rest_api.auth_api.id # API ID
  parent_id   = aws_api_gateway_resource.data_resource.id # Parent resource is 'data'
  path_part   = "{proxy+}" # Define a catch-all path for the data resource
}

# API method for handling all HTTP methods on the data resource
resource "aws_api_gateway_method" "data_method" {
  rest_api_id   = aws_api_gateway_rest_api.auth_api.id # API ID
  resource_id   = aws_api_gateway_resource.data_proxy_resource.id # Resource ID
  http_method   = "ANY" # Allow any HTTP method (GET, POST, etc.)
  authorization = "NONE" # No authorization for this method
}

# API Gateway integration for the data Lambda function using AWS Lambda
resource "aws_api_gateway_integration" "data_integration" {
  rest_api_id             = aws_api_gateway_rest_api.auth_api.id # API ID
  resource_id             = aws_api_gateway_resource.data_proxy_resource.id # Resource ID
  http_method             = aws_api_gateway_method.data_method.http_method # HTTP method (ANY)
  integration_http_method = "POST" # HTTP method for the Lambda integration
  type                    = "AWS_PROXY" # Lambda proxy integration type
  uri                     = aws_lambda_function.data_function.invoke_arn # URI to invoke the Lambda function
}

# Lambda permission to allow API Gateway to invoke the data Lambda function
resource "aws_lambda_permission" "apigw_lambda_data" {
  statement_id  = "AllowAPIGatewayInvokeData" # Statement ID
  action        = "lambda:InvokeFunction" # Lambda invoke action
  function_name = aws_lambda_function.data_function.function_name # Lambda function name
  principal     = "apigateway.amazonaws.com" # Principal service (API Gateway)
  source_arn    = "${aws_api_gateway_rest_api.auth_api.execution_arn}/*/*" # Source ARN (API Gateway execution ARN)
}

# API Gateway deployment resource
resource "aws_api_gateway_deployment" "auth_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.auth_integration,
    aws_api_gateway_integration.data_integration
  ] # Ensure both integrations are created before deploying
  rest_api_id = aws_api_gateway_rest_api.auth_api.id # API ID
}

# API Gateway stage for development
resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.auth_api_deployment.id # Deployment ID
  rest_api_id   = aws_api_gateway_rest_api.auth_api.id # API ID
  stage_name    = "dev" # Stage name (development stage)
}

# Output the API Gateway endpoint URL for user reference
output "api_endpoint" {
  value = aws_api_gateway_stage.dev.invoke_url # API endpoint URL
}

# OPTIONS method for CORS support on the data resource
resource "aws_api_gateway_method" "data_options" {
  rest_api_id   = aws_api_gateway_rest_api.auth_api.id # API ID
  resource_id   = aws_api_gateway_resource.data_proxy_resource.id # Resource ID
  http_method   = "OPTIONS" # HTTP method for CORS
  authorization = "NONE" # No authorization for this method
}

# Mock integration for the OPTIONS method (CORS pre-flight response)
resource "aws_api_gateway_integration" "data_options" {
  rest_api_id = aws_api_gateway_rest_api.auth_api.id # API ID
  resource_id = aws_api_gateway_resource.data_proxy_resource.id # Resource ID
  http_method = aws_api_gateway_method.data_options.http_method # HTTP method (OPTIONS)
  type        = "MOCK" # Mock integration type
  request_templates = {
    "application/json" = "{\"statusCode\": 200}" # Return 200 OK for pre-flight CORS request
  }
}

# Declare variables for the table and secrets (sensitive information)
variable "USERS_TABLE" {
  type = string # Type of the variable is string
}

variable "JWT_SECRET" {
  type = string # Type of the variable is string
  sensitive = true # Mark as sensitive (will not be logged)
}

variable "REFRESH_TOKEN_SECRET" {
  type = string # Type of the variable is string
  sensitive = true # Mark as sensitive (will not be logged)
}
