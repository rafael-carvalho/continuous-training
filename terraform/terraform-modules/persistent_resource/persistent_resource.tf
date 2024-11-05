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

This module verifies if the persistent resource with the given name exists. If it does not already exist, then it will create it.

Since the provider does not have persistent resources modules, we need to create them ourselves via gcloud cli commands.

*/

variable "project" {
  type = object({
    project_id = string
    number     = string
  })
  description = "The Google Cloud project details."
}

variable "gcp_region" {
  type        = string
  default     = "us-central1"
  description = "Location in which the persistent resource will be created."
}

variable "persistent_resource_name" {
  type    = string
  default = "my-cluster"
}

resource "terraform_data" "verify_existence_of_persistent_resource" {

  triggers_replace = [
    timestamp()
  ]

  provisioner "local-exec" {
    when        = create
    working_dir = path.module
    command     = <<EOF
bash -c 'cat <<- SCRIPT | sh -s -- -p ${var.project.project_id} -r ${var.gcp_region} -n ${var.persistent_resource_name}
$(cat "verify_existence_of_persistent_resource.sh")
SCRIPT'
EOF
  }

}

resource "null_resource" "create_vertex_ai_persistent_resource" {
  depends_on = [terraform_data.verify_existence_of_persistent_resource]
  # Create if the resource *does not* exist
  count = terraform_data.verify_existence_of_persistent_resource.output == "False" ? 0 : 1
  triggers = {
    project_id = var.project.project_id
    region     = var.gcp_region
    name       = var.persistent_resource_name
  }
  provisioner "local-exec" {
    when        = create
    working_dir = path.module
    command     = "bash create_persistent_resource.sh -p ${self.triggers.project_id} -r ${self.triggers.region} -n ${self.triggers.name}"
  }

  provisioner "local-exec" {
    when        = destroy
    working_dir = path.module
    command     = "bash delete_persistent_resource.sh -p ${self.triggers.project_id} -r ${self.triggers.region} -n ${self.triggers.name}"
  }
}

output "uri" {
  value = "projects/${var.project.number}/locations/${var.gcp_region}/persistentResources/${var.persistent_resource_name}"
}

output "id" {
  value = var.persistent_resource_name
}
