#!/usr/bin/env bash
function detectScriptLocation() {
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
        DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    echo "${DIR}"
}

readonly SCRIPT_DIR="$(detectScriptLocation)"
readonly DEFAULT_RUN="/builder/build-in-docker.sh"
readonly UNRAID_VERSION="6.12.1"
#readonly UNRAID_VERSION="6.11.5"
readonly CONFIG_DIR="${SCRIPT_DIR}/../config"
readonly OUTPUT_DIR="${SCRIPT_DIR}/../output"
readonly CACHE_DIR="${SCRIPT_DIR}/../cache"

readonly MODUL_GIT_REMOTE="https://github.com/mafredri/asustor-platform-driver.git"
readonly MODUL_GIT_BRANCH="it87"

readonly HOST_KERNEL_BUILD_SCRIPT="${SCRIPT_DIR}/unraid-module-builder/build.sh"

mkdir -p "${CONFIG_DIR}"
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${CACHE_DIR}"

function runInDocker(){
    DOCKER_RUN_OPTS=""
    DOCKER_RUN_OPTS="${DOCKER_RUN_OPTS} -v ${HOST_KERNEL_BUILD_SCRIPT}:/opt/scripts/build.sh:Z"
    DOCKER_RUN_OPTS="${DOCKER_RUN_OPTS} --entrypoint="""

    DOCKER_RUN_ARGS=""
    if [ -z "${1}" ]; then
        DOCKER_RUN_ARGS="${DOCKER_RUN_ARGS} ${DEFAULT_RUN}"
    else
        DOCKER_RUN_ARGS="${@}"
    fi

    exec docker run --rm -it \
    -v "${CONFIG_DIR}:/config" \
    -v "${OUTPUT_DIR}:/output" \
    -v "${SCRIPT_DIR}:/builder" \
    -e "UNRAID_VERSION=${UNRAID_VERSION}" \
    -e "CPU_COUNT=4" \
    -v "${CACHE_DIR}:/cache" \
    ${DOCKER_RUN_OPTS} \
    gameonwhales/unraid-module-builder ${DOCKER_RUN_ARGS}
}

if [ ! -f /.dockerenv ]; then
    echo $1
    runInDocker "$@"
    exit
fi

function build_kernel(){
    # Create a Dummy file if no Kernel Module Configs exists
    ls /config/*.config ||  touch /config/dummy.config

    /opt/scripts/build.sh
}

function build_dkms_asustor_it87(){
    local target_path="$(realpath /${CACHE_DIR}/asustor_it87)"
    git clone "${MODUL_GIT_REMOTE}" -b "${MODUL_GIT_BRANCH}" "${target_path}"

    "${SCRIPT_DIR}/compile.sh" "${target_path}"
}

function prepare_system(){
    apt update -y
    apt install -y git binwalk
}

function main(){
    # Inject dummy execs
    export PATH="${SCRIPT_DIR}/dummy:${PATH}"

    prepare_system
    build_kernel
    echo $KERNEL_VERSION
    build_dkms_asustor_it87
}

#bash
main
