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
import nbformat
from nbformat.v4 import new_notebook, new_code_cell, new_markdown_cell
import os
import logging
import argparse
from google.cloud import storage
import tempfile

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)


def log_environment_variables():
    """Logs environment variables."""
    logging.info("Environment Variables:")
    for key, value in sorted(os.environ.items()):
        logging.info(f"{key}: {value}")


def create_variables_cell(
    variables: dict, variables_to_skip=[], variables_to_add={}
) -> str:
    """Creates the content for the variables cell."""
    variable_assignments = []

    # Combine and sort variables
    all_variables = dict(sorted(variables.items()))
    all_variables.update(variables_to_add)  # Add additional variables

    for k, v in all_variables.items():
        if k in variables_to_skip:
            continue

        if v is None:
            value_str = "None"
        elif isinstance(v, bool):  # Check for boolean type
            value_str = str(v)
        elif isinstance(v, (int, float)):  # Check for numeric types
            value_str = str(v)
        elif isinstance(v, str) and (v.isnumeric() or v in ["True", "False"]):
            value_str = v  # Keep numeric strings and boolean strings as they are
        elif isinstance(v, str):  # Quote other strings
            value_str = f'"{v}"'
        else:
            value_str = repr(v)  # Use repr for other data types

        variable_assignments.append(f"{k.upper()} = {value_str}")

    return "# @title Set the variables\n" + "\n".join(variable_assignments)


def modify_notebook(nb: nbformat.NotebookNode, mappings: list):
    """Modifies the notebook according to the provided mappings."""
    for mapping in mappings:
        for cell in nb.cells:
            if mapping["cell_marker"] in cell.source:
                if mapping["action"] == "append":
                    new_cell = (
                        new_code_cell
                        if mapping["type"] == "code"
                        else new_markdown_cell
                    )(mapping["value"])
                    nb.cells.insert(nb.cells.index(cell) + 1, new_cell)
                    logging.info(
                        f"Appended content after marker: {mapping['cell_marker']}"
                    )
                elif mapping["action"] == "replace":
                    cell.source = mapping["value"]
                    logging.info(
                        f"Replaced content for marker: {mapping['cell_marker']}"
                    )
                break  # Exit inner loop after processing the marker


def remove_cell_ids(nb: nbformat.NotebookNode):
    """Removes cell IDs from the notebook, if present."""  # More robust handling of nbformat versions
    if nb.nbformat == 4:  # Only remove if nbformat is 4
        for cell in nb.cells:
            if "id" in cell:
                del cell["id"]


def save_notebook(nb: nbformat.NotebookNode, local_path: str):
    """Saves the modified notebook to a local file."""
    with open(local_path, "w") as f:
        nbformat.write(nb, f)
    logging.info(f"Saved modified notebook to: {local_path}")


def upload_to_gcs(local_path: str, gcs_uri: str):
    """Uploads the local file to GCS."""
    try:
        bucket_name, blob_name = gcs_uri.replace("gs://", "").split("/", 1)
        storage_client = storage.Client()
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(blob_name)
        blob.upload_from_filename(local_path)
        logging.info(f"Uploaded notebook to: {gcs_uri}")
    except Exception as e:
        logging.exception(f"Error uploading to GCS: {e}")


def main(notebook_template_path: str, args):  # Correctly pass args
    """Main function to orchestrate notebook modification and upload."""

    variables_to_skip = ["tag"]
    variables_to_add = {
        "existing_model": False,
        "parent_model_resource_name": None,
    }  # Dictionary format

    variables = vars(args)  # Convert args to a dictionary

    variables_cell_content = create_variables_cell(
        variables,
        variables_to_skip=variables_to_skip,
        variables_to_add=variables_to_add,
    )

    mappings = [
        {
            "cell_marker": "@title Set the variables",
            "value": variables_cell_content,
            "action": "replace",  # Changed to replace to avoid multiple variable definitions
            "type": "code",
        }
    ]

    try:
        with open(notebook_template_path, "r") as f:
            nb = nbformat.read(f, as_version=4)

        modify_notebook(nb, mappings)
        remove_cell_ids(nb)

        local_destination_path = tempfile.NamedTemporaryFile(
            delete=False, suffix=".ipynb"
        ).name
        save_notebook(nb, local_destination_path)

        upload_to_gcs(
            local_destination_path, args.notebook_gcs_uri
        )  # Use args.notebook_gcs_uri

    except FileNotFoundError:
        logging.error(f"Template notebook not found at: {notebook_template_path}")
    except Exception as e:
        logging.exception(f"An unexpected error occurred: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--notebook_gcs_uri", type=str, required=True)
    parser.add_argument("--bucket", type=str, required=True)
    parser.add_argument("--project_number", type=str, required=True)
    parser.add_argument("--gcs_sample_training_data_uri", type=str, required=True)
    parser.add_argument("--trigger_bucket", type=str, required=True)

    # PIPELINE PARAMS
    parser.add_argument("--pipeline_template_path", type=str, required=True)
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
    parser.add_argument("--tag", type=str, required=False, default=None)
    parser.add_argument("--tensorboard", type=str, default=None)
    parser.add_argument("--training_container_image_uri", type=str, required=True)

    args = parser.parse_args()

    notebook_template_path = (
        "continuous_training_template.ipynb"  # Make sure this path is correct
    )

    print(args)

    main(notebook_template_path, args)  # Pass args to main
