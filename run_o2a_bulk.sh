#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

CONVERTED_FOLDER="CRM_CASA_SEGMENT_MODEL_CONVERTED"
LOG_FILE="o2a_conversion_log_$(date +%Y%m%d_%H%M%S).log"

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

run_o2a() {
    local input_dir="$1"
    local output_dir="$2"
    local action_type="$3"

    log "INFO" "Converting $action_type action: $(basename "$input_dir")"
    log "INFO" "Input directory: $input_dir"
    log "INFO" "Output directory: $output_dir"

    if [ ! -f "$input_dir/hdfs/workflow.xml" ]; then
        log "ERROR" "workflow.xml not found in $input_dir/hdfs/"
        return 1
    fi

    ./bin/o2a -i "$input_dir" -o "$output_dir"
    if [ $? -ne 0 ]; then
        log "ERROR" "o2a conversion failed for $input_dir"
        return 1
    fi
    log "INFO" "Conversion successful for $(basename "$input_dir")"
}

log "INFO" "Starting bulk conversion process"

# Convert shell actions
for subflow in "$CONVERTED_FOLDER"/shell_actions/*; do
    if [ -d "$subflow" ]; then
        run_o2a "$subflow" "$CONVERTED_FOLDER/output/shell_$(basename "$subflow")" "shell"
    fi
done

# Convert subworkflow actions
for subflow in "$CONVERTED_FOLDER"/subworkflow_actions/*; do
    if [ -d "$subflow" ]; then
        run_o2a "$subflow" "$CONVERTED_FOLDER/output/subwf_$(basename "$subflow")" "subworkflow"
    fi
done

log "INFO" "Bulk conversion completed"
