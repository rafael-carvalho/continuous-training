# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#!/bin/bash

# Fail on any error and print each command before executing
#set -xe
set -e

# Get the project root directory
project_root=$(git rev-parse --show-toplevel)

# Define the path to the Terraform output file
json_file="$project_root/terraform/infrastructure.json"

# Extract Terraform outputs into the JSON file
terraform -chdir="$project_root/terraform" output -json > "$json_file"

# Check if the JSON file exists and is not empty
if [[ ! -s "$json_file" ]]; then
  echo "Error: File '$json_file' is empty or does not exist."
  exit 1
fi

# Extract values from the JSON file using jq
PROJECT_ID=$(jq -r '.project_id.value' "$json_file")
REGION=$(jq -r '.region.value' "$json_file")
TRIGGER_BUCKET=$(jq -r '.trigger_bucket.value' "$json_file")
GCS_SAMPLE_TRAINING_DATA_URI=$(jq -r '.gcs_sample_training_data_uri.value' "$json_file")

# Get the current timestamp
now=$(date -Iseconds)

# Define short and long sleep durations
sleep_time_short=7
sleep_time_long=15

# Upload the sample CSV file to the trigger bucket
echo "Uploading sample CSV file to $TRIGGER_BUCKET..."

# Remove any existing file named 'sample.csv' in the bucket
#gsutil rm gs://$TRIGGER_BUCKET/sample.csv || echo "File not in bucket"

# Copy the CSV file from the GCS source URI to the trigger bucket
gsutil cp $GCS_SAMPLE_TRAINING_DATA_URI gs://$TRIGGER_BUCKET/$now.csv

# Wait for the 'storage_trigger' function to be triggered
echo "#################"
echo "Waiting $sleep_time_long seconds for 'storage_trigger' function to be triggered..."
echo "The expectation is that logs were generated after the upload... if you see 'Listed 0 items.' it means the function was not triggered"

echo "https://console.cloud.google.com/functions/details/$REGION/storage_trigger?env=gen2&project=$PROJECT_ID&tab=logs"
sleep $sleep_time_long
echo "#################"

# Display logs for the 'storage_trigger' function
echo "----------------------------------"
echo "Logs for 'storage_trigger' function:"
gcloud functions logs read storage_trigger --project="$PROJECT_ID" --start-time="$now"
echo "----------------------------------"

# Wait for the 'submit_pipeline' function to be triggered
echo "#################"
echo "Waiting $sleep_time_short seconds for 'submit_pipeline' function to be triggered..."
echo "https://console.cloud.google.com/functions/details/$REGION/submit_pipeline?env=gen2&project=$PROJECT_ID&tab=logs"
sleep $sleep_time_short
echo "#################"

# Display logs for the 'submit_pipeline' function
echo "----------------------------------"
echo "Logs for 'submit_pipeline' function:"
gcloud functions logs read submit_pipeline --project="$PROJECT_ID" --start-time="$now"
echo "----------------------------------"