DOCKER_IMAGE_NAME ?= docker-tc
DOCKER_PUBLIC_IMAGE_NAME ?= lukaszlach/docker-tc
.PHONY: init build run test push clean

build: init
	docker build \
		--build-arg VERSION=$$(cat .version) \
		--build-arg BUILD_DATE=$$(date -Is 2>/dev/null || docker run --rm busybox date -Is) \
		--build-arg VCS_REF=$$(git rev-parse --short HEAD || echo "dev") \
		-t ${DOCKER_IMAGE_NAME} \
		.
	docker images | grep "${DOCKER_IMAGE_NAME}"

init:
	@which docker >/dev/null || ( echo "Error: Docker is not installed"; exit 1 )

run:
	@which docker-compose >/dev/null || ( echo "Error: docker-compose is not installed"; exit 1 )
	docker-compose down
	docker-compose rm -f
	DOCKER_IMAGE_TERMINAL=${DOCKER_IMAGE_NAME} \
		docker-compose up

push:
	docker tag ${DOCKER_IMAGE_NAME} ${DOCKER_PUBLIC_IMAGE_NAME}
	docker push ${DOCKER_PUBLIC_IMAGE_NAME}

test:
	docker network rm test-net || true
	docker network create test-net
	docker rm -f ${DOCKER_IMAGE_NAME}-test || true
	docker run -it \
		--net test-net \
		--name ${DOCKER_IMAGE_NAME}-test \
		--label "com.docker-tc.enabled=1" \
		--label "com.docker-tc.limit=200kbps" \
		--label "com.docker-tc.delay=100ms" \
		--label "com.docker-tc.loss=50%" \
		--label "com.docker-tc.duplicate=50%" \
		busybox \
		ping google.com

clean:
	docker rmi -f ${DOCKER_IMAGE_NAME}