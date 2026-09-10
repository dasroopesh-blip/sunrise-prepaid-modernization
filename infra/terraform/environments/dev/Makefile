# environments/dev/Makefile
# Convenience wrappers around common Terraform commands.
# Usage: `make plan`, `make apply`, etc. Run from this directory.

.PHONY: init plan apply destroy fmt validate output

init:            ## Download providers + configure backend
	terraform init

plan:            ## Preview changes (no changes made)
	terraform plan

apply:           ## Apply changes (asks for confirmation)
	terraform apply

destroy:         ## Tear down EVERYTHING in this env (dev only!)
	terraform destroy

fmt:             ## Auto-format all .tf files in the repo
	terraform fmt -recursive ../../

validate:        ## Validate syntax + references
	terraform validate

output:          ## Show output values
	terraform output
