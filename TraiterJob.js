const AWS = require('aws-sdk');

exports.handler = async (event) => {
  const dynamoDB = new AWS.DynamoDB.DocumentClient();
  
  try {
    const jobId = event.Records[0].dynamodb.NewImage.id.S;
    const jobType = event.Records[0].dynamodb.NewImage.job_type.S;
    
    
    let message;
    
    if (jobType === 'addToS3') {
      const content = event.Records[0].dynamodb.NewImage.content.S;
      
      // Effectuer l'ajout du contenu à S3
      const s3 = new AWS.S3();
      
      const params = {
        Bucket: 'bucketjobstpaws', // Remplacez par le nom de votre bucket S3
        Key: jobId, // Utilisez l'ID du job comme clé du fichier dans le bucket S3
        Body: content
      };
      
      await s3.putObject(params).promise();
      
      message = 'Job processed and added to S3';
      
    } else if (jobType === 'addToDynamoDB') {
      const content = event.Records[0].dynamodb.NewImage.content.S;
      
      // Effectuer l'ajout du contenu à la nouvelle table DynamoDB (Contenu)
      const Contenu = new AWS.DynamoDB.DocumentClient({ region: 'eu-west-3' }); // Remplacez par la région souhaitée
      
      const params = {
        TableName: 'Contenu', // Remplacez par le nom de votre table DynamoDB (Contenu)
        Item: {
          id: jobId, // Utilisez l'ID du job comme clé dans la nouvelle table DynamoDB
          content
        }
      };
      
      await Contenu.put(params).promise();
      
      message = 'Job processed and added to DynamoDB (Contenu)';

      await dynamoDB.update({
        TableName: 'Jobs',
        Key: { id: jobId },
        UpdateExpression: 'SET processed = :val',
        ExpressionAttributeValues: { ':val': true }
      }).promise();
    }
    
    
    
    return {
      statusCode: 200,
      body: JSON.stringify({ message })
    };
  } catch (error) {
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error processing job' })
    };
  }
};