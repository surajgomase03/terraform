resource "aws_s3_bucket" "first_bucket" {
  bucket = "first_bucket_with_versioning"
  
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.first_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
  
}