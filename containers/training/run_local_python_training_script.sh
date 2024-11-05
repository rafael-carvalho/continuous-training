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

PROJECT_ID=$(jq -r '.project_id.value' "$json_file")
REGION=$(jq -r '.region.value // "us-central1"' "$json_file")
BQ_DATASET=$(jq -r '.bq_dataset.value' "$json_file") # Ensure this is read
TRIGGER_PIPELINE_PUBSUB_TOPIC=$(jq -r '.trigger_pipeline_pubsub_topic.value' "$json_file")
RUNNER_SERVICE_ACCOUNT_EMAIL=$(jq -r '.runner_service_account_email.value' "$json_file")
ARTIFACT_REGISTRY_REPO_KFP_URI=$(jq -r '.artifact_registry_repo_kfp_uri.value' "$json_file")
PERSISTENT_RESOURCE_NAME=$(jq -r '.persistent_resource_name.value' "$json_file")
TRAINING_CONTAINER_IMAGE_URI=$(jq -r '.training_container_image_uri.value' "$json_file")
PRODUCTION_ENDPOINT_ID=$(jq -r '.production_endpoint_id.value' "$json_file")
PREDICTION_CONTAINER_IMAGE_URI=$(jq -r '.prediction_container_image_uri.value' "$json_file")
BQ_SAMPLE_TRAINING_DATA_URI=$(jq -r '.bq_sample_training_data_uri.value' "$json_file")
MODEL_CHECKPOINT_DIR=$(jq -r '.model_checkpoint_dir.value' "$json_file")
TENSORBOARD=$(jq -r '.tensorboard.value' "$json_file")
BUCKET=$(jq -r '.bucket_name.value' "$json_file") # Ensure this is read
TIMESTAMP=$(date -u +%y%m%d_%H%M%S)
PIPELINE_ROOT="gs://$BUCKET/pipeline_triggered_locally/$TIMESTAMP"

ARGS="--data_path=$BQ_SAMPLE_TRAINING_DATA_URI --model_checkpoint_dir=$MODEL_CHECKPOINT_DIR"

python trainer/train.py $ARGS