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
from typing import Optional, List
from google.cloud import aiplatform
import argparse
import os
from datetime import datetime


def create_custom_job_on_persistent_resource_sample(
    project: str,
    location: str,
    staging_bucket: str,
    display_name: str,
    container_uri: str,
    persistent_resource_id: str,
    service_account: Optional[str] = None,
    tensorboard: Optional[str] = None,
    training_args: Optional[List[str]] = [],
) -> None:
    aiplatform.init(project=project, location=location, staging_bucket=staging_bucket)
    args = ["train"]
    if training_args:
        args = args + training_args

    worker_pool_specs = [
        {
            "machine_spec": {
                "machine_type": "n1-standard-4",
                # "accelerator_type": "NVIDIA_TESLA_K80",
                # "accelerator_count": 0,
            },
            "replica_count": 1,
            "container_spec": {
                "image_uri": container_uri,
                "command": ["/bin/bash", "entrypoint.sh"],
                "args": args,
            },
        }
    ]

    pr = None
    if persistent_resource_id:
        pr = persistent_resource_id.split("/")[-1]

    custom_job = aiplatform.CustomJob(
        display_name=display_name,
        worker_pool_specs=worker_pool_specs,
        persistent_resource_id=pr,
    )

    custom_job.run(service_account=service_account, tensorboard=tensorboard)


def get_args():
    """Parses command line arguments."""
    parser = argparse.ArgumentParser(
        description="Submit a custom training job to Vertex AI using a persistent resource."
    )

    parser.add_argument(
        "--project",
        type=str,
        required=False,
        default=os.environ.get("PROJECT_ID", None),
        help="Your Google Cloud project ID.",
    )

    parser.add_argument("--location", type=str, required=True, help="Vertex AI region.")

    parser.add_argument(
        "--staging-bucket", type=str, required=True, help="GCS staging bucket."
    )
    parser.add_argument(
        "--display-name",
        type=str,
        required=False,
        default=f"python-sdk-{datetime.now().strftime('%Y%m%d%H%M%S')}",
        help="Name of the custom job.",
    )
    parser.add_argument(
        "--training_container_image_uri",
        type=str,
        required=True,
        help="URI of the training container image.",
    )
    parser.add_argument(
        "--persistent-resource-id",
        type=str,
        required=False,
        help="ID of the persistent resource (cluster).",
    )
    parser.add_argument(
        "--service-account", type=str, help="Service account email (optional)."
    )
    parser.add_argument("--tensorboard", type=str, required=False)
    parser.add_argument(
        "--training-args",
        nargs="*",  # 0 or more arguments
        default=[],  # Default to an empty list
        help="Additional arguments to pass to the training script.",
    )

    return parser.parse_args()


if __name__ == "__main__":
    args = get_args()
    if not args.project:
        raise ValueError(
            "Please provide a project ID, either via a param or a environment variable."
        )

    create_custom_job_on_persistent_resource_sample(
        project=args.project,
        location=args.location,
        staging_bucket=args.staging_bucket,
        display_name=args.display_name,
        container_uri=args.training_container_image_uri,
        persistent_resource_id=args.persistent_resource_id,
        service_account=args.service_account,
        tensorboard=args.tensorboard,
        training_args=args.training_args,
    )

    print("Training job created successfully!")
    print(f"Persistent resource id: {args.persistent_resource_id}")
    print(f"Training container image uri: {args.training_container_image_uri}")
