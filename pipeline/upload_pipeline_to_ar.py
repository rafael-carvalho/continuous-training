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
from kfp.registry import RegistryClient
from typing import List


def upload_to_artifact_registry(
    local_pipeline_file, kfp_ar_image_uri, tags: List[str] = ["latest"]
):
    """
    Upload a pipeline package to Artifact Registry.
    args:
        local_pipeline_file: The path to the pipeline package to upload.
        kfp_ar_image_uri: The URI of the Artifact Registry to upload to.
        tags: A list of tags to apply to the uploaded pipeline package.

    returns:
        The URI of the uploaded pipeline package.
    """
    client = RegistryClient(host=f"https://{kfp_ar_image_uri}")
    template_name, version_name = client.upload_pipeline(
        file_name=local_pipeline_file,
        tags=tags,
        extra_headers={"description": "Continuous Training Pipeline Template"},
    )

    print(f"KFP Template name: {template_name}")
    print(f"KFP Version name: {version_name}")
    print(f"KFP Template {template_name} uploaded to AR {kfp_ar_image_uri}")

    # print the template with the tags
    uri = f"https://{kfp_ar_image_uri}/{template_name}/{version_name}"
    print(f"Template URI: {uri}")
    for tag in tags:
        print(f"https://{kfp_ar_image_uri}/{template_name}/{tag}")
