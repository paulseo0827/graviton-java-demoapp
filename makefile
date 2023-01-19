# Used by `deploy` target, sets AWS deployment defaults, override as required
AWS_ACCOUNT_ID ?= XXXXXXXXXX
AWS_REGION ?= ap-northeast-2
AWS_AVAILABILITY_ZONES ?= $(AWS_REGION)a,$(AWS_REGION)b
AWS_STACK_NAME ?= java-demoapp
JAVA_WEBAPP_REPO ?= $(AWS_STACK_NAME)

# Used by `image`, `push` & `deploy` targets, override as required
IMAGE_LOCAL ?= $(JAVA_WEBAPP_REPO)
IMAGE_ECR_REPO ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(JAVA_WEBAPP_REPO)
IMAGE_TAG ?= latest$(if $(IMAGE_SUFFIX),-$(IMAGE_SUFFIX),)
IMAGE_LOCAL_TAG_FULL := $(IMAGE_LOCAL):$(IMAGE_TAG)
IMAGE_ECR_TAG_FULL := $(IMAGE_ECR_REPO):$(IMAGE_TAG)

# Used by `multiarch-*` targets
PLATFORMS ?= linux/arm64,linux/amd64

# Used by `test-api` target
TEST_HOST ?= localhost:8080

# Don't change
SRC_DIR := src
REPO_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

# Set this to false on initial stack creation
CREATE_SERVICE ?= true

.PHONY: help lint lint-fix image push run deploy undeploy clean test test-api test-report .EXPORT_ALL_VARIABLES
.DEFAULT_GOAL := help

help:  ## 💬 This help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

lint:  ## 🔎 Lint & format, will not fix but sets exit code on error
	./mvnw checkstyle:check

lint-fix:  ## 📜 Lint & format, will try to fix errors and modify code
	@echo "Lint auto fixing not implemented, Java support for this sucks"

image-local:  ## 🔨 Build container image from Dockerfile
	docker build . --file build/Dockerfile \
        --tag $(IMAGE_LOCAL_TAG_FULL)

push-local:  ## 📤 Push container image to registry
	docker push $(IMAGE_LOCAL_TAG_FULL)

image:  ## 🔨 Build container image from Dockerfile
	docker build . --file build/Dockerfile \
	--tag $(IMAGE_ECR_TAG_FULL)

push:  ## 📤 Push container image to registry
	aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
	docker push $(IMAGE_ECR_TAG_FULL)

multiarch-image: ## 🔨 Build multi-arch container image from Dockerfile
	docker buildx build . --file build/Dockerfile \
	--platform $(PLATFORMS) \
	--tag $(IMAGE_TAG_FULL)

multiarch-push: ## 📤 Build and push multi-arch container image to registry
	docker buildx build . --file build/Dockerfile \
	--platform $(PLATFORMS) \
	--tag $(IMAGE_TAG_FULL) \
	--push

multiarch-manifest: ## 📤 Build and push multi-arch manifest to registry
	docker manifest create $(IMAGE_TAG_FULL) \
		$(foreach suffix,$(IMAGE_SUFFIXES),$(IMAGE_TAG_FULL)-$(suffix))
	docker manifest push $(IMAGE_TAG_FULL)

run:  ## 🏃 Run application in Docker container, exposing port 8080
	docker run --rm -p 8080:8080 $(IMAGE_TAG_FULL)

deploy: ## 🚀 Deploy to Amazon ECS
	aws cloudformation deploy \
		$(if $(CLOUDFORMATION_ROLE_ARN),--role-arn $(CLOUDFORMATION_ROLE_ARN),) \
		--no-fail-on-empty-changeset \
		--capabilities CAPABILITY_IAM \
		--template-file $(REPO_DIR)/deploy/aws/ecs-service-template.yaml \
		--stack-name $(AWS_STACK_NAME) \
		--parameter-overrides \
			$(if $(ECS_CLUSTER),ClusterName=$(ECS_CLUSTER),) \
			$(if $(ECS_SERVICE),ServiceName=$(ECS_SERVICE),) \
			CreateService=$(CREATE_SERVICE) \
			AvailabilityZones=$(AWS_AVAILABILITY_ZONES) \
			CreateNATGateways=false \
			CreatePrivateSubnets=false \
			ImageTag=$(IMAGE_TAG)
	@echo "### 🚀 App deployed & available here: http://`aws cloudformation describe-stacks --stack-name $(AWS_STACK_NAME) --query 'Stacks[0].Outputs[?OutputKey==\`AlbDnsUrl\`].OutputValue' --output text`"

undeploy: ## 💀 Remove from AWS
	@echo "### WARNING! Going to delete $(AWS_STACK_NAME) 😲"
	aws cloudformation delete-stack --stack-name $(AWS_STACK_NAME)
	aws cloudformation wait stack-delete-complete --stack-name $(AWS_STACK_NAME)

test:  ## 🎯 JUnit tests for application
	./mvnw test

test-report: test  ## 🎯 JUnit tests for application (with report output)

test-api: .EXPORT_ALL_VARIABLES  ## 🚦 Run integration API tests, server must be running
	cd tests \
	&& npm install newman \
	&& ./node_modules/.bin/newman run ./postman_collection.json --env-var apphost=$(TEST_HOST)

clean:  ## 🧹 Clean up project
	rm -rf target/
