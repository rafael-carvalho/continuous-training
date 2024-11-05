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

import submit_pipeline_job
import functions_framework
import json
import base64


@functions_framework.cloud_event
def main(cloud_event, test_json=None):
    try:
        if not test_json:
            print(f"Received message: {cloud_event}")
            decoded_message = base64.b64decode(
                cloud_event.data["message"]["data"]
            ).decode()
            print(f"Decoded message: {decoded_message}")
            request_data = json.loads(
                decoded_message
            )  # Decode from bytes to string then parse JSON
            print(f"Decoded json: {json.dumps(request_data)}")
        else:
            request_data = test_json

        # Access parameters directly from request_data
        project_id = request_data.get("project_id")
        location = request_data.get("location")
        pipeline_root = request_data.get("pipeline_root")
        pipeline_parameters = request_data.get("pipeline_parameters")
        persistent_resource_name = request_data.get("persistent_resource_name")
        pipeline_template_path = request_data.get("pipeline_template_path")
        service_account = request_data.get("service_account")
        enable_caching = request_data.get("enable_caching", False)

        # Verify required parameters (Keep this check)
        if not all(
            [
                project_id,
                location,
                pipeline_root,
                pipeline_parameters,
                pipeline_template_path,
                service_account,
            ]
        ):
            raise ValueError("Missing required parameters in Pub/Sub message.")

        # Submit the pipeline job (Assuming submit_pipeline_job is defined elsewhere)

        submit_pipeline_job.submit_pipeline_job_with_persistent_resource(
            project_id=project_id,
            location=location,
            pipeline_root=pipeline_root,
            pipeline_parameters=pipeline_parameters,
            pipeline_template_path=pipeline_template_path,
            service_account=service_account,
            enable_caching=enable_caching,
            persistent_resource_name=persistent_resource_name,
        )
        return (
            f"Pipeline job submitted successfully",
            200,
        )

    except (ValueError, Exception) as e:  # Catch broader exceptions
        print(f"Error submitting pipeline: {e}")
        # print stacktrace
        import traceback

        traceback.print_exc()
        return (
            f"Error submitting pipeline: {e}",
            500,
        )  # Return error and appropriate status code
