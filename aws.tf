# Provider

provider "aws" {
  region = "eu-west-1"

  assume_role {
    role_arn = "arn:aws:iam::301581146302:role/fullaccess"
  }
}

# Lambda

resource "aws_iam_role" "lambda" {
  name = "nangelovaGreeterRoleTF"
  assume_role_policy = "${data.aws_iam_policy_document.lambda-assume-role.json}"
}

data "aws_iam_policy_document" "lambda-assume-role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda.js"
  output_path = "lambda.zip"
}

resource "aws_lambda_function" "greeter-lambda" {
  filename         = "${data.archive_file.lambda.output_path}"
  function_name    = "nangelovaGreeterLambdaTF"
  role             = "${aws_iam_role.lambda.arn}"
  handler          = "lambda.handler"
  runtime          = "nodejs6.10"
  source_code_hash = "${base64sha256(file(data.archive_file.lambda.output_path))}"
}

resource "aws_iam_role_policy" "lambda-cloudwatch-log-group" {
  name   = "kzonov-cloudwatch-log-group"
  role   = "${aws_iam_role.lambda.name}"
  policy = "${data.aws_iam_policy_document.cloudwatch-log-group-lambda.json}"
}

data "aws_iam_policy_document" "cloudwatch-log-group-lambda" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:::*",
    ]
  }
}

# API Gateway

resource "aws_api_gateway_rest_api" "api" {
  name = "nangelovaGreeterApiTF"
}

resource "aws_api_gateway_resource" "api-resource" {
  path_part = "greetings"
  parent_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.api-resource.id}"
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.api-resource.id}"
  http_method             = "${aws_api_gateway_method.method.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:eu-west-1:lambda:path/2015-03-31/functions/${aws_lambda_function.greeter-lambda.arn}/invocations"
}

resource "aws_lambda_permission" "greeter-permissions" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.greeter-lambda.arn}"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_dynamodb_table" "greeted-table" {
  name = "kzonovGreetedVisitorsTF"
  hash_key = "name"
  read_capacity = 5
  write_capacity = 5
  attribute {
    name = "name"
    type = "S"
  }
}

resource "aws_iam_role_policy" "lambda-dynamodb-group" {
  name   = "kzonov-dynamodb-group"
  role   = "${aws_iam_role.lambda.name}"
  policy = "${data.aws_iam_policy_document.dynamodb-group-lambda.json}"
}

data "aws_iam_policy_document" "dynamodb-group-lambda" {
  statement {
    actions = [
      "dynamodb:PutItem"
    ]
    resources = [
      "${aws_dynamodb_table.greeted-table.arn}"
    ]
  }
}

# homework - create dynamo table
