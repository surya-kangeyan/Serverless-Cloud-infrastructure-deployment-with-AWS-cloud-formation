# CS-218-final-Assignment

## QnA

**1. What are the primary advantages of using CloudFormation for this project?**

- Using CloudFormation in this project offers significant advantages in simplifying resource management and deployment.

- Instead of manually creating each AWS resource like S3 buckets and Lambda functions individually, we can define everything in a single template file.

- This template acts as a blueprint that ensures consistent setup every time we deploy our resources.

- If anything goes wrong during the deployment process, CloudFormation automatically rolls back all changes, helping us maintain a stable environment.

- Making updates becomes straightforward as we only need to modify the template rather than manually adjusting resources in the AWS console, which significantly reduces the chance of configuration errors.

- One of the most valuable benefits is that any team member can use this template to create identical environments, ensuring consistency across deployments.

- CloudFormation also handles the sequencing of resource creation automatically, making sure dependencies are properly managed - for example, creating IAM roles before the Lambda functions that need them.

- This automated approach saves time and reduces complexity in managing our AWS infrastructure, making the entire process more reliable and efficient.

**2. How did you approach debugging issues during the deployment process?**

- During the deployment process, I encountered several challenges that required a systematic debugging approach. I primarily relied on CloudFormation's stack events to trace issues, which proved invaluable when my initial stack deployments failed. For example, when I first deployed the template, I discovered missing IAM permissions for the Lambda functions through stack event logs, requiring me to iteratively refine the IAM role definitions in template.yaml.

- When my initial CloudFormation stack deployment failed with a 'ROLLBACK_COMPLETE' status, I used 'aws cloudformation describe-stack-events' to trace the root cause, which revealed issues with resource dependencies and IAM role configurations in my template.yaml.

- I made extensive use of CloudWatch Logs to debug Lambda function behavior. When the queue-populator Lambda wasn't finding .json.gz files, I added detailed logging statements to track the exact path being searched, which helped me identify that I needed to modify the S3 prefix path in the code from "AWSDynamoDB/" to include the full export path structure.

- The deployment process required multiple iterations of both the CloudFormation template and Lambda code. I had to revise template.yaml several times to properly handle resource dependencies and permissions. The collate.sh script also underwent several revisions - initially, it wasn't properly handling the Lambda response format, causing base64 encoding errors that I identified through AWS CLI error messages.

- Stack cleanup presented its own challenges, especially with non-empty S3 buckets preventing deletion. I resolved this by implementing proper resource cleanup in my deployment scripts, using 'aws s3 rm s3://bucket-name --recursive' before attempting stack deletion. Each deployment failure led to template improvements, such as adding DLQ (Dead Letter Queue) configurations and appropriate visibility timeout settings for the SQS queue.

- This iterative debugging process helped me build a more robust and reliable solution, with each iteration addressing specific issues discovered during testing and deployment.

**3. Which AWS service or component did you find most challenging, and why?**

- The most challenging aspect of this project was handling the Lambda function code updates and their integration with CloudFormation stack deployments. I particularly struggled with the sequence of uploading Lambda code to S3 (which I always seemed to forget after resetting and creating a new stack) and ensuring the CloudFormation stack could access it correctly multiple times. When my initial deployments failed, I discovered that simply updating the stack wasn't enough - I needed to maintain a specific order of operations: creating zip files, uploading to S3, and then updating the Lambda functions, which was initially very hard to find out.

- This challenge became evident when my output CSV files were empty, despite successful stack creation. Through CloudWatch logs, I discovered that while my stack was deploying successfully, the Lambda functions were using outdated code versions. I learned that I needed to explicitly update the Lambda function code using 'aws lambda update-function-code' after each stack deployment, even though the functions were defined in CloudFormation, again this took me a lot of time to identify.

- The debugging process was particularly complex because it involved multiple services working together. For example, when the queue-populator Lambda wasn't finding files, I had to verify the S3 bucket contents using 'aws s3 ls', check Lambda execution role permissions, and monitor CloudWatch logs simultaneously. This helped me understand that my Lambda function needed updated code to handle the specific path structure of the DynamoDB export files (AWSDynamoDB/01734455334387-d14728cf/data/).


**4. How would you modify the architecture to handle an increased number of .json.gz files (e.g., scaling considerations)?**

- To handle a larger volume of .json.gz files efficiently, I would implement several architectural modifications focusing on scalability and performance. The primary change would be optimizing the Lambda function configurations for better parallel processing. Instead of processing files sequentially, I would modify the queue-populator Lambda to implement batch processing, allowing it to send multiple messages to SQS simultaneously using batch operations (sqs:SendMessageBatch).

- For the converting layer, I would adjust the Lambda concurrency settings to allow more parallel file processing. Currently, the json-to-csv-converter Lambda processes one file at a time, but by increasing the SQS batch size and Lambda memory allocation (from 512MB to 1024MB or higher), we could handle multiple files concurrently. I would also try to implement a proper dead-letter queue (DLQ) (which I came to know about when researching about the errors related to converter lambda function) configuration with retries to handle any processing failures gracefully.

- For very large files, I would implement streaming processing using S3 Select to read .json.gz files in chunks rather than loading entire files into Lambda memory. This would help avoid Lambda timeout issues and memory constraints.

- These modifications,I think, would make the system more resilient and efficient when processing thousands of files, while maintaining data consistency and reliability.

**5. What assumptions did you make while designing the system, and how could they affect real-world deployment?**

- During the development of this system, I made several key assumptions that simplified the implementation process. My primary assumption was that the created template.yaml structure was production-ready and wouldn't require modifications. This assumption led me to focus on getting the correct deployment sequence working (setup.sh → deploy_stack.sh → collate.sh) rather than optimizing the infrastructure code. Focusing on adding proper IAM policies in the template.sh file would've saved me several iterations of starting the project from scratch`

- I took the liberty of modifying the queue-populator/ and json-to-csv-converter/ index.py files to include try-catch blocks for debugging purposes. Additionally, I optimized the json-to-csv-converter/index.py script to handle files more efficiently, which improved the robustness of the system during development and testing.

- Another significant assumption was about the Lambda function code. I assumed that once the CloudFormation stack was successfully created, I only needed to focus on uploading the Lambda code correctly to S3 and updating the functions. This led to multiple iterations of the deployment process where I had to carefully sequence my actions: first deploying the stack, then uploading code to S3, and finally updating the Lambda functions.

- I also assumed that the location of .json.gz files in the input bucket would follow the exact structure provided in the example (AWSDynamoDB/[ID]/data/). While this worked for our specific use case, a production system might need to handle different file organization patterns or multiple input sources.

- These assumptions simplified the development process but might require reconsideration in a production environment where requirements are more dynamic and systems need greater flexibility.
