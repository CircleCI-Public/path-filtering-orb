#!/usr/bin/env bash
MAPPING="$(echo "$MAPPING" | circleci env subst)"
OUTPUT_PATH="$(echo "$OUTPUT_PATH" | circleci env subst)"
CONFIG_PATH="$(echo "$CONFIG_PATH" | circleci env subst)"
BASE_REVISION="$(echo "$BASE_REVISION" | circleci env subst)"

filtered_config_list_file="/tmp/filtered-config-list"
git checkout "$BASE_REVISION"
git checkout "$CIRCLE_SHA1"
MERGE_BASE=$(git merge-base "$BASE_REVISION" "$CIRCLE_SHA1")

function is_mapping_line() {
    local line="$1"
    local trimmed
    trimmed=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    if [[ -z "$trimmed" || "$trimmed" == \#* ]]; then
        return 1
    else 
        return 0
    fi
}

function write_mappings() {
    local output_path="$1"
    shift
    {
        echo -n "{"
        local first=true
        for i in "$@"; do
            key="${i%% *}" 
            value=$(printf '%s' "${i#* }" | jq .)
            if [ "$first" = true ]; then
                first=false
            else
                echo -n ","
            fi
            printf '"%s":%s' "$key" "$value"
        done
        echo "}"
    } > "$output_path"
}

function write_filtered_config_list() {
    local file_path="$1"
    shift
    : > "$file_path"
    for file in "$@"; do
        echo "$file" >> "$file_path"
    done
}

function already_in_list() {
    local item="$1"
    shift
    for existing in "$@"; do
        [[ "$existing" == "$item" ]] && return 0
    done
    return 1
}

if [[ "$MERGE_BASE" == "$CIRCLE_SHA1" ]]; then
    if git rev-parse HEAD~1; then
        MERGE_BASE=$(git rev-parse HEAD~1)
    else
        # This is the empty tree SHA in case the repo has no commits and the previous command dosn't work
        MERGE_BASE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
    fi
fi

echo "Comparing $MERGE_BASE...$CIRCLE_SHA1"
FILES_CHANGED=$(git -c core.quotepath=false diff --name-only "$MERGE_BASE" "$CIRCLE_SHA1")

echo "$FILES_CHANGED"

if [ -f "$MAPPING" ]; then
    # In this case MAPPING is a file with the mappings
    MAPPING=$(cat "$MAPPING")
fi

filtered_mapping=()
filtered_files_set=()
while IFS= read -r line; do
    if is_mapping_line "$line"; then
        read -ra tokens <<< "$line"
        
        if [ "${#tokens[@]}" -eq 3 ]; then
            MAPPING_PATH="${tokens[0]}"
            PARAM_NAME="${tokens[1]}"
            PARAM_VALUE="${tokens[2]}"
        elif [ "${#tokens[@]}" -eq 4 ]; then
            MAPPING_PATH="${tokens[0]}"
            PARAM_NAME="${tokens[1]}"
            PARAM_VALUE="${tokens[2]}"
            CONFIG_FILE="${tokens[3]}"
        else
            echo "Invalid mapping length of ${#tokens[@]}"
            exit 1
        fi
        if ! PARAM_VALUE=$(echo "$PARAM_VALUE" | jq .); then
            echo "Cannot parse pipeline value $PARAM_VALUE from mapping"
            exit 2
        fi
        type=$(echo "$PARAM_VALUE" | jq -r 'type')
        if [[ "$type" == "string" || "$type" == "number" || "$type" == "boolean" ]]; then
            regex="^$MAPPING_PATH\$"
            for i in $FILES_CHANGED; do
                if [[ "$i" =~ $regex ]]; then
                    filtered_mapping+=("$PARAM_NAME $PARAM_VALUE")

                    if [[ -n "$CONFIG_FILE" ]] && ! already_in_list "$CONFIG_FILE" "${filtered_files_set[@]}"; then
                        filtered_files_set+=("$CONFIG_FILE")
                    fi
                    break
                fi
            done
        else
            echo "Pipeline parameters can only be integer, string or boolean type."
            echo "Found $PARAM_VALUE of type $type"
            exit 3
        fi
    fi
done <<< "$MAPPING"

if [[ ${#filtered_mapping[@]} -eq 0 ]]; then
    echo "No change detected in the paths defined in the mapping parameter"
fi

write_mappings "$OUTPUT_PATH" "${filtered_mapping[@]}"
if [[ ${#filtered_files_set[@]} -eq 0 ]]; then
    filtered_files_set+=("$CONFIG_PATH")
fi
write_filtered_config_list "$filtered_config_list_file" "${filtered_files_set[@]}"
