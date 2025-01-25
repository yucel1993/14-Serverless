import json
import base64
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.client('dynamodb')

def lambda_handler(event, context):
    try:
        auth_header = event['headers']['Authorization']
        auth_type, auth_value = auth_header.split(' ')
        
        if auth_type != 'Basic':
            raise ValueError('Invalid authorization type')

        username, password = base64.b64decode(auth_value).decode('utf-8').split(':')

        response = dynamodb.get_item(
            TableName='Users',
            Key={'username': {'S': username}}
        )

        if 'Item' not in response or response['Item']['password']['S'] != password:
            return {
                'statusCode': 401,
                'body': json.dumps({'message': 'Unauthorized'})
            }

        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Authorized'})
        }
        
    except (KeyError, ValueError, ClientError):
        return {
            'statusCode': 401,
            'body': json.dumps({'message': 'Unauthorized'})
        }
