CONF_DIR="$THIS_DIR/../../conf"
RF_CONF_FILE="$CONF_DIR/rf.conf"
NOW=$(date +%Y%m%d-%H%M%S)

function cmd_help() {
    echo "$0 <dataset> [-conf <rf.conf>]"
    echo "   Run RF with help of $TOOL"
    echo "   <dataset>       : name of existing dataset"
    echo "   -conf <rf.conf> : load also given RF config file (override all other configurations)" 
    echo
}

function list_datasets() {
local dir="$1"
cat <<EOF
Available datasets:
$(ls -1 "$dir" | sed -s 's/^/  /')
EOF
}

function check_datasets() {
    if [ ! -f $RF_TRAIN_DS ]; then
        echo "Training dataset $RF_TRAIN_DS does not exist!"
        cmd_help
        list_datasets "$RF_DSS_DIR"
        exit -1
    fi
    if [ ! -f $RF_TEST_DS ]; then
        echo "Testing dataset $RF_TEST_DS does not exist!"
        cmd_help
        list_datasets "$RF_DSS_DIR"
        exit -1
    fi
    if [ -z "$RF_MTRY" ]; then
       echo "Property RF_MTRY has to be explicitely specified in rf.conf for dataset $(dirname $RF_TRAIN_DS) !"
       exit -1
    fi
    if [ -z "$RF_PRED_CLASS_IDX" ]; then
       echo "Property RF_PRED_CLASS_IDX has to be explicitely specified in rf.conf for dataset $(dirname $RF_TRAIN_DS) !"
       exit -1
    fi
}

function parse_conf() {
    # Parse global RF configuration
    source "$RF_CONF_FILE"

    # Parse dataset local RF configuration
    if [ -f "$RF_DS_CONF" ]; then
        source "$RF_DS_CONF"
    fi

    # Parse local config file
    if [ -f "$RF_LOCAL_CONF" ]; then
        source "$RF_LOCAL_CONF"
    fi

    # Parse given config file
    for PARAM in "$@"; do
        case $PARAM in
            -conf) 
                shift
                LOCAL_CONF="$1"
                shift
                ;;
            -h2orng)
                shift
                RF_H2O_RNG="$1"
                shift
                ;;
            -sample)
                shift
                RF_SAMPLING_RATIO="$1"
                shift
                ;;
            -dss)
                list_datasets "$RF_DSS_DIR"
                exit 
                ;;
        esac
    done

    RF_ADDITIONAL_PARAMS="$@"
    echo "Cmd line options:"
    echo "  LOCAL_CONF=$LOCAL_CONF"
    echo "  RF_H2O_RNG=$RF_H2O_RNG"
    echo "  RF_SAMPLING_RATIO=$RF_SAMPLING_RATIO"
    echo "  RF_ADDITIONAL_PARAMS=$RF_ADDITIONAL_PARAMS"
    
    if [ -f "$LOCAL_CONF" ]; then
        source "$LOCAL_CONF"
    elif [ -n "$LOCAL_CONF" ]; then
        echo "File \"$LOCAL_CONF\" does not exist!"
        exit
    fi

    # ### End of configuraiton ###
}

function compute_time_diff() {
local start=$1
local end=$2
echo "$((end - start)) seconds"
}

function print_conf() {
#cat | tee "$RF_OUTPUT_RUNCONFG" <<EOF
cat > "$RF_OUTPUT_RUNCONFG" <<EOF
========================================================
RF configuration:
   Train dataset: $RF_TRAIN_DS
   Test dataset:  $RF_TEST_DS
   RF output:     $RF_OUTPUT_DIR

   Seed:          $RF_SEED
   Num of trees:  $RF_NTREES

   All RF variables:
$(set -o posix; set | grep "^RF_" | sed -e "s/^/        /")

   Dataset configuration:
$(cat  "$RF_DS_CONF" | sed -e "s/^/       /" )
========================================================
EOF
cat "$RF_OUTPUT_RUNCONFG"
}

function print_header() {
local HEADER="Trees,Features,Sample,BinLimit,LeavesMin,LeavesMean,LeavesMax,DepthMin,DepthMean,DepthMax,TrainSize,OOB,TestSize,ClassError,TrainTime,TestTime"
echo $HEADER
}

function print_stats() {
    local OUTPUT_FILE=$1
    echo 
    (print_header; tail -n 1 "$OUTPUT_FILE" ) | column -s, -t
}

function h2o_get_run_stats() {
    local f="$1"

    ntrees=$(tail -n 100 "$f" | grep "Number of trees:" | uniq | sed -e "s/[^:]*: \([0-9]*\).*/\1/")
    mtry=$(tail -n 100 "$f" | grep "at each split:" | uniq | sed -e "s/[^:]*: \([0-9]*\).*/\1/")

    oobee=$(tail -n 100 "$f" | grep "err. rate:" | head -n 1 | sed -e "s/[^(]*(\([^)]*\))/\1/")
    classerr=$(tail -n 100 "$f" | grep "err. rate:" | tail -n 1 | sed -e "s/[^(]*(\([^)]*\))/\1/")
    
    tree_stats=$(tail -n 100 "$f" | grep "Avg tree leaves" | uniq | sed -e "s/[^:]*: \(.*\)/\1/" | sed -e "s/\//,/g" -e "s/ //g")
    depth_stats=$(tail -n 100 "$f" | grep "Avg tree depth" | uniq | sed -e "s/[^:]*: \(.*\)/\1/" | sed -e "s/\//,/g" -e "s/ //g")

    train_size=$(tail -n 100 "$f" | grep "Validated on" | head -n 1 | sed -e "s/[^:]*: \([0-9]*\)$/\1/")
    test_size=$(tail -n 100 "$f" | grep "Validated on" | tail -n 1 | sed -e "s/[^:]*: \([0-9]*\)$/\1/")

    sample=$(grep "\-sample" "$f"| head -n 1 | sed -e "s/.*-sample=\([0-9]*\) .*/\1/" )
    binlimit=$(grep "\-binLimit" "$f"| head -n 1 | sed -e "s/.*-binLimit=\([0-9]*\) .*/\1/" )

    traintime=$(grep "Random forest finished" "$f" | sed -e "s/.* Random forest finished in \([^ ]*\) .*/\1/")
    testtime=$(grep "Validation done in" "$f" | sed -e "s/.* Validation done in: \([^ ]*\) .*/\1/")
#    echo "ntrees=$ntrees"
#    echo "mtry=$mtry"
#    echo "oobee=$oobee"
#    echo "classerr=$classerr"
#    echo "tree_stats=$tree_stats"
#    echo "depth_stats=$depth_stats"
#    echo "train_size=$train_size"
#    echo "test_size=$test_size"
    echo "$ntrees,$mtry,$sample,$binlimit,$tree_stats,$depth_stats,$train_size,$oobee,$test_size,$classerr,$traintime,$testtime"
}
