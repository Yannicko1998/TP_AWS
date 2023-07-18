provider "aws" {
    region = "eu-west-3"
    access_key = "AKIAWG4ANRHCYQ7AO5IL"
    secret_key= "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"
}

# Définition de la ressource DynamoDB : Job Table
resource "aws_dynamodb_table" "job_table" {
  name           = "Jobs"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }

}

# Définition de la ressource DynamoDB : ContentDB Table
resource "aws_dynamodb_table" "content_table" {
  name           = "Contenu"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

# Définition de la ressource S3 Bucket
resource "aws_s3_bucket" "s3_bucket" {
  bucket = "bucketjobstpaws"
}


# Définition de la fonction Lambda : AddJob

resource "aws_lambda_function" "ajouter_job_lambda" {
  function_name    = "addjob"
  handler          = "AjoutJobs.addJobHandler"
  runtime          = "nodejs14.x"
  filename         = "./AjoutJobs.zip"
  source_code_hash = filebase64sha256("./AjoutJobs.zip")

  role = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.job_table.name
    }
  }
}

# Définition de la fonction Lambda : ProcessJob

resource "aws_lambda_function" "traiter_job_lambda" {
  function_name    = "processjob"
  handler          = "TraiterJob.handler"
  runtime          = "nodejs14.x"
  filename         = "./TraiterJob.zip"
  source_code_hash = filebase64sha256("./TraiterJob.zip")

  role = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.content_table.name
    }
  }

  depends_on = [aws_dynamodb_table.content_table]
}
# Définition de la fonction Lambda : RetrieveJobs

resource "aws_lambda_function" "recup_job_lambda" {
  function_name    = "retrievejob"
  handler          = "RecupJobs.handler"
  runtime          = "nodejs14.x"
  filename         = "./RecupJobs.zip"
  source_code_hash = filebase64sha256("./RecupJobs.zip")

  role = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.content_table.name
    }
  }
  depends_on = [aws_dynamodb_table.content_table]
}

resource "aws_cloudwatch_event_rule" "job_add_rule" {
  name        = "job_add_rule"
  description = "Trigger the addJobLambda function when a new record is added to JOB_ADD table"

  event_pattern = jsonencode({
    source      = ["aws.dynamodb"],
    detail_type = ["AWS API Call via CloudTrail"],
    detail      = {
      eventSource           = ["dynamodb.amazonaws.com"],
      eventName             = ["PutItem"],
      requestParameters     = {
        tableName           = [aws_dynamodb_table.content_table.name]
      }
    }
  })
}

resource "aws_cloudwatch_event_rule" "job_process_rule" {
  name        = "job_process_rule"
  description = "Trigger the processJobLambda function when a new record is added or updated in JOB_PROCESS table"

  event_pattern = jsonencode({
    source      = ["aws.dynamodb"],
    detail_type = ["AWS API Call via CloudTrail"],
    detail      = {
      eventSource           = ["dynamodb.amazonaws.com"],
      eventName             = ["PutItem", "UpdateItem"],
      requestParameters     = {
        tableName           = [aws_dynamodb_table.content_table.name]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "add_job_target" {
  rule      = aws_cloudwatch_event_rule.job_add_rule.name
  target_id = "add_job_target"
  arn       = aws_lambda_function.ajouter_job_lambda.arn
}

resource "aws_cloudwatch_event_target" "process_job_target" {
  rule      = aws_cloudwatch_event_rule.job_process_rule.name
  target_id = "process_job_target"
  arn       = aws_lambda_function.traiter_job_lambda.arn
}


resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "lambda_dynamodb_policy_attachment" {
  name       = "lambda_dynamodb_policy_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_policy_attachment" "lambda_s3_policy_attachment" {
  name       = "lambda_s3_policy_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_apigatewayv2_api" "api_gateway" {
  name          = "job_api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "add_job_integration" {
  api_id             = aws_apigatewayv2_api.api_gateway.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.ajouter_job_lambda.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "get_processed_jobs_integration" {
  api_id             = aws_apigatewayv2_api.api_gateway.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.recup_job_lambda.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "add_job_route" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "POST /jobs"
  target    = "integrations/${aws_apigatewayv2_integration.add_job_integration.id}"
}

resource "aws_apigatewayv2_route" "get_processed_jobs_route" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "GET /processed-jobs"
  target    = "integrations/${aws_apigatewayv2_integration.get_processed_jobs_integration.id}"
}

resource "aws_lambda_permission" "apigateway_add_job_permission" {
  statement_id  = "AllowAPIGatewayToInvokeAddJobLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ajouter_job_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = aws_apigatewayv2_api.api_gateway.arn
}

resource "aws_lambda_permission" "apigateway_get_processed_jobs_permission" {
  statement_id  = "AllowAPIGatewayToInvokeGetProcessedJobsLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.recup_job_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = aws_apigatewayv2_api.api_gateway.arn
}
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.api_gateway.id
  name        = "prod"
  auto_deploy = true
}