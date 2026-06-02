import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client('ec2')
route53 = boto3.client('route53')

def lambda_handler(event, context):
    try:
        # 1. Get Configuration
        hosted_zone_id = os.environ['HOSTED_ZONE_ID']
        subdomains_env = os.environ['SUBDOMAIN_LIST']
        subdomains = [s.strip() for s in subdomains_env.split(',')]
        
        # 2. Get Instance Details
        # The .strip() here is to fix any potential whitespace issues in the event data, which can cause problems when querying EC2.
        instance_id = event['detail']['instance-id'].strip() 
        state = event['detail']['state']
        
        logger.info(f"Instance {instance_id} is {state}. Preparing to update {len(subdomains)} records.")

        # 3. Fetch Public IP
        instance_data = ec2.describe_instances(InstanceIds=[instance_id])
        reservations = instance_data.get('Reservations', [])
        if not reservations:
            raise Exception(f"Instance {instance_id} not found.")
            
        instance = reservations[0]['Instances'][0]
        public_ip = instance.get('PublicIpAddress')

        if not public_ip:
            logger.warning(f"Instance {instance_id} has no Public IP. Skipping.")
            return {'statusCode': 400, 'body': 'No Public IP'}

        # --- GATEKEEPER CHECK ---
        tags = {t['Key']: t['Value'] for t in instance.get('Tags', [])}
        target_tag_value = 'monitoring-instance' # Ensure this matches your EC2 tag exactly
        
        # Use .get() safely to avoid errors if 'Name' tag is missing
        current_name = tags.get('Name', 'Unknown')
        
        if current_name != target_tag_value:
            logger.info(f"Instance Name is '{current_name}', not '{target_tag_value}'. Skipping.")
            return {
                'statusCode': 200, 
                'body': f"Skipped: Instance is '{current_name}'"
            }

        # 4. Build the Batch Request
        changes = []
        for domain in subdomains:
            changes.append({
                'Action': 'UPSERT',
                'ResourceRecordSet': {
                    'Name': domain,
                    'Type': 'A',
                    'TTL': 60,
                    'ResourceRecords': [{'Value': public_ip}]
                }
            })

        # 5. Send Batch Update to Route 53
        logger.info(f"Updating DNS for: {subdomains} -> {public_ip}")
        
        response = route53.change_resource_record_sets(
            HostedZoneId=hosted_zone_id,
            ChangeBatch={
                'Comment': f'Auto update for {instance_id}',
                'Changes': changes
            }
        )
        
        logger.info(f"Update Status: {response['ChangeInfo']['Status']}")
        return {'statusCode': 200, 'body': f"Updated {len(subdomains)} records."}

    except Exception as e:
        logger.error(f"Error: {str(e)}")
        raise e