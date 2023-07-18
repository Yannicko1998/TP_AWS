# TP_AWS

#manipulation 1 : Après avoir recupérer le fichier et ouvert la console; Faire Terraform init => Terraform Plan => Terraform apply;

#manipulation 2 : Ouvrir la console AWS; rechercher IAM dans la barre de recherche et ajouter les polices suivant au rôle nommé "lambda_role":
(AmazonDynamoDBFullAccess, AWSLambdaExecute, AWSLambdaInvocation-DynamoDB, AmazonS3FullAccess, AWSLambdaRole, AWSLambdaBasicExecutionRole, AWSLambdaDynamoDBExecutionRole, AWSLambda_ReadOnlyAccess, AWSLambda_FullAccess)

#manipulation 3 : Ajouter les déclencheurs suivant pour les lambdas
  *Lambda addjob: DynamoDB: Jobs, API Gateway: job_api
  
  *Lambda retrievejob: DynamoDB: Jobs, API Gateway: job_api
  
  *Lambda processjob: 	DynamoDB: Jobs, DynamoDB: Contenu, S3: bucketjobstpaws

#pour tester: on a que 2 requetes, 
              => pour ajouter des élements à la table: lancer la requête Méthode POST: url job_api/addjob et mettre en body le json puis SEND
              => pour récupérer la liste des élements traités: lancer la requête GET: url job_api/retrievejob puis Send
  
