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
import json
import logging
from cloudevents.http import CloudEvent
import functions_framework
from google.cloud import pubsub_v1, storage, bigquery
from datetime import datetime
import re

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment variables
PROJECT_ID = os.environ.get("PROJECT_ID")
BQ_DATASET = os.environ.get("BQ_DATASET")
TRIGGER_PIPELINE_PUBSUB_TOPIC = os.environ.get("TRIGGER_PIPELINE_PUBSUB_TOPIC")
TABLE_PREFIX = "uploaded_csv_"  # Prefix for BigQuery table names
RUNNER_SERVICE_ACCOUNT_EMAIL = os.environ.get("RUNNER_SERVICE_ACCOUNT_EMAIL")
ARTIFACT_REGISTRY_REPO_KFP_URI = os.environ.get("ARTIFACT_REGISTRY_REPO_KFP_URI")
PERSISTENT_RESOURCE_NAME = os.environ.get("PERSISTENT_RESOURCE_NAME")
TRAINING_CONTAINER_IMAGE_URI = os.environ.get("TRAINING_CONTAINER_IMAGE_URI")
PRODUCTION_ENDPOINT_ID = os.environ.get("PRODUCTION_ENDPOINT_ID")
PREDICTION_CONTAINER_IMAGE_URI = os.environ.get("PREDICTION_CONTAINER_IMAGE_URI")
PIPELINE_ROOT = os.environ.get("PIPELINE_ROOT")
TENSORBOARD = os.environ.get("TENSORBOARD")
REGION = os.environ.get("REGION", "us-central1")
MACHINE_TYPE = os.environ.get("MACHINE_TYPE", "n1-standard-4")
MODEL_CHECKPOINT_DIR = os.environ.get("MODEL_CHECKPOINT_DIR")


# Initialize clients
publisher = pubsub_v1.PublisherClient()
storage_client = storage.Client(project=PROJECT_ID)
bq_client = bigquery.Client(project=PROJECT_ID)


def upload_to_bigquery(bucket_name, file_name):
    """Uploads a CSV file from Cloud Storage to BigQuery."""
    logger.info(f"Starting BigQuery upload for gs://{bucket_name}/{file_name}")

    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file_name)
    uri = f"gs://{bucket_name}/{file_name}"  # Correct URI

    if not blob.exists():
        logger.error(f"File not found: {uri}")
        return None
    if not file_name.lower().endswith(".csv"):
        logger.error(f"Not a CSV file: {uri}")
        return None

    file_name_clean = re.sub(
        r"[^a-zA-Z0-9_]", "_", file_name[:-4]
    )  # Remove .csv and invalid chars

    table_name = f"{TABLE_PREFIX}{file_name_clean}"
    dataset_ref = bq_client.dataset(BQ_DATASET)
    table_ref = dataset_ref.table(table_name)

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        autodetect=True,
    )

    load_job = bq_client.load_table_from_uri(uri, table_ref, job_config=job_config)
    load_job.result()

    logger.info(f"Loaded {load_job.output_rows} rows to {table_ref.path}")
    return f"bq://{PROJECT_ID}.{BQ_DATASET}.{table_name}"  # Correct BigQuery URI


