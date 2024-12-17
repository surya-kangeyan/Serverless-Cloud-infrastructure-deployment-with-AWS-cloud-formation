#!/bin/bash


STUDENT_ID="017407299"
STACK_NAME="cs218-final-resources"
REGION="us-west-2"


QUEUE_URL=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query 'Stacks[0].Outputs[?OutputKey==`QueueUrl`].OutputValue' \
  --output text \
  --region $REGION)

OUTPUT_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query 'Stacks[0].Outputs[?OutputKey==`OutputBucketName`].OutputValue' \
  --output text \
  --region $REGION)

INPUT_BUCKET="cs218-final-input-bucket-${STUDENT_ID}"

echo "Using Input Bucket: $INPUT_BUCKET"
echo "Using Output Bucket: $OUTPUT_BUCKET"
echo "Using Queue URL: $QUEUE_URL"


echo "{\"input_bucket\": \"$INPUT_BUCKET\", \"queue_url\": \"$QUEUE_URL\", \"output_bucket\": \"$OUTPUT_BUCKET\"}" > payload.json


echo "Invoking queue populator lambda..."
aws lambda invoke \
  --function-name queue-populator-${STUDENT_ID} \
  --payload file://payload.json \
  --cli-binary-format raw-in-base64-out \
  response.json


if [ $? -ne 0 ]; then
    echo "Failed to invoke queue-populator Lambda"
    exit 1
fi


echo "Waiting for processing to complete..."
while true; do
  MESSAGES=$(aws sqs get-queue-attributes \
    --queue-url $QUEUE_URL \
    --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
    --query 'Attributes.ApproximateNumberOfMessages' \
    --output text \
    --region $REGION)
  
  MESSAGES_IN_FLIGHT=$(aws sqs get-queue-attributes \
    --queue-url $QUEUE_URL \
    --attribute-names ApproximateNumberOfMessagesNotVisible \
    --query 'Attributes.ApproximateNumberOfMessagesNotVisible' \
    --output text \
    --region $REGION)
  
  echo "Messages in queue: $MESSAGES, Messages in flight: $MESSAGES_IN_FLIGHT"
  
  if [ "$MESSAGES" == "0" ] && [ "$MESSAGES_IN_FLIGHT" == "0" ]; then
    echo "All messages processed"
    break
  fi
  sleep 5
done


sleep 10


mkdir -p csv_files


echo "Combining CSV files..."
aws s3 sync s3://$OUTPUT_BUCKET/csv_files/ csv_files/ --region $REGION


if ls csv_files/*.csv 1> /dev/null 2>&1; then

    echo "Creating final output.csv..."
    FIRST_FILE=$(ls csv_files/*.csv | head -1)
    head -1 "$FIRST_FILE" > output.csv
    for f in csv_files/*.csv; do
        tail -n +2 "$f" >> output.csv
    done
    echo "Successfully created output.csv"
else
    echo "No CSV files found to combine"
fi


rm -rf csv_files
rm -f response.json
rm -f payload.json

echo "Process complete. Check output.csv"