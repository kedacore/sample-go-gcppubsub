##################################################
# Variables                                      #
##################################################
ARCH?=amd64
CGO?=0
TARGET_OS?=linux

##################################################
# Build                                          #
##################################################
.PHONY: build
build:
	CGO_ENABLED=$(CGO) GOOS=$(TARGET_OS) GOARCH=$(ARCH) go build \
		-o ./app \
		main.go
	docker build -t ${IMAGE_NAME} .

##################################################
# Run                                            #
##################################################
.PHONY: run
run:
	docker run -e "SUBSCRIPTION_NAME=$$SUBSCRIPTION_NAME" \
		-e "PROJECT_ID=$$PROJECT_ID" \
		-e "GOOGLE_APPLICATION_CREDENTIALS_JSON=$$GOOGLE_APPLICATION_CREDENTIALS_JSON" \
		${IMAGE_NAME}
