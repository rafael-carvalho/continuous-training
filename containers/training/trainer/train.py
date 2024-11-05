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
import os
import pandas as pd
import numpy as np
import xgboost as xgb
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
from typing import Tuple, Dict, Any
import json
import datetime
from tensorboardX import SummaryWriter
import tempfile
import os
from google.cloud import bigquery


# https://github.com/dmlc/xgboost/issues/5727
class TensorBoardCallback(xgb.callback.TrainingCallback):
    def __init__(self, experiment: str = "xgboost_experiment"):  # Default name
        self.experiment = experiment
        self.log_dir = f"runs/{self.experiment}"  # Simpler path
        self.writer = SummaryWriter(log_dir=self.log_dir)  # Single writer

    def after_iteration(
        self, model, epoch: int, evals_log: xgb.callback.TrainingCallback.EvalsLog
    ) -> bool:
        if not evals_log:
            return False

        for data, metric in evals_log.items():
            for metric_name, log in metric.items():
                score = log[-1][0] if isinstance(log[-1], tuple) else log[-1]
                self.writer.add_scalar(
                    f"{data}/{metric_name}", score, epoch
                )  # combined data/metric name
        return False


print("*" * 80)
print("INSIDE train.py")
print("*" * 80)


def print_environment_variables() -> None:
    """Prints environment variables in alphabetical order."""

    print("Environment Variables:")
    output = ""
    for key, value in sorted(os.environ.items()):
        output += f"  {key}: {value}\n"
    print(output)


def load_data(data_path: str) -> pd.DataFrame:
    """Loads data from a CSV file."""
    try:
        df = pd.read_csv(data_path)
        print(f"Data loaded from {data_path} successfully. Shape: {df.shape}")
        return df
    except FileNotFoundError:
        print(f"File not found: {data_path}")
        exit(1)  # Exit with error code 1
    except Exception as e:
        print(f"Error loading data: {e}")
        exit(1)


def preprocess_data(df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.Series]:
    """Preprocesses the data."""

    # Sample preprocessing (replace with your actual preprocessing steps)
    df = df.dropna()  # Remove rows with NaN

    # Example: For Iris dataset
    X = df.drop("target", axis=1)  # Features
    y = df["target"]  # Labels

    print("Data preprocessed successfully.")
    return X, y


def create_model_architecture(
    params: Dict[str, Any]
) -> xgb.XGBClassifier:  # Or xgb.XGBRegressor
    """Creates the XGBoost model architecture."""
    model = xgb.XGBClassifier(**params)
    print("XGBoost model architecture created.")
    return model


def train_model(
    model: xgb.XGBClassifier, X_train: pd.DataFrame, y_train: pd.Series
) -> xgb.XGBClassifier:
    """Trains the XGBoost model."""
    model.fit(
        X_train,
        y_train,
        # eval_metric="mlogloss",  # Specify the metric for monitoring
        callbacks=[TensorBoardCallback(experiment="exp_1")],  # Use simplified callback
    )

    print("XGBoost model trained successfully.")
    return model


def evaluate_model(
    model: xgb.XGBClassifier, X_test: pd.DataFrame, y_test: pd.Series
) -> float:  # Or other suitable metric
    """Evaluates the trained model."""
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)  # Example metric, change as needed
    print(f"Model evaluation complete. Accuracy: {accuracy}")
    return accuracy


