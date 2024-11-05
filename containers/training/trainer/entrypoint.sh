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

# Set execution tracing (optional - can be removed for cleaner output)
# set -x 

# Script to run either training or evaluation based on the first argument.

# Get the script name for usage messages
SCRIPT_NAME=$(basename "$0")

# Check if any arguments are provided
if [ -z "$1" ]; then
  echo "Usage: $SCRIPT_NAME [train|eval] [arguments...]"
  exit 1
fi

# Get the first argument (command)
COMMAND="$1"

# Shift the arguments to remove the command
shift

# Case statement for cleaner command handling
case "$COMMAND" in
  "train")
    echo "Starting training..."
    python train.py "$@"  # Pass all remaining arguments to train.py
    ;;
  "eval")
    echo "Starting evaluation..."
    python evaluation.py "$@"  # Pass all remaining arguments to eval.py
    ;;
  *)
    echo "Invalid command: $COMMAND"
    echo "Usage: $SCRIPT_NAME [train|eval] [arguments...]"
    exit 1
    ;;
esac

echo "Finished."