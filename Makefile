.PHONY: all clean ubuntu debian sles amazon redhat test
export PYTHONPATH := $(shell pwd)/test:$(shell pwd):$(PYTHONPATH)

all: clean ubuntu debian sles amazon redhat
redhat:
		docker buildx build --load --platform linux/amd64 -t rhel-8-init -f test/Dockerfile.redhat_8 .
		docker buildx build --load --platform linux/amd64 -t rhel-9-init -f test/Dockerfile.redhat_9 .
ubuntu:
		docker buildx build --load --platform linux/amd64 -t ubuntu-focal-init -f test/Dockerfile.ubuntu_focal .
		docker buildx build --load --platform linux/amd64 -t ubuntu-jammy-init -f test/Dockerfile.ubuntu_jammy .
debian:
		docker buildx build --load --platform linux/amd64 -t debian-bullseye-init -f test/Dockerfile.debian_bullseye .
sles:
		docker buildx build --load --platform linux/amd64 -t opensuse-init -f test/Dockerfile.opensuse .
		docker buildx build --load --platform linux/amd64 -t sles-155-init -f test/Dockerfile.sles_15_5 .
		docker buildx build --load --platform linux/amd64 -t sles-153-init -f test/Dockerfile.sles_15_3 .
amazon:
		docker buildx build --load --platform linux/amd64 -t amazon-2-init -f test/Dockerfile.amazon_2 .
		docker buildx build --load --platform linux/amd64 -t amazon-2023-init -f test/Dockerfile.amazon_2023 .
clean:
		@if docker image inspect ubuntu-focal-init > /dev/null 2>&1; then docker rmi ubuntu-focal-init; fi
		@if docker image inspect ubuntu-jammy-init > /dev/null 2>&1; then docker rmi ubuntu-jammy-init; fi
		@if docker image inspect debian-bullseye-init > /dev/null 2>&1; then docker rmi debian-bullseye-init; fi
		@if docker image inspect opensuse-init > /dev/null 2>&1; then docker rmi opensuse-init; fi
		@if docker image inspect sles-155-init > /dev/null 2>&1; then docker rmi sles-155-init; fi
		@if docker image inspect sles-153-init > /dev/null 2>&1; then docker rmi sles-153-init; fi
		docker image prune -f
		docker volume prune -f
		docker buildx prune -f
test:
		python -m pytest test/test_1.py
