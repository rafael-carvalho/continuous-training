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

import os
from kfp import compiler

from typing import Callable, Dict, Any, Optional, List
import json
import os
import tempfile
import pipeline


# Compile a pipeline function to a pipeline package.


def compile_pipeline(
    pipeline_func: Callable,
    pipeline_name: str,
    filename: str,
    pipeline_params: Optional[Dict[str, Any]] = None,
):
    """
    Compile a pipeline function to a pipeline package.

    args:
        pipeline_func: The pipeline function to compile.
        pipeline_name:  pipeline name to pass to the pipeline function.
        filename: The name of the pipeline package to generate.
        pipeline_params: Optional pipeline parameters to pass to the pipeline function.

    returns:
        The path to the compiled pipeline package.

    """
    tmp_dir = tempfile.gettempdir()
    package_path = os.path.join(tmp_dir, filename)
    if pipeline_params:
        pipeline_params = {k: v for k, v in pipeline_params.items() if v is not None}
        print("Will use following pipeline params to compile the pipeline")
        print(json.dumps(pipeline_params, indent=2))
    else:
        pipeline_params = {}

    compiler.Compiler().compile(
        pipeline_func=pipeline_func,
        pipeline_name=pipeline_name,
        package_path=package_path,
        pipeline_parameters=pipeline_params,
    )

    print(f"Pipeline compiled to {package_path}")
    return package_path


def edit_template(local_file_path: str):

    # convert yaml to a in-memory object for API call

    import yaml

    with open(local_file_path, "r") as stream:
        try:
            pipeline_spec = yaml.safe_load(stream)

        except yaml.YAMLError as exc:
            print(exc)
    print(pipeline_spec)


def main(
    parameters: Optional[Dict[str, Any]] = None,
    pipeline_name="pipeline",
    filename="pipeline.yaml",
):
    return compile_pipeline(
        pipeline_func=pipeline.continous_model_training_deployment_pipeline,
        pipeline_name=pipeline_name,
        filename=filename,
        pipeline_params=parameters,
    )
