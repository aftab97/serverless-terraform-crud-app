
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      serverless-lambda-project = "lambda-api-gateway"
    }
  }

}

resource "random_pet" "lambda_bucket_name" {
  prefix = "terraform-functions"
  length = 4
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id
}

resource "aws_s3_bucket_ownership_controls" "lambda_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "lambda_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.lambda_bucket]

  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

data "archive_file" "lambda_hello_world" {
  type = "zip"

  source_dir  = "${path.module}/hello-world"
  output_path = "${path.module}/hello-world.zip"
}

resource "aws_s3_object" "lambda_hello_world" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "hello-world.zip"
  source = data.archive_file.lambda_hello_world.output_path

  etag = filemd5(data.archive_file.lambda_hello_world.output_path)
}

resource "aws_lambda_function" "hello_world" {
  function_name = "HelloWorld"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_hello_world.key

  runtime = "nodejs20.x"
  handler = "hello.handler"

  source_code_hash = data.archive_file.lambda_hello_world.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_cloudwatch_log_group" "hello_world" {
  name = "/aws/lambda/${aws_lambda_function.hello_world.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

# attach policy to role to allow lambda to execute
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  # adds the policy for lambda to create log groups / log streams etc..
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# attach policy to role to allow lambda to access Dynamo DB Table 
resource "aws_iam_role_policy" "dynamodb-lambda-policy" {
   role = aws_iam_role.lambda_exec.id
   name = "dynamodb_lambda_policy"
   policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
           "Effect" : "Allow",
           "Action" : ["dynamodb:*"],
           "Resource" : "${aws_dynamodb_table.basic-dynamodb-table.arn}"
        }
      ]
   })
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "serverless_lambda_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "hello_world" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.hello_world.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "hello_world" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.hello_world.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

# Dynamo DB Create:
resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name = var.my_table
  # defaults to provisioned and read / write capacity of 5
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "StudentId"
  attribute {
    name = "StudentId"
    type = "S"
  }
  tags = {
    name        = "Demo DynamoDB Table"
    Envirorment = "Testing"
  }
}

# Dynamo DB Create Mock Item
resource "aws_dynamodb_table_item" "item" {
  depends_on = [
    aws_dynamodb_table.basic-dynamodb-table
  ]
  table_name = aws_dynamodb_table.basic-dynamodb-table.name
  hash_key   = aws_dynamodb_table.basic-dynamodb-table.hash_key
  item       = <<ITEM
   {
      "StudentId":{"S": "001"},
      "StudentGrade":{"N": "95"},
      "StudentName":{"S": "Aftab Alam"}
   },
   {
      "StudentId":{"S": "002"},
      "StudentGrade":{"N": "90"},
      "StudentName":{"S": "Dua Shahid"}
   }
   ITEM
}

// create a lambda function to get students from DynamoDB Table
data "archive_file" "lambda_get_students" {
  type = "zip"

  source_dir  = "${path.module}/students"
  output_path = "${path.module}/getStudents.zip"
}

resource "aws_s3_object" "lambda_get_students" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "getStudents.zip"
  source = data.archive_file.lambda_get_students.output_path

  etag = filemd5(data.archive_file.lambda_get_students.output_path)
}

# create lambda func from s3 zip file
resource "aws_lambda_function" "get_students" {
  function_name = "GetStudents"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_get_students.key

  runtime = "nodejs20.x"
  handler = "getStudents.handler"

  source_code_hash = data.archive_file.lambda_get_students.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

# Cloudwatch
resource "aws_cloudwatch_log_group" "get_students" {
  name = "/aws/lambda/${aws_lambda_function.get_students.function_name}"

  retention_in_days = 30
}

# Integrate with API GW
resource "aws_apigatewayv2_integration" "get_students" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.get_students.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

# create GET route in API GW
resource "aws_apigatewayv2_route" "get_students" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /getStudents"
  target    = "integrations/${aws_apigatewayv2_integration.get_students.id}"
}

# Gives external source (API GW) access to Lambda
resource "aws_lambda_permission" "api_gw_2" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_students.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}