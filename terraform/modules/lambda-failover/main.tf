# terraform/modules/lambda-failover/main.tf

# IAM role for Lambda
resource "aws_iam_role" "failover_lambda" {
  name = "${var.project_name}-failover-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Lambda
resource "aws_iam_role_policy" "failover_lambda" {
  name = "${var.project_name}-failover-lambda-policy"
  role = aws_iam_role.failover_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeClusters",
          "ecs:ListServices"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:PromoteReadReplicaDBCluster",
          "rds:DescribeDBClusters",
          "rds:ModifyDBCluster"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeLoadBalancers"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.project_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach AWS managed policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.failover_lambda.name
}

# Lambda function code
resource "aws_lambda_function" "failover_orchestrator" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-failover-orchestrator"
  role            = aws_iam_role.failover_lambda.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      PROJECT_NAME     = var.project_name
      DR_REGION        = var.dr_region
      PRIMARY_REGION   = var.primary_region
      SNS_TOPIC_ARN    = var.sns_topic_arn
      DR_CLUSTER_NAME  = var.dr_ecs_cluster_name
      DR_SERVICE_NAME  = var.dr_ecs_service_name
      DR_RDS_CLUSTER   = var.dr_rds_cluster_identifier
    }
  }

  tags = {
    Name        = "${var.project_name}-failover-orchestrator"
    Environment = var.environment
  }
}

# Create Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  
  source {
    content  = file("${path.module}/lambda_function.py")
    filename = "index.py"
  }
}

# EventBridge rule to trigger Lambda
resource "aws_cloudwatch_event_rule" "failover_trigger" {
  name        = "${var.project_name}-failover-trigger"
  description = "Trigger failover when primary region fails"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName = [var.primary_alb_alarm_name]
      state = {
        value = ["ALARM"]
      }
    }
  })
}

# EventBridge target
resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.failover_trigger.name
  target_id = "FailoverLambda"
  arn       = aws_lambda_function.failover_orchestrator.arn
}

# Permission for EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.failover_orchestrator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.failover_trigger.arn
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-failover-orchestrator"
  retention_in_days = 7
}