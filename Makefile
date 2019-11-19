UPSTREAM_SCIPY_NOTEBOOK_VER=2ce7c06a61a1  # Image updated Aug 11, 2019 03:40 AM
CRAN_URL=https://cran.microsoft.com/snapshot/2019-07-05/

# base image - jupyter stuff only, not much software
VER_BASE=1.8
# Python
VER_STD=1.8.8
# Julia
VER_JULIA=1.8.0
# R
VER_R=1.8.11-dev-genome
# OpenCV
VER_CV=1.8.0

# VER2_R=$(VER_R)-$(GIT_REV)
TEST_MEM_LIMIT="--memory=2G"

.PHONY: default

default:
	echo "Please specifiy a command to run"

full-rebuild: base standard test-standard


base:
	docker build -t aaltoscienceit/notebook-server-base:$(VER_BASE) . -f base.Dockerfile --build-arg=UPSTREAM_SCIPY_NOTEBOOK_VER=$(UPSTREAM_SCIPY_NOTEBOOK_VER)
standard:
	docker build -t aaltoscienceit/notebook-server:$(VER_STD) . -f standard.Dockerfile --build-arg=VER_BASE=$(VER_BASE)
#r:
#	docker build -t aaltoscienceit/notebook-server-r:0.4.0 --pull=false . -f r.Dockerfile
r:
	docker build -t aaltoscienceit/notebook-server-r-ubuntu:$(VER_R) --pull=false . -f r-ubuntu.Dockerfile --build-arg=VER_BASE=$(VER_BASE) --build-arg=CRAN_URL=$(CRAN_URL)
julia:
	docker build -t aaltoscienceit/notebook-server-julia:$(VER_JULIA) --pull=false . -f julia.Dockerfile --build-arg=VER_BASE=$(VER_BASE)
opencv:
	docker build -t notebook-server-opencv:$(VER_CV) --pull=false . -f opencv.Dockerfile --build-arg=VER_STD=$(VER_STD)


test-standard:
	mkdir -p /tmp/nbs-tests
	rsync -a --delete tests/ /tmp/nbs-tests/
	docker run --volume=/tmp/nbs-tests:/tests:ro ${TEST_MEM_LIMIT} aaltoscienceit/notebook-server:$(VER_STD) pytest -o cache_dir=/tmp/pytestcache /tests/python/${TESTFILE} ${TESTARGS}
#	CC="clang" CXX="clang++" jupyter nbconvert --exec --ExecutePreprocessor.timeout=300 pystan_demo.ipynb --stdout
test-standard-full: test-standard
	docker run --volume=/tmp/nbs-tests:/tests:ro ${TEST_MEM_LIMIT} aaltoscienceit/notebook-server:$(VER_STD) bash -c 'cd /tmp ; git clone https://github.com/avehtari/BDA_py_demos ; cd BDA_py_demos/demos_pystan/ ; CC=clang CXX=clang++ jupyter nbconvert --exec --ExecutePreprocessor.timeout=300 pystan_demo.ipynb --stdout > /dev/null'
	@echo
	@echo
	@echo
	@echo "All tests passed..."

test-r: r
	mkdir -p /tmp/tests
	rsync -a tests/ /tmp/tests/
	docker run --volume=/tmp/tests:/tests:ro ${TEST_MEM_LIMIT} aaltoscienceit/notebook-server-r-ubuntu:$(VER_R) Rscript /tests/r/test_bayes.r



push-standard: standard
	docker push aaltoscienceit/notebook-server:$(VER_STD)
push-r: r
	docker push aaltoscienceit/notebook-server-r-ubuntu:$(VER_R)
push-julia: julia
#	time docker save aaltoscienceit/notebook-server-julia:${VER_JULIA} | ssh manager ssh jupyter-k8s-node2.cs.aalto.fi 'docker load'
	docker push aaltoscienceit/notebook-server-julia:$(VER_JULIA)
push-dev: check-khost standard
	## NOTE: Saving and loading the whole image takes a long time. Pushing
	##       partial changes to a DockerHub repo using `push-devhub` is faster
	# time docker save aaltoscienceit/notebook-server-r-ubuntu:${VER_STD} | ssh ${KHOST} ssh jupyter-k8s-node2.cs.aalto.fi 'docker load'
	time docker save aaltoscienceit/notebook-server:${VER_STD} | ssh ${KHOST} ssh k8s-node4.cs.aalto.fi 'docker load'
push-devhub: check-khost check-hubrepo standard
	docker tag aaltoscienceit/notebook-server:${VER_STD} ${HUBREPO}/notebook-server:${VER_STD}
	docker push ${HUBREPO}/notebook-server:${VER_STD}
	ssh ${KHOST} ssh jupyter-k8s-node3.cs.aalto.fi "docker pull ${HUBREPO}/notebook-server:${VER_STD}"
push-devhub-base: check-khost check-hubrepo base
	docker tag aaltoscienceit/notebook-server-base:${VER_BASE} ${HUBREPO}/notebook-server-base:${VER_BASE}
	docker push ${HUBREPO}/notebook-server-base:${VER_BASE}
	ssh ${KHOST} ssh jupyter-k8s-node3.cs.aalto.fi "docker pull ${HUBREPO}/notebook-server-base:${VER_BASE}"

pull-standard: check-khost check-knodes
	ssh ${KHOST} time pdsh -R ssh -w ${KNODES} "docker pull aaltoscienceit/notebook-server:${VER_STD}"
pull-r: check-khost check-knodes
	ssh ${KHOST} time pdsh -R ssh -w ${KNODES} "docker pull aaltoscienceit/notebook-server-r-ubuntu:${VER_R}"
pull-julia: check-khost check-knodes
	ssh ${KHOST} time pdsh -R ssh -w ${KNODES} "docker pull aaltoscienceit/notebook-server-julia:${VER_JULIA}"

# Clean up disk space
prune-images: check-khost check-knodes
#	ssh ${KHOST} time pdsh -R ssh -w ${KNODES} 'docker rmi aaltoscienceit/notebook-server:0.5.{0,1,2,3,4,5,6,7}'
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
