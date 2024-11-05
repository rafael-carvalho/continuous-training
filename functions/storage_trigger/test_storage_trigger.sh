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

# Project root directory (make this an absolute path for robustness)
project_root="$(git rev-parse --show-toplevel)"

# JSON output file (using project root avoids relative path issues)
json_file="$project_root/terraform/infrastructure.json"

# Generate Terraform output only once
terraform -chdir="$project_root/terraform" output -json > "$json_file"

# Check if the file exists and is not empty (simplified)
[[ -s "$json_file" ]] || { echo "File $json_file is empty or does not exist."; exit 1; }

cd $project_root/functions/storage_trigger

# Extract the value using jq, handling potential missing values
export PROJECT_ID=$(jq -r '.project_id.value' "$json_file")
export REGION=$(jq -r '.region.value // "us-central1"' "$json_file")
export BQ_DATASET=$(jq -r '.bq_dataset.value' "$json_file") # Ensure this is read
export TRIGGER_PIPELINE_PUBSUB_TOPIC=$(jq -r '.trigger_pipeline_pubsub_topic.value' "$json_file")
export RUNNER_SERVICE_ACCOUNT_EMAIL=$(jq -r '.runner_service_account_email.value' "$json_file")
export ARTIFACT_REGISTRY_REPO_KFP_URI=https://$(jq -r '.artifact_registry_repo_kfp_uri.value' "$json_file")/pipeline/latest
export PERSISTENT_RESOURCE_NAME=$(jq -r '.persistent_resource_name.value' "$json_file")
export TRAINING_CONTAINER_IMAGE_URI=$(jq -r '.training_container_image_uri.value' "$json_file")
export PRODUCTION_ENDPOINT_ID=$(jq -r '.production_endpoint_id.value' "$json_file")
export PREDICTION_CONTAINER_IMAGE_URI=$(jq -r '.prediction_container_image_uri.value' "$json_file")
export BQ_SAMPLE_TRAINING_DATA_URI=$(jq -r '.bq_sample_training_data_uri.value' "$json_file")
export MODEL_CHECKPOINT_DIR=$(jq -r '.model_checkpoint_dir.value' "$json_file")
export TENSORBOARD=$(jq -r '.tensorboard.value' "$json_file")
export BUCKET=$(jq -r '.bucket_name.value' "$json_file") # Ensure this is read
export TIMESTAMP=$(date -u +%y%m%d_%H%M%S)
export PIPELINE_ROOT="gs://$BUCKET/pipeline_triggered_locally/$TIMESTAMP"


python main.py --bucket=$BUCKET --file="data/sample.csv"