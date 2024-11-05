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

# Script to create a Vertex AI PersistentResource.

# --- Set default values for optional arguments ---
LOCATION="us-central1"
PERSISTENT_RESOURCE_ID=""

# --- Usage instructions ---
usage() {
  echo "Usage: $0 -p <PROJECT_ID> [-r <REGION> | -l <LOCATION>] [-n <PERSISTENT_RESOURCE_ID>]"
  echo "  -p: Google Cloud Project ID (required)"
  echo "  -r: Region (optional, defaults to us-central1)"
  echo "  -l: Location (synonym for -r)"
  echo "  -n: Persistent Resource ID (optional, generates random name if not provided)"
  exit 1
}

# --- Parse command-line arguments using getopts ---
while getopts "p:r:l:n:" opt; do
  case $opt in
    p)
      PROJECT_ID="$OPTARG"
      ;;
    r)
      LOCATION="$OPTARG"
      ;;
    l)
      LOCATION="$OPTARG" # Allow --location as synonym for --region
      ;;
    n)
      PERSISTENT_RESOURCE_ID="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
  esac
done

# --- Check if PROJECT_ID is provided ---
if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: PROJECT_ID is required." >&2
  usage
fi

# --- Shift arguments after processing options ---
shift $((OPTIND-1))

# --- Generate a random name if PERSISTENT_RESOURCE_ID is not provided ---
if [[ -z "$PERSISTENT_RESOURCE_ID" ]]; then
  PERSISTENT_RESOURCE_ID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
  echo "Generated random PersistentResource ID: $PERSISTENT_RESOURCE_ID"
fi

# --- Check if a persistent resource with the same name already exists ---
if gcloud ai persistent-resources describe "$PERSISTENT_RESOURCE_ID" --project="$PROJECT_ID" --region="$LOCATION" &>/dev/null; then
  echo "Persistent resource with name '$PERSISTENT_RESOURCE_ID' already exists. Exiting."
  exit 0
fi

# --- Create the persistent resource and capture the operation ID ---
# **Note:** Replace 'worker_pools_specs.yaml' with your desired worker pool configuration.
OPERATION_ID=$(gcloud ai persistent-resources create \
  --persistent-resource-id="$PERSISTENT_RESOURCE_ID" \
  --display-name="$PERSISTENT_RESOURCE_ID" \
  --project="$PROJECT_ID" \
  --region="$LOCATION" \
  --config=worker_pools_specs.yaml \
  --enable-custom-service-account \
  --format="value(name)") || exit 1

OPERATION_NAME="${OPERATION_ID##*/}" # Extract just the operation name

echo "Operation to create PersistentResource [$OPERATION_ID] is submitted successfully."

# --- Wait for the operation to complete ---
while true; do
  OPERATION_STATUS=$(gcloud ai operations describe projects/$PROJECT_ID/locations/$LOCATION/operations/$OPERATION_NAME --format='value(metadata.progressMessage)')

  if [[ "$OPERATION_STATUS" == "Your persistent resource is ready." ]]; then
    echo "Persistent resource created successfully!"
    exit 0
  elif [[ "$OPERATION_STATUS" == "Waiting for persistent resource to be ready." || "$OPERATION_STATUS" == "Create PersistentResource request received. Checking project configuration and quota..." ]]; then
    echo "Waiting for persistent resource to be ready..."
    sleep 10
  else
    echo "Error creating persistent resource: $OPERATION_STATUS"
    exit 1
  fi
done