# versions.tf
# ---------------------------------------------------------------------------
# Pins the Terraform CLI version and the provider versions this code was
# written against. Pinning prevents "it worked yesterday" surprises when a
# newer provider changes behavior.
# ---------------------------------------------------------------------------

terraform {
  # Require Terraform 1.5 or newer (but below 2.0).
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    # The AWS provider talks to the AWS APIs.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60" # any 5.60.x — patch updates allowed, minor/major not
    }
    # Used to generate random suffixes (e.g., unique bucket names).
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    # Used to render local files / templates where needed.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
