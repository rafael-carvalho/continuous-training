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


# This variable defines the GCP project
variable "project" {
  type = object({
    project_id = string
    number     = string
  })
  description = "The Google Cloud project details."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "The GCP region in which the resources will be created."
}

variable "notebook_machine_type" {
  default     = "e2-highmem-4"
  description = "The machine type of the notebook instance"
  type        = string
}

variable "colab_runtime_template" {
  default     = "colab-runtime-template"
  type        = string
  description = "The name of the Colab runtime template to use."
}

variable "colab_runtime_id" {
  default     = "colab-runtime-id"
  type        = string
  description = "The ID of the Colab runtime to use."
}

# This resource creates a VPC network.
resource "google_compute_network" "vpc_network" {
  project                 = var.project.number
  name                    = "colab-vpc-network"
  auto_create_subnetworks = false
}

# This resource creates a subnetwork.
resource "google_compute_subnetwork" "subnet" {
  name                     = "colab-subnetwork"
  ip_cidr_range            = "192.168.1.0/24"
  region                   = var.region
  project                  = var.project.number
  network                  = google_compute_network.vpc_network.self_link
  private_ip_google_access = true
}

# This resource creates a router.
resource "google_compute_router" "router" {
  project = var.project.project_id
  name    = "colab-nat-router"
  network = google_compute_network.vpc_network.self_link
  region  = var.region
}

# This module creates a Cloud NAT configuration.
module "cloud-nat" {
  source                             = "terraform-google-modules/cloud-nat/google"
  project_id                         = var.project.project_id
  region                             = var.region
  router                             = google_compute_router.router.name
  name                               = "colab-nat-config"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}



# This resource creates a Colab runtime template.
resource "null_resource" "colab_runtime_template" {
  triggers = {
    project_number         = var.project.number
    region                 = var.region
    notebook_machine_type  = var.notebook_machine_type
    subnet                 = google_compute_subnetwork.subnet.name
    network                = google_compute_network.vpc_network.name
    colab_runtime_template = var.colab_runtime_template
    colab_runtime_id       = var.colab_runtime_id
  }
  provisioner "local-exec" {

    when    = create
    command = <<EOF
  curl -X POST \
  https://${self.triggers.region}-aiplatform.googleapis.com/ui/projects/${self.triggers.project_number}/locations/${self.triggers.region}/notebookRuntimeTemplates?notebookRuntimeTemplateId=${self.triggers.colab_runtime_template} \
  --header "Authorization: Bearer $(gcloud auth print-access-token)" \
  --header "Content-Type: application/json" \
  --data '{
    displayName: "${self.triggers.colab_runtime_template}", 
    description: "${self.triggers.colab_runtime_template}",
    isDefault: true,
    machineSpec: {
      machineType: "${self.triggers.notebook_machine_type}"
    },
    dataPersistentDiskSpec: {
      diskType: "pd-standard",
      diskSizeGb: 500,
    },
    networkSpec: {
      enableInternetAccess: false,
      network: "projects/${self.triggers.project_number}/global/networks/${self.triggers.network}", 
      subnetwork: "projects/${self.triggers.project_number}/regions/${self.triggers.region}/subnetworks/${self.triggers.subnet}"
    },
    shieldedVmConfig: {
      enableSecureBoot: true
    }
  }'
EOF
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
curl -X DELETE \
https://${self.triggers.region}-aiplatform.googleapis.com/ui/projects/${self.triggers.project_number}/locations/${self.triggers.region}/notebookRuntimeTemplates/${self.triggers.colab_runtime_template} \
--header "Authorization: Bearer $(gcloud auth print-access-token)"
EOF

  }
  depends_on = [
    google_compute_subnetwork.subnet,
    google_compute_router.router
  ]
}

output "colab_url" {
  value = "https://console.cloud.google.com/vertex-ai/colab/runtimes?project=${var.project.project_id}"
}