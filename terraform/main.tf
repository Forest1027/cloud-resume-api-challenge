locals {
    project_id = "lyrical-caster-455607-i7"
    region = "europe-west2"
    cloud_function_sa = "cloud-function-service-account@lyrical-caster-455607-i7.iam.gserviceaccount.com"
}

variable "function_source_dir" {
  default = "../function"
}

variable "function_bucket" {
  default = "cloud-function-bucket-eu"
}

terraform {
  backend "gcs" {
    bucket = "terraform-state-bucket-455607-i7"
    prefix = "envs/dev"
  }
}

provider "google" {
  project     = local.project_id
  region      = local.region
}

resource "google_storage_bucket" "function_bucket" {
  name     = var.function_bucket
  location = "EU"
  force_destroy = true
}

# Zip and upload function code
resource "null_resource" "zip_and_upload" {
  provisioner "local-exec" {
    command = <<EOT
      cd ${var.function_source_dir}
      zip -r function-source.zip .
      gsutil cp function-source.zip gs://${var.function_bucket}/function-source.zip
    EOT
  }

  triggers = {
    source_hash = filesha256("${var.function_source_dir}/main.py")
  }
}

resource "google_cloudfunctions2_function" "cloud_resume_function" {
  name                  = "cloud-resume"
  location              = "europe-west2"

  build_config {
    runtime               = "python311"
    entry_point           = "get_resume"
    source {
        storage_source {
            bucket = google_storage_bucket.function_bucket.name
            object = "function-source.zip"
        }
    }
  }

  service_config {
    available_memory = "512Mi"
    ingress_settings = "ALLOW_ALL"
    service_account_email = local.cloud_function_sa
  }
  
  depends_on = [null_resource.zip_and_upload]
}

resource "google_cloudfunctions2_function_iam_member" "invoker" {
  project        = google_cloudfunctions2_function.cloud_resume_function.project
  location         = google_cloudfunctions2_function.cloud_resume_function.location
  cloud_function = google_cloudfunctions2_function.cloud_resume_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}