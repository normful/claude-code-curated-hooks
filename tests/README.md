# Tests for install-one-liner-hook.sh

This directory contains unit tests for the `install-one-liner-hook.sh` script using the [bashunit](https://bashunit.typeddevs.com/) testing framework.

## Running the Tests

### Quick Start
```bash
# From the project root directory
./run-tests.sh
```

### Manual Setup
1. Install bashunit:
   ```bash
   curl -s https://bashunit.typeddevs.com/install.sh | bash
   ```

2. Run the tests:
   ```bash
   ./lib/bashunit ./tests/install_one_liner_hook_test.sh
   ```

## Test Coverage

The test suite covers the following functions from `install-one-liner-hook.sh`:

- **`get_available_scripts()`**: Tests listing of available scripts in the `one-liners/` directory
- **`extract_script_metadata()`**: Tests parsing of script metadata (event, matcher, command) from script files
- **`choose_installation_location()`**: Tests user input handling for choosing settings file location
- **`install_hook()`**: Tests JSON manipulation and hook installation logic
- **`check_dependencies()`**: Tests dependency checking (jq availability)
- **Integration test**: Full workflow simulation

## Test Structure

Each test function follows the bashunit convention:
- Function names start with `test_`
- Use `assert_*` functions for validation
- Include setup/teardown where needed for temporary files and directories

## Test Data

Tests create temporary directories and mock script files to avoid dependencies on the actual `one-liners/` directory content.