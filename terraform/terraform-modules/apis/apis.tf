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

#List of API's that will be enabled
variable "project" {
  type = object({
    project_id = string
  })
  description = "The Google Cloud project details."
}

/*

Artifact Registry API
BigQuery API
Cloud Build API
Cloud Functions API
Cloud Logging API
Pub/Sub API
Cloud Run Admin API
Cloud Storage API
Eventarc API
Service Usage API
Vertex AI API
*/



#List of API's that will be enabled
variable "gcp_service_list" {
  description = "All required API's to run this project"
  type        = list(string)
  default = [
    "artifactregistry",
    "aiplatform",
    "bigquery",
    "cloudbuild",
    "cloudfunctions",
    "cloudaicompanion",
    "cloudresourcemanager",
    "compute",
    "dataform",
    "eventarc",
    "iam",
    "pubsub",
    "run",
    "storage",
  ]
}

# Enables the API's
resource "google_project_service" "gcp_services" {
  for_each                   = toset(var.gcp_service_list)
  service                    = "${each.key}.googleapis.com"
  project                    = var.project.project_id
  disable_dependent_services = false
  disable_on_destroy         = false
  provisioner "local-exec" {
    when        = create
    command     = <<EOT
    echo "Sleeping for some time so that API enablement is propagated."
    sleep 60
    EOT
    working_dir = path.root
  }
}


resource "null_resource" "create_identities" {

  provisioner "local-exec" {
    when    = create
    command = <<EOF
  gcloud beta services identity create --service=eventarc.googleapis.com --project=${var.project.project_id}
  gcloud beta services identity create --service=cloudbuild.googleapis.com --project=${var.project.project_id}
EOF
  }

}