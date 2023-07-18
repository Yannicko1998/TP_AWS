const AWS = require('aws-sdk');
const dynamoDB = new AWS.DynamoDB.DocumentClient();

exports.addJobHandler = async (event, context) => {
  try {
    const { id, job_type, content, processed = true } = JSON.parse(event.body);

    // Vérifier la valeur de job_type
    if (job_type !== "addToS3" && job_type !== "addToDynamoDB") {
      return {
        statusCode: 400,
        body: JSON.stringify({ message: "Invalid job_type value" })
      };
    }

    // Enregistrer le job dans la table DynamoDB
    await dynamoDB.put({
      TableName: 'Jobs',
      Item: {
        id,
        job_type,
        content,
        processed: processed
      }
    }).promise();

    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Job added successfully' })
    };
  } catch (error) {
    console.error('Erreur lors de l\'ajout du job:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Error adding job' })
    };
  }
};
