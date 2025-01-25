4. Install the dependencies:

   ```sh
   cd lambda
   npm install
   ```

5. Zip the contents of the `lambda` directory:
   ```sh
   zip -r ../lambda_function_payload.zip .
   ```
   Ensure you are inside the `lambda` directory when running this command.

### Step 4: Deploy the Infrastructure

    be in the node.js folder

1. Initialize Terraform:

   ```sh
   cd ..
   terraform init
   ```

2. Apply the Terraform configuration:
   ```sh
   terraform apply
   ```
   Type `yes` when prompted to confirm the deployment.

### Step 5: Test the API

1. Get the API endpoint from the Terraform output. It will look something like this:

   ```sh
   api_endpoint = "https://<api_id>.execute-api.us-east-1.amazonaws.com/dev/auth"
   ```

2. Test the API using `curl`:

   ```sh
   curl -X POST https://<api_id>.execute-api.us-east-1.amazonaws.com/dev/auth -H "Authorization: Basic dGVzdHVzZXI6dGVzdHBhc3N3b3Jk" -H "Content-Type: application/json"
   ```

   Replace `<api_id>` with the actual API ID from the output. The base64-encoded string `dGVzdHVzZXI6dGVzdHBhc3N3b3Jk` represents `testuser:testpassword`.

### Troubleshooting

- **Lambda Function Errors**: Check the Lambda function logs in CloudWatch for detailed error messages.
- **API Gateway Errors**: Check the API Gateway logs for detailed error messages.
- **Terraform Errors**: Ensure all resources are properly defined and check for typos in the Terraform configuration.

### Conclusion

This guide provides a comprehensive walkthrough for setting up and testing AWS infrastructure using Node.js, AWS SDK, and Terraform. By following these steps, you should be able to successfully create a DynamoDB table, deploy a Lambda function, and set up an API Gateway endpoint to authenticate.
