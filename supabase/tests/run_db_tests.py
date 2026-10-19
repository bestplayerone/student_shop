#!/usr/bin/env python3
"""Run SQL tests against a fresh local PostgreSQL, never a linked Supabase project.

Set PG_BIN to a directory containing initdb, pg_ctl, and postgres. All state lives
under TMPDIR (or the Hermes scratch directory); the database is stopped and
removed even when a test fails. No production credentials are read.
"""
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    pg_bin = Path(os.environ.get("PG_BIN", ""))
    for name in ("initdb", "pg_ctl", "postgres"):
        if not (pg_bin / name).is_file():
            raise SystemExit("Set PG_BIN to a PostgreSQL bin directory")
    scratch = os.environ.get("TMPDIR", str(Path.home() / ".hermes/cache/scratch"))
    Path(scratch).mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="bmc-db-test-", dir=scratch) as temp:
        data = str(Path(temp) / "data")
        log = str(Path(temp) / "postgres.log")
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        subprocess.run([str(pg_bin / "initdb"), "-D", data, "-U", "postgres",
                        "-A", "trust", "--no-locale", "-E", "UTF8"], check=True,
                       stdout=subprocess.DEVNULL)
        subprocess.run([str(pg_bin / "pg_ctl"), "-D", data, "-l", log,
                        "-o", f"-h 127.0.0.1 -p {port} -k {temp} -F", "-w", "start"], check=True)
        try:
            env = dict(os.environ, BACKEND_TEST_DATABASE_URL=f"postgresql://postgres@127.0.0.1:{port}/bmc_test")
            deno = [shutil.which("deno")] if shutil.which("deno") else ["npx", "--yes", "deno"]
            result = subprocess.run(deno + ["task", "test:db"], cwd=root, env=env)
            return result.returncode
        finally:
            subprocess.run([str(pg_bin / "pg_ctl"), "-D", data, "-m", "immediate", "-w", "stop"], check=True)


if __name__ == "__main__":
    raise SystemExit(main())
