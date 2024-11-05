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
from kfp.dsl import Input
from google_cloud_pipeline_components.types.artifact_types import VertexModel


@component(
    base_image="python:3.11-slim",
    # packages_to_install=["google-cloud-aiplatform", "google-cloud-bigquery"],
)
def deploy_to_endpoint(
    endpoint_id: str,
    model_dir: str,
):
    print("Will use following pipeline params to compile the pipeline")
    print(f"endpoint_id: {endpoint_id}")
    print(f"model_dir: {model_dir}")

    return
