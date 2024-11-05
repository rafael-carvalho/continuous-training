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


from kfp.dsl import container_component, ContainerSpec, component
from kfp.dsl import Output, Metrics
from typing import NamedTuple
from typing import List


@component(
    base_image="python:3.11-slim",
    packages_to_install=["google-cloud-aiplatform", "scikit-learn", "pandas", "numpy"],
)
def validate_infra(
    project: str, endpoint_id: str, location: str = "us-central1"
) -> bool:

    def prepare_iris_data(num_instances=6):
        from sklearn.datasets import load_iris
        import pandas as pd
        import numpy as np

        """Loads and preprocesses Iris data for prediction."""
        iris = load_iris()
        iris_df = pd.DataFrame(
            data=np.c_[iris["data"], iris["target"]],
            columns=iris["feature_names"] + ["target"],
        )
        iris_df = iris_df.dropna()
        X = iris_df.drop("target", axis=1)
        return X.values[:num_instances].tolist()

    from google.cloud import aiplatform
    from google.protobuf import json_format
    from google.protobuf.struct_pb2 import Value
    from collections import namedtuple
    import json

    instances_list = prepare_iris_data()
    instances = {"instances": instances_list}
    instance_json = json.dumps(instances)
    print("Will use the following instance: " + instance_json)
    aiplatform.init(project=project, location=location)
    endpoint = aiplatform.Endpoint(endpoint_id)
    response = endpoint.predict(instances=instances_list)

    print(f"Response: {response}")

    # Basic validation - check if the response contains predictions
    if response.predictions:
        print("Prediction successful")
        return True
    else:
        print("Prediction failed. Empty response.")
        return False


if __name__ == "__main__":
    from kfp import local

    # local.init(runner=local.DockerRunner(), pipeline_root="/tmp/pipeline_outputs")
    local.init(runner=local.SubprocessRunner(), pipeline_root="/tmp/pipeline_outputs")
    project_id = f"your-project-id"
    endpoint_id = f"projects/{project_id}/locations/us-central1/endpoints/production"
    validate_infra(project=project_id, endpoint_id=endpoint_id)
