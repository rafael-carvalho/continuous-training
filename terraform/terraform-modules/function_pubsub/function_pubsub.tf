# Copyright 2024 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

/*
Module description: Creates a Cloud Function to be triggered by a Cloud Storage event.
*/

# Project ID
variable "project" {
  type = object({
    project_id = string
  })
  description = "The Google Cloud project details."
}

variable "source_code_upload_bucket_name" {
  type        = string
  description = "The name of the bucket where the function code will be uploaded."
}

variable "gcp_region" {
  type        = string
  default     = "us-central1"
  description = "The region where the function will be deployed."
}

variable "pubsub_topic_id" {
  type = string
}

variable "filter_pattern" {
  type    = string
  default = "*.*"
}

variable "environment_variables" {
  default     = {}
  description = "Environment variables to set in the function."
}

variable "runner_service_account" {

}
variable "builder_service_account" {

}

variable "source_dir" {
  type = string
}

variable "entry_point" {
  default = "main"
}

variable "function_name" {
}

variable "memory" {
  default = "512M"
}
variable "timeout" {
  type    = number
  default = 300
}

variable "description" {
  default = "Function to ..."
}

variable "event_type" {
  default = "google.cloud.pubsub.topic.v1.messagePublished"
}

locals {
  files              = [for f in fileset(path.root, "${var.source_dir}/**") : f]
  source_folder_hash = sha1(join("", [for f in fileset(path.root, "${var.source_dir}/**") : filesha1(f)]))
}

# Zips the source code of the function, including the hash in the filename
data "archive_file" "source_code_zip" {
  type        = "zip"
  output_path = "/tmp/${var.function_name}-${local.source_folder_hash}.zip"
  source_dir  = var.source_dir
  excludes    = ["**/__pycache__/**"]
}

# Uploads the zipped source code to a bucket
resource "google_storage_bucket_object" "object" {
  name         = "functions/${var.function_name}-${local.source_folder_hash}.zip" # Include hash in object name
  bucket       = var.source_code_upload_bucket_name
  content_type = "application/zip"
  source       = data.archive_file.source_code_zip.output_path
}

# Deploys the Second Generation Google Cloud Function
resource "google_cloudfunctions2_function" "storage_function" {
  name        = var.function_name
  location    = var.gcp_region
  project     = var.project.project_id
  description = var.description

  build_config {
    runtime     = "python311"
    entry_point = var.entry_point
    source {
      storage_source {
        bucket = google_storage_bucket_object.object.bucket
        object = google_storage_bucket_object.object.name
      }
    }
    service_account = var.builder_service_account.id
  }

  service_config {
    max_instance_count             = 1000
    min_instance_count             = 1
    available_memory               = var.memory
    timeout_seconds                = var.timeout
    environment_variables          = var.environment_variables
    ingress_settings               = "ALLOW_ALL"
    all_traffic_on_latest_revision = true
    service_account_email          = var.runner_service_account.email

  }
  event_trigger {
    trigger_region        = var.gcp_region # The trigger must be in the same location as the bucket
    event_type            = var.event_type
    retry_policy          = "RETRY_POLICY_DO_NOT_RETRY"
    pubsub_topic          = var.pubsub_topic_id
    service_account_email = var.runner_service_account.email

  }
  lifecycle {
    create_before_destroy = true
  }

}

output "function" {
  value = google_cloudfunctions2_function.storage_function
}
output "files" {
  value = local.files
}