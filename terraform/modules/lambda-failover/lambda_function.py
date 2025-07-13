# terraform/modules/lambda-failover/lambda_function.py
import json
import boto3
import os
import time
from datetime import datetime

# Initialize AWS clients
ecs_primary = boto3.client('ecs', region_name=os.environ['PRIMARY_REGION'])
ecs_dr = boto3.client('ecs', region_name=os.environ['DR_REGION'])
rds_dr = boto3.client('rds', region_name=os.environ['DR_REGION'])
elb_primary = boto3.client('elbv2', region_name=os.environ['PRIMARY_REGION'])
sns = boto3.client('sns')
ssm = boto3.client('ssm')
cloudwatch = boto3.client('cloudwatch')

def handler(event, context):
    """
    Main handler for automatic failover orchestration
    """
    print(f"Failover triggered at {datetime.now()}")
    print(f"Event: {json.dumps(event)}")
    
    failover_status = {
        'timestamp': datetime.now().isoformat(),
        'primary_region': os.environ['PRIMARY_REGION'],
        'dr_region': os.environ['DR_REGION'],
        'steps': []
    }
    
    try:
        # Step 1: Verify primary region failure
        print("Step 1: Verifying primary region failure...")
        if not verify_primary_failure():
            print("Primary region appears healthy. Aborting failover.")
            return {
                'statusCode': 200,
                'body': json.dumps('Primary region healthy. No failover needed.')
            }
        failover_status['steps'].append({'step': 'verify_failure', 'status': 'completed'})
        
        # Step 2: Check if failover is already in progress
        if is_failover_in_progress():
            print("Failover already in progress. Exiting.")
            return {
                'statusCode': 200,
                'body': json.dumps('Failover already in progress.')
            }
        
        # Mark failover as in progress
        mark_failover_in_progress(True)
        
        # Step 3: Send notification about failover start
        send_notification("🚨 DR Failover Started", 
                         f"Automatic failover to {os.environ['DR_REGION']} has been initiated due to primary region failure.")
        
        # Step 4: Promote RDS read replica
        print("Step 4: Promoting RDS read replica...")
        new_db_endpoint = promote_rds_replica()
        failover_status['steps'].append({
            'step': 'promote_rds',
            'status': 'completed',
            'new_endpoint': new_db_endpoint
        })
        
        # Step 5: Scale up ECS service in DR region
        print("Step 5: Scaling up ECS service in DR region...")
        scale_ecs_service()
        failover_status['steps'].append({'step': 'scale_ecs', 'status': 'completed'})
        
        # Step 6: Wait for ECS service to be healthy
        print("Step 6: Waiting for ECS service to stabilize...")
        wait_for_ecs_health()
        failover_status['steps'].append({'step': 'ecs_health_check', 'status': 'completed'})
        
        # Step 7: Update failover metrics
        update_failover_metrics()
        
        # Step 8: Send success notification
        send_notification("✅ DR Failover Completed", 
                         f"Failover to {os.environ['DR_REGION']} completed successfully. " +
                         f"New database endpoint: {new_db_endpoint}")
        
        # Mark failover as complete
        mark_failover_complete(failover_status)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Failover completed successfully',
                'status': failover_status
            })
        }
        
    except Exception as e:
        print(f"Failover failed: {str(e)}")
        send_notification("❌ DR Failover Failed", 
                         f"Failover to {os.environ['DR_REGION']} failed: {str(e)}")
        mark_failover_in_progress(False)
        raise

def verify_primary_failure():
    """
    Verify that the primary region is actually down
    """
    try:
        # Check primary ALB health
        response = elb_primary.describe_target_health(
            TargetGroupArn=get_primary_target_group_arn()
        )
        
        healthy_targets = [t for t in response['TargetHealthDescriptions'] 
                          if t['TargetHealth']['State'] == 'healthy']
        
        if len(healthy_targets) > 0:
            return False
            
        # Additional check: Try to describe ECS service
        try:
            ecs_primary.describe_services(
                cluster=f"{os.environ['PROJECT_NAME']}-cluster",
                services=[f"{os.environ['PROJECT_NAME']}-service"]
            )
        except Exception:
            # Primary region ECS is not responding
            return True
            
        return True
        
    except Exception as e:
        print(f"Error verifying primary failure: {str(e)}")
        # If we can't reach primary region, assume it's down
        return True

