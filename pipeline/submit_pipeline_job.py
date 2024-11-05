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

from google.cloud import aiplatform as vertex
from google.auth import default
from google.auth.transport.requests import AuthorizedSession
import yaml
import json


def submit_pipeline_job_with_persistent_resource(
    project_id,
    location,
    pipeline_parameters,
    persistent_resource_name,
    pipeline_template_path,
    service_account,
    pipeline_root: str,
    enable_caching: bool = False,
):

    vertex.init(project=project_id, location=location, staging_bucket=pipeline_root)
    display_name = "pipeline"
    print(
        f"Creating Pipeline Job with display_name={display_name} and the following params"
    )
    print(json.dumps(pipeline_parameters, indent=2))

    pipeline_job = vertex.PipelineJob(
        display_name=display_name,
        parameter_values=pipeline_parameters,
        enable_caching=enable_caching,
        template_path=pipeline_template_path,
        pipeline_root=pipeline_root,
    )

    endpoint, headers, pipeline_spec = form_request(
        project_id=project_id,
        location=location,
        persistent_resource_name=persistent_resource_name,
        service_account=service_account,
        pipeline_job=pipeline_job,
    )

    # Get default credentials (may require authentication)
    credentials, project_id = default()

    # Create a session with authorized credentials
    session = AuthorizedSession(credentials)
    # Make the POST request to create the job

    print("Will submit the request")
    response = session.post(endpoint, headers=headers, data=json.dumps(pipeline_spec))

    # json.dumps(response.json(), indent=2)
    response_json = response.json()

    return response_json.get("name")


def form_request(
    project_id,
    location,
    pipeline_job,
    service_account,
    persistent_resource_name: str,
):
    # API Reference https://cloud.google.com/vertex-ai/docs/reference/rest/v1/projects.locations.pipelineJobs/create
    endpoint = f"https://{location}-aiplatform.googleapis.com/v1beta1/projects/{project_id}/locations/{location}/pipelineJobs"

    headers = {"Content-Type": "application/json"}

    pipeline_spec = pipeline_job.to_dict()
    pipeline_spec["serviceAccount"] = service_account
    pipeline_spec["runtimeConfig"]["defaultRuntime"] = {
        "persistentResourceRuntimeDetail": {
            "persistentResourceName": persistent_resource_name
        }
    }
    # print(json.dumps(pipeline_spec, indent=2))

    # Make the POST request to create the job
    return endpoint, headers, pipeline_spec
