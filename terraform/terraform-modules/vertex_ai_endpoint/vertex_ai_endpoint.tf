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

variable "gcp_region" {
  type    = string
  default = "us-central1"
}

variable "endpoint_name" {
  type = string
}

variable "description" {
  type    = string
  default = null
}

resource "google_vertex_ai_endpoint" "endpoint" {
  name         = var.endpoint_name
  display_name = var.endpoint_name
  description  = var.description
  location     = var.gcp_region
  project      = var.project.project_id
  region       = var.gcp_region

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
bash -c '
  set -xe
  endpoint_id=${self.id}
  echo "Undeploying models from endpoint: $endpoint_id"

  deployed_models=$(gcloud ai endpoints describe "$endpoint_id" --project="${self.project}" --region="${self.region}" --format="value(deployedModels.id)")

  if [[ -n "$deployed_models" ]]; then
    IFS=";" read -r -a dep_models <<< "$deployed_models"
    for dep_model in "$${dep_models[@]}"; do
      echo "Undeploying model: $dep_model from endpoint $endpoint_id"
      gcloud ai endpoints undeploy-model "$endpoint_id" --project="${self.project}" --region="${self.region}" --deployed-model-id="$dep_model" --quiet
    done
  fi

  gcloud ai endpoints delete "$endpoint_id" --project="${self.project}" --region="${self.region}" --quiet
'
EOF
  }
}

output "endpoint" {
  value = google_vertex_ai_endpoint.endpoint
}