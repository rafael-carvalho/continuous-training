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
import nbformat
from nbconvert.preprocessors import ExecutePreprocessor
from google.cloud import storage
import os
import sys
from typing import Tuple


def execute_notebook(filepath: str, project_id: str) -> None:
    """
    Executes a Jupyter Notebook and raises any exceptions encountered during execution.

    Args:
        filepath: The path to the Jupyter Notebook file. Can be a local file path or a GCS URI.
        project_id: Google Cloud Project ID for GCS access.

    Raises:
        Exception: Any exception raised during notebook execution.
    """

    # Download the notebook from GCS if necessary
    if filepath.startswith("gs://"):
        local_filepath, _ = download_from_gcs(filepath, project_id)
    else:
        local_filepath = filepath

    # Check if local file exists
    if not os.path.exists(local_filepath):
        raise FileNotFoundError(f"Notebook file not found: {local_filepath}")

    with open(local_filepath, encoding="utf-8") as f:
        nb = nbformat.read(f, as_version=4)

    ep = ExecutePreprocessor(
        timeout=600, kernel_name="python3"
    )  # Set timeout as needed

    try:
        ep.preprocess(
            nb, {"metadata": {"path": os.path.dirname(local_filepath)}}
        )  # Use the notebook directory as the working dir
        print("Notebook executed successfully.")
        sys.exit(0)  # Exit with success code

    except Exception as e:
        print(f"Notebook execution failed: {e}")
        raise  # Re-raise the original exception


def download_from_gcs(gcs_uri: str, project_id: str) -> Tuple[str, str]:
    """Downloads a file from Google Cloud Storage to a temporary local file.

    Args:
        gcs_uri: The GCS URI of the file to download.
        project_id: The Google Cloud Project ID.

    Returns:
        A tuple containing the local filepath and the original filename.

    Raises:
        google.cloud.exceptions.NotFound: If the GCS object doesn't exist.
    """
    try:
        storage_client = storage.Client(project=project_id)
        bucket_name, blob_name = gcs_uri[5:].split(
            "/", 1
        )  # Split the URI into bucket and blob name
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(blob_name)

        filename = os.path.basename(blob_name)
        local_filepath = os.path.join("/tmp", filename)  # Download to /tmp

        blob.download_to_filename(local_filepath)  # Downloads to local storage.

        print(f"Downloaded {gcs_uri} to {local_filepath}")
        return local_filepath, filename

    except Exception as e:  # Catch broader exceptions during download
        print(f"Error downloading from GCS: {e}")
        raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Execute a Jupyter Notebook.")
    parser.add_argument("--notebook_gcs_uri", type=str, required=True)
    parser.add_argument("--project_id", type=str, required=True)

    args = parser.parse_args()
    print(args)
    try:
        execute_notebook(args.notebook_gcs_uri, args.project_id)
    except Exception as e:
        sys.exit(1)  # Exit with error code
