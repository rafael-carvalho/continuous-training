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


variable "project" {
  type = object({
    project_id = string
  })
  description = "The Google Cloud project details."
}
variable "repo_id_ml" {
  type    = string
  default = "ml-images"

}
variable "repo_id_kfp" {
  type    = string
  default = "kubeflow-pipelines"
}
variable "gcp_region" {
  type    = string
  default = "us-central1"
}

resource "google_artifact_registry_repository" "kfp" {
  project       = var.project.project_id
  location      = var.gcp_region
  repository_id = var.repo_id_kfp
  description   = "Kubeflow Pipeline Repository"
  format        = "KFP"
}

resource "google_artifact_registry_repository" "docker" {
  project       = var.project.project_id
  location      = var.gcp_region
  repository_id = var.repo_id_ml
  description   = "ML Images"
  format        = "Docker"
}
resource "google_artifact_registry_repository" "docker_cloud_build" {
  project       = var.project.project_id
  location      = var.gcp_region
  repository_id = "cloudbuild-images"
  description   = "Cloud Build Images"
  format        = "Docker"
}

output "repo_kfp_uri" {
  value = "${google_artifact_registry_repository.kfp.location}-kfp.pkg.dev/${google_artifact_registry_repository.kfp.project}/${google_artifact_registry_repository.kfp.repository_id}"
}

output "repo_ml_uri" {
  value = "${google_artifact_registry_repository.docker.location}-docker.pkg.dev/${google_artifact_registry_repository.docker.project}/${google_artifact_registry_repository.docker.repository_id}"
}

output "repo_cloud_build_uri" {
  value = "${google_artifact_registry_repository.docker_cloud_build.location}-docker.pkg.dev/${google_artifact_registry_repository.docker_cloud_build.project}/${google_artifact_registry_repository.docker_cloud_build.repository_id}"
}

