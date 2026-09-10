# environments/prod/Makefile
# PROD: apply requires explicit confirmation. Consider requiring a plan file.
.PHONY: init plan apply fmt validate output

init:
	terraform init

plan:
	terraform plan -out=prod.tfplan

apply:
	terraform apply prod.tfplan

fmt:
	terraform fmt -recursive ../../

validate:
	terraform validate

output:
	terraform output

# NOTE: no `destroy` target in prod on purpose. Databases have deletion
# protection; tearing prod down should be a deliberate, manual action.
