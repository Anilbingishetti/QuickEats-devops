variable "region" {
  default = "ap-south-1"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "key_name" {
  default = "my-keypair"
}

variable "ecr_repo_url" {
  description = "ECR repository URL (no tag)"
  default     = "387056640483.dkr.ecr.ap-south-1.amazonaws.com/QuickEats-website"
}

variable "image_tag" {
  default = "latest"
}

variable "security_group_name" {
  default = "jenkins-ec2-sg"
}
