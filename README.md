Welcome to the CS218 final.

1. Authenticate with your AWS account using CLI. You should have root privileges
2. Run setup.sh, which will get you set up with the necessary resources. It may take up to
   20 minutes for the ddb to finish exporting to S3.
   Read the script and make edits to the script. Blindly running it will not work. The script might report errors.
   You are expected to fix the errors.
3. Create a file named template.yaml. This will be the file you will use to set up the infrastructure.
   This is where most of the work lies.
4. Use deploy_stack.sh to deploy any resources declared in template.yaml.
5. Write collate.sh to execute the Lambda, download the csv files to a temp folder, and collate them.

After running step 2, you should see something like this:
Export status: COMPLETED
2024-12-14 08:30:57 0 AWSDynamoDB/01734193780233-6ecbd199/\_started
2024-12-14 08:36:34 83 AWSDynamoDB/01734193780233-6ecbd199/data/6exvpw7cmy6nna3q7gnst62pwa.json.gz
2024-12-14 08:35:49 93 AWSDynamoDB/01734193780233-6ecbd199/data/ja6agllg6u4vhc4for6k54yolq.json.gz
2024-12-14 08:35:56 95 AWSDynamoDB/01734193780233-6ecbd199/data/lqsajatoaazgnmchi4mqq3feru.json.gz
2024-12-14 08:35:46 83 AWSDynamoDB/01734193780233-6ecbd199/data/uvdm4fon4i67jblia7pz5aq2j4.json.gz
2024-12-14 08:36:57 780 AWSDynamoDB/01734193780233-6ecbd199/manifest-files.json
2024-12-14 08:36:57 24 AWSDynamoDB/01734193780233-6ecbd199/manifest-files.md5
2024-12-14 08:36:57 639 AWSDynamoDB/01734193780233-6ecbd199/manifest-summary.json
2024-12-14 08:36:58 24 AWSDynamoDB/01734193780233-6ecbd199/manifest-summary.md5

Good luck and enjoy!!!

# CS-218-final-Assignment
