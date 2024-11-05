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
Module description: Creates the required pubsub topic.
*/

# Project ID
variable "project" {
  type = object({
    project_id = string
  })
  description = "The Google Cloud project details."
}

variable "topic_name" {
  type = string
}

resource "google_pubsub_topic" "topic" {
  name = var.topic_name

  labels = {
    foo = "bar"
  }
  message_retention_duration = "86600s"
}

output "topic" {
  value = google_pubsub_topic.topic
}