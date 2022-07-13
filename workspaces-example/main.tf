terraform {
  backend "s3" {
    bucket = "og-terraform-up-and-running-state" 
     key = "example/terraform.tfstate"
    region = "us-east-2"
    dynamodb_table = "og-terraform-up-and-running-locks"
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "example" {
  ami = "ami-0c55b159cbfafe1f0" 
  instance_type = "t2.micro"
}