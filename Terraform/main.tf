provider "aws" {
  region = var.region
}

# ------------------------------
# IAM Role for EC2 to Access ECR
# ------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "ec2-ecr-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_readonly_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# ------------------------------
# Security Group
# ------------------------------
resource "aws_security_group" "web_sg" {
  name        = var.security_group_name
  description = "Allow HTTP and SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.security_group_name
  }
}

# ------------------------------
# Latest Amazon Linux 2 AMI
# ------------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

# ------------------------------
# EC2 Instance
# ------------------------------
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type           = var.instance_type
  key_name                = var.key_name
  iam_instance_profile    = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids  = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y

              # Install AWS CLI
              yum install -y unzip
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              ./aws/install

              # Install Docker
              amazon-linux-extras install docker -y
              systemctl enable docker
              systemctl start docker
              usermod -aG docker ec2-user
              sleep 10

              REGION=${var.region}
              REPO=${var.ecr_repo_url}
              TAG=${var.image_tag}

              # Login to ECR + Pull Image
              aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REPO
              docker pull $REPO:$TAG

              # Restart container if exists
              docker rm -f college-website || true

              # Run container
              docker run -d --name college-website -p 80:80 $REPO:$TAG
              EOF

  tags = {
    Name = "QuickEats-EC2"
  }
}
