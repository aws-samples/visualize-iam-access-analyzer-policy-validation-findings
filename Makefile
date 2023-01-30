help: ## Display this help screen.
	@grep -h -E '^[1-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "· \033[36m%-30s\033[0m %s\n", $$1, $$2}'

deploy-hub: ## Deploys the hub.template.yaml to the central security account using parameter aws-region.
	$(eval pOrgId := $(shell aws organizations describe-organization --query "Organization.Id" | tr -d '"'))
	aws cloudformation deploy \
		--stack-name access-analyzer-policy-validation-findings \
		--template-file multi-account-deployment/hub.template.yaml \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--parameter-overrides pOrgId=$(pOrgId) pS3BucketName=access-analyzer-findings-$(pOrgId) \
		--region $(aws-region) \
		--no-fail-on-empty-changeset

deploy-dashboard-hub: ## Deploys the quicksight-hub.template.yaml to the central security account using parameter quicksight-user-arn.
	aws cloudformation deploy \
		--stack-name access-analyzer-findings-dashboard \
		--template-file quicksight-dashboard-deployment/quicksight-hub.template.yaml \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--parameter-overrides pQuickSightUserNameArn=$(quicksight-user-arn) \
		--region $(aws-region)

describe-hub-outputs: ## Describes the hub.template.yaml CloudFormation Outputs using parameter aws-region.
	aws cloudformation describe-stacks \
		--stack-name access-analyzer-policy-validation-findings \
		--region $(aws-region) \
		--query "Stacks[0].Outputs"

delete-hub: ## Deletes the CloudFormation stack deployed using the template hub.template.yaml from the central security account using parameter aws-region.
	aws cloudformation delete-stack \
		--stack-name  access-analyzer-policy-validation-findings \
		--region $(aws-region) 

deploy-members: ## Creates a StackSet and StackSet instances using the stackset.template.yaml file using parameters SQSQueueUrl, KMSKeyArn and aws-region. You must run this command in the AWS management account.
	$(eval pRootId := $(shell aws organizations list-roots --query "Roots[0].Id" | tr -d '"'))
	aws cloudformation create-stack-set \
		--stack-set-name access-analyzer-policy-validation-resources \
		--template-body file://multi-account-deployment/stackset.template.yaml \
		--parameters ParameterKey=pSQSQueueUrl,ParameterValue=$(SQSQueueUrl) ParameterKey=pKMSKeyArn,ParameterValue=$(KMSKeyArn) \
		--capabilities CAPABILITY_NAMED_IAM \
		--permission-model SERVICE_MANAGED \
		--auto-deployment Enabled=true,RetainStacksOnAccountRemoval=false \
		--region $(aws-region) && \
	aws cloudformation create-stack-instances \
		--stack-set-name access-analyzer-policy-validation-resources \
		--regions $(aws-region) \
		--deployment-targets OrganizationalUnitIds=$(pRootId) \
		--region $(aws-region)

delete-stackset: ## Deletes created StackSet using parameter aws-region. You must run this command in the AWS management account.
	aws cloudformation delete-stack-set \
		--stack-set-name access-analyzer-policy-validation-resources \
		--region $(aws-region)

delete-stackset-instances: ## Deletes created StackSet instances using parameter aws-region. You must run this command in the AWS management account.
	$(eval pRootId := $(shell aws organizations list-roots --query "Roots[0].Id" | tr -d '"'))
	aws cloudformation delete-stack-instances \
		--stack-set-name access-analyzer-policy-validation-resources \
		--deployment-targets OrganizationalUnitIds=$(pRootId) \
		--regions $(aws-region) \
		--no-retain-stacks \
		--region $(aws-region)

delete-dashboard: ## Deletes the CloudFormation stack access-analyzer-findings-dashboard from your AWS account using parameter aws-region.
	aws cloudformation delete-stack \
		--stack-name access-analyzer-findings-dashboard \
		--region $(aws-region)