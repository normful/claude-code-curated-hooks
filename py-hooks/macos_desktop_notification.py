#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "cchooks",
# ]
# ///
# event: Notification
# matcher: *

import os
from cchooks import create_context, NotificationContext

c = create_context()
assert isinstance(c, NotificationContext)
if "permission" in c.message.lower():
    # Requires https://github.com/julienXX/terminal-notifier
    _ = os.system(f'terminal-notifier -title Claude Code -message "{c.message}"')
