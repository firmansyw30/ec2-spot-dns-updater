module "eventbridge" {
  source = "terraform-aws-modules/eventbridge/aws"

  create_bus = false

  rules = {
    ec2_running = {
      description = "Trigger Lambda when EC2 instance state changes to running"

      event_pattern = jsonencode({
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance State-change Notification"]
        detail = {
          state = ["running"]
        }
      })
    }
  }

  targets = {
    ec2_running = [
      {
        name  = "trigger-lambda-update-route53"
        arn   = module.lambda_function.lambda_function_arn
        input = jsonencode({ "source" : "eventbridge" })
      }
    ]
  }

  attach_lambda_policy = true
  lambda_target_arns   = [module.lambda_function.lambda_function_arn]

  tags = {
    Name = "ec2-spot-instance-state-change-rule"
  }
}

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "auto-update-dns-record-function"
  description   = "Update Route53 record when EC2 Spot instance is running"
  handler       = "index.lambda_handler"
  runtime       = "python3.14"

  source_path = "../lambda-code"

  attach_policy = true
  policy        = module.iam_policy.arn

  environment_variables = {
    HOSTED_ZONE_ID = module.zone.id
    SUBDOMAIN_LIST = "sample-ec2-instance.terraform-aws-modules-example.com"
  }

  tags = {
    Name = "auto-update-dns-record-function"
  }
}

module "zone" {
  source = "terraform-aws-modules/route53/aws"

  name    = "terraform-aws-modules-example.com"
  comment = "Public zone for terraform-aws-modules example"

  tags = {
    Environment = "example"
    Project     = "ec2-spot-dns-updater"
  }
}

module "iam_policy" {
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"

  name        = "lambda_execution_policy"
  path        = "/"
  description = "Lambda policy to update Route53 records"

  policy = <<-EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "EC2ReadPermissions",
                "Effect": "Allow",
                "Action": [
                    "ec2:DescribeInstances",
                    "ec2:DescribeSpotInstanceRequests",
                    "ec2:DescribeSpotFleetInstances"
                ],
                "Resource": "*"
            },
            {
                "Sid": "Route53UpdatePermissions",
                "Effect": "Allow",
                "Action": [
                    "route53:GetChange",
                    "route53:GetHostedZone",
                    "route53:ListHostedZones",
                    "route53:ListHostedZonesByName",
                    "route53:ChangeResourceRecordSets"
                ],
                "Resource": "*"
            }
        ]
    }
  EOF

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-southeast-3a"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "private_key" {
  content         = tls_private_key.example.private_key_pem
  filename        = "${path.module}/user1.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "generated_key" {
  key_name   = "user1"
  public_key = tls_private_key.example.public_key_openssh
}

module "ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "spot-instance"

  create_spot_instance = true
  spot_price           = "0.60"
  spot_type            = "persistent"

  instance_type = "t4g.medium"
  key_name      = aws_key_pair.generated_key.key_name
  monitoring    = true
  subnet_id     = module.vpc.public_subnets[0]
  user_data     = file("../user-data/install_nginx.sh")

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_route53_record" "ec2" {
  zone_id = module.zone.id
  name    = "sample-ec2-instance.terraform-aws-modules-example.com"
  type    = "A"
  ttl     = 60
  records = ["127.0.0.1"]

  lifecycle {
    ignore_changes = [records]
  }
}
