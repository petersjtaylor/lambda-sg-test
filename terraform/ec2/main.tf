provider "aws" {
  profile = "default"
  region  = var.region
}

provider "archive" {}

locals {
  environment = "lambda-cleanup"
}
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "../../lambda"
  output_path = "lambda.zip"
}

data "aws_vpc" "vpc" {
  filter {
    name = "tag:Name"
    values = ["${local.environment}-vpc"]
  }
}

data "aws_subnet" "subnet_private" {
  filter {
    name = "tag:Name"
    values = ["${local.environment}-subnet-private"]
  }
}

data "aws_subnet" "subnet_public" {
  filter {
    name = "tag:Name"
    values = ["${local.environment}-subnet-public"]
  }
}

data "aws_iam_policy_document" "AWSLambdaTrustPolicy" {
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "iam_role" {
  assume_role_policy = data.aws_iam_policy_document.AWSLambdaTrustPolicy.json
  name               = "${var.project}-iam-role-lambda-trigger"
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment_lambda_vpc_access_execution" {
  role       = aws_iam_role.iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment_lambda_basic_execution" {
  role       = aws_iam_role.iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "lambda_function" {
  code_signing_config_arn = ""
  description             = ""
  filename                = data.archive_file.lambda.output_path
  function_name           = "${var.project}-lambda-function"
  role                    = aws_iam_role.iam_role.arn
  handler                 = "index.handler"
  runtime                 = "nodejs14.x"
  source_code_hash        = filebase64sha256(data.archive_file.lambda.output_path)

  vpc_config {
    subnet_ids         = [data.aws_subnet.subnet_private.id]
    security_group_ids = [aws_security_group.security_group.id]
  }
}

resource "aws_security_group" "security_group" {
  vpc_id = data.aws_vpc.vpc.id
  name = "Simple SG"

  ingress {
    protocol  = -1
    from_port = 0
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2049
    to_port     = 2049
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
    Name = "${var.project}-security-group"
  }
}

resource "null_resource" "reassign_EIP" {
  triggers = {
    sg      = aws_security_group.security_group.id
    vpc_id  = data.aws_vpc.vpc.id
  }
  provisioner "local-exec" {
    when    = destroy
    command = "bash ./update-lambda-sg.sh ${self.triggers.vpc_id} ${self.triggers.sg}"
  }
}

resource "tls_private_key" "node_key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "key_pair" {
  key_name = "efs-key"
  public_key = tls_private_key.node_key.public_key_openssh
}

resource "null_resource" "save_key_pair" {
  provisioner "local-exec" {
    command = "echo '${tls_private_key.node_key.private_key_pem}' > node.pem && chmod 600 node.pem"
  }
}

# Public EC2 instance
resource "aws_instance" "bastion" {
  ami                    = "ami-0d729d2846a86a9e7"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.key_pair.key_name
  subnet_id              = data.aws_subnet.subnet_public.id
  vpc_security_group_ids = [aws_security_group.security_group.id]
  tags = {
    Name = "Bastion"
  }

  provisioner "local-exec" {
    command = "echo '${aws_instance.bastion.public_ip}' > publicIP.txt"
  }
}

resource "aws_efs_file_system" "efs" {
  creation_token = "ec2-efs"
  tags = {
    Name = "EFS Volume"
  }
}

resource "aws_efs_mount_target" "mount" {
  depends_on      = [aws_efs_file_system.efs]
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = aws_instance.bastion.subnet_id
  security_groups = [aws_security_group.security_group.id]
}

resource "null_resource" "configure_nfs" {
  depends_on = [aws_efs_mount_target.mount]
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = tls_private_key.node_key.private_key_pem
    host        = aws_instance.bastion.public_ip
  }
  provisioner "remote-exec" {
    inline = [
    "sudo mkdir -p /wibble",
    "mountpoint -q /wibble && echo 'Nothing to do' || sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,port=2049 ${aws_efs_mount_target.mount.ip_address}:/ /wibble",
    "sudo chown ec2-user:ec2-user /wibble"
    ]
  }
}
