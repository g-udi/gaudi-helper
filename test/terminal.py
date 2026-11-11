#!/usr/bin/env python3
"""Run a shell on a pseudo-terminal and type the lines of a file into it.

    terminal.py <file with commands> <shell> [args...]

A line is typed whenever the shell has gone quiet, the way a person waits for
the prompt. The terminal output is printed and the shell's exit status is
returned. test.sh uses this to load the helper into a real interactive shell.
"""
import os
import pty
import select
import sys
import time

with open(sys.argv[1]) as handle:
    lines = handle.read().splitlines()
command = sys.argv[2:]

pid, master = pty.fork()
if pid == 0:
    os.execvp(command[0], command)

output = b""
deadline = time.time() + 60
raw = None
while True:
    if time.time() > deadline:
        os.kill(pid, 9)
        break
    ready, _, _ = select.select([master], [], [], 0.4)
    if ready:
        try:
            data = os.read(master, 4096)
        except OSError:
            data = b""
        if not data:
            break
        output += data
    elif lines:
        os.write(master, (lines.pop(0) + "\n").encode())
    else:
        finished, raw = os.waitpid(pid, os.WNOHANG)
        if finished:
            break
        raw = None

if raw is None:
    _, raw = os.waitpid(pid, 0)

sys.stdout.write(output.decode(errors="replace"))
sys.exit(os.WEXITSTATUS(raw) if os.WIFEXITED(raw) else 1)
