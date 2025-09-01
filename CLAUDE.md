# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a curated collection of Claude Code hooks - automation scripts that trigger on Claude Code events. The project supports two types of hooks:

1. **One-liner hooks** (bash scripts in `one-liners/`) - Simple shell commands
2. **Python hooks** (Python scripts in `py-hooks/`) - More complex hooks using the cchooks library

## Architecture

### Core Components

- **`install-hook.sh`** - Interactive installation script that installs hooks to Claude Code settings files
- **`one-liners/`** - Directory containing bash one-liner hook scripts
- **`py-hooks/`** - Directory containing Python hook scripts that use the cchooks library
- **`tests/`** - Comprehensive test suite using bashunit framework

### Hook Script Format

**One-liner hooks** follow this format:

```bash
# event: PostToolUse
# matcher: Write|Edit|MultiEdit
command_to_execute
```

**Python hooks** use metadata comments and the cchooks library:

```python
#!/usr/bin/env -S uv run --script
# ... other comments about dependencies, added by uv
# event: Notification
# matcher: *

# ... hook implementation in Python, using the cchooks libray
```

### Installation Process

The `install-hook.sh` script:
1. Lists available hooks from both directories
2. Extracts metadata (event, matcher, command) from selected script
3. Prompts user to choose installation location:
   - `.claude/settings.local.json` (personal project settings)
   - `.claude/settings.json` (team project settings)
   - `~/.claude/settings.json` (global personal settings)
4. Uses `jq` to manipulate JSON and install the hook

## Development Commands

### Running Bash Unit Tests

```bash
# Run all tests (auto-installs bashunit if needed)
./run-bash-tests.sh
```

### Installing Hooks

```bash
./install-hook.sh
```

## Dependencies

- **`jq`** - Required for JSON manipulation during hook installation
- **`bashunit`** - Testing framework (auto-installed by test script)
- **`uv`** - For Python hook execution (Python hooks use `#!/usr/bin/env -S uv run --script`)
- **`terminal-notifier`** - Required for macOS notification hooks

## Testing Architecture

The test suite (`tests/install-hook-test.sh`) provides comprehensive coverage:

- Unit tests for all core functions
- Mock script creation for isolated testing
- JSON manipulation validation
- Input/output simulation for interactive functions
- Integration testing of the complete workflow

Tests use temporary directories and mock data to avoid dependencies on actual hook files.
