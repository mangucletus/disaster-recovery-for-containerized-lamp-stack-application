# Database Module - Creates RDS Aurora MySQL with optional read replica

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Subnet group for Aurora MySQL"
  subnet_ids  = var.subnet_ids

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# Get available Aurora MySQL versions
data "aws_rds_engine_version" "aurora_mysql" {
  engine       = "aurora-mysql"
  version      = "8.0"
  default_only = true
}

# Aurora Cluster (Primary or DR)
resource "aws_rds_cluster" "main" {
  count = var.is_read_replica ? 0 : 1

  cluster_identifier = "${var.project_name}-aurora-cluster"
  engine             = "aurora-mysql"
  engine_version     = data.aws_rds_engine_version.aurora_mysql.version
  database_name      = var.database_name
  master_username    = var.master_username
  master_password    = var.master_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = "07:00-09:00"
  preferred_maintenance_window = "wed:05:00-wed:06:00"

  # Enable backtrack for Aurora MySQL (if supported by the version)
  backtrack_window = 24

  # Enable encryption
  storage_encrypted = true

  # For DR setup, we'll promote read replica manually
  skip_final_snapshot       = var.environment == "dr" ? true : false
  final_snapshot_identifier = var.environment == "production" ? "${var.project_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  tags = {
    Name        = "${var.project_name}-aurora-cluster"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [
      engine_version  # Ignore minor version updates
    ]
  }
}

# Aurora Instance (Primary)
resource "aws_rds_cluster_instance" "main" {
  count = var.is_read_replica ? 0 : var.instance_count

  identifier         = "${var.project_name}-aurora-instance-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.main[0].id
  instance_class     = var.instance_class
  engine             = "aurora-mysql"

  performance_insights_enabled = false

  tags = {
    Name        = "${var.project_name}-aurora-instance-${count.index + 1}"
    Environment = var.environment
  }
}

# Cross-Region Read Replica (for DR)
resource "aws_rds_cluster" "read_replica" {
  count = var.is_read_replica ? 1 : 0

  cluster_identifier            = "${var.project_name}-aurora-cluster-replica"
  engine                        = "aurora-mysql"
  engine_version                = data.aws_rds_engine_version.aurora_mysql.version
  replication_source_identifier = var.source_cluster_arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]

  # Read replica specific settings
  backup_retention_period = 1 # Minimal for cost savings
  skip_final_snapshot     = true

  tags = {
    Name        = "${var.project_name}-aurora-cluster-replica"
    Environment = var.environment
    Type        = "ReadReplica"
  }

  lifecycle {
    ignore_changes = [
      engine_version  # Ignore minor version updates
    ]
  }
}

# Read Replica Instance
resource "aws_rds_cluster_instance" "read_replica" {
  count = var.is_read_replica ? 1 : 0

  identifier         = "${var.project_name}-aurora-replica-instance-1"
  cluster_identifier = aws_rds_cluster.read_replica[0].id
  instance_class     = var.instance_class
  engine             = "aurora-mysql"

  tags = {
    Name        = "${var.project_name}-aurora-replica-instance-1"
    Environment = var.environment
    Type        = "ReadReplica"
  }
}

# Store the database password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name_prefix = "${var.project_name}-db-password-${var.environment}-"

  tags = {
    Name        = "${var.project_name}-db-password"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.master_username
    password = var.master_password
  })
}