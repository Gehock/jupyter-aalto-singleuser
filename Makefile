# https://hub.docker.com/r/jupyter/minimal-notebook
# f8aca249b70b: 2022-12-19, hub-3.1.0, notebook-6.5.2,  ubuntu-22.04, lab-3.5.1, python-3.10.8
# ed2908bbb62e: 2022-10-22, hub-3.0.0, notebook-6.4.12, ubuntu-22.04, lab-3.4.8, python-3.9.13
# 4d70cf8da953: 2023-05-30, hub-4.0.0, notebook-6.5.4,  ubuntu-22.04, lab=4.0.1, python-3.10.11, node-18.15.0
UPSTREAM_MINIMAL_NOTEBOOK_VER=4d70cf8da953
CRAN_URL=https://cran.microsoft.com/snapshot/2022-08-19/

# base image - jupyter stuff only, not much software
VER_BASE=6.1
# Set VER_BASE_CACHE to the version you want to use as the cache for the base
# image. When bumping VER_BASE to build a new image, this should be set to the
# previously published version for the duration of the build process.
VER_BASE_CACHE=6.1

# Python
VER_STD=6.1.0
# See the comment for VER_BASE_CACHE
VER_STD_CACHE=6.1.0

# Julia
VER_JULIA=5.0.16
# R
VER_R=5.0.25
# OpenCV
VER_CV=1.8.0

# Software for the standard image
BUILD_PATH=/m/scicomp/software/anaconda-ci/aalto-jupyter-anaconda
ENVIRONMENT_NAME=jupyter-generic
ENVIRONMENT_VERSION=2023-07-12
# Built from https://github.com/AaltoSciComp/science-build-configs/commit/f6d7d25eb19dcd3c8283a5f77d907b7218f36c37
ENVIRONMENT_HASH=2a58d30f

ENVIRONMENT_FILE=$(BUILD_PATH)/software/$(ENVIRONMENT_NAME)/$(ENVIRONMENT_VERSION)/$(ENVIRONMENT_HASH)/environment.yml

TEST_MEM_LIMIT="--memory=2G"
R_INSTALL_JOB_COUNT=10

# For private registry, run: `make REGISTRY=registry.cs.aalto.fi/ GROUP=jupyter [BASE_REG_GROUP=aaltoscienceit] [..]`
REGISTRY=
GROUP=aaltoscienceit

# Optional hostname ("registry") and namespace ("group") for the base image.
# When left empty, defaults to the same values as the standard image.
BASE_REG_GROUP=${REGISTRY}${GROUP}

.PHONY: default

default:
	echo "Please specify a command to run"

full-rebuild: base standard test-standard

buildtest: container-builder
	chmod 600 file
	docker buildx build .\
		-t buildtest \
		-f buildtest.Dockerfile \
		--cache-to type=registry,ref=docker.io/gehock/notebook-server-base-cache:buildtest \
		--cache-from type=registry,ref=docker.io/gehock/notebook-server-base-cache:buildtest \
		--builder=jupyter \
		--load

base: pre-build container-builder
	@! grep -P '\t' -C 1 base.Dockerfile || { echo "ERROR: Tabs in base.Dockerfile" ; exit 1 ; }
	docker buildx build . \
		-t $(BASE_REG_GROUP)/notebook-server-base:$(VER_BASE) \
		-f base.Dockerfile \
		--builder=jupyter \
		--load \
		--build-arg=UPSTREAM_MINIMAL_NOTEBOOK_VER=$(UPSTREAM_MINIMAL_NOTEBOOK_VER) \
		--cache-to type=registry,ref=aaltoscienceit/notebook-server-cache:base-$(VER_BASE) \
		--cache-from type=registry,ref=aaltoscienceit/notebook-server-cache:base-$(VER_BASE) \
		--cache-from type=registry,ref=aaltoscienceit/notebook-server-cache:base-$(VER_BASE_CACHE)
	docker run --rm $(BASE_REG_GROUP)/notebook-server-base:$(VER_BASE) conda env export -n base > environment-yml/$@-$(VER_BASE).yml
	docker run --rm $(BASE_REG_GROUP)/notebook-server-base:$(VER_BASE) conda list --revisions > conda-history/$@-$(VER_BASE).yml
standard: pre-build container-builder
	@! grep -P '\t' -C 1 standard.Dockerfile || { echo "ERROR: Tabs in standard.Dockerfile" ; exit 1 ; }
	docker buildx build . \
		-t $(REGISTRY)$(GROUP)/notebook-server:$(VER_STD) \
		-f standard.Dockerfile \
		--builder=jupyter \
		--load \
		--build-arg=BASE_IMAGE=$(BASE_REG_GROUP)/notebook-server-base:$(VER_BASE) \
		--build-arg=JUPYTER_SOFTWARE_IMAGE=$(ENVIRONMENT_NAME)_$(ENVIRONMENT_VERSION)_$(ENVIRONMENT_HASH) \
		--build-arg=VER_STD=$(VER_STD) \
		--cache-to type=registry,ref=aaltoscienceit/notebook-server-cache:standard-$(VER_STD) \
		--cache-from type=registry,ref=aaltoscienceit/notebook-server-cache:standard-$(VER_STD) \
		--cache-from type=registry,ref=aaltoscienceit/notebook-server-cache:standard-$(VER_STD_CACHE)
#	docker run --rm ${REGISTRY}${GROUP}/notebook-server:$(VER_STD) conda env export -n base > environment-yml/$@-$(VER_STD).yml
#	docker run --rm ${REGISTRY}${GROUP}/notebook-server:$(VER_STD) conda list --revisions > conda-history/$@-$(VER_STD).yml
#r:
#	DOCKER_BUILDKIT=1 docker build -t ${REGISTRY}${GROUP}/notebook-server-r:0.4.0 --pull=false . -f r.Dockerfile
r-ubuntu: pre-build
	@! grep -P '\t' -C 1 r-ubuntu.Dockerfile || { echo "ERROR: Tabs in r-ubuntu.Dockerfile" ; exit 1 ; }
	DOCKER_BUILDKIT=1 docker build -t ${REGISTRY}${GROUP}/notebook-server-r-ubuntu:$(VER_R) --pull=false . -f r-ubuntu.Dockerfile --build-arg=VER_BASE=$(VER_BASE) --build-arg=CRAN_URL=$(CRAN_URL) --build-arg=INSTALL_JOB_COUNT=$(R_INSTALL_JOB_COUNT)
#	#docker run --rm ${REGISTRY}${GROUP}/notebook-server-r-ubuntu:$(VER_R) conda env export -n base > environment-yml/$@-$(VER_R).yml
	docker run --rm ${REGISTRY}${GROUP}/notebook-server-r-ubuntu:$(VER_R) conda list --revisions > conda-history/$@-$(VER_R).yml
julia: pre-build
	@! grep -P '\t' -C 1 julia.Dockerfile || { echo "ERROR: Tabs in julia.Dockerfile" ; exit 1 ; }
	DOCKER_BUILDKIT=1 docker build -t ${REGISTRY}${GROUP}/notebook-server-julia:$(VER_JULIA) --pull=false . -f julia.Dockerfile --build-arg=VER_BASE=$(VER_BASE)
	docker run --rm ${REGISTRY}${GROUP}/notebook-server-julia:$(VER_JULIA) conda env export -n base > environment-yml/$@-$(VER_JULIA).yml
	docker run --rm ${REGISTRY}${GROUP}/notebook-server-julia:$(VER_JULIA) conda list --revisions > conda-history/$@-$(VER_JULIA).yml
opencv: pre-build
	@! grep -P '\t' -C 1 opencv.Dockerfile || { echo "ERROR: Tabs in opencv.Dockerfile" ; exit 1 ; }
	DOCKER_BUILDKIT=1 docker build -t notebook-server-opencv:$(VER_CV) --pull=false . -f opencv.Dockerfile --build-arg=VER_STD=$(VER_STD)
	docker run --rm notebook-server-opencv:$(VER_CV) conda env export -n base > environment-yml/$@-$(VER_CV).yml
	docker run --rm ${REGISTRY}${GROUP}/notebook-server:$(VER_CV) conda list --revisions > conda-history/$@-$(VER_CV).yml

update-environment:
	cp $(ENVIRONMENT_FILE) environment.yml


pre-test:
	$(eval TEST_DIR := $(shell mktemp -d /tmp/pytest.XXXXXX))
	rsync --chmod=Do+x,+r -a --delete tests/ $(TEST_DIR)

test-standard: pre-test
	docker run --volume=$(TEST_DIR):/tests:ro ${TEST_MEM_LIMIT} ${REGISTRY}${GROUP}/notebook-server:$(VER_STD) pytest -o cache_dir=/tmp/pytestcache /tests/python/${TESTFILE} ${TESTARGS}
	rm -r $(TEST_DIR)
#	CC="clang" CXX="clang++" jupyter nbconvert --exec --ExecutePreprocessor.timeout=300 pystan_demo.ipynb --stdout
test-standard-full: test-standard pre-test
	docker run --volume=/tmp/nbs-tests:/tests:ro ${TEST_MEM_LIMIT} ${REGISTRY}${GROUP}/notebook-server:$(VER_STD) bash -c 'cd /tmp ; git clone https://github.com/avehtari/BDA_py_demos ; cd BDA_py_demos/demos_pystan/ ; CC=clang CXX=clang++ jupyter nbconvert --exec --ExecutePreprocessor.timeout=300 pystan_demo.ipynb --stdout > /dev/null'
	rm -r $(TEST_DIR)
	@echo
	@echo
	@echo
	@echo "All tests passed..."

test-r-ubuntu: r-ubuntu pre-test
	docker run --volume=$(TEST_DIR):/tests:ro ${TEST_MEM_LIMIT} ${REGISTRY}${GROUP}/notebook-server-r-ubuntu:$(VER_R) Rscript /tests/r/test_bayes.r
	rm -r $(TEST_DIR)

# Because the docker-container driver is isolated from the system docker and
# can't access the default image store, the base image has to be pushed into a
# registry before building other images
push-base: base
	docker push $(REGISTRY)$(GROUP)/notebook-server-base:$(VER_BASE)
push-standard: standard
	docker push ${REGISTRY}${GROUP}/notebook-server:$(VER_STD)
push-r-ubuntu: r-ubuntu
	docker push ${REGISTRY}${GROUP}/notebook-server-r-ubuntu:$(VER_R)
push-julia: julia
#	time docker save ${REGISTRY}${GROUP}/notebook-server-julia:${VER_JULIA} | ssh manager ssh jupyter-k8s-node4.cs.aalto.fi 'docker load'
	docker push ${REGISTRY}${GROUP}/notebook-server-julia:$(VER_JULIA)
push-dev: check-khost standard
	## NOTE: Saving and loading the whole image takes a long time. Pushing
	##       partial changes to a DockerHub repo using `push-devhub` is faster
	# time docker save ${REGISTRY}${GROUP}/notebook-server-r-ubuntu:${VER_STD} | ssh ${KHOST} ssh jupyter-k8s-node4.cs.aalto.fi 'docker load'
	time docker save ${REGISTRY}${GROUP}/notebook-server:${VER_STD} | ssh ${KHOST} ssh k8s-node4.cs.aalto.fi 'docker load'
push-devhub: check-khost check-hubrepo standard
	docker tag ${REGISTRY}${GROUP}/notebook-server:${VER_STD} ${HUBREPO}/notebook-server:${VER_STD}
	docker push ${HUBREPO}/notebook-server:${VER_STD}
	ssh ${KHOST} ssh k8s-node4.cs.aalto.fi "docker pull ${HUBREPO}/notebook-server:${VER_STD}"
