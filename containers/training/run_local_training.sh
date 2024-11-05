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

# 1) It builds the Docker image.
# 2) It runs the image locally using Docker, which is significantly faster than submitting directly to Vertex AI.
# 3) Once local testing is successful, it pushes the image to Artifact Registry.
# 4) Finally, it submits a training job to Vertex AI using the newly built image.


# Fail on any error and print each command before executing
set -xe

# Project root directory (make this an absolute path for robustness)
project_root="$(git rev-parse --show-toplevel)"

# JSON output file (using project root avoids relative path issues)
json_file="$project_root/terraform/infrastructure.json"

# Generate Terraform output 
terraform -chdir="$project_root/terraform" output -json > "$json_file"

# Check if the file exists and is not empty
[[ -s "$json_file" ]] || { echo "File $json_file is empty or does not exist."; exit 1; }


# Extract values from Terraform output using jq
PROJECT_ID=$(jq -r '.project_id.value' "$json_file")
GCP_REGION=$(jq -r '.region.value // "us-central1"' "$json_file") # Default to us-central1
REPO_NAME=$(jq -r '.repo_name.value' "$json_file") # Provide a default if not in Terraform output
BUCKET=$(jq -r '.bucket_name.value' "$json_file")
TENSORBOARD_NAME=$(jq -r '.tensorboard_name.value' "$json_file") # Default
PERSISTENT_RESOURCE_NAME=$(jq -r '.persistent_resource_name.value' "$json_file")
TRAINING_CONTAINER_IMAGE_URI=$(jq -r '.training_container_image_uri.value' "$json_file") # You should output this from Terraform
RUNNER_SERVICE_ACCOUNT_EMAIL=$(jq -r '.runner_service_account_email.value' "$json_file")
BQ_SAMPLE_TRAINING_DATA_URI=$(jq -r '.bq_sample_training_data_uri.value' "$json_file")
MODEL_CHECKPOINT_DIR=$(jq -r '.model_checkpoint_dir.value' "$json_file")

TRAINING_DIR=$BUCKET/local_training_dir
DATA_PATH_ARG="--data_path=$BQ_SAMPLE_TRAINING_DATA_URI --model_checkpoint_dir=$MODEL_CHECKPOINT_DIR"
# Training Job Configuration
DOCKER_PARAMS="train $DATA_PATH_ARG" # Arguments passed to the training container
# --------------------------------------------------------------------------------------
# Build and Push Docker Image

# Build the Docker image
docker build . -t "$TRAINING_CONTAINER_IMAGE_URI"

# Stop and remove any existing local container named "local" (ignore errors if not running)
docker stop local || true 
docker rm local -f || true

# Run the Docker image locally to make sure it runs fine before submitting the new image
docker run --name local \
    -v "$HOME/.config/gcloud/application_default_credentials.json:/app/credentials.json" \
    -e GOOGLE_APPLICATION_CREDENTIALS=/app/credentials.json \
    -e CLOUD_ML_PROJECT_ID="$PROJECT_ID" \
    -e AIP_MODEL_DIR="$TRAINING_DIR" \
    -e AIP_TENSORBOARD_LOG_DIR="$TENSORBOARD_URI" \
    "$TRAINING_CONTAINER_IMAGE_URI" $DOCKER_PARAMS

# Push the Docker image to the registry
docker push "$TRAINING_CONTAINER_IMAGE_URI"

# --------------------------------------------------------------------------------------
# Run Vertex AI Training Job

# Submit the training job using the `run_training.py` script (assumes this handles Vertex AI job submission)
python run_training.py \
    --training_container_image_uri="$TRAINING_CONTAINER_IMAGE_URI" \
    --location="$GCP_REGION" \
    --project="$PROJECT_ID" \
    --tensorboard="$TENSORBOARD_URI" \
    --staging-bucket="$TRAINING_DIR" \
    --persistent-resource-id="$PERSISTENT_RESOURCE_NAME" \
    --service-account="$RUNNER_SERVICE_ACCOUNT_EMAIL" \
    --training-args="$DATA_PATH_ARG"