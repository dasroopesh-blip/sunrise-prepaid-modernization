# providers.tf
# ---------------------------------------------------------------------------
# Configures HOW Terraform connects to AWS. The region and default tags are
# passed in as variables so the same code works across environments.
# ---------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  # default_tags are automatically applied to EVERY taggable resource.
  # This is how we keep consistent tagging without repeating ourselves.
  default_tags {
    tags = {
      project     = var.project
      environment = var.environment
      managed_by  = "terraform"
    }
  }
}

# A SECOND aws provider aliased "dr" for the disaster-recovery region.
# Modules that need cross-region resources reference provider = aws.dr.
provider "aws" {
  alias  = "dr"
  region = var.dr_region

  default_tags {
    tags = {
      project     = var.project
      environment = var.environment
      managed_by  = "terraform"
      role        = "dr"
    }
  }
}
