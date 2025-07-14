terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.3.0"

  backend "s3" {
    bucket = "project-b-tf-state"
    key    = "s3/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

data "terraform_remote_state" "project_a" {
  backend = "s3"
  config = {
    bucket = "asutosh-projcet-b"
    key    = "ec2/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_s3_bucket" "terminus_bucket" {
  bucket        = "terminus-bucket-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Name = "terminus-bucket"
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.terminus_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
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

