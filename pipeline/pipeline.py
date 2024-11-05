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

from kfp import dsl
from kfp.dsl import importer
from kfp.dsl import OneOf
from google_cloud_pipeline_components.v1.custom_job import CustomTrainingJobOp
from google_cloud_pipeline_components.types import artifact_types
from google_cloud_pipeline_components.v1.model import ModelUploadOp
from google_cloud_pipeline_components.v1.endpoint import ModelDeployOp
from google_cloud_pipeline_components.v1.dataset import TabularDatasetCreateOp

from custom_components import (
    model_evaluation,
    deploy_to_endpoint,
    validate_infrastructure,
)


# define the train-deploy pipeline
@dsl.pipeline(name="continuous-model-training-deployment")
def continous_model_training_deployment_pipeline(
    project: str,
    location: str,
    bq_training_data_uri: str,
    model_artifact_dir: str,
    persistent_resource_id: str,
    pipeline_root: str,
    prediction_container_image_uri: str,
    service_account: str,
    training_job_display_name: str,
    worker_pool_specs: list,
    existing_model: bool = False,
    parent_model_resource_name: str = None,
    production_endpoint_id: str = None,
    tensorboard: str = None,
):

    dataset_op = TabularDatasetCreateOp(
        display_name="pipeline_dataset",
        bq_source=bq_training_data_uri,
    ).set_caching_options(False)

    custom_job_task = CustomTrainingJobOp(
        project=project,
        display_name=training_job_display_name,
        worker_pool_specs=worker_pool_specs,
        base_output_directory=pipeline_root,
        location=location,
        persistent_resource_id=persistent_resource_id,
        service_account=service_account,
        tensorboard=tensorboard,
    ).after(dataset_op)
    custom_job_task.set_caching_options(False)

    # Import the unmanaged model
    import_unmanaged_model_task = importer(
        artifact_uri=model_artifact_dir,
        artifact_class=artifact_types.UnmanagedContainerModel,
        metadata={
            "containerSpec": {
                "imageUri": prediction_container_image_uri,
            },
            "displayName": "Import model",
        },
    ).after(custom_job_task)
    import_unmanaged_model_task.set_caching_options(False)

    with dsl.If(existing_model == True, "Import existing model"):
        # Import the parent model to upload as a version
        import_registry_model_task = importer(
            artifact_uri=parent_model_resource_name,
            artifact_class=artifact_types.VertexModel,
            metadata={"resourceName": parent_model_resource_name},
        ).after(import_unmanaged_model_task)
        # Upload the model as a version
        model_version_upload_op = ModelUploadOp(
            project=project,
            location=location,
            display_name="pipeline_model",
            parent_model=import_registry_model_task.outputs["artifact"],
            unmanaged_container_model=import_unmanaged_model_task.outputs["artifact"],
            version_aliases=["default"],
        ).set_caching_options(False)

    with dsl.Else("Create new model"):
        # Upload the model
        model_upload_op = ModelUploadOp(
            project=project,
            location=location,
            display_name="pipeline_model",
            unmanaged_container_model=import_unmanaged_model_task.outputs["artifact"],
        ).set_caching_options(False)

    # Get the model (or model version)
    model_resource = OneOf(
        model_version_upload_op.outputs["model"], model_upload_op.outputs["model"]
    )

    model_evaluation_task = model_evaluation.model_evaluation(
        project=project,
        model_dir=model_artifact_dir,
    ).set_caching_options(False)
    model_evaluation_task.set_caching_options(False).after(custom_job_task)
    model_evaluation_result = model_evaluation_task.outputs["deploy_decision"]

    with dsl.If(model_evaluation_result == True or True, "Deploy model"):
        import_endpoint_task = importer(
            artifact_uri=production_endpoint_id,
            artifact_class=artifact_types.VertexEndpoint,
            metadata={"resourceName": production_endpoint_id},
        )  # .after(import_unmanaged_model_task)
        model_deploy_task = ModelDeployOp(
            endpoint=import_endpoint_task.outputs["artifact"],
            model=model_resource,
            deployed_model_display_name="pipeline-model",
            dedicated_resources_machine_type="n1-standard-4",
            dedicated_resources_min_replica_count=1,
            dedicated_resources_max_replica_count=1,
            enable_access_logging=True,
            service_account=service_account,
            traffic_split={"0": 100},
        ).set_caching_options(False)
        deploy_to_endpoint.deploy_to_endpoint(
            endpoint_id=production_endpoint_id,
            model_dir=pipeline_root,
        ).set_caching_options(False)

        validate_infrastructure.validate_infra(
            project=project, endpoint_id=production_endpoint_id, location=location
        ).after(model_deploy_task).set_caching_options(False)

    return
