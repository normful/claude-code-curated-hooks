#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_available_scripts() {
    ls "$SCRIPT_DIR/one-liners/"
}

list_available_scripts() {
    echo "Available one-liner Claude Code hooks:"
    echo

    local -a options=($(get_available_scripts))
    for i in "${!options[@]}"; do
        echo "$((i+1)). ${options[i]}"
    done
}

get_user_choice() {
    local -a options=($(get_available_scripts))
    local choice

    echo
    read -p "Enter the number of the script you want to install: " choice

    # Validate choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#options[@]}" ]; then
        echo "Invalid choice. Please enter a number between 1 and ${#options[@]}."
        exit 1
    fi

    # Remove any trailing whitespace/newlines
    local selected="${options[$((choice-1))]}"
    echo "${selected}" | tr -d '\n\r'
}

extract_script_metadata() {
    local script_name="$1"
    # Strip any remaining whitespace/newlines
    script_name=$(echo "$script_name" | tr -d '\n\r ')
    local script_path="$SCRIPT_DIR/one-liners/$script_name"

    local event=$(sed -n '1s/^# event: //p' "$script_path")
    local matcher=$(sed -n '2s/^# matcher: //p' "$script_path")
    local command=$(sed -n '3p' "$script_path")

    echo "Selected: $script_name"

    # Save the extracted values
    HOOK_EVENT="$event"
    HOOK_MATCHER="$matcher"
    HOOK_COMMAND="$command"
}

choose_installation_location() {
    echo >&2
    echo "Where would you like to install this hook?" >&2
    echo >&2
    echo "1. $(pwd)/.claude/settings.local.json (personal project-specific settings)" >&2
    echo "2. $(pwd)/.claude/settings.json (team-shared project-specific settings)" >&2
    echo "3. ~/.claude/settings.json (personal settings for all projects)" >&2
    echo >&2

    local choice
    read -p "Enter your choice (1-3): " choice >&2

    case "$choice" in
        1)
            echo "$(pwd)/.claude/settings.local.json"
            ;;
        2)
            echo "$(pwd)/.claude/settings.json"
            ;;
        3)
            echo "$HOME/.claude/settings.json"
            ;;
        *)
            echo "Invalid choice. Please enter 1, 2, or 3." >&2
            exit 1
            ;;
    esac
}

install_hook() {
    local settings_file="$1"

    echo
    echo "Installing hook to: $settings_file"

    # Create directory if it doesn't exist
    local settings_dir=$(dirname "$settings_file")
    if [[ ! -d "$settings_dir" ]]; then
        mkdir -p "$settings_dir"
        echo "Created directory: $settings_dir"
    fi

    # Initialize file with empty JSON if it doesn't exist
    if [[ ! -f "$settings_file" ]]; then
        echo '{}' > "$settings_file"
        echo "Created new settings file: $settings_file"
    fi

    # Normalize matcher (use null for no matcher)
    local matcher_value="${HOOK_MATCHER:-null}"

    # Find matching entry or create new one
    local temp_file=$(mktemp)
    jq --arg event "$HOOK_EVENT" \
       --argjson matcher "$([[ "$matcher_value" == "null" ]] && echo "null" || echo "\"$HOOK_MATCHER\"")" \
       --argjson command "\"$HOOK_COMMAND\"" \
       '
       # Ensure hooks structure exists
       .hooks = (.hooks // {}) |
       .hooks[$event] = (.hooks[$event] // []) |

       # Find existing entry that matches our criteria
       if (.hooks[$event] | map(
           if $matcher == null then
               (has("matcher") | not)
           else
               (.matcher == $matcher)
           end
       ) | any) then
           # Add to existing matching entry
           .hooks[$event] = (.hooks[$event] | map(
               if (($matcher == null and (has("matcher") | not)) or (.matcher == $matcher)) then
                   .hooks += [{type: "command", command: $command}]
               else
                   .
               end
           ))
       else
           # Create new entry
           .hooks[$event] += [
               if $matcher == null then
                   {hooks: [{type: "command", command: $command}]}
               else
                   {matcher: $matcher, hooks: [{type: "command", command: $command}]}
               end
           ]
       end
       ' "$settings_file" > "$temp_file"

    if [[ $? -eq 0 ]]; then
        mv "$temp_file" "$settings_file"
        echo
        echo "✓ Hook successfully installed! Hooks in $settings_file now look like:"
        jq '.hooks' "$settings_file"
    else
        rm -f "$temp_file"
        echo "Error: Failed to install hook." >&2
        exit 1
    fi
}

check_dependencies() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required but not installed." >&2
        echo "Please install jq: https://jqlang.github.io/jq/download/" >&2
        exit 1
    fi
}

main() {
    check_dependencies

    list_available_scripts

    local script_name
    script_name=$(get_user_choice)

    extract_script_metadata "$script_name"

    local settings_file
    settings_file=$(choose_installation_location)

    install_hook "$settings_file"
}

main
