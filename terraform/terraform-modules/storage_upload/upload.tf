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
Module description: Uploads files to GCS
*/


variable "bucket" {
  type = object({
    name = string
    url  = string
  })
}

variable "data_directory" {
  type        = string
  description = "Path to the directory containing files to upload"
}


variable "bucket_prefix" {
  type    = string
  default = ""
}


# Upload each file as a separate object in the bucket
resource "google_storage_bucket_object" "file_upload" {
  for_each = fileset(var.data_directory, "/**/*")
  name     = var.bucket_prefix == "" ? each.key : "${var.bucket_prefix}/${each.key}"
  bucket   = var.bucket.name
  source   = "${var.data_directory}/${each.key}"
}

output "uploaded_folder" {
  value       = var.bucket_prefix
  description = "Bucket prefix of where the data was uploaded"
}

output "uploaded_prefix" {
  value = var.bucket_prefix == "" ? "${var.bucket.url}" : "${var.bucket.url}/${var.bucket_prefix}"
}