def is_failover_in_progress():
    """
    Check if failover is already in progress
    """
    try:
        response = ssm.get_parameter(
            Name=f"/{os.environ['PROJECT_NAME']}/failover/in-progress"
        )
        return response['Parameter']['Value'] == 'true'
    except:
        return False

def mark_failover_in_progress(in_progress):
    """
    Mark failover as in progress or not
    """
    ssm.put_parameter(
        Name=f"/{os.environ['PROJECT_NAME']}/failover/in-progress",
        Value='true' if in_progress else 'false',
        Type='String',
        Overwrite=True
    )

def promote_rds_replica():
    """
    Promote RDS read replica to standalone cluster
    """
    cluster_id = os.environ['DR_RDS_CLUSTER']
    
    # Promote the read replica
    response = rds_dr.promote_read_replica_db_cluster(
        DBClusterIdentifier=cluster_id
    )
    
    # Wait for promotion to complete
    waiter = rds_dr.get_waiter('db_cluster_available')
    waiter.wait(
        DBClusterIdentifier=cluster_id,
        WaiterConfig={
            'Delay': 30,
            'MaxAttempts': 40  # 20 minutes max
        }
    )
    
    # Get new endpoint
    response = rds_dr.describe_db_clusters(
        DBClusterIdentifier=cluster_id
    )
    
    new_endpoint = response['DBClusters'][0]['Endpoint']
    
    # Store new endpoint in parameter store
    ssm.put_parameter(
        Name=f"/{os.environ['PROJECT_NAME']}/dr/promoted-db-endpoint",
        Value=new_endpoint,
        Type='String',
        Overwrite=True
    )
    
    return new_endpoint

def scale_ecs_service():
    """
    Scale up ECS service in DR region
    """
    response = ecs_dr.update_service(
        cluster=os.environ['DR_CLUSTER_NAME'],
        service=os.environ['DR_SERVICE_NAME'],
        desiredCount=2,
        forceNewDeployment=True
    )
    
    print(f"Scaled ECS service to 2 tasks")

def wait_for_ecs_health():
    """
    Wait for ECS service to have healthy tasks
    """
    max_attempts = 20
    attempt = 0
    
    while attempt < max_attempts:
        response = ecs_dr.describe_services(
            cluster=os.environ['DR_CLUSTER_NAME'],
            services=[os.environ['DR_SERVICE_NAME']]
        )
        
        service = response['services'][0]
        running_count = service['runningCount']
        desired_count = service['desiredCount']
        
        print(f"ECS Service: {running_count}/{desired_count} tasks running")
        
        if running_count >= desired_count and running_count > 0:
            print("ECS service is healthy")
            return
            
        time.sleep(30)
        attempt += 1
    
    raise Exception("ECS service failed to become healthy within timeout")

def get_primary_target_group_arn():
    """
    Get primary ALB target group ARN from parameter store
    """
    try:
        response = ssm.get_parameter(
            Name=f"/{os.environ['PROJECT_NAME']}/primary/target-group-arn"
        )
        return response['Parameter']['Value']
    except:
        # Fallback: construct ARN
        return f"arn:aws:elasticloadbalancing:{os.environ['PRIMARY_REGION']}:*:targetgroup/{os.environ['PROJECT_NAME']}-tg/*"

def update_failover_metrics():
    """
    Update CloudWatch metrics for failover monitoring
    """
    cloudwatch.put_metric_data(
        Namespace=f"{os.environ['PROJECT_NAME']}/Failover",
        MetricData=[
            {
                'MetricName': 'FailoverExecuted',
                'Value': 1,
                'Unit': 'Count',
                'Timestamp': datetime.now()
            }
        ]
    )

def mark_failover_complete(status):
    """
    Mark failover as complete and store status
    """
    # Store failover status
    ssm.put_parameter(
        Name=f"/{os.environ['PROJECT_NAME']}/failover/last-status",
        Value=json.dumps(status),
        Type='String',
        Overwrite=True
    )
    
    # Update failover timestamp
    ssm.put_parameter(
        Name=f"/{os.environ['PROJECT_NAME']}/failover/last-timestamp",
        Value=datetime.now().isoformat(),
        Type='String',
        Overwrite=True
    )
    
    # Mark as not in progress
    mark_failover_in_progress(False)

def send_notification(subject, message):
    """
    Send SNS notification
    """
    sns.publish(
        TopicArn=os.environ['SNS_TOPIC_ARN'],
        Subject=subject,
        Message=message
    )

    