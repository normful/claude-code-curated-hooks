#!/usr/bin/env python3
import asyncio
from cchooks import create_context, NotificationContext
from desktop_notifier import DesktopNotifier

c = create_context()
assert isinstance(c, NotificationContext)

notifier = DesktopNotifier()


async def send_notification():
    assert isinstance(c, NotificationContext)
    _ = await notifier.send(title="Hello world!", message=f"{c.message}")


if "permission" in c.message.lower():
    asyncio.run(send_notification())
