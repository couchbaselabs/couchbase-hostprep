.PHONY: all build clean

all: clean build
build:
		docker buildx build --load --platform linux/amd64 -t ubuntu-focal-init -f test/Dockerfile.ubuntu_focal .
		docker buildx build --load --platform linux/amd64 -t opensuse-init -f test/Dockerfile.opensuse .
clean:
		@if docker image inspect ubuntu-focal-init > /dev/null 2>&1; then docker rmi ubuntu-focal-init; fi
		@if docker image inspect opensuse-init > /dev/null 2>&1; then docker rmi opensuse-init; fi
		docker image prune -f
		docker volume prune -f
		docker buildx prune -f
