import { verifyToken } from './auth';
import * as AWS from 'aws-sdk';

// Sample data - adjust as needed
const publicData = {
  message: "This is public data"
};

const privateData = {
  message: "This is private data"
};

export const handler = async (event: any): Promise<any> => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,OPTIONS'
  };

  // Handle OPTIONS requests for CORS
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: ''
    };
  }

  try {
    const { path, httpMethod, headers } = event

    switch (path) {
      case "/data/public": // Update path to include /data
        if (httpMethod === "GET") {
          return { 
            statusCode: 200, 
            headers: corsHeaders,
            body: JSON.stringify(publicData) 
          };
        }
        break;
      case "/data/private": // Update path to include /data
        if (httpMethod === "GET") {
          const token = headers.Authorization?.split(" ")[1];
          if (!token || !verifyToken(token)) {
            return { 
              statusCode: 401, 
              headers: corsHeaders,
              body: JSON.stringify({ message: "Unauthorized" }) 
            };
          }
          return { 
            statusCode: 200, 
            headers: corsHeaders,
            body: JSON.stringify(privateData) 
          };
        }
        break;
    }

    return { 
      statusCode: 404, 
      headers: corsHeaders,
      body: JSON.stringify({ message: "Not Found" }) 
    }
  } catch (error) {
    console.error(error)
    return { 
      statusCode: 500, 
      headers: corsHeaders,
      body: JSON.stringify({ message: "Internal Server Error" }) 
    }
  }
}