import * as AWS from "aws-sdk"
import * as crypto from "crypto"

const dynamodb = new AWS.DynamoDB()
const algorithm = "aes-256-cbc"
const key = Buffer.from(process.env.ENCRYPTION_KEY || "", "hex")

interface APIGatewayEvent {
  body: string
}

interface APIGatewayResponse {
  statusCode: number
  body: string
}

function encrypt(text: string): { iv: string; encryptedData: string } {
  const iv = crypto.randomBytes(16)
  const cipher = crypto.createCipheriv(algorithm, key, iv)
  let encrypted = cipher.update(text, "utf8", "hex")
  encrypted += cipher.final("hex")
  return {
    iv: iv.toString("hex"),
    encryptedData: encrypted,
  }
}

exports.handler = async (event: APIGatewayEvent): Promise<APIGatewayResponse> => {
  try {
    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({ message: "Missing request body" }),
      }
    }

    const { username, password } = JSON.parse(event.body)

    if (!username || !password) {
      return {
        statusCode: 400,
        body: JSON.stringify({ message: "Username and password are required" }),
      }
    }

    // Check if user already exists
    const checkParams: AWS.DynamoDB.GetItemInput = {
      TableName: process.env.USERS_TABLE as string,
      Key: {
        username: { S: username },
      },
    }

    const existingUser = await dynamodb.getItem(checkParams).promise()

    if (existingUser.Item) {
      return {
        statusCode: 409,
        body: JSON.stringify({ message: "Username already exists" }),
      }
    }

    // Encrypt password
    const encryptedPassword = encrypt(password)
    const storedPassword = encryptedPassword.iv + encryptedPassword.encryptedData

    const params: AWS.DynamoDB.PutItemInput = {
      TableName: process.env.USERS_TABLE as string,
      Item: {
        username: { S: username },
        password: { S: storedPassword },
      },
    }

    await dynamodb.putItem(params).promise()

    return {
      statusCode: 201,
      body: JSON.stringify({ message: "User registered successfully" }),
    }
  } catch (error) {
    console.error("Error processing request:", error)
    return {
      statusCode: 500,
      body: JSON.stringify({ message: "Internal Server Error" }),
    }
  }
}

