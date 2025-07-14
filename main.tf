terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.3.0"

  backend "s3" {
    bucket = "asutosh-project-b-20250714"
    key    = "s3/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region     = "us-east-1"

}

data "terraform_remote_state" "project_a" {
  backend = "s3"
  config = {
    bucket = "asutosh-project-a-tf-state"
    key    = "ec2/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}


resource "aws_kms_key" "s3_key" {
  description              = "Customer-managed KMS key for S3 encryption"
  deletion_window_in_days = 7
  enable_key_rotation      = true
}


resource "aws_s3_bucket" "terminus_bucket" {
  bucket        = "terminus-bucket-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Name = "terminus-bucket"
  }
}

resource "aws_s3_bucket_versioning" "terminus_bucket_versioning" {
  bucket = aws_s3_bucket.terminus_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "terminus_bucket_public_access" {
  bucket = aws_s3_bucket.terminus_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terminus_bucket_sse" {
  bucket = aws_s3_bucket.terminus_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_key.arn
    }
  }
}


resource "aws_s3_bucket" "log_bucket" {
  bucket        = "terminus-logs-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "log_bucket_versioning" {
  bucket = aws_s3_bucket.log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "log_bucket_public_access" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket_sse" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_key.arn
    }
  }
}

resource "aws_s3_bucket_logging" "log_bucket_logging" {
  bucket        = aws_s3_bucket.log_bucket.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "self-log/"
}


resource "aws_s3_bucket_logging" "bucket_logging" {
  bucket        = aws_s3_bucket.terminus_bucket.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}


resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.terminus_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "AllowWriteFromIAMRole",
        Effect   = "Allow",
        Principal = {
          AWS = data.terraform_remote_state.project_a.outputs.iam_role_arn
        },
        Action   = "s3:PutObject",
        Resource = "${aws_s3_bucket.terminus_bucket.arn}/*"
      }
    ]
  })
}
