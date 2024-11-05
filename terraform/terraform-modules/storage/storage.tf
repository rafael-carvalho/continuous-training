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
Module description: Creates the required storage buckets for the project.
*/

# Project ID
variable "project" {
  type = object({
    project_id = string
    number     = string
  })
  description = "The Google Cloud project details."
}

variable "region" {
  type        = string
  description = "GCP region in which the bucket(s) will be created."
}

# create a bucket for the project to store the cloud function code
resource "google_storage_bucket" "bucket" {
  project                     = var.project.project_id
  name                        = var.project.project_id
  location                    = var.region
  force_destroy               = true
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  versioning {
    enabled = false
  }
}

# create a bucket for the project to store the cloud function code
resource "google_storage_bucket" "trigger_bucket" {
  project                     = var.project.project_id
  name                        = "${var.project.project_id}-trigger"
  location                    = var.region
  force_destroy               = true
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  versioning {
    enabled = false
  }
}

output "bucket" {
  value = google_storage_bucket.bucket
}

output "bucket_trigger" {
  value = google_storage_bucket.trigger_bucket
}