def trigger_pipeline(bq_table_uri):
    """Triggers the Vertex AI pipeline with the BigQuery table URI."""

    pipeline_root = f"{PIPELINE_ROOT}/pipeline_triggered_via_storage/{datetime.now().strftime('%Y%m%d%H%M%S')}"
    worker_pool_specs = [
        {
            "machine_spec": {"machine_type": MACHINE_TYPE},
            "replica_count": 1,
            "container_spec": {
                "image_uri": TRAINING_CONTAINER_IMAGE_URI,
                "command": ["python", "train.py"],
                "args": [
                    "--data_path",
                    bq_table_uri,
                    "--model_checkpoint_dir",
                    MODEL_CHECKPOINT_DIR,
                ],
            },
        }
    ]

    pipeline_parameters = {
        "project": PROJECT_ID,
        "location": REGION,
        "training_job_display_name": "training_job_display_name",
        "worker_pool_specs": worker_pool_specs,
        "pipeline_root": pipeline_root,
        "model_artifact_dir": f"{pipeline_root}/model",  # Ensure leading slash
        "production_endpoint_id": PRODUCTION_ENDPOINT_ID,
        "prediction_container_image_uri": PREDICTION_CONTAINER_IMAGE_URI,
        "service_account": RUNNER_SERVICE_ACCOUNT_EMAIL,
        "persistent_resource_id": (
            PERSISTENT_RESOURCE_NAME.split("/")[-1]
            if PERSISTENT_RESOURCE_NAME
            else None
        ),
        "tensorboard": TENSORBOARD,
        "existing_model": None,
        "parent_model_resource_name": None,
        "bq_training_data_uri": bq_table_uri,
    }

    request_data = {
        "project_id": PROJECT_ID,
        "location": REGION,
        "pipeline_root": pipeline_root,
        "pipeline_parameters": pipeline_parameters,
        "persistent_resource_name": PERSISTENT_RESOURCE_NAME,
        "pipeline_template_path": ARTIFACT_REGISTRY_REPO_KFP_URI,
        "service_account": RUNNER_SERVICE_ACCOUNT_EMAIL,
        "enable_caching": False,
    }

    message_json = json.dumps(request_data)
    future = publisher.publish(
        TRIGGER_PIPELINE_PUBSUB_TOPIC, message_json.encode("utf-8")
    )
    print(f"Published message ID: {future.result()} to {TRIGGER_PIPELINE_PUBSUB_TOPIC}")


@functions_framework.cloud_event
def main(cloud_event: CloudEvent) -> str:

    data = cloud_event.data
    bucket_name = data.get("bucket")
    file_name = data.get("name")

    bq_table_uri = upload_to_bigquery(bucket_name, file_name)

    if bq_table_uri:
        trigger_pipeline(bq_table_uri)
        return "Success!"
    else:
        return "Failed: Not a CSV file or file not found."


def test_main():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--bucket", type=str, required=True)
    parser.add_argument("--file", type=str, required=True)

    # PIPELINE PARAMS
    args = parser.parse_args()

    bucket = args.bucket
    file = args.file
    cloud_event = {
        "attributes": {
            "specversion": "1.0",
            "id": "12362828986129261",
            "source": f"//storage.googleapis.com/projects/_/buckets/{bucket}",
            "type": "google.cloud.storage.object.v1.finalized",
            "datacontenttype": "application/json",
            "subject": "objects/outputs.tf",
            "time": "2024-09-25T16:16:39.150127Z",
            "bucket": bucket,
        },
        "data": {
            "kind": "storage#object",
            "id": f"{bucket}/{file}/1727280999136435",
            "selfLink": f"https://www.googleapis.com/storage/v1/b/{bucket}/o/{file}",
            "name": file,
            "bucket": bucket,
            "generation": "1727280999136435",
            "metageneration": "1",
            "contentType": "application/octet-stream",
            "timeCreated": "2024-09-25T16:16:39.150Z",
            "updated": "2024-09-25T16:16:39.150Z",
            "storageClass": "STANDARD",
            "timeStorageClassUpdated": "2024-09-25T16:16:39.150Z",
            "size": "1103",
            "md5Hash": "aousP70aNPd/adKgC1OWJw==",
            "mediaLink": f"https://storage.googleapis.com/download/storage/v1/b/{bucket}/o/{file}?generation=1727280999136435&alt=media",
            "contentLanguage": "en",
            "crc32c": "HNzGSg==",
            "etag": "CLP5hZO/3ogDEAE=",
        },
    }

    cloud_event = CloudEvent(cloud_event["attributes"], cloud_event["data"])

    # Call the main function with the mock event
    result = main(cloud_event)

    # Verify the result
    assert result == "Success!"


if __name__ == "__main__":
    test_main()
