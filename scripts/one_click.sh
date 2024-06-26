#!/usr/bin/env bash
set -euxo pipefail

if [ $# -lt 2 ]; then
    echo "Parameters required: <key_pair> <instance_count> [<branch_name>] [<repository_url>] [<enable_flamegraph>] "
    exit 1
fi
key_pair="$1"
slave_count=$2
branch="${3:-master}"
repo="${4:-https://github.com/Mazze-Chain/mazze-rust}"
enable_flamegraph=${5:-false}
slave_role=${key_pair}_exp_slave

nodes_per_host=1

run_latency_exp () {
    branch=$1
    exp_config=$2
    tps=$3
    max_block_size_in_bytes=$4

    #1) Create master instance and slave image
    ./create_slave_image.sh $key_pair $branch $repo
    ./ip.sh --public

    #2) Launch slave instances
    master_ip=`cat ips`
    slave_image=`cat slave_image`
    ssh ubuntu@${master_ip} "cd ./mazze-rust/tests/extra-test-toolkits/scripts;rm exp.log;rm -rf ~/.ssh/known_hosts;./launch-on-demand.sh $slave_count $key_pair $slave_role $slave_image;"

    # The images already have the compiled binary setup in `setup_image.sh`,
    # but we can use the following to recompile if we have code updated after image setup.
    #ssh ubuntu@${master_ip} "cd ./mazze-rust/tests/extra-test-toolkits/scripts;export RUSTFLAGS=\"-g\" && cargo build --release ;\
    #parallel-scp -O \"StrictHostKeyChecking no\" -h ips -l ubuntu -p 1000 ../../../target/release/mazze ~ |grep FAILURE|wc -l;"

    #4) Run experiments
    flamegraph_option=""
    if [ $enable_flamegraph = true ]; then
        flamegraph_option="--enable-flamegraph"
    fi
    ssh -tt ubuntu@${master_ip} "cd ./mazze-rust/tests/extra-test-toolkits/scripts;python3 ./exp_latency.py \
    --vms $slave_count \
    --batch-config \"$exp_config\" \
    --storage-memory-gb 16 \
    --bandwidth 20 \
    --tps $tps \
    --send-tx-period-ms 200 \
    $flamegraph_option \
    --nodes-per-host $nodes_per_host \
    --max-block-size-in-bytes $max_block_size_in_bytes \
    --enable-tx-propagation "

    #5) Terminate slave instances
    rm -rf tmp_data
    mkdir tmp_data
    cd tmp_data
    ../list-on-demand.sh $slave_role || true
    ../terminate-on-demand.sh
    cd ..

    # Download results
    archive_file="exp_stat_latency.tgz"
    log="exp_stat_latency.log"
    scp ubuntu@${master_ip}:~/mazze-rust/tests/extra-test-toolkits/scripts/${archive_file} .
    tar xfvz $archive_file
    cat $log
    mv $archive_file ${archive_file}.`date +%s`
    mv $log ${log}.`date +%s`
}

# Parameter for one experiment is <block_gen_interval_ms>:<txs_per_block>:<tx_size>:<num_blocks>
# Different experiments in a batch is divided by commas
# Example: "250:1:150000:1000,250:1:150000:1000,250:1:150000:1000,250:1:150000:1000"
exp_config="250:1:300000:2000"

# For experiments with --enable-tx-propagation , <txs_per_block> and <tx_size> will not take effects.
# Block size is limited by `max_block_size_in_bytes`.

tps=6000
max_block_size_in_bytes=300000
echo "start run $branch"
run_latency_exp $branch $exp_config $tps $max_block_size_in_bytes

# Terminate master instance and delete slave images
# Comment this line if the data on the master instances are needed for further analysis
./terminate-on-demand.sh
