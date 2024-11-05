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
set -xe

# Local - read from Terraform output
project_root="$(git rev-parse --show-toplevel)"
json_file="$project_root/terraform/infrastructure.json"

terraform -chdir="$project_root/terraform" output -json > "$json_file"

if [[ ! -s "$json_file" ]]; then
  echo "File $json_file is empty or does not exist."
  exit 1
fi

cd "$project_root/notebook"

PROJECT_ID=$(jq -r '.project_id.value' "$json_file")
_REGION=$(jq -r '.region.value // "us-central1"' "$json_file")
_BQ_DATASET=$(jq -r '.bq_dataset.value' "$json_file") # Ensure this is read
_TRIGGER_PIPELINE_PUBSUB_TOPIC=$(jq -r '.trigger_pipeline_pubsub_topic.value' "$json_file")
_RUNNER_SERVICE_ACCOUNT_EMAIL=$(jq -r '.runner_service_account_email.value' "$json_file")
_PIPELINE_TEMPLATE_PATH=$(jq -r '.pipeline_template_path.value' "$json_file")
_PERSISTENT_RESOURCE_NAME=$(jq -r '.persistent_resource_name.value' "$json_file")
_TRAINING_CONTAINER_IMAGE_URI=$(jq -r '.training_container_image_uri.value' "$json_file")
_PRODUCTION_ENDPOINT_ID=$(jq -r '.production_endpoint_id.value' "$json_file")
_PREDICTION_CONTAINER_IMAGE_URI=$(jq -r '.prediction_container_image_uri.value' "$json_file")
_BQ_SAMPLE_TRAINING_DATA_URI=$(jq -r '.bq_sample_training_data_uri.value' "$json_file")
_MODEL_CHECKPOINT_DIR=$(jq -r '.model_checkpoint_dir.value' "$json_file")
_TENSORBOARD=$(jq -r '.tensorboard.value' "$json_file")
_BUCKET=$(jq -r '.bucket_name.value' "$json_file") # Ensure this is read
_TIMESTAMP=$(date -u +%y%m%d_%H%M%S)
_PIPELINE_ROOT="gs://$_BUCKET/pipeline_triggered_locally/$_TIMESTAMP"
_NOTEBOOK_GCS_URI=$(jq -r '.notebook_gcs_uri.value' "$json_file")
_BUCKET=$(jq -r '.bucket_name.value' "$json_file")
_PROJECT_NUMBER=$(jq -r '.project_number.value' "$json_file")
_TRIGGER_BUCKET=$(jq -r '.trigger_bucket.value' "$json_file")
_GCS_SAMPLE_TRAINING_DATA_URI=$(jq -r '.gcs_sample_training_data_uri.value' "$json_file")
_TAG_LOCAL="local"

#  Execute the Python script
python3 "$project_root/notebook/generate_notebook.py" \
  --project_id="$PROJECT_ID" \
  --project_number="$_PROJECT_NUMBER" \
  --bucket=$_BUCKET \
  --pipeline_template_path="$_PIPELINE_TEMPLATE_PATH" \
  --bq_training_data_uri="$_BQ_SAMPLE_TRAINING_DATA_URI" \
  --persistent_resource_name="$_PERSISTENT_RESOURCE_NAME" \
  --pipeline_root="$_PIPELINE_ROOT" \
  --prediction_container_image_uri="$_PREDICTION_CONTAINER_IMAGE_URI" \
  --production_endpoint_id="$_PRODUCTION_ENDPOINT_ID" \
  --project_id="$PROJECT_ID" \
  --region="$_REGION" \
  --runner_service_account_email="$_RUNNER_SERVICE_ACCOUNT_EMAIL" \
  --tensorboard="$_TENSORBOARD" \
  --training_container_image_uri="$_TRAINING_CONTAINER_IMAGE_URI" \
  --model_checkpoint_dir="$_MODEL_CHECKPOINT_DIR" \
  --notebook_gcs_uri="$_NOTEBOOK_GCS_URI" \
  --gcs_sample_training_data_uri="$_GCS_SAMPLE_TRAINING_DATA_URI" \
  --trigger_bucket="$_TRIGGER_BUCKET"

export IS_TESTING="True"

echo "Will execute the notebook"

python3 "$project_root/notebook/run_notebook.py" \
  --notebook_gcs_uri="$_NOTEBOOK_GCS_URI" \
  --project_id="$PROJECT_ID"