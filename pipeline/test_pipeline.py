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
import argparse
from pyexpat import model
import time
from typing import Dict, List

from google.cloud import aiplatform as vertex
from google.api_core.exceptions import NotFound
from google.cloud.aiplatform_v1.types import pipeline_state

import compile_pipeline
from upload_pipeline_to_ar import upload_to_artifact_registry
import submit_pipeline_job
from datetime import datetime
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)


def wait_for_pipeline(
    project_id: str, region: str, pipeline_job_resource_name: str
) -> bool:
    """
    Waits for a Vertex AI pipeline to finish.

    Args:
        project_id (str): The Google Cloud project ID.
        region (str): The region where the pipeline is running.
        pipeline_job_resource_name (str): The resource name of the pipeline job.

    Returns:
        bool: True if the pipeline succeeded, False otherwise.
    """

    # Initialize the AIPlatform client
    vertex.init(project=project_id, location=region)

    # Get the pipeline job
    pipeline_job = vertex.PipelineJob.get(resource_name=pipeline_job_resource_name)
    logging.info(
        f"https://console.cloud.google.com/vertex-ai/pipelines/locations/{region}/runs/{pipeline_job.resource_name.split('/')[-1]}?project={project_id}"
    )
    # Get the pipeline job's current status
    while True:
        status = pipeline_job.state
        logging.info(f"Pipeline Job status: {status.name}")

        if status in [
            pipeline_state.PipelineState.PIPELINE_STATE_SUCCEEDED,
            pipeline_state.PipelineState.PIPELINE_STATE_FAILED,
            pipeline_state.PipelineState.PIPELINE_STATE_CANCELLED,
        ]:
            break  # Exit the loop if the job is finished
        # Wait for a short time before checking again
        time.sleep(10)  # Adjust the wait time as needed

    # Do something based on the final status
    if status == pipeline_state.PipelineState.PIPELINE_STATE_SUCCEEDED:
        logging.info("Pipeline succeeded")
        return True
    elif status == pipeline_state.PipelineState.PIPELINE_STATE_CANCELLED:
        raise Exception("Pipeline cancelled")
    elif status == pipeline_state.PipelineState.PIPELINE_STATE_FAILED:
        raise Exception("Pipeline failed")


def main(project_id: str, region: str, **kwargs):
    """
    Compiles, submits, and monitors a Vertex AI pipeline.
    """

    preset_pipeline_params = {
        "project": project_id,
        "location": region,
        "training_job_display_name": "training_job_display_name",
        "tensorboard": kwargs.get("tensorboard", None),
    }

    logging.info("Compiling pipeline with preset params")
    local_pipeline_file = compile_pipeline.main(parameters=preset_pipeline_params)
    pipeline_root = kwargs.get("pipeline_root")
    pipeline_root = f"{pipeline_root}/pipeline_triggered_via_test_pipeline/{datetime.now().strftime('%Y%m%d%H%M%S')}"

    logging.info(f"Will use pipeline root: {pipeline_root}")

    bq_training_data_uri = kwargs.get("bq_training_data_uri")
    if not bq_training_data_uri:
        raise Exception("bq_training_data_uri is required")

    if not bq_training_data_uri.startswith("bq://"):
        bq_training_data_uri = f"bq://{bq_training_data_uri}"
    model_checkpoint_dir = kwargs.get("model_checkpoint_dir")
    worker_pool_specs: List[Dict[str, Dict[str, str]]] = [
        {
            "machine_spec": {"machine_type": kwargs.get("machine_type")},
            "replica_count": 1,
            "container_spec": {
                "image_uri": kwargs.get("training_container_image_uri"),
                "command": ["python", "train.py"],
                "args": [
                    "--data_path",
                    bq_training_data_uri,
                    "--model_checkpoint_dir",
                    model_checkpoint_dir,
                ],
            },
        }
    ]

    logging.info(f"Will use worker_pool_specs: {worker_pool_specs}")
    model_artifact_dir = f"{pipeline_root}/model"
    pipeline_parameters = kwargs.copy()

    # Add the missing parameters
    pipeline_parameters["service_account"] = pipeline_parameters.pop(
        "runner_service_account_email"
    )
    pipeline_parameters["persistent_resource_id"] = pipeline_parameters.pop(
        "persistent_resource_name"
    ).split("/")[-1]
    pipeline_parameters["model_artifact_dir"] = model_artifact_dir
    pipeline_parameters["worker_pool_specs"] = worker_pool_specs
    pipeline_parameters["bq_training_data_uri"] = bq_training_data_uri
    pipeline_parameters["pipeline_root"] = pipeline_root

    kwargs_that_are_not_pipeline_params = [
        "artifact_registry_repo_kfp_uri",
        "machine_type",
        "model_checkpoint_dir",
        "tag",
        "training_container_image_uri",
    ]
    for x in kwargs_that_are_not_pipeline_params:
        pipeline_parameters.pop(x)

    runner_service_account_email = kwargs.get("runner_service_account_email")
    artifact_registry_repo_kfp_uri = kwargs.get("artifact_registry_repo_kfp_uri")
    persistent_resource_name = kwargs.get("persistent_resource_name")

    pipeline_job_name = (
        submit_pipeline_job.submit_pipeline_job_with_persistent_resource(
            project_id=project_id,
            location=region,
            pipeline_root=pipeline_root,
            pipeline_parameters=pipeline_parameters,
            persistent_resource_name=persistent_resource_name,
            pipeline_template_path=local_pipeline_file,
            service_account=runner_service_account_email,
            enable_caching=False,
        )
    )

    wait_for_pipeline(project_id, region, pipeline_job_name)

    tags = ["latest"]
    kwargs_tag = kwargs.get("tag")
    if kwargs_tag:
        tags.append(kwargs_tag)
    upload_to_artifact_registry(
        local_pipeline_file, kfp_ar_image_uri=artifact_registry_repo_kfp_uri, tags=tags
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifact_registry_repo_kfp_uri", type=str, required=True)
    parser.add_argument("--bq_training_data_uri", type=str, required=True)
    parser.add_argument("--existing_model", type=str, required=False)
    parser.add_argument("--machine_type", type=str, default="n1-standard-4")
    parser.add_argument(
        "--model_checkpoint_dir", type=str, required=False, default=None
    )
    parser.add_argument("--parent_model_resource_name", type=str, default=None)
    parser.add_argument("--persistent_resource_name", type=str, required=True)
    parser.add_argument("--pipeline_root", type=str, required=True)
    parser.add_argument("--prediction_container_image_uri", type=str, required=True)
    parser.add_argument("--production_endpoint_id", type=str, default=None)
    parser.add_argument("--project_id", type=str, required=True)
    parser.add_argument("--region", type=str, required=True)
    parser.add_argument("--runner_service_account_email", type=str, required=True)
    parser.add_argument("--tag", type=str, default=None)
    parser.add_argument("--tensorboard", type=str, default=None)
    parser.add_argument("--training_container_image_uri", type=str, required=True)

    args = parser.parse_args()
    logging.info(args)
    main(
        artifact_registry_repo_kfp_uri=args.artifact_registry_repo_kfp_uri,
        bq_training_data_uri=args.bq_training_data_uri,
        existing_model=args.existing_model,
        machine_type=args.machine_type,
        model_checkpoint_dir=args.model_checkpoint_dir,
        parent_model_resource_name=args.parent_model_resource_name,
        persistent_resource_name=args.persistent_resource_name,
        pipeline_root=args.pipeline_root,
        prediction_container_image_uri=args.prediction_container_image_uri,
        production_endpoint_id=args.production_endpoint_id,
        project_id=args.project_id,
        region=args.region,
        runner_service_account_email=args.runner_service_account_email,
        tag=args.tag,
        tensorboard=args.tensorboard,
        training_container_image_uri=args.training_container_image_uri,
    )
