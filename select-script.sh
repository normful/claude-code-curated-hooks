#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

get_available_scripts() {
    ls one-liner-shell-scripts/
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
    local script_path="one-liner-shell-scripts/$script_name"

    local event=$(sed -n '1s/^# event: //p' "$script_path")
    local matcher=$(sed -n '2s/^# matcher: //p' "$script_path")
    local command=$(sed -n '3p' "$script_path")

    echo "Selected: $script_name"
    echo
    echo "Event: $event"
    echo "Matcher: $matcher"
    echo "Command: $command"
}

main() {
    list_available_scripts

    local script_name
    script_name=$(get_user_choice)

    extract_script_metadata "$script_name"
}

main
