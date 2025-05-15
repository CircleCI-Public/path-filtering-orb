#!/usr/bin/env bash
MAPPING="$(echo "$MAPPING" | circleci env subst)"
EXCLUDE="$(echo "$EXCLUDE" | circleci env subst)"
OUTPUT_PATH="$(echo "$OUTPUT_PATH" | circleci env subst)"
CONFIG_PATH="$(echo "$CONFIG_PATH" | circleci env subst)"
BASE_REVISION="$(echo "$BASE_REVISION" | circleci env subst)"
SAME_BASE_RUN="$(echo "$SAME_BASE_RUN" | circleci env subst)"

filtered_config_list_file="/tmp/filtered-config-list"
files_changed_file="/tmp/files-changed-list"
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
            raw_value="${i#* }"
            if ! echo "$raw_value" | jq -e . >/dev/null 2>&1; then
                value=$(printf '%s' "$raw_value" | jq -R .)
            else
                value="$raw_value"
            fi
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
    if [ "$SAME_BASE_RUN" == "0" ]; then
        echo "Already in the base revision, exiting"
        echo "{}" > "$OUTPUT_PATH"
        : > "$filtered_config_list_file"
        exit 0
    fi
    if git rev-parse HEAD~1; then
        MERGE_BASE=$(git rev-parse HEAD~1)
    else
        # This is the empty tree SHA in case the repo has no commits and the previous command dosn't work
        MERGE_BASE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
    fi
fi

echo "Comparing $MERGE_BASE...$CIRCLE_SHA1"
FILES_CHANGED=$(git -c core.quotepath=false diff --name-only "$MERGE_BASE" "$CIRCLE_SHA1")

echo "$FILES_CHANGED" > $files_changed_file

if [ -f "$MAPPING" ]; then
    # In this case MAPPING is a file with the mappings
    MAPPING=$(cat "$MAPPING")
fi
if [ -f "$EXCLUDE" ]; then
    # In this case EXCLUDE is a file with the exclusions
    EXCLUDE=$(cat "$EXCLUDE")
fi

filtered_mapping=()
filtered_files_set=()
while IFS= read -r line; do
    if is_mapping_line "$line"; then
        read -ra tokens <<< "$line"
        if [ "${#tokens[@]}" -eq 1 ]; then # <path>
            MAPPING_PATH="${tokens[0]}"
        elif [ "${#tokens[@]}" -eq 2 ]; then # <path> <config>
            MAPPING_PATH="${tokens[0]}"
            CONFIG_FILE="${tokens[1]}"
        elif [ "${#tokens[@]}" -eq 3 ]; then # <path> <key_param> <value_param>
            MAPPING_PATH="${tokens[0]}"
            PARAM_NAME="${tokens[1]}"
            PARAM_VALUE="${tokens[2]}"
        elif [ "${#tokens[@]}" -eq 4 ]; then # <path> <key_param> <value_param> <config>
            MAPPING_PATH="${tokens[0]}"
            PARAM_NAME="${tokens[1]}"
            PARAM_VALUE="${tokens[2]}"
            CONFIG_FILE="${tokens[3]}"
        else
            echo "Invalid mapping length of ${#tokens[@]}"
            exit 1
        fi
        regex="^$MAPPING_PATH\$"
        for i in $FILES_CHANGED; do
            PATH_EXCLUDED=0
            if [[ "$i" =~ $regex ]]; then
                while IFS= read -r ex; do
                    regex_exclude="^$ex\$"
                    if [[ "$i" =~ $regex_exclude ]]; then
                        PATH_EXCLUDED=1
                        break
                    fi
                done <<< "$EXCLUDE"
                if [ "$PATH_EXCLUDED" -eq 1 ]; then
                    continue
                fi

                if [ -n "$PARAM_VALUE" ]; then
                    filtered_mapping+=("$PARAM_NAME $PARAM_VALUE")
                fi
                if [[ -n "$CONFIG_FILE" ]] && ! already_in_list "$CONFIG_FILE" "${filtered_files_set[@]}"; then
                    filtered_files_set+=("$CONFIG_FILE")
                fi
                break
            fi
        done
    fi
done <<< "$MAPPING"

if [[ ${#filtered_mapping[@]} -eq 0 && -n "$PARAM_VALUE" ]]; then
    echo "No change detected in the paths defined in the mapping parameter"
fi

write_mappings "$OUTPUT_PATH" "${filtered_mapping[@]}"
if [[ ${#filtered_files_set[@]} -eq 0 ]]; then
    filtered_files_set+=("$CONFIG_PATH")
fi
write_filtered_config_list "$filtered_config_list_file" "${filtered_files_set[@]}"
