docker.iso: docker.build
	docker run --rm dockercore/iso sh -c 'build-iso.sh >&2 && cat /tmp/docker.iso' > docker.iso
	ls -lh docker.iso

base.iso: base.build
	docker run --rm dockercore/iso:base sh -c 'build-iso.sh >&2 && cat /tmp/docker.iso' > docker-base.iso
	ls -lh docker-base.iso

%.iso: %.build
	docker run --rm dockercore/iso:$(@:.iso=) sh -c 'build-iso.sh >&2 && cat /tmp/docker.iso' > docker-$@
	ls -lh docker-$@

all: docker.iso virtualbox.iso vmware.iso

base.build: Dockerfile.base
	docker build -t dockercore/iso:base -f Dockerfile.base .
docker.build: base.build Dockerfile.docker
	docker build -t dockercore/iso -f Dockerfile.docker .
%.build: docker.build Dockerfile.%
	docker build -t dockercore/iso:$(@:.build=) -f Dockerfile.$(@:.build=) .
