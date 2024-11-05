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

# Reference: https://cloud.google.com/architecture/managing-infrastructure-as-code

# Pub/Sub topic that will be used to trigger pipeline compilation
# Bucket that will be used to store the pipeline artifacts

variable "display_name" {
  type    = string
  default = "my-tensorboard"
}

variable "description" {
  type    = string
  default = "Description of the tensorboard"
}

variable "gcp_region" {
  type    = string
  default = "us-central1"
}

resource "google_vertex_ai_tensorboard" "tensorboard" {
  display_name = var.display_name
  region       = var.gcp_region
}

output "tensorboard" {
  value = google_vertex_ai_tensorboard.tensorboard
}