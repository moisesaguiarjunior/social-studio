#!/usr/bin/env python3
"""Start one POSIX render command in an owned process group.

The first stdout line is a private readiness handshake. The Dart parent must
wait for it before signalling the group, including cancellation during startup.
No media is read and no dependency or binary is downloaded here.
"""

import os
import sys

os.setsid()
print("social-studio-process-ready-v1", flush=True)
os.execvp(sys.argv[1], sys.argv[1:])
