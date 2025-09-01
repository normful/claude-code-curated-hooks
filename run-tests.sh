#!/usr/bin/env bash

set -e

# Check if bashunit is installed, install if not
if [[ ! -f "lib/bashunit" ]]; then
    echo "Installing bashunit..."
    curl -s https://bashunit.typeddevs.com/install.sh | bash
fi

# Run the tests
echo "Running tests for install-one-liner-hook.sh..."
./lib/bashunit ./tests/install_one_liner_hook_test.sh