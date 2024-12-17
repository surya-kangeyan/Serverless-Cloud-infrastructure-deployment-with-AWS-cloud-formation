import boto3, json, os

s3 = boto3.client('s3', region_name='us-west-2')

def list_files_in_s3(bucket_name, prefix):
    print(f"Searching in bucket: {bucket_name} with prefix: {prefix}")
    paginator = s3.get_paginator('list_objects_v2')
    all_files = []
    
    for page in paginator.paginate(Bucket=bucket_name, Prefix=prefix):
        if 'Contents' in page:
            for obj in page['Contents']:
                if obj['Key'].endswith('.json.gz'):
                    all_files.append(obj['Key'])
    
    print(f"Found {len(all_files)} .json.gz files")
    return all_files

def handler(event, context):
    input_bucket = event['input_bucket']
    prefix = "AWSDynamoDB/"  # Base prefix
    files = list_files_in_s3(input_bucket, prefix)
    queue_url = event['queue_url']
    output_bucket = event['output_bucket']

    print(f"Found files: {files}")
    
    file_count = 0
    for json_path in files:
        sqs_message = {
            'input_bucket': input_bucket,
            'output_bucket': output_bucket,
            'json_path': json_path,
            'output_key': f'csv_files/{os.path.basename(json_path).split(".json")[0]}.csv'
        }

        sqs = boto3.client('sqs', region_name='us-west-2')
        sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps(sqs_message)
        )
        file_count += 1

    print(f"Started json to csv conversion for {file_count} files.")
    return {'file_count': file_count}