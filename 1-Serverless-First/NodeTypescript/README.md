# Task Eppendorf

### Cloning the rep

```
git clone https://github.com/yucel1993/Task
```

```shell

# add secret key to the lambda function
sed -i 's/<Your-secret-key>/e4a8b7c2d1f8e3b4c5d6e7f8a9b0c1d2e4a8b7c2d1f8e3b4c5d6e7f8a9b0c1d2/' path/to/your/terraform/configuration/file

# Navigate to your project directory
cd lambda/

# add .env file with followings

echo 'ENCRYPTION_KEY=e4a8b7c2d1f8e3b4c5d6e7f8a9b0c1d2e4a8b7c2d1f8e3b4c5d6e7f8a9b0c1d2' > .env
echo 'USERS_TABLE=Users' >> .env


# Install dependencies
npm install

# Compile TypeScript to JavaScript
npx tsc

# Create the zip package and wait terminal
npm run deploy

# go to your main directory

cd ..

```

### Setup AWS Server via Terraform

Initialize Terraform

```
terraform init
```

### Deploy AWS Infrastructure

```shell
terraform apply --auto-approve
```

We already send test credentials with `main.tf`
but you can also create your credentials in the DynamoDB hashed password please use crypto.js

### Access the deployed application

You can access the deployed application via the URL you get from the terraform output.

Something like : https://XXXXXXXXXX.execute-api.us-east-1.amazonaws.com/dev/auth

Test credentials are :

- Username: `testuser`
- Password: `testpassword`

You need to pass the credentials via header `Authorization: Basic ...`

Type your password and run it get the hashed password and use in the DynamoDB as password value

Dont forget to `terraform destroy --auto-approve` at the end of the task
