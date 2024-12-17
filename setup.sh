#!/bin/bash

# To test whether your role has the proper permissions, you may use: 
# aws sts get-caller-identity 

# Define variables
STUDENT_ID="017407299"
DDB_TABLE_NAME="cs218-final-ddb-table"
S3_INPUT_BUCKET="cs218-final-input-bucket-${STUDENT_ID}"
S3_CODE_BUCKET="cs218-final-code-bucket-${STUDENT_ID}"
REGION="us-west-2"
STACK_NAME="cs218-final-resources"

# Check if the stack already exists
if aws cloudformation describe-stacks --stack-name $STACK_NAME >/dev/null 2>&1; then
  echo "Stack $STACK_NAME exists. Deleting the stack..."
  
  # Delete the stack
  aws cloudformation delete-stack --stack-name $STACK_NAME
  
  # Wait for the stack to be deleted
  echo "Waiting for stack $STACK_NAME to be deleted..."
  aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME
  
  echo "Stack $STACK_NAME has been successfully deleted."
else
  echo "Stack $STACK_NAME does not exist."
fi

# Create DynamoDB table if it doesn't exist
if ! aws dynamodb describe-table --table-name $DDB_TABLE_NAME --region $REGION > /dev/null 2>&1; then
  aws dynamodb create-table \
    --table-name $DDB_TABLE_NAME \
    --attribute-definitions AttributeName=ID,AttributeType=S \
    --key-schema AttributeName=ID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION \
    --output text
else
  echo "DynamoDB table $DDB_TABLE_NAME already exists."
fi

# Wait for the table to be active
aws dynamodb wait table-exists --table-name $DDB_TABLE_NAME --region $REGION

# Enable point-in-time recovery for the DynamoDB table
aws dynamodb update-continuous-backups \
  --table-name $DDB_TABLE_NAME \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
  --region $REGION

# Populate the table with dummy entries
for i in {1..10}; do
  aws dynamodb put-item \
    --table-name $DDB_TABLE_NAME \
    --item '{"ID": {"S": "Item'$i'"}, "Name": {"S": "Name'$i'"}, "Value": {"N": "'$i'"}}' \
    --region $REGION
done

# Create input S3 bucket if it doesn't exist
if ! aws s3api head-bucket --bucket $S3_INPUT_BUCKET 2>/dev/null; then
  aws s3api create-bucket \
    --bucket $S3_INPUT_BUCKET \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION
else
  echo "S3 bucket $S3_INPUT_BUCKET already exists."
  aws s3 rm s3://$S3_INPUT_BUCKET --recursive
  echo "Contents of $S3_INPUT_BUCKET have been removed."
fi

# Create code S3 bucket if it doesn't exist
if ! aws s3api head-bucket --bucket $S3_CODE_BUCKET 2>/dev/null; then
  aws s3api create-bucket \
    --bucket $S3_CODE_BUCKET \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION
else
  echo "S3 bucket $S3_CODE_BUCKET already exists."
  aws s3 rm s3://$S3_CODE_BUCKET --recursive
  echo "Contents of $S3_CODE_BUCKET have been removed."
fi


# Export DynamoDB table to S3
EXPORT_TASK_ID=$(aws dynamodb export-table-to-point-in-time \
  --table-arn $(aws dynamodb describe-table --table-name $DDB_TABLE_NAME --region $REGION --query "Table.TableArn" --output text) \
  --s3-bucket $S3_INPUT_BUCKET \
  --region $REGION \
  --query "ExportDescription.ExportArn" --output text)

echo "Export task ID: $EXPORT_TASK_ID"

# Verify export status
while true; do
  STATUS=$(aws dynamodb describe-export \
    --export-arn $EXPORT_TASK_ID \
    --region $REGION \
    --query "ExportDescription.ExportStatus" --output text)
  echo "Export status: $STATUS"
  if [ "$STATUS" == "COMPLETED" ]; then
    break
  elif [ "$STATUS" == "FAILED" ]; then
    echo "Export failed. Exiting."
    exit 1
  fi
  sleep 10
done

# List files in the S3 bucket
aws s3 ls s3://$S3_INPUT_BUCKET/ --recursive

