#!/usr/bin/env python3
"""Runs `fls --lol` in a pseudo-terminal and checks how it treats Ctrl-C,
Ctrl-D and SIGINT. usage: tests/lol_test.py [path/to/fls]"""
import fcntl
import os
import re
import select
import signal
import struct
import subprocess
import sys
import termios
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FLS = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "fls")
LEAVE_ALT_SCREEN = b"\x1b[?1049l"

passed = failed = 0


def check(ok, what, detail=""):
    global passed, failed
    if ok:
        passed += 1
    else:
        failed += 1
        print(f"FAIL: {what} {detail}".rstrip())


def run(args, actions, timeout=30.0):
    """Starts fls on a fresh 80x24 pty as its controlling terminal, performs
    `actions` ((seconds, bytes-or-signal) pairs) and returns (wait status,
    seconds taken, output, still running at each action, termios after)."""
    master, slave = os.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
    saved = termios.tcgetattr(slave)

    def make_controlling():
        fcntl.ioctl(0, termios.TIOCSCTTY, 0)

    child = subprocess.Popen(
        [FLS] + args, stdin=slave, stdout=slave, stderr=slave,
        start_new_session=True, preexec_fn=make_controlling,
        env=dict(os.environ, TERM="xterm-256color"))
    started = time.monotonic()
    output = bytearray()
    alive = []
    pending = sorted(actions, key=lambda a: a[0])
    status = None
    while time.monotonic() - started < timeout:
        now = time.monotonic() - started
        while pending and pending[0][0] <= now:
            _, action = pending.pop(0)
            alive.append(child.poll() is None)
            if isinstance(action, bytes):
                os.write(master, action)
            else:
                os.kill(child.pid, action)
        ready, _, _ = select.select([master], [], [], 0.02)
        if ready:
            try:
                output += os.read(master, 65536)
            except OSError:
                pass
        if child.poll() is not None:
            status = child.returncode
            break
    if status is None:
        child.kill()
        child.wait()
    # Collect whatever is left on the pty.
    while select.select([master], [], [], 0.05)[0]:
        try:
            chunk = os.read(master, 65536)
        except OSError:
            break
        if not chunk:
            break
        output += chunk
    after = termios.tcgetattr(slave)
    termios.tcsetattr(slave, termios.TCSANOW, saved)
    os.close(master)
    os.close(slave)
    return status, time.monotonic() - started, bytes(output), alive, after, saved


def cooked(mode):
    lflag = mode[3]
    return bool(lflag & termios.ICANON and lflag & termios.ECHO and lflag & termios.ISIG)


# Plain --lol: Ctrl-C, Ctrl-D and SIGINT all bounce off; the plane takes off
# and the program ends by itself with a clean terminal.
status, took, out, alive, after, _ = run(["--lol"], [
    (0.5, b"\x03"), (0.8, b"\x04"), (1.1, signal.SIGINT),
    (1.4, b"\x03\x04\x03"), (1.7, b"q\x1b"), (2.0, b"x"),
])
check(all(alive), "--lol keeps flying through ^C, ^D and SIGINT", f"(alive at each: {alive})")
check(status == 0, "--lol exits 0 on its own", f"(status {status})")
check(took > 3.0, "--lol plays the whole takeoff", f"(took {took:.1f}s)")
plain = re.sub(rb"\x1b\[[0-9;?]*[A-Za-z]", b"", out)
check(b"|fls" in plain and b"(O)" in plain and b"====" in plain, "--lol draws the plane")
check(out.rstrip().endswith(LEAVE_ALT_SCREEN) or LEAVE_ALT_SCREEN in out[-64:],
      "--lol leaves the alternate screen")
check(cooked(after), "--lol restores the terminal mode")

# --lol=signal: Ctrl-C or Ctrl-D ends it at once, cleanly, with status 0.
for name, key in (("^C", b"\x03"), ("^D", b"\x04")):
    status, took, out, alive, after, _ = run(["--lol=signal"], [(0.5, key)])
    check(status == 0, f"--lol=signal exits 0 on {name}", f"(status {status})")
    check(took < 1.5, f"--lol=signal stops promptly on {name}", f"(took {took:.1f}s)")
    check(LEAVE_ALT_SCREEN in out[-64:], f"--lol=signal leaves the alternate screen on {name}")
    check(cooked(after), f"--lol=signal restores the terminal mode on {name}")

# --lol=signal does not catch SIGINT at all: the default action applies.
status, took, out, alive, after, _ = run(["--lol=signal"], [(0.5, signal.SIGINT)])
check(status == -signal.SIGINT, "--lol=signal leaves SIGINT uncaught", f"(status {status})")

# Errors.
result = subprocess.run([FLS, "--lol=nope"], capture_output=True, text=True)
check(result.returncode == 3 and "--lol" in result.stderr, "rejects a bad --lol value",
      f"(status {result.returncode}: {result.stderr.strip()})")
result = subprocess.run([FLS, "--lol"], stdin=subprocess.DEVNULL, capture_output=True, text=True)
check(result.returncode == 2 and "terminal" in result.stderr, "--lol needs a terminal",
      f"(status {result.returncode}: {result.stderr.strip()})")

print(f"lol: passed {passed}, failed {failed}")
sys.exit(1 if failed else 0)
