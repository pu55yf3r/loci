#!/bin/bash

# NOTE(SamYaple): It is not safe to have multiple instances of this script
# running at once due to (poor) error handling
# TODO(SamYaple): Make this script safer if running outside the gate

set -eux

if [[ -e /etc/nodepool/provider ]]; then
    export RUNNING_IN_GATE=true
    export LOGS_DIR=${WORKSPACE}/logs
else
    export RUNNING_IN_GATE=false
    export LOGS_DIR=$(mktemp -d)
fi

function prep_log_dir {
    rm -rf ${LOGS_DIR}/build_error
    mkdir -p ${LOGS_DIR}/builds
}

function dump_error_logs {
    while read -r line; do
        cat $line
    done < ${LOGS_DIR}/build_error
    exit 1
}

function debian_override {
    mkdir -p etc/apt/
    echo 'APT::Get::AllowUnauthenticated "true";' > etc/apt/apt.conf
    cat <<-EOF > etc/apt/sources.list
	deb http://${NODEPOOL_MIRROR_HOST}/debian jessie main
	deb http://${NODEPOOL_MIRROR_HOST}/debian jessie-updates main
	deb http://${NODEPOOL_MIRROR_HOST}/debian jessie-security main
	EOF
}

function ubuntu_override {
    mkdir -p etc/apt/
    echo 'APT::Get::AllowUnauthenticated "true";' > etc/apt/apt.conf
    cat <<-EOF > etc/apt/sources.list
	deb http://${NODEPOOL_MIRROR_HOST}/ubuntu xenial main restricted universe
	deb http://${NODEPOOL_MIRROR_HOST}/ubuntu xenial-updates main restricted universe
	deb http://${NODEPOOL_MIRROR_HOST}/ubuntu xenial-security main restricted universe
	EOF
}

function centos_override {
    mkdir -p etc/yum.repos.d/
    cat <<-EOF > etc/yum.repos.d/CentOS-Base.repo
	[base]
	name=CentOS-\$releasever - Base
	baseurl=http://${NODEPOOL_MIRROR_HOST}/centos/\$releasever/os/\$basearch/
	gpgcheck=0

	[updates]
	name=CentOS-\$releasever - Updates
	baseurl=http://${NODEPOOL_MIRROR_HOST}/centos/\$releasever/updates/\$basearch/
	gpgcheck=0

	[extras]
	name=CentOS-\$releasever - Extras
	baseurl=http://${NODEPOOL_MIRROR_HOST}/centos/\$releasever/extras/\$basearch/
	gpgcheck=0
	EOF
}

function debian_backports_override {
    mkdir -p etc/apt/sources.list.d/
    cat <<-EOF > etc/apt/sources.list.d/backports.list
	deb http://${NODEPOOL_MIRROR_HOST}/debian jessie-backports main
	EOF
}

