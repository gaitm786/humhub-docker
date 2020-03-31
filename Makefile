.PHONY: help
.SILENT:

PREPARE := $(shell test -e .env || cp .env.dist .env)
IS_ENV_PRESENT := $(shell test -e .env && echo -n yes)

ifeq ($(IS_ENV_PRESENT), yes)
	include .env
	export $(shell sed 's/=.*//' .env)
endif

SHELL=/bin/bash
SUDO=sudo
IMAGE=quay.io/riotkit/humhub
RIOTKIT_UTILS_VER=v2.1.0
COMPOSE_ENV=ci
COMPOSE=docker-compose --project-directory=$(pwd) -f ci/compose.ci-builder.yml -p ${COMPOSE_ENV}
PRECISE_DOCKER_TAG=""

help:
	@grep -E '^[a-zA-Z\-\_0-9\.@]+:.*?## .*$$' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build: ## Build image (VERSION, PRECISE_DOCKER_TAG)
	${SUDO} ${COMPOSE} build --build-arg HUMHUB_VERSION=${VERSION}
	set -x; ${SUDO} docker tag ${COMPOSE_ENV}_humhub ${IMAGE}:${VERSION}
	set -x; ${SUDO} docker tag ${COMPOSE_ENV}_humhub ${IMAGE}:${PRECISE_DOCKER_TAG}

push: ## Release image to the registry (VERSION, PRECISE_DOCKER_TAG)
	set -x; ${SUDO} docker push ${IMAGE}:${VERSION}${VERSION}
	set -x; ${SUDO} docker push ${IMAGE}:${VERSION}${PRECISE_DOCKER_TAG}

#
# For each release on github.com/humhub/humhub build an image
#
ci@all:## CI task to build everythinh (GIT_TAG, COMMIT_MESSAGE)
	BUILD_PARAMS="--dont-rebuild "; \
	RELEASE_TAG_TEMPLATE="%MATCH_0%"; \
	if [[ "$$COMMIT_MESSAGE" == *"@force-rebuild"* ]] || [[ "${GIT_TAG}" != "" ]]; then \
		BUILD_PARAMS=" "; \
		if [[ "${GIT_TAG}" != "" ]]; then \
			RELEASE_TAG_TEMPLATE="%MATCH_0%-b${GIT_TAG}"; \
		fi; \
	fi; \
	set -x; \
	./.helpers/for-each-github-release \
		--exec "make build  VERSION=%MATCH_0% PRECISE_DOCKER_TAG=$${RELEASE_TAG_TEMPLATE}" \
		--repo-name humhub/humhub \
		--dest-docker-repo ${IMAGE} \
		$${BUILD_PARAMS}\
		--allowed-tags-regexp="v([0-9\.]+)$$" \
		--release-tag-template="$${RELEASE_TAG_TEMPLATE}" \
		--max-versions=3 \
		--verbose

_download_tools:
	make -s _download_tool TOOL_NAME=extract-envs-from-dockerfile
	make -s _download_tool TOOL_NAME=find-closest-github-release
	make -s _download_tool TOOL_NAME=env-to-json
	make -s _download_tool TOOL_NAME=for-each-github-release
	make -s _download_tool TOOL_NAME=docker-generate-readme

_download_tool:
	@mkdir -p .helpers
	@test -f .helpers/${TOOL_NAME} || curl -s -f https://raw.githubusercontent.com/riotkit-org/ci-utils/${RIOTKIT_UTILS_VER}/bin/${TOOL_NAME} > .helpers/${TOOL_NAME}
	@chmod +x ./.helpers/*
