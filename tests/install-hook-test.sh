#!/usr/bin/env bash

# Source the script to test (without executing main)
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")/.."
source <(sed '/^main$/,$d' "$SCRIPT_DIR/install-hook.sh")

# Test setup function
function setup() {
    # Create temporary test directories
    TEST_DIR=$(mktemp -d)
    TEST_ONE_LINER_SCRIPTS_DIR="$TEST_DIR/one-liners"
    TEST_PY_HOOKS_DIR="$TEST_DIR/py-hooks"
    mkdir -p "$TEST_ONE_LINER_SCRIPTS_DIR"
    mkdir -p "$TEST_PY_HOOKS_DIR"

    # Override SCRIPT_DIR to point to test directory
    SCRIPT_DIR="$TEST_DIR"

    # Create test script files
    cat > "$TEST_ONE_LINER_SCRIPTS_DIR/test-script1.sh" << 'EOF'
# event: PostToolUse
# matcher: Write|Edit
echo "Complex command with spaces & special chars: $HOME/path with spaces/*.txt" | grep -E "pattern.*"
EOF

    cat > "$TEST_ONE_LINER_SCRIPTS_DIR/test-script2.sh" << 'EOF'
# event: PreToolUse
# matcher: Read
curl -H "Content-Type: application/json" -d '{"key": "value with \"quotes\"", "path": "/tmp/file name.txt"}' https://api.example.com/webhook
EOF

    cat > "$TEST_ONE_LINER_SCRIPTS_DIR/test-script3.sh" << 'EOF'
# event: PostToolUse
# matcher:
python3 -c "import os; print(f'Processing file: {os.environ.get(\"FILE_PATH\", \"default.txt\")}'); os.system('ls -la \"$PWD\"')"
EOF

    # Create test Python hook files
    cat > "$TEST_PY_HOOKS_DIR/test-notification.py" << 'EOF'
#!/usr/bin/env python3
# event: Notification
# matcher: *

print("Test notification hook")
EOF

    cat > "$TEST_PY_HOOKS_DIR/test-posttool.py" << 'EOF'
#!/usr/bin/env python3
# event: PostToolUse
# matcher: Write

print("Test post-tool hook")
EOF

    cat > "$TEST_PY_HOOKS_DIR/test-no-matcher.py" << 'EOF'
#!/usr/bin/env python3
# event: PreToolUse

print("Test hook without matcher")
EOF

    # Change to test directory
    cd "$TEST_DIR"
}

# Test cleanup function
function teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Tests for get_available_scripts function
function test_get_available_scripts_returns_all_script_files_in_directory() {
    setup
    local result=$(get_available_scripts | sort)
    local expected=$'one-liners/test-script1.sh\none-liners/test-script2.sh\none-liners/test-script3.sh\npy-hooks/test-no-matcher.py\npy-hooks/test-notification.py\npy-hooks/test-posttool.py'
    assert_same "$expected" "$result"
    teardown
}

function test_get_available_scripts_returns_empty_when_no_scripts_exist() {
    TEST_DIR=$(mktemp -d)
    mkdir -p "$TEST_DIR/one-liners"
    mkdir -p "$TEST_DIR/py-hooks"
    cd "$TEST_DIR"

    # Override SCRIPT_DIR for this test
    SCRIPT_DIR="$TEST_DIR"

    local result=$(get_available_scripts)
    assert_same "" "$result"

    cd /
    rm -rf "$TEST_DIR"
}

# Tests for extract_script_metadata function
function test_extract_script_metadata_parses_event_matcher_and_command_correctly() {
    setup
    extract_script_metadata "one-liners/test-script1.sh"

    assert_same "PostToolUse" "$HOOK_EVENT"
    assert_same "Write|Edit" "$HOOK_MATCHER"
    assert_same 'echo "Complex command with spaces & special chars: $HOME/path with spaces/*.txt" | grep -E "pattern.*"' "$HOOK_COMMAND"
    teardown
}

function test_extract_script_metadata_handles_missing_matcher_gracefully() {
    setup
    extract_script_metadata "one-liners/test-script3.sh"

    assert_same "PostToolUse" "$HOOK_EVENT"
    assert_same "" "$HOOK_MATCHER"
    assert_same 'python3 -c "import os; print(f'"'"'Processing file: {os.environ.get(\"FILE_PATH\", \"default.txt\")}'"'"'); os.system('"'"'ls -la \"$PWD\"'"'"')"' "$HOOK_COMMAND"
    teardown
}

function test_extract_script_metadata_supports_different_hook_events() {
    setup
    extract_script_metadata "one-liners/test-script2.sh"

    assert_same "PreToolUse" "$HOOK_EVENT"
    assert_same "Read" "$HOOK_MATCHER"
    assert_same 'curl -H "Content-Type: application/json" -d '\''{"key": "value with \"quotes\"", "path": "/tmp/file name.txt"}'\'' https://api.example.com/webhook' "$HOOK_COMMAND"
    teardown
}

function test_extract_script_metadata_handles_python_files() {
    setup
    extract_script_metadata "py-hooks/test-notification.py"

    assert_same "Notification" "$HOOK_EVENT"
    assert_same "*" "$HOOK_MATCHER"
    assert_same "$TEST_DIR/py-hooks/test-notification.py" "$HOOK_COMMAND"
    teardown
}

function test_extract_script_metadata_handles_python_files_without_matcher() {
    setup
    extract_script_metadata "py-hooks/test-no-matcher.py"

    assert_same "PreToolUse" "$HOOK_EVENT"
    assert_same "" "$HOOK_MATCHER"
    assert_same "$TEST_DIR/py-hooks/test-no-matcher.py" "$HOOK_COMMAND"
    teardown
}

function test_extract_script_metadata_handles_different_python_events() {
    setup
    extract_script_metadata "py-hooks/test-posttool.py"

    assert_same "PostToolUse" "$HOOK_EVENT"
    assert_same "Write" "$HOOK_MATCHER"
    assert_same "$TEST_DIR/py-hooks/test-posttool.py" "$HOOK_COMMAND"
    teardown
}

# Tests for check_dependencies function
function test_check_dependencies_validates_jq_installation() {
    if command -v jq >/dev/null 2>&1; then
        # jq is available, function should succeed
        assert_successful_code "check_dependencies"
    else
        # jq is not available, function should fail
        assert_general_error "check_dependencies"
    fi
}

# Tests for install_hook function - these require more complex setup
function test_install_hook_creates_new_settings_file_when_none_exists() {
    TEST_DIR=$(mktemp -d)
    TEST_SETTINGS="$TEST_DIR/test-settings.json"

    # Set up hook variables
    HOOK_EVENT="PostToolUse"
    HOOK_MATCHER="Write"
    HOOK_COMMAND="echo test"

    install_hook "$TEST_SETTINGS"

    assert_file_exists "$TEST_SETTINGS"

    # Check that the JSON structure is correct
    local event_count=$(jq -r '.hooks.PostToolUse | length' "$TEST_SETTINGS")
    assert_same "1" "$event_count"

    local command_in_file=$(jq -r '.hooks.PostToolUse[0].hooks[0].command' "$TEST_SETTINGS")
    assert_same "echo test" "$command_in_file"

    rm -rf "$TEST_DIR"
}

function test_install_hook_appends_command_to_existing_matcher_entry() {
    TEST_DIR=$(mktemp -d)
    TEST_SETTINGS="$TEST_DIR/test-settings.json"

    # Create initial settings file
    cat > "$TEST_SETTINGS" << 'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "existing command"
          }
        ]
      }
    ]
  }
}
EOF

    # Set up hook variables to add another command to same matcher
    HOOK_EVENT="PostToolUse"
    HOOK_MATCHER="Write"
    HOOK_COMMAND="new command"

    install_hook "$TEST_SETTINGS"

    # Check that there are now 2 commands for the same matcher
    local command_count=$(jq -r '.hooks.PostToolUse[0].hooks | length' "$TEST_SETTINGS")
    assert_same "2" "$command_count"

    # Check the new command was added
    local new_command=$(jq -r '.hooks.PostToolUse[0].hooks[1].command' "$TEST_SETTINGS")
    assert_same "new command" "$new_command"

    rm -rf "$TEST_DIR"
}

function test_install_hook_creates_separate_entry_for_different_matcher() {
    TEST_DIR=$(mktemp -d)
    TEST_SETTINGS="$TEST_DIR/test-settings.json"

    # Create initial settings file
    cat > "$TEST_SETTINGS" << 'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "existing command"
          }
        ]
      }
    ]
  }
}
EOF

    # Set up hook variables for different matcher
    HOOK_EVENT="PostToolUse"
    HOOK_MATCHER="Edit"
    HOOK_COMMAND="edit command"

    install_hook "$TEST_SETTINGS"

    # Check that there are now 2 entries in PostToolUse array
    local entry_count=$(jq -r '.hooks.PostToolUse | length' "$TEST_SETTINGS")
    assert_same "2" "$entry_count"

    # Check the new entry has correct matcher
    local new_matcher=$(jq -r '.hooks.PostToolUse[1].matcher' "$TEST_SETTINGS")
    assert_same "Edit" "$new_matcher"

    rm -rf "$TEST_DIR"
}

function test_install_hook_creates_entry_without_matcher_when_not_specified() {
    TEST_DIR=$(mktemp -d)
    TEST_SETTINGS="$TEST_DIR/test-settings.json"

    # Set up hook variables with no matcher
    HOOK_EVENT="PostToolUse"
    HOOK_MATCHER=""
    HOOK_COMMAND="no matcher command"

    install_hook "$TEST_SETTINGS"

    # Check that entry was created without matcher field
    local has_matcher=$(jq -r '.hooks.PostToolUse[0] | has("matcher")' "$TEST_SETTINGS")
    assert_same "false" "$has_matcher"

    local command_in_file=$(jq -r '.hooks.PostToolUse[0].hooks[0].command' "$TEST_SETTINGS")
    assert_same "no matcher command" "$command_in_file"

    rm -rf "$TEST_DIR"
}

# Tests for choose_installation_location function (using input simulation)
function test_choose_installation_location_selects_local_settings_for_option_1() {
    # Mock user input: choose option 1
    echo "1" | choose_installation_location >/dev/null 2>&1
    local result=$(echo "1" | choose_installation_location 2>/dev/null)
    assert_same "$(pwd)/.claude/settings.local.json" "$result"
}

function test_choose_installation_location_selects_project_settings_for_option_2() {
    # Mock user input: choose option 2
    local result=$(echo "2" | choose_installation_location 2>/dev/null)
    assert_same "$(pwd)/.claude/settings.json" "$result"
}

function test_choose_installation_location_selects_global_settings_for_option_3() {
    # Mock user input: choose option 3
    local result=$(echo "3" | choose_installation_location 2>/dev/null)
    assert_same "$HOME/.claude/settings.json" "$result"
}

function test_choose_installation_location_exits_with_error_for_invalid_choice() {
    # Mock invalid input - this should exit with code 1
    local output
    set +e  # Temporarily disable exit on error
    output=$(echo "4" | choose_installation_location 2>&1)
    local exit_code=$?
    set -e  # Re-enable exit on error
    assert_same "1" "$exit_code"
    assert_contains "Invalid choice" "$output"
}

# Tests for main function workflow components
function test_get_user_choice_returns_correct_script_for_valid_input() {
    setup

    # Test valid choice: script 2
    local user_choice
    user_choice=$(echo "2" | get_user_choice 2>/dev/null | tr -d '\n\r ')
    assert_same "one-liners/test-script2.sh" "$user_choice"

    teardown
}

function test_get_user_choice_returns_python_script_for_valid_input() {
    setup

    # Test valid choice: script 5 (should be a python script)
    local user_choice
    user_choice=$(echo "5" | get_user_choice 2>/dev/null | tr -d '\n\r ')
    assert_same "py-hooks/test-notification.py" "$user_choice"

    teardown
}

function test_get_user_choice_fails_for_invalid_input() {
    setup

    # Test invalid choice: script 7 (only 6 scripts exist now)
    local choice_output
    set +e
    choice_output=$(echo "7" | get_user_choice 2>&1)
    local exit_code=$?
    set -e

    assert_same "1" "$exit_code"
    assert_contains "Invalid choice" "$choice_output"

    teardown
}