function debian_ceph_override {
    mkdir -p etc/apt/sources.list.d/
    # NOTE(SamYaple): Update after https://review.openstack.org/#/c/452547/
    # Currently Jewel repos are not mirrored.
    cat <<-EOF > etc/apt/sources.list.d/ceph.list
	deb http://download.ceph.com/debian-jewel/ jessie main
	EOF
    cat <<-EOF > ceph.asc
	-----BEGIN PGP PUBLIC KEY BLOCK-----
	Version: GnuPG v1

	mQINBFX4hgkBEADLqn6O+UFp+ZuwccNldwvh5PzEwKUPlXKPLjQfXlQRig1flpCH
	E0HJ5wgGlCtYd3Ol9f9+qU24kDNzfbs5bud58BeE7zFaZ4s0JMOMuVm7p8JhsvkU
	C/Lo/7NFh25e4kgJpjvnwua7c2YrA44ggRb1QT19ueOZLK5wCQ1mR+0GdrcHRCLr
	7Sdw1d7aLxMT+5nvqfzsmbDullsWOD6RnMdcqhOxZZvpay8OeuK+yb8FVQ4sOIzB
	FiNi5cNOFFHg+8dZQoDrK3BpwNxYdGHsYIwU9u6DWWqXybBnB9jd2pve9PlzQUbO
	eHEa4Z+jPqxY829f4ldaql7ig8e6BaInTfs2wPnHJ+606g2UH86QUmrVAjVzlLCm
	nqoGymoAPGA4ObHu9X3kO8viMBId9FzooVqR8a9En7ZE0Dm9O7puzXR7A1f5sHoz
	JdYHnr32I+B8iOixhDUtxIY4GA8biGATNaPd8XR2Ca1hPuZRVuIiGG9HDqUEtXhV
	fY5qjTjaThIVKtYgEkWMT+Wet3DPPiWT3ftNOE907e6EWEBCHgsEuuZnAbku1GgD
	LBH4/a/yo9bNvGZKRaTUM/1TXhM5XgVKjd07B4cChgKypAVHvef3HKfCG2U/DkyA
	LjteHt/V807MtSlQyYaXUTGtDCrQPSlMK5TjmqUnDwy6Qdq8dtWN3DtBWQARAQAB
	tCpDZXBoLmNvbSAocmVsZWFzZSBrZXkpIDxzZWN1cml0eUBjZXBoLmNvbT6JAjgE
	EwECACIFAlX4hgkCGwMGCwkIBwMCBhUIAgkKCwQWAgMBAh4BAheAAAoJEOhKwsBG
	DzmUXdIQAI8YPcZMBWdv489q8CzxlfRIRZ3Gv/G/8CH+EOExcmkVZ89mVHngCdAP
	DOYCl8twWXC1lwJuLDBtkUOHXNuR5+Jcl5zFOUyldq1Hv8u03vjnGT7lLJkJoqpG
	l9QD8nBqRvBU7EM+CU7kP8+09b+088pULil+8x46PwgXkvOQwfVKSOr740Q4J4nm
	/nUOyTNtToYntmt2fAVWDTIuyPpAqA6jcqSOC7Xoz9cYxkVWnYMLBUySXmSS0uxl
	3p+wK0lMG0my/gb+alke5PAQjcE5dtXYzCn+8Lj0uSfCk8Gy0ZOK2oiUjaCGYN6D
	u72qDRFBnR3jaoFqi03bGBIMnglGuAPyBZiI7LJgzuT9xumjKTJW3kN4YJxMNYu1
	FzmIyFZpyvZ7930vB2UpCOiIaRdZiX4Z6ZN2frD3a/vBxBNqiNh/BO+Dex+PDfI4
	TqwF8zlcjt4XZ2teQ8nNMR/D8oiYTUW8hwR4laEmDy7ASxe0p5aijmUApWq5UTsF
	+s/QbwugccU0iR5orksM5u9MZH4J/mFGKzOltfGXNLYI6D5Mtwrnyi0BsF5eY0u6
	vkdivtdqrq2DXY+ftuqLOQ7b+t1RctbcMHGPptlxFuN9ufP5TiTWSpfqDwmHCLsT
	k2vFiMwcHdLpQ1IH8ORVRgPPsiBnBOJ/kIiXG2SxPUTjjEGOVgeA
	=/Tod
	-----END PGP PUBLIC KEY BLOCK-----
	EOF
}

function ubuntu_ceph_override {
    mkdir -p etc/apt/sources.list.d/
    cat <<-EOF > etc/apt/sources.list.d/ceph.list
	deb http://${NODEPOOL_MIRROR_HOST}/debian-xenial/ xenial main
	EOF
    cat <<-EOF > ceph.asc
	-----BEGIN PGP PUBLIC KEY BLOCK-----
	Version: GnuPG v1

	mQINBFX4hgkBEADLqn6O+UFp+ZuwccNldwvh5PzEwKUPlXKPLjQfXlQRig1flpCH
	E0HJ5wgGlCtYd3Ol9f9+qU24kDNzfbs5bud58BeE7zFaZ4s0JMOMuVm7p8JhsvkU
	C/Lo/7NFh25e4kgJpjvnwua7c2YrA44ggRb1QT19ueOZLK5wCQ1mR+0GdrcHRCLr
	7Sdw1d7aLxMT+5nvqfzsmbDullsWOD6RnMdcqhOxZZvpay8OeuK+yb8FVQ4sOIzB
	FiNi5cNOFFHg+8dZQoDrK3BpwNxYdGHsYIwU9u6DWWqXybBnB9jd2pve9PlzQUbO
	eHEa4Z+jPqxY829f4ldaql7ig8e6BaInTfs2wPnHJ+606g2UH86QUmrVAjVzlLCm
	nqoGymoAPGA4ObHu9X3kO8viMBId9FzooVqR8a9En7ZE0Dm9O7puzXR7A1f5sHoz
	JdYHnr32I+B8iOixhDUtxIY4GA8biGATNaPd8XR2Ca1hPuZRVuIiGG9HDqUEtXhV
	fY5qjTjaThIVKtYgEkWMT+Wet3DPPiWT3ftNOE907e6EWEBCHgsEuuZnAbku1GgD
	LBH4/a/yo9bNvGZKRaTUM/1TXhM5XgVKjd07B4cChgKypAVHvef3HKfCG2U/DkyA
	LjteHt/V807MtSlQyYaXUTGtDCrQPSlMK5TjmqUnDwy6Qdq8dtWN3DtBWQARAQAB
	tCpDZXBoLmNvbSAocmVsZWFzZSBrZXkpIDxzZWN1cml0eUBjZXBoLmNvbT6JAjgE
	EwECACIFAlX4hgkCGwMGCwkIBwMCBhUIAgkKCwQWAgMBAh4BAheAAAoJEOhKwsBG
	DzmUXdIQAI8YPcZMBWdv489q8CzxlfRIRZ3Gv/G/8CH+EOExcmkVZ89mVHngCdAP
	DOYCl8twWXC1lwJuLDBtkUOHXNuR5+Jcl5zFOUyldq1Hv8u03vjnGT7lLJkJoqpG
	l9QD8nBqRvBU7EM+CU7kP8+09b+088pULil+8x46PwgXkvOQwfVKSOr740Q4J4nm
	/nUOyTNtToYntmt2fAVWDTIuyPpAqA6jcqSOC7Xoz9cYxkVWnYMLBUySXmSS0uxl
	3p+wK0lMG0my/gb+alke5PAQjcE5dtXYzCn+8Lj0uSfCk8Gy0ZOK2oiUjaCGYN6D
	u72qDRFBnR3jaoFqi03bGBIMnglGuAPyBZiI7LJgzuT9xumjKTJW3kN4YJxMNYu1
	FzmIyFZpyvZ7930vB2UpCOiIaRdZiX4Z6ZN2frD3a/vBxBNqiNh/BO+Dex+PDfI4
	TqwF8zlcjt4XZ2teQ8nNMR/D8oiYTUW8hwR4laEmDy7ASxe0p5aijmUApWq5UTsF
	+s/QbwugccU0iR5orksM5u9MZH4J/mFGKzOltfGXNLYI6D5Mtwrnyi0BsF5eY0u6
	vkdivtdqrq2DXY+ftuqLOQ7b+t1RctbcMHGPptlxFuN9ufP5TiTWSpfqDwmHCLsT
	k2vFiMwcHdLpQ1IH8ORVRgPPsiBnBOJ/kIiXG2SxPUTjjEGOVgeA
	=/Tod
	-----END PGP PUBLIC KEY BLOCK-----
	EOF
}

