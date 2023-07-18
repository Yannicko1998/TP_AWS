//recupjob
const AWS = require('aws-sdk');

exports.handler = async (event) => {
  const dynamoDB = new AWS.DynamoDB.DocumentClient();
  
  try {
    const params = {
      TableName: 'Jobs',
      FilterExpression: '#processed = :processed',
      ExpressionAttributeNames: {
        '#processed': 'processed'
      },
      ExpressionAttributeValues: {
        ':processed': true
      }
    };
    
    const { Items } = await dynamoDB.scan(params).promise();
    
    return {
      statusCode: 200,
      body: JSON.stringify(Items)
    };
  } catch (error) {
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error retrieving processed jobs' })
    };
  }
};