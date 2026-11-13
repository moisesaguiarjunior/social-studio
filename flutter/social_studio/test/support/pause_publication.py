"""Hold the CLI's review write while delivering a handled test interrupt."""

import json
import os
from pathlib import Path
import signal
import sys
import time

# Bound failure cases where the CLI never opens the FIFO.
signal.alarm(10)
ready = Path(os.environ["TEST_READY"])
pending = ready.with_suffix(".pending")
pending.write_text(json.dumps({"group": os.getpgrp(), "phase": "publication"}))
pending.replace(ready)
with open(sys.argv[1], "rb") as review:
    review.read(1)
    os.kill(int(sys.argv[2]), int(os.environ["TEST_INTERRUPT"]))
    # Larger-than-pipe review data keeps the write pending while the Dart
    # event loop handles the signal. Drain afterwards so it can reach its gate.
    time.sleep(0.15)
    review.read()
