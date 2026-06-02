output "eventbridge_bus_arn" {
  description = "ARN of the EventBridge bus"
  value       = module.eventbridge.eventbridge_bus_arn
}

output "eventbridge_bus_name" {
  description = "Name of the EventBridge bus"
  value       = module.eventbridge.eventbridge_bus_name
}

output "eventbridge_rule_arns" {
  description = "ARNs of the EventBridge rules"
  value       = module.eventbridge.eventbridge_rule_arns
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda_function.lambda_function_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda_function.lambda_function_name
}

output "lambda_role_arn" {
  description = "ARN of the IAM role attached to the Lambda function"
  value       = module.lambda_function.lambda_role_arn
}

output "ec2_instance_public_ip" {
  description = "Public IP address of the EC2 spot instance"
  value       = module.ec2_instance.public_ip
}

output "vpc_id" {
  description = "VPC ID created by the VPC module"
  value       = module.vpc.vpc_id
}

output "route53_zone_id" {
  description = "Hosted zone ID created for Route53"
  value       = module.zone.id
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = module.zone.name
}

output "route53_record_fqdn" {
  description = "FQDN of the Route53 record managed by Lambda"
  value       = aws_route53_record.ec2.fqdn
}

