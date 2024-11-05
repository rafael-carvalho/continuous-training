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

# Script to delete a Vertex AI PersistentResource.

# --- Usage instructions ---
usage() {
  echo "Usage: $0 -p <PROJECT_ID> [-r <REGION> | -l <LOCATION>] -n <PERSISTENT_RESOURCE_ID>"
  echo "  -p: Google Cloud Project ID (required)"
  echo "  -r: Region (optional, defaults to us-central1)"
  echo "  -l: Location (synonym for -r)"
  echo "  -n: Persistent Resource ID (required)"
  exit 1
}

# --- Parse command-line arguments using getopts ---
LOCATION="us-central1" # Default location
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


# --- Check if required arguments are provided ---
if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: PROJECT_ID is required." >&2
  usage
fi

if [[ -z "$PERSISTENT_RESOURCE_ID" ]]; then
  echo "Error: PERSISTENT_RESOURCE_ID is required." >&2
  usage
fi

# --- Delete the persistent resource ---
gcloud ai persistent-resources delete "$PERSISTENT_RESOURCE_ID" \
  --project="$PROJECT_ID" \
  --region="$LOCATION" \
  --async

echo "Deletion of PersistentResource '$PERSISTENT_RESOURCE_ID' initiated."