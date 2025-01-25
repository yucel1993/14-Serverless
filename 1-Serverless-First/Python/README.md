Step 5: Deploy the Infrastructure
terraform init
terraform apply

Step 6: Testing the Function
Retrieve the API endpoint:
After the terraform apply command completes, note the API endpoint from the output.

Generate Base64 encoded credentials:
echo -n 'testuser:testpassword' | base64

Test using curl:

bash

curl -X POST <API_ENDPOINT> -H "Authorization: Basic <Base64_Encoded_Credentials>"

# AWS Lambda Authentication Function

## Description

This project implements a serverless authentication function using AWS Lambda and DynamoDB.

## Setup

### Prerequisites

- AWS CLI configured
- Terraform installed

### Deployment

1. Clone the repository
2. Navigate to the project directory
3. Run `terraform init`
4. Run `terraform apply`

### Testing

Use the following test credentials:

- Username: `testuser`
- Password: `testpassword`

Use a tool like `curl` or Postman to send a POST request to the API Gateway endpoint with the Authorization header:

Authorization: Basic dGVzdHVzZXI6dGVzdHBhc3N3b3Jk

## Security

Passwords are stored as hashed values in DynamoDB. The hashing algorithm used is SHA-256.

## Notes

This is a simplified example and not production-ready. For a production system, consider using more secure password hashing algorithms and handling edge cases more robustly.

curl -X POST <API_ENDPOINT>/auth \
 -H "Authorization: Basic <Base64_Encoded_Credentials>" \
 -H "Content-Type: application/json"

## OpenAPI Specification

The API is defined using OpenAPI specification and can be accessed through the AWS API Gateway.

### Endpoint

- **POST** `/auth`

### Request

- **Headers**:
  - `Authorization`: Basic Auth credentials (Base64 encoded `username:password`)

### Responses

- **200 OK**: Authenticated
- **401 Unauthorized**: Invalid credentials

### Testing

You can test the API using tools like `curl` or Postman.

Example `curl` command:

```bash
curl -X POST <API_ENDPOINT>/auth \
  -H "Authorization: Basic <Base64_Encoded_Credentials>" \
  -H "Content-Type: application/json"

```
