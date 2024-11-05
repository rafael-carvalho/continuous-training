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
Module description: Manage IAM permissions for the project
*/

variable "project" {
  type = object({
    project_id = string
    number     = string
  })
  description = "The Google Cloud project details."
}

data "google_storage_project_service_account" "gcs_account" {
}
data "google_compute_default_service_account" "default" {
}

locals {
  google_cloud_build_service_account = {
    email  = "${var.project.number}@cloudbuild.gserviceaccount.com"
    member = "serviceAccount:${var.project.number}@cloudbuild.gserviceaccount.com"
  }
  google_cloud_build_service_agent = {
    email  = "service-${var.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
    member = "serviceAccount:service-${var.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
  }

  iam_roles_required_by_builder_sa = [
    "roles/owner", # Should remove this role in production environments
    "roles/cloudbuild.builds.editor",
    "roles/storage.admin"
  ]

  iam_roles_required_by_runner_sa = [
    "roles/editor", # Should remove this role in production environments
  ]

  google_eventarc_service_agent = {
    email  = "service-${var.project.number}@gcp-sa-eventarc.iam.gserviceaccount.com"
    member = "serviceAccount:service-${var.project.number}@gcp-sa-eventarc.iam.gserviceaccount.com"
  }
}

resource "google_project_service_identity" "cloud_build_sa" {
  provider = google-beta
  project  = var.project.project_id
  service  = "cloudbuild.googleapis.com"
}

resource "google_project_service_identity" "eventarc_service_identity" {
  provider = google-beta
  project  = var.project.project_id
  service  = "eventarc.googleapis.com"
}

#https://cloud.google.com/eventarc/docs/troubleshooting#trigger-error
resource "google_project_iam_member" "race_condition" {
  project = var.project.project_id
  role    = "roles/eventarc.serviceAgent"
  member  = local.google_eventarc_service_agent.member
}

# Before creating a trigger for direct events from Cloud Storage, grant the Pub/Sub Publisher role (roles/pubsub.publisher) to the Cloud Storage service agent, a Google-managed service account:
# https://cloud.google.com/eventarc/docs/workflows/quickstart-storage#:~:text=Before%20creating%20a%20trigger%20for%20direct%20events%20from%20Cloud%20Storage%2C%20grant%20the%20Pub/Sub%20Publisher%20role%20(roles/pubsub.publisher)%20to%20the%20Cloud%20Storage%20service%20agent%2C%20a%20Google%2Dmanaged%20service%20account%3A
resource "google_project_iam_member" "iam_storage_service_agent_pubsub_publisher" {
  project = var.project.project_id
  role    = "roles/pubsub.publisher"
  member  = data.google_storage_project_service_account.gcs_account.member
}

resource "google_project_iam_member" "cloudbuild_storage_object_creator" {
  project = var.project.project_id
  role    = "roles/storage.admin"
  member  = local.google_cloud_build_service_account.member
}

resource "google_service_account" "runner_sa" {
  project      = var.project.project_id
  account_id   = "runner-sa"
  display_name = "SA used by the pipeline"
}

resource "google_service_account" "builder_sa" {
  project      = var.project.project_id
  account_id   = "builder-sa"
  display_name = "SA used to build resources (e.g. images via cloud build )"
}

resource "google_project_iam_member" "iam_member_builder_sa" {
  for_each = toset(local.iam_roles_required_by_builder_sa)
  role     = each.key
  project  = var.project.project_id
  member   = google_service_account.builder_sa.member
  provisioner "local-exec" {
    when        = create
    command     = <<EOT
    echo "Sleeping for some time so that permissions are propagated"
    sleep 60
    EOT
    working_dir = path.root
  }
}

resource "google_project_iam_member" "iam_member_runner_sa" {
  for_each = toset(local.iam_roles_required_by_runner_sa)
  role     = each.key
  project  = var.project.project_id
  member   = google_service_account.runner_sa.member
}

output "runner_service_account" {
  value = google_service_account.runner_sa
}

output "builder_service_account" {
  value = google_service_account.builder_sa
}