function centos_openstack_override {
    # TODO(SamYaple): Ceph mirror in infra?
    cat <<-EOF > etc/yum.repos.d/CentOS-OpenStack.repo
	[centos-openstack-ocata]
	includepkgs=liberasurecode*
	name=CentOS-7 - OpenStack Ocata
	baseurl=http://${NODEPOOL_MIRROR_HOST}/centos/7/cloud/\$basearch/openstack-ocata/
	gpgcheck=0
	EOF
}

function generate_override {
    set -eux

    source /etc/nodepool/provider

    if [[ -z "${NODEPOOL_MIRROR_HOST-}" ]]; then
        local NODEPOOL_MIRROR_HOST=mirror.${NODEPOOL_REGION,,}.${NODEPOOL_CLOUD}.openstack.org
    fi

    local TARBALL=${PWD}/override.tar.gz
    cd $(mktemp -d)

    ${DISTRO}_override
    if [[ -n ${PLUGIN-} ]]; then
        ${DISTRO}_${PLUGIN}_override
    fi
    if [[ -n ${EXTRA-} ]]; then
        ${DISTRO}_${EXTRA}_override
    fi

    tar cfz ${TARBALL} .
}

function builder {
    set -eux

    local directory=$1
    cd ${directory}
    source testvars
    if [[ ! -n "${PLUGIN-}" ]]; then
        local log=${LOGS_DIR}/builds/${DISTRO}.log
    else
        local log=${LOGS_DIR}/builds/${DISTRO}-${PLUGIN}.log
    fi

    local build_args=""

    if $RUNNING_IN_GATE; then
        build_args+="--build-arg OVERRIDE=override.tar.gz"
        build_args+=" --build-arg PROJECT_REPO=http://172.17.0.1/openstack/${ZUUL_PROJECT#*-} --build-arg PROJECT_REF=zuul"
        build_args+=" --build-arg SCRIPTS_REPO=http://172.17.0.1/openstack/loci --build-arg SCRIPTS_REF=zuul"
        $(generate_override)
    fi
    if [[ ! -n "${PLUGIN-}" ]]; then
        docker build --tag openstackloci/${PROJECT}:${DISTRO} --no-cache ${build_args} . 2>&1 > ${log} || echo ${log} >> ${LOGS_DIR}/build_error
    else
        docker build --tag openstackloci/${PROJECT}:${DISTRO}-${PLUGIN} --no-cache ${build_args} . 2>&1 > ${log} || echo ${log} >> ${LOGS_DIR}/build_error
    fi
}

# NOTE(SamYaple): We must export the functions for use with subshells (xargs)
export -f $(compgen -A function)

prep_log_dir

echo "Building images"
find . -mindepth 2 -maxdepth 2 -type f -name Dockerfile -printf '%h\0' | xargs -r -0 -P10 -n1 bash -c 'builder $1' _
echo "Building plugins"
find . -mindepth 3 -maxdepth 3 -type f -name Dockerfile -printf '%h\0' | xargs -r -0 -P10 -n1 bash -c 'builder $1' _

if [[ -f ${LOGS_DIR}/build_error ]]; then
    echo "Building images failure; Dumping failed logs to stdout"
    dump_error_logs
else
    echo "Building images successful"
fi
