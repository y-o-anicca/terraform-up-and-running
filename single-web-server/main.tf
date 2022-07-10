provider "aws" { 
  region = "us-east-2"
}

resource "aws_instance" "example" {
  ami = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.instance.id ]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF

  tags={
    Name = "terraform-example"
  }
}

// By default, AWS does not allow any incoming or outgoing traffic from an EC2 Instance.
// To Allow the EC2 to receive traffic on 8080, It requires you to create a security group.
resource "aws_security_group" "instance" { 
  name = "terraform-example-instance"
  
  ingress {
    from_port = 8080
    to_port = 8080 
    protocol = "tcp" 
    // The CIDR block 0.0.0.0/0 is an IP address range that includes all possible IP addresses.
    // so this security group allows incoming requests on port 8080 from any IP.7
    cidr_blocks = ["0.0.0.0/0"]
  } 
}