def save_model_artifacts(
    model: xgb.XGBClassifier, model_dir: str, accuracy: float, tensorboard_log_dir=None
) -> None:
    """Saves the trained model and other artifacts."""

    # GCSFuse conversion
    gs_prefix = "gs://"
    gcsfuse_prefix = "/gcs/"
    if model_dir.startswith(gs_prefix):
        model_dir = model_dir.replace(gs_prefix, gcsfuse_prefix)

    # Ensure directory exists, even if nested
    os.makedirs(model_dir, exist_ok=True)

    # Export the classifier to a file
    gcs_model_path = os.path.join(model_dir, "model.bst")
    print("Saving model artifacts to {}".format(gcs_model_path))
    model.save_model(gcs_model_path)

    print("Saving metrics to {}/metrics.json".format(model_dir))
    gcs_metrics_path = os.path.join(model_dir, "metrics.json")
    metrics_dict = {"accuracy": accuracy}
    if tensorboard_log_dir:
        tensorboard_writer = SummaryWriter(log_dir=tensorboard_log_dir)

        tensorboard_writer.add_scalar("accuracy", accuracy)
    with open(gcs_metrics_path, "w") as f:
        json.dump(metrics_dict, f)

    """
    
    from google.cloud.aiplatform.constants.prediction import MODEL_FILENAME_JOBLIB
    import os
    import joblib

    print(f"Saving model to {model_dir}")

    if model_dir.startswith("gs://"):
        print(f"[GCS] Uploading model to {model_dir}")
        from google.cloud import storage

        client = (
            storage.Client()
        )  # No need to specify project_id explicitly if running on Vertex AI
        bucket_name, prefix = model_dir.replace("gs://", "").split("/", 1)
        bucket = client.bucket(bucket_name)  # Use client.bucket()
        print(f"Bucket: {bucket}")
        print(f"Prefix: {prefix}")
        # Correct blob path by adding the file name
        blob = bucket.blob(prefix + MODEL_FILENAME_JOBLIB)
        print(f"Joblib dump started")
        joblib.dump(model, MODEL_FILENAME_JOBLIB)
        print(f"Joblib dump finished")
        print(f"Blob upload started from {MODEL_FILENAME_JOBLIB}")
        blob.upload_from_filename(
            MODEL_FILENAME_JOBLIB
        )  # Upload after defining the correct blob path.
        print(f"[GCS] Model uploaded to {blob.public_url}")

    else:  # Save locally
        print(f"[Local] Saving model to {model_dir}")
        local_path = os.path.join(model_dir, MODEL_FILENAME_JOBLIB)
        joblib.dump(model, local_path)
        print(f"Model saved to {local_path} using joblib.")
    """


def check_file_exists_gcsfuse(gcs_uri: str, file_name: str) -> bool:
    """Checks if a file exists in GCS using GCSFuse.

    Args:
        gcs_uri (str): The GCS URI of the directory (e.g., 'gs://bucket-name/path/to/dir').
        file_name (str): The name of the file to check.

    Returns:
        bool: True if the file exists, False otherwise.
    """

    gcsfuse_path = gcs_uri.replace("gs://", "/gcs/")
    full_path = os.path.join(gcsfuse_path, file_name)
    print(f"Checking if {full_path} exists...")
    return os.path.exists(full_path)


def run_loop(**kwargs):
    print_environment_variables()
    args = argparse.Namespace(**kwargs)
    print("####################################")
    print("Starting XGBoost training...")

    # ... (print all variables - now after args are parsed)
    print("Input Arguments:")
    for arg, value in vars(args).items():
        print(f"  {arg}: {value}")

    # Load and preprocess data
    df = load_data(args.data_path)
    X, y = preprocess_data(df)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )  # Split data

    if args.model_checkpoint_dir and check_file_exists_gcsfuse(
        args.model_checkpoint_dir, "model.bst"
    ):
        model = load_model_checkpoint(
            os.path.join(args.model_checkpoint_dir, "model.bst")
        )  # pass checkpoint location
        print("Checkpoint loaded successfully.")
    else:
        print("Random Initializing of model")
        params = {  # Example, replace with your desired hyperparameters
            "n_estimators": args.n_estimators,
            "max_depth": args.max_depth,
            "objective": "multi:softmax",  # "binary:logistic" for binary classification
            "num_class": len(y.unique()),  # Update based on your number of classes
            "eval_metric": "mlogloss",
            # "use_label_encoder": False,  # if necessary set to True
        }

        # Create the model
        model = create_model_architecture(params)

    # Train, and evaluate model
    model = train_model(model, X_train, y_train)
    accuracy = evaluate_model(model, X_test, y_test)

    # Save the model artifacts

    save_model_artifacts(
        model, args.model_dir, accuracy, tensorboard_log_dir=args.tensorboard
    )

    print("XGBoost training completed successfully.")

    save_model_checkpoint(model, args.model_checkpoint_dir)


import pandas as pd
from google.cloud import bigquery


import tempfile
import os
from google.cloud import bigquery


