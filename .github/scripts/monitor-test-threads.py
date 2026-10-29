"""Observe macOS/Simulator xctest processes without instrumenting their code."""
import csv
import os
from pathlib import Path
import signal
import subprocess
import time


def monitor():
    output = Path(os.environ["RUNNER_TEMP"]) / "ThreadDiagnostics"
    output.mkdir(parents=True, exist_ok=True)
    stopping = False

    def stop(_signum, _frame):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    sampling_enabled = os.environ.get("NETWORKLIB_SAMPLE_STACKS") == "1"
    next_sample = {}
    samplers = []
    with (output / "threads.csv").open("w", buffering=1) as counts, \
            (output / "monitor.log").open("w", buffering=1) as log:
        log.write(f"Stack sampling enabled: {sampling_enabled}\n")
        writer = csv.writer(counts)
        writer.writerow(["unix_time", "pid", "thread_count"])
        try:
            while not stopping:
                processes = subprocess.run(
                    ["/usr/bin/pgrep", "-x", "xctest"], capture_output=True, text=True, check=False
                )
                if processes.returncode not in (0, 1):
                    log.write(processes.stderr)
                now = time.monotonic()
                remaining = []
                for process, started in samplers:
                    if process.poll() is not None:
                        continue
                    if now - started >= 10:
                        log.write(f"Stopping sample PID {process.pid}: exceeded 10 seconds\n")
                        process.kill()
                        process.wait()
                    else:
                        remaining.append((process, started))
                samplers = remaining
                live = set(processes.stdout.split())
                for pid in live:
                    result = subprocess.run(
                        ["/bin/ps", "-M", "-p", pid], capture_output=True, text=True, check=False
                    )
                    if result.returncode != 0:
                        continue  # The runner may have exited between pgrep and ps.
                    writer.writerow([time.time(), pid, max(0, len(result.stdout.splitlines()) - 1)])
                    if pid not in next_sample:
                        log.write(f"Discovered xctest PID {pid}\n")
                        next_sample[pid] = now + 20
                    if sampling_enabled and now >= next_sample[pid] and not samplers:
                        path = output / f"sample-{pid}-{time.time_ns()}.txt"
                        samplers.append((subprocess.Popen(
                            ["/usr/bin/sample", pid, "3", "10", "-mayDie", "-file", str(path)],
                            stdout=log, stderr=log,
                        ), time.monotonic()))
                        next_sample[pid] = now + 20
                next_sample = {pid: due for pid, due in next_sample.items() if pid in live}
                time.sleep(1)
        finally:
            for process, _ in samplers:
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == "__main__":
    monitor()
