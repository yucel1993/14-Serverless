import * as AWS from "aws-sdk"
import * as bcrypt from "bcryptjs"
import * as jwt from "jsonwebtoken"
import { v4 as uuidv4 } from "uuid"

const dynamodb = new AWS.DynamoDB.DocumentClient()
const JWT_SECRET = process.env.JWT_SECRET || "your-secret-key"
const REFRESH_TOKEN_SECRET = process.env.REFRESH_TOKEN_SECRET || "your-refresh-secret-key"

interface User {
  username: string
  password: string
  refreshToken?: string
}

async function register(username: string, password: string): Promise<{ accessToken: string; refreshToken: string }> {
  const hashedPassword = await bcrypt.hash(password, 10)
  const refreshToken = uuidv4()

  await dynamodb
    .put({
      TableName: process.env.USERS_TABLE || "Users",
      Item: {
        username,
        password: hashedPassword,
        refreshToken,
      },
      ConditionExpression: "attribute_not_exists(username)",
    })
    .promise()

  const accessToken = jwt.sign({ username }, JWT_SECRET, { expiresIn: "15m" })
  return { accessToken, refreshToken }
}

async function login(username: string, password: string): Promise<{ accessToken: string; refreshToken: string }> {
  const result = await dynamodb
    .get({
      TableName: process.env.USERS_TABLE || "Users",
      Key: { username },
    })
    .promise()

  const user = result.Item as User
  if (!user || !(await bcrypt.compare(password, user.password))) {
    throw new Error("Invalid credentials")
  }

  const accessToken = jwt.sign({ username }, JWT_SECRET, { expiresIn: "15m" })
  const refreshToken = uuidv4()

  await dynamodb
    .update({
      TableName: process.env.USERS_TABLE || "Users",
      Key: { username },
      UpdateExpression: "SET refreshToken = :refreshToken",
      ExpressionAttributeValues: {
        ":refreshToken": refreshToken,
      },
    })
    .promise()

  return { accessToken, refreshToken }
}

async function logout(refreshToken: string): Promise<void> {
  //? todo it's not working as expected
  const result = await dynamodb
    .query({
      TableName: process.env.USERS_TABLE || "Users",
      IndexName: "RefreshTokenIndex",
      KeyConditionExpression: "refreshToken = :refreshToken",
      ExpressionAttributeValues: {
        ":refreshToken": refreshToken,
      },
    })
    .promise()

  if (result.Items && result.Items.length > 0) {
    const user = result.Items[0] as User
    await dynamodb
      .update({
        TableName: process.env.USERS_TABLE || "Users",
        Key: { username: user.username },
        UpdateExpression: "REMOVE refreshToken",
      })
      .promise()
  }
}

async function refreshAccessToken(refreshToken: string): Promise<string> {
  const result = await dynamodb
    .query({
      TableName: process.env.USERS_TABLE || "Users",
      IndexName: "RefreshTokenIndex",
      KeyConditionExpression: "refreshToken = :refreshToken",
      ExpressionAttributeValues: {
        ":refreshToken": refreshToken,
      },
    })
    .promise()

  if (!result.Items || result.Items.length === 0) {
    throw new Error("Invalid refresh token")
  }

  const user = result.Items[0] as User
  const accessToken = jwt.sign({ username: user.username }, JWT_SECRET, { expiresIn: "15m" })
  return accessToken
}

export const verifyToken = (token: string): boolean => {
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET!);
    return !!decoded;
  } catch (error) {
    return false;
  }
};

export const handler = async (event: any): Promise<any> => {
  try {
    const { path, httpMethod, headers } = event

    // CORS support
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization',
      'Access-Control-Allow-Methods': 'POST,OPTIONS'
    };

    // Handle OPTIONS pre-flight request for CORS
    if (httpMethod === "OPTIONS") {
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: ''
      };
    }

    switch (path) {
      case "/auth/register":
        if (httpMethod === "POST") {
          const { username, password } = JSON.parse(event.body)
          const tokens = await register(username, password)
          return { statusCode: 201, body: JSON.stringify(tokens), headers: corsHeaders }
        }
        break
      case "/auth/login":
        if (httpMethod === "POST") {
          const { username, password } = JSON.parse(event.body)
          const tokens = await login(username, password)
          return { statusCode: 200, body: JSON.stringify(tokens), headers: corsHeaders }
        }
        break
      case "/auth/logout":
        if (httpMethod === "POST") {
          // Extract Bearer token from Authorization header
          const authHeader = headers.Authorization
          if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return {
              statusCode: 400,
              body: JSON.stringify({ message: "Bad Request - Bearer token is required" }),
              headers: corsHeaders
            }
          }

          const refreshToken = authHeader.split(' ')[1];  // Extract the token
          await logout(refreshToken)

          return { statusCode: 200, body: JSON.stringify({ message: "Logged out successfully" }), headers: corsHeaders }
        }
        break
      case "/auth/refresh":
        if (httpMethod === "POST") {
          const { refreshToken } = JSON.parse(event.body)
          const accessToken = await refreshAccessToken(refreshToken)
          return { statusCode: 200, body: JSON.stringify({ accessToken }), headers: corsHeaders }
        }
        break
    }

    return { statusCode: 404, body: JSON.stringify({ message: "Not Found" }), headers: corsHeaders }
  } catch (error) {
    console.error(error)
    return { statusCode: 500, body: JSON.stringify({ message: "Internal Server Error" }) }
  }
}
