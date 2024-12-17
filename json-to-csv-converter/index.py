import boto3, json, csv, gzip, os
from boto3.dynamodb.types import TypeDeserializer
from datetime import datetime

def download_and_decompress_file(bucket_name, key, download_path):
    print(f"Downloading from bucket: {bucket_name}, key: {key} to {download_path}")
    s3 = boto3.client('s3')
    s3.download_file(bucket_name, key, download_path)
    records = []
    with gzip.open(download_path, 'rt') as f_in:
        for line in f_in:
            if line.strip():  # Skip empty lines
                try:
                    record = json.loads(line)
                    if 'Item' in record:  # Make sure we have an Item field
                        records.append(record)
                except json.JSONDecodeError as e:
                    print(f"Error decoding JSON line: {e}")
                    continue
    print(f"Extracted {len(records)} records from file")
    return records

def from_dynamodb_to_json(item):
    d = TypeDeserializer()
    try:
        return {k: d.deserialize(value=v) for k, v in item.items()}
    except Exception as e:
        print(f"Error deserializing DynamoDB item: {e}")
        return None

def convert_ddb_json_to_csv(all_records, schema, bucket_name, output_key):
    print(f"Converting {len(all_records)} records to CSV with schema: {schema}")
    
    s3 = boto3.resource('s3')
    bucket = s3.Bucket(bucket_name)
    
    os.makedirs('/tmp/ddb_to_csv_temp/', mode=0o774, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    temp_file = f'/tmp/ddb_to_csv_temp/output_{timestamp}.csv'
    
    converted_count = 0
    with open(temp_file, 'w', newline='') as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=schema)
        writer.writeheader()
        
        for record in all_records:
            if 'Item' in record:
                cleaned_record = from_dynamodb_to_json(record['Item'])
                if cleaned_record:
                    try:
                        writer.writerow(cleaned_record)
                        converted_count += 1
                    except Exception as e:
                        print(f"Error writing record to CSV: {e}")
                        continue

    print(f"Successfully converted {converted_count} records to CSV")
    
    # Upload to S3
    try:
        bucket.upload_file(temp_file, output_key)
        print(f"Successfully uploaded CSV to {bucket_name}/{output_key}")
    except Exception as e:
        print(f"Error uploading to S3: {e}")
        return False

    # Cleanup
    if os.path.isfile(temp_file):
        os.remove(temp_file)

    return True

def handler(event, context):
    print("Starting handler")
    for record in event['Records']:
        try:
            message_body = json.loads(record['body'])
            json_gz_file = message_body['json_path']
            input_bucket = message_body['input_bucket']
            output_bucket = message_body['output_bucket']
            output_key = message_body['output_key']

            print(f"Processing file: {json_gz_file}")
            print(f"Input bucket: {input_bucket}")
            print(f"Output bucket: {output_bucket}")
            print(f"Output key: {output_key}")

            download_dir = '/tmp'
            download_path = os.path.join(download_dir, os.path.basename(json_gz_file))
            
            records = download_and_decompress_file(input_bucket, json_gz_file, download_path)
            print(f"Downloaded and extracted {len(records)} records")

            schema = ['ID', 'Name', 'Value']
            
            success = convert_ddb_json_to_csv(records, schema, output_bucket, output_key)
            
            if os.path.exists(download_path):
                os.remove(download_path)

            if not success:
                raise Exception("Failed to convert and upload CSV")

        except Exception as e:
            print(f"Error processing message: {e}")
            raise e

    return {'statusCode': 200}