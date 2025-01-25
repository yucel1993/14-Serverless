const AWS = require("aws-sdk");
const dynamodb = new AWS.DynamoDB();
const crypto = require("crypto");

const algorithm = "aes-256-cbc";
const key = Buffer.from(process.env.ENCRYPTION_KEY, "hex");

function decrypt(encryptedObject) {
  const iv = Buffer.from(encryptedObject.iv, "hex");
  const encryptedText = Buffer.from(encryptedObject.encryptedData, "hex");
  const decipher = crypto.createDecipheriv(algorithm, key, iv);
  let decrypted = decipher.update(encryptedText, "hex", "utf8");
  decrypted += decipher.final("utf8");
  return decrypted;
}

exports.handler = async (event) => {
  console.log(event);
  console.log(event.headers.Authorization);
  try {
    if (!event.headers || !event.headers.Authorization) {
      return {
        statusCode: 401,
        body: JSON.stringify({
          message: "Unauthorized: Missing Authorization header",
        }),
      };
    }

    const authHeader = event.headers.Authorization;
    const [authType, authValue] = authHeader.split(" ");

    if (authType !== "Basic") {
      return {
        statusCode: 401,
        body: JSON.stringify({
          message: "Unauthorized: Incorrect Authorization type",
        }),
      };
    }

    const decodedValue = Buffer.from(authValue, "base64").toString("utf-8");
    const [username, password] = decodedValue.split(":");

    const params = {
      TableName: process.env.USERS_TABLE,
      Key: {
        username: { S: username },
      },
    };

    const response = await dynamodb.getItem(params).promise();

    if (!response.Item) {
      return {
        statusCode: 401,
        body: JSON.stringify({ message: "Unauthorized: User not found" }),
      };
    }

    const storedPassword = response.Item.password.S;

    // Decrypt the stored password
    const decryptedPassword = decrypt({
      iv: storedPassword.slice(0, 32), // assuming first 32 characters are IV
      encryptedData: storedPassword.slice(32),
    });

    if (decryptedPassword !== password) {
      return {
        statusCode: 401,
        body: JSON.stringify({ message: "Unauthorized: Incorrect password" }),
      };
    }

    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Authorized" }),
    };
  } catch (error) {
    return {
      statusCode: 401,
      body: JSON.stringify({ message: "Unauthorized: Error occurred" }),
    };
  }
};
