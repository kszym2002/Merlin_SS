#!/bin/bash
# Author: An Shen
# Date: 2023-01-30

. /etc/profile

function log(){
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] - $1"
}

function get_latest_info(){
    local latest_info_file='/tmp/NeverIdle-latest-info.json'
    wget -q -O ${latest_info_file} https://api.github.com/repos/layou233/NeverIdle/releases/latest
    [[ $? -ne 0 ]] && log "Failed to get latest info" && exit 1
    latest_version=$(grep tag_name ${latest_info_file} | cut -d '"' -f 4| sed 's/^v//g')
    latest_comments=$(grep body ${latest_info_file} | cut -d '"' -f 4)
    rm -f ${latest_info_file}
}

function auto_set_mem_test_size(){
    mem_test='-m 2'
    if [[ $mem_total -lt 4 ]]
    then
        log "AMD doesn't need to test memory !"
        mem_test=''
    elif [[ $mem_total -lt 13  ]]
    then
        log "Memory test size: [1G]"
        mem_test='-m 1'
    else
        log "Memory test size: [2G]"
    fi
}

function download_and_run() {
    local base_download_url="https://github.com/layou233/NeverIdle/releases/download"
    local filename="NeverIdle-${platform}"
    local download_dir="/tmp"
    local download_url="${base_download_url}/${latest_version}/${filename}"
    
    mkdir -p $download_dir
    rm -f ${download_dir}/NeverIdle

    log "Downloading ${filename} to ${download_dir}/NeverIdle ..."
    wget -q -O ${download_dir}/NeverIdle ${download_url}
    [[ $? -ne 0 ]] && log "Download ${filename} failed" && exit 1

    chmod +x ${download_dir}/NeverIdle
    
    if [[ ${memory_test_size} -gt $mem_total ]] || [[ "x${memory_test_size}" == "x" ]]
    then
        log "invalid memory size: [${memory_test_size}]"
        auto_set_mem_test_size
    elif [[ "x${memory_test_size}" == "x0" ]]
    then
        mem_test=''
        log "Memory test disabled."
    else
        mem_test="-m ${memory_test_size}"
        log "Memory test size: [${memory_test_size}]"
    fi

    local cpu_test="-c 2h"
    if [[ "x${cpu_test_interval}" == "x" ]]
    then
        local cpu_test="-c 2h"
        log "cpu test interval is empty, set to default value: [2h]"
    elif [[ "x${cpu_test_interval}" == "x0" ]]
    then
        local cpu_test="-c 2h"
        log "cpu test can't disable, set to default value: [2h]."
    else
        local cpu_test="-c ${cpu_test_interval}h"
        log "cpu test interval: [${cpu_test_interval}h]"
    fi

    local network_test="-n 4h"
    if [[ "x${network_test_interval}" == "x" ]]
    then
        local network_test="-n 4h"
        log "network test interval is empty, set to default value: [4h]"
    elif [[ "x${network_test_interval}" == "x0" ]]
    then
        local network_test=""
        log "network test diabled."
    else
        local network_test="-n ${network_test_interval}h"
        log "network test interval: ${network_test_interval}"
    fi

    log "cmd: ${download_dir}/NeverIdle -c 12h -cp 0.2 -m 4 -n 4h"
    nohup ${download_dir}/NeverIdle -c 12h -cp 0.2 -m 4 -n 4h > ${download_dir}/NeverIdle.log 2>&1 &
    local pid=$(pgrep NeverIdle)
    log "NeverIdle [${pid}] is running"
    log "log file: ${download_dir}/NeverIdle.log"
    log "========================================"
    log "run 'pkill NeverIdle' to stop it."
    log "run 'rm -f ${download_dir}/NeverIdle ${download_dir}/NeverIdle.log' to clean it."
}

function print_help_msg(){
    echo "usage:"
    echo -e "\t-c \t cpu test interval, defaut: 2h, can't disable."
    echo -e "\t-m \t memory test size, value/total memory range: 0/<4 1G/<13 2G/>13, 0 to disable test"
    echo -e "\t-n \t network test interval, 0 to disable test"
    echo -e "\t-h \t show help info."
    exit 0
}

function read_args(){
    while getopts ":c:m:n:h" opt; do
        case "$opt" in
            c)
              cpu_test_interval="$OPTARG";;
            n)
              network_test_interval="$OPTARG";;
            m)
              memory_test_size="$OPTARG";;
            h)
              print_help_msg;;
        esac
    done

    if [[ "${cpu_test_interval}" -lt 0 ]]
    then
        log "invalid cpu test interval [${cpu_test_interval}], set to 2"
        cpu_test_interval="2"
    fi

    if [[ "${network_test_interval}" -lt 0 ]]
    then
        log "invalid network test interval [${network_test_interval}], set to 4"
        network_test_interval="4"
    fi

    if [[ "${memory_test_size}" -lt 0 ]]
    then
        log "invalid memory size [${memory_test_size}]"
        memory_test_size=""
    fi

}

function init(){
    mem_total=$(free -g | awk '/Mem/ {print $2}')

    case $(uname -m) in
    "x86_64")
        platform="linux-amd64"
        ;;
    "aarch64")
        platform="linux-arm64"
        ;;
    *)
        log "Unsupported platform !"
        exit 1
        ;;
    esac
}

function keep_stop(){
    pkill -9 NeverIdle
}


function main(){
    keep_stop
    init
    get_latest_info
    download_and_run
}
read_args "$@"
main