def load_data_from_bq(bq_uri: str) -> str:
    """Loads data from the bq_uri to a local csv file"""

    print(f"Starting data load from: {bq_uri}")

    try:
        print("Attempting to parse URI with project ID...")
        project_id, dataset_name, table_name = bq_uri.replace("bq://", "").split(".")
        table_ref = f"{project_id}.{dataset_name}.{table_name}"
    except ValueError:
        print(
            "URI parsing with project ID failed. Trying without project ID..."
        )  # More specific log
        dataset_name, table_name = bq_uri.replace("bq://", "").split(".")
        project_id = os.environ.get("CLOUD_ML_PROJECT_ID")  # or another method
        if project_id is None:
            raise ValueError(
                "Project ID must be provided in the URI or environment variable."
            )
        table_ref = f"{project_id}.{dataset_name}.{table_name}"

    print(f"Parsed table reference: {table_ref}")

    try:
        bq_client = bigquery.Client(project=project_id)
        print(f"BigQuery client initialized with project ID: {project_id}")
    except Exception as e:
        print(f"Error initializing BigQuery client: {e}")
        raise  # Re-raise the exception after logging

    sql = f"SELECT * FROM `{table_ref}`"
    print(f"SQL query: {sql}")

    try:
        df = bq_client.query(sql).to_dataframe()
        print(f"Data fetched from BigQuery. Number of rows: {len(df)}")
    except Exception as e:
        print(f"Error querying BigQuery: {e}")
        raise

    temp_file_path = tempfile.NamedTemporaryFile(delete=False, suffix=".csv").name
    print(f"Saving data to temporary file: {temp_file_path}")

    try:
        df.to_csv(temp_file_path, index=False)
        print("Data successfully saved to CSV.")
    except Exception as e:
        print(f"Error saving data to CSV: {e}")
        raise

    return temp_file_path


def save_model_checkpoint(
    model: xgb.XGBClassifier, checkpoint_dir: str = None, epoch: int = None
):
    """Saves a checkpoint of the model if checkpoint_dir is provided.

    Args:
        model (xgb.XGBClassifier): The XGBoost model to save.
        epoch (int, optional): The current epoch number (for filename).
        checkpoint_dir (str, optional): Directory to save checkpoints.
                                        If None, no checkpoint is saved.
    """
    # GCSFuse conversion
    gs_prefix = "gs://"
    gcsfuse_prefix = "/gcs/"
    if checkpoint_dir:
        if checkpoint_dir.startswith(gs_prefix):
            checkpoint_dir = checkpoint_dir.replace(gs_prefix, gcsfuse_prefix)

        if checkpoint_dir:
            os.makedirs(checkpoint_dir, exist_ok=True)
            if epoch is not None:
                checkpoint_path = os.path.join(checkpoint_dir, f"model_{epoch}.bst")
            else:
                checkpoint_path = os.path.join(checkpoint_dir, "model.bst")
            model.save_model(checkpoint_path)
            print(f"Checkpoint saved to {checkpoint_path}")
    else:
        print("No checkpoint directory provided, not saving checkpoint.")


def load_model_checkpoint(model_checkpoint_path: None) -> xgb.XGBClassifier:

    # GCSFuse conversion
    gs_prefix = "gs://"
    gcsfuse_prefix = "/gcs/"
    if model_checkpoint_path.startswith(gs_prefix):
        model_checkpoint_path = model_checkpoint_path.replace(gs_prefix, gcsfuse_prefix)

    print(f"Loading model checkpoint from {model_checkpoint_path}")
    model = xgb.XGBClassifier()  # Initialize model before loading
    model.load_model(model_checkpoint_path)
    return model


def main():
    """Main function."""

    parser = argparse.ArgumentParser(description="Train an XGBoost model.")
    parser.add_argument(
        "--data_path",
        type=str,
        required=False,
        help="Path to the input data file (CSV).",
    )
    parser.add_argument(
        "--model_dir",
        type=str,
        default=os.environ.get("AIP_MODEL_DIR", None),
        help="Directory to save the trained model.",
    )
    parser.add_argument(
        "--model_checkpoint_dir",
        type=str,
        help="Directory to load previously trained models.",
    )

    # Add other hyperparameters as needed
    parser.add_argument(
        "--n_estimators", type=int, default=100, help="Number of estimators"
    )
    parser.add_argument(
        "--max_depth", type=int, default=3, help="Maximum depth of trees"
    )
    parser.add_argument(
        "--tensorboard",
        type=str,
        help="Tensorboard",
        default=os.environ.get("AIP_TENSORBOARD_LOG_DIR", None),
    )
    # ... add other hyperparameter arguments

    args = parser.parse_args()

    if not args.model_dir:
        raise Exception(
            "You need to provide a directory where to store the model artifacts"
        )

    if args.data_path and args.data_path.startswith("bq://"):
        args.data_path = load_data_from_bq(args.data_path)

    if not args.data_path:

        from sklearn.datasets import load_iris

        iris = load_iris()
        iris_df = pd.DataFrame(
            data=np.c_[iris["data"], iris["target"]],
            columns=iris["feature_names"] + ["target"],
        )
        iris_df.to_csv("iris.csv", index=False)

        args.data_path = "iris.csv"

    # Print environment variables
    run_loop(**vars(args))


if __name__ == "__main__":
    main()
