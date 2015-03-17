all:
	docker build -t dockercore/iso:base -f Dockerfile.base .
	docker build -t dockercore/iso -f Dockerfile.docker .
	docker run --rm dockercore/iso sh -c 'build-iso.sh >&2 && cat /tmp/docker.iso' > docker.iso
	ls -lh docker.iso