push-devhub-base: check-khost check-hubrepo base
	docker tag ${BASE_REG_GROUP}/notebook-server-base:${VER_BASE} ${HUBREPO}/notebook-server-base:${VER_BASE}
	docker push ${HUBREPO}/notebook-server-base:${VER_BASE}
	ssh ${KHOST} ssh k8s-node4.cs.aalto.fi "docker pull ${HUBREPO}/notebook-server-base:${VER_BASE}"

pull-standard: check-khost check-knodes
	ssh ${KHOST} time pdsh -R ssh -w ${KNODES} "docker pull ${REGISTRY}${GROUP}/notebook-server:${VER_STD}"
	ssh ${KHOST} time pdsh -R ssh -w ${KNODES} "docker tag ${REGISTRY}${GROUP}/notebook-server:${VER_STD} ${REGISTRY}${GROUP}/notebook-server:${VER_STD}"
pull-r-ubuntu: check-khost check-knodes
	ssh ${KHOST} time pdsh -R ssh -w ${KNODES} "docker pull ${REGISTRY}${GROUP}/notebook-server-r-ubuntu:${VER_R}"
	ssh ${KHOST} time pdsh -R ssh -w ${KNODES} "docker tag ${REGISTRY}${GROUP}/notebook-server-r-ubuntu:${VER_R} ${REGISTRY}${GROUP}/notebook-server-r-ubuntu:${VER_R}"
pull-julia: check-khost check-knodes
	ssh ${KHOST} time pdsh -R ssh -w ${KNODES} "docker pull ${REGISTRY}${GROUP}/notebook-server-julia:${VER_JULIA}"
	ssh ${KHOST} time pdsh -R ssh -w ${KNODES} "docker tag ${REGISTRY}${GROUP}/notebook-server-julia:${VER_JULIA} ${REGISTRY}${GROUP}/notebook-server-julia:${VER_JULIA}"

pull-standard-dev: push-standard
	ssh 3 ctr -n k8s.io images pull ${REGISTRY}${GROUP}/notebook-server:${VER_STD}
pull-r-dev: push-r-ubuntu
	ssh 3 ctr -n k8s.io images pull ${REGISTRY}${GROUP}/notebook-server-r-ubuntu:${VER_R}

# Clean up disk space
prune-images: check-khost check-knodes
#	ssh ${KHOST} time pdsh -R ssh -w ${KNODES} 'docker rmi ${REGISTRY}${GROUP}/notebook-server:0.5.{0,1,2,3,4,5,6,7}'
	ssh ${KHOST} time pdsh -R ssh -w ${KNODES} 'docker image prune -f'
	ssh ${KHOST} time pdsh -R ssh -w ${KNODES} 'docker container prune -f'
	ssh ${KHOST} time pdsh -R ssh -w ${KNODES} 'docker images' | cut '-d:' '-f2-' | sort

# Aborts the process if necessary environment variables are not set
# https://stackoverflow.com/a/4731504/3005969
check-khost:
ifndef KHOST
	$(error KHOST is undefined. Format: KHOST=user@kubernetes_host.tld)
endif

check-knodes:
ifndef KNODES
	$(error KNODES is undefined. Format: KNODES=kubernetes-node[1-n].tld)
endif

check-hubrepo:
ifndef HUBREPO
	$(error HUBREPO is undefined. Format: HUBREPO=dockerhub_repo_name)
endif

# Git only tracks the execute bit of the owner, no other permissions. Running
# chmod makes sure that having a different umask on different machines doesn't
# cause cache invalidation.
pre-build:
	mkdir -p conda-history environment-yml
	chmod 600 environment.yml
	find hooks scripts -type f -exec chmod 600 {} \;
	find hooks scripts -type d -exec chmod 700 {} \;

container-builder:
	if ! docker buildx inspect jupyter > /dev/null 2>&1; then \
		docker buildx create --name jupyter --driver docker-container --use ; \
	fi
