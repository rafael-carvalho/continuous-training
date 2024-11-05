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

/**

This module triggers a Google Cloud Build based on changes within a specified source directory. 

It utilizes a `null_resource` with a `local-exec` provisioner to execute the `gcloud builds submit` command. 
The build is triggered whenever files within the source directory are modified. 
The module accepts variables for the project ID, region, source directory path relative to the main Terraform module, builder service account, and substitutions for the build. 
 
This setup enables automated builds within a CI/CD pipeline, streamlining the deployment process.
*/

variable "project" {
  type = object({
    project_id = string
  })
  description = "The Google Cloud project details."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "The region to execute the build."
}

variable "source_dir_relative_to_main_terraform_module" {
  type        = string
  description = "The path to the source directory relative to the main Terraform module."
}


variable "builder_service_account" {
  type = object({
    id    = string
    email = string # Include email for better tracking and potential use in future
  })
  description = "The service account to use for the build trigger.  Includes both ID and email."
}

variable "substitutions" {
  type        = map(string)
  default     = {}
  description = "Substitutions to use in the build configuration."
}

locals {
  source_dir        = "${path.root}/${var.source_dir_relative_to_main_terraform_module}"
  substitutions_str = join(",", [for k, v in var.substitutions : "${k}=${v}"])
}

# Local execution of gcloud builds submit to trigger Cloud Build
resource "null_resource" "build_trigger" {
  triggers = {
    # Triggers the build when any file in the source directory changes
    source_dir_hash            = sha1(join("", [for f in fileset(path.root, "${local.source_dir}/**") : filesha1(f)]))
    substitutions              = local.substitutions_str
    project_id                 = var.project.project_id
    region                     = var.region
    builder_service_account_id = var.builder_service_account.id
  }
  provisioner "local-exec" {
    command     = <<EOT
       gcloud builds submit . \
        --project=${self.triggers.project_id} \
        --service-account=${self.triggers.builder_service_account_id} \
        --region=${self.triggers.region} \
        --default-buckets-behavior="regional-user-owned-bucket" \
        --quiet \
        --substitutions=${local.substitutions_str}
EOT
    working_dir = local.source_dir
  }
}