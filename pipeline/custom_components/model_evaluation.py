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

from kfp.dsl import component
from kfp.dsl import Output, Metrics
from typing import NamedTuple


@component(
    base_image="python:3.11-slim",
    packages_to_install=[
        "google-cloud-storage",
    ],
)
def model_evaluation(
    project: str,
    model_dir: str,
    metrics: Output[Metrics],
) -> NamedTuple("Output", [("deploy_decision", bool)]):
    from google.cloud import storage
    import json
    import os
    from collections import namedtuple

    print(
        f"--->Starting model evaluation for project: {project}, model_dir: {model_dir}"
    )
    client = storage.Client(project=project)

    # Construct the path to metrics.json within the model_dir
    metrics_file_path = f"metrics.json"

    # Access the bucket and blob
    bucket_name, prefix = model_dir.replace("gs://", "").split("/", maxsplit=1)

    blob_name = os.path.join(prefix, metrics_file_path)
    bucket = client.get_bucket(bucket_name)
    blob = bucket.blob(blob_name)
    print(f"--->Accessing blob: gs://{bucket_name}/{blob_name}")

    # Download and load the JSON file

    metrics_json = blob.download_as_string().decode(
        "utf-8"
    )  # Decode byte string to regular string
    obtained_metrics = json.loads(metrics_json)
    print(f"--->Successfully downloaded and parsed metrics.json: {obtained_metrics}")
    for k, v in obtained_metrics.items():
        metrics.log_metric(k, v)

    # Check the accuracy value
    output = namedtuple("Output", ["deploy_decision"])
    if "accuracy" in obtained_metrics and obtained_metrics["accuracy"] > 0.9:
        print(f"--->Model accuracy meets the threshold (above 0.9).")
        return output(True)  # Return as a named tuple
    else:
        print(
            f"--->Model accuracy ({obtained_metrics.get('accuracy', 'N/A')}) does not meet the threshold."
        )
        return output(False)  # Return as a named tuple


if __name__ == "__main__":
    from kfp import local

    # local.init(runner=local.DockerRunner(), pipeline_root="/tmp/pipeline_outputs")
    local.init(runner=local.SubprocessRunner(), pipeline_root="/tmp/pipeline_outputs")

    model_dir = "gs://your-project-id/local_via_sdk/aiplatform-custom-job-2024-09-27-22:30:49.918/model"
    training_container_image_uri = (
        "us-central1-docker.pkg.dev/your-project-id/ml-images/training:latest"
    )
    project_id = "your-project-id"
    model_evaluation(
        project=project_id,
        model_dir=model_dir,
    )
