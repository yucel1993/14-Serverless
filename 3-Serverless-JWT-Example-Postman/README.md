# Serverless Authentication API with AWS Lambda and API Gateway

This project implements a serverless authentication system using AWS Lambda, API Gateway, and DynamoDB. It provides user registration, login, logout functionality, and both public and private API endpoints protected by JWT authentication.

## Features

- User Registration
- User Login with JWT tokens
- Token Refresh mechanism
- Logout functionality
- Public and Private API endpoints
- Secure password encryption
- DynamoDB for data persistence

## Prerequisites

- Node.js (v14 or later)
- AWS CLI configured with appropriate credentials
- Terraform installed
- Git (optional)

## Project Structure 

- `lambda/src/register_function.ts`: User registration logic
- `lambda/src/login_function.ts`: User login logic
- `lambda/src/logout_function.ts`: Logout functionality
- `lambda/src/data.ts`: Public and private data endpoints


## Setup Instructions

1. **Clone the repository** (if using Git):
   ```bash
   git clone <repository-url>
   cd <project-directory>
   ```

2. **Install dependencies**:
   ```bash
   cd lambda
   npm install
   ```

3. **Configure environment variables**:
   Create a `.env` file in the `lambda` directory with the following content:
   ```
   ENCRYPTION_KEY=<your-encryption-key>
   USERS_TABLE=Users
   JWT_SECRET=<your-jwt-secret>
   REFRESH_TOKEN_SECRET=<your-refresh-token-secret>
   ```

4. **Build and package Lambda functions**:
   ```bash
   npm run build
   npm run deploy
   ```
   This will create `auth.zip` and `data.zip` in the lambda directory.

5. **Deploy infrastructure with Terraform**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
   When prompted for variables, enter your JWT and refresh token secrets.

## API Endpoints

After deployment, you'll get an API endpoint URL. Use it as the base URL for the following endpoints:

### Authentication Endpoints

1. **Register User**
   - URL: `POST /register`
   - Body:
     ```json
     {
       "username": "user@example.com",
       "password": "password123"
     }
     ```

2. **Login**
   - URL: `POST /login`
   - Body:
     ```json
     {
       "username": "user@example.com",
       "password": "password123"
     }
     ```

3. **Logout**
   - URL: `POST /logout`
   - Body:
     ```json
     {
       "refreshToken": "your-refresh-token"
     }
     ```

4. **Refresh Token**
   - URL: `POST /refresh`
   - Body:
     ```json
     {
       "refreshToken": "your-refresh-token"
     }
     ```

### Data Endpoints

1. **Public Data** (No authentication required)
   - URL: `GET /public`

2. **Private Data** (Requires authentication)
   - URL: `GET /private`
   - Headers:
     ```
     Authorization: Bearer <your-access-token>
     ```

## Testing the API

You can test the API using curl or Postman. Here are some example curl commands:

1. **Register a new user**:
   ```bash
   curl -X POST https://your-api-url/register \
     -H "Content-Type: application/json" \
     -d '{"username":"test@example.com","password":"password123"}'
   ```

2. **Login**:
   ```bash
   curl -X POST https://your-api-url/login \
     -H "Content-Type: application/json" \
     -d '{"username":"test@example.com","password":"password123"}'
   ```

3. **Access private endpoint**:
   ```bash
   curl -X GET https://your-api-url/private \
     -H "Authorization: Bearer <your-access-token>"
   ```

4. **Access public endpoint**:
   ```bash
   curl -X GET https://your-api-url/public
   ```

## Security Considerations

- The JWT token expires after 15 minutes
- Passwords are hashed using bcrypt
- Refresh tokens are stored in DynamoDB
- Environment variables are used for sensitive data
- API Gateway endpoints use HTTPS

## Cleanup

To remove all created resources: