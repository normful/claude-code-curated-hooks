#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "cchooks",
# ]
# ///

import os
from cchooks import create_context, NotificationContext

c = create_context()
assert isinstance(c, NotificationContext)

# Requires https://github.com/julienXX/terminal-notifier
_ = os.system(f'terminal-notifier -title Claude Code -message "{c.message}"')
