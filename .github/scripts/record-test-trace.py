"""Run a test command alongside a bounded, system-wide Instruments recording."""

import os
import json
from datetime import datetime
import xml.etree.ElementTree as ET
from pathlib import Path
import signal
import subprocess
import sys
import time


def stop_recording(process, log):
    if process.poll() is None:
        process.send_signal(signal.SIGINT)
    try:
        # System Trace can spend several minutes processing after recording stops.
        code = process.wait(timeout=300)
    except subprocess.TimeoutExpired:
        log.write("\nTrace finalization exceeded 300 seconds; terminating.\n")
        log.flush()
        process.terminate()
        try:
            code = process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            code = process.wait()
    if code != 0:
        print(f"::warning::Instruments exited with status {code}; see system-trace artifacts.", flush=True)


def inspect_trace(toc_path, test_start, test_end):
    root = ET.parse(toc_path).getroot()
    summary = root.find("./run/info/summary")
    if summary is None:
        raise ValueError("Trace has no run summary")
    duration = float(summary.findtext("duration", "0"))
    start = datetime.fromisoformat(summary.findtext("start-date")).timestamp()
    end = datetime.fromisoformat(summary.findtext("end-date")).timestamp()
    runners = [p.attrib for p in root.findall(".//process")
               if p.get("name") == "xctest"]
    problems = []
    if not runners:
        problems.append("No xctest process in trace")
    if start > test_start + 2 or end < test_end - 2:
        problems.append("Trace does not cover the test command's time interval")
    if duration < test_end - test_start - 2:
        problems.append("Trace duration is shorter than the test command")
    return {"duration_seconds": duration,
            "recording_mode": summary.findtext("recording-mode"),
            "trace_start_epoch": start, "trace_end_epoch": end,
            "xctest_processes": runners, "problems": problems}


def validate_trace(output, test_start, test_end):
    report = {"test_start_epoch": test_start, "test_end_epoch": test_end,
              "test_duration_seconds": test_end - test_start}
    try:
        with (output / "validation.log").open("w") as log:
            subprocess.run(
                ["xcrun", "xctrace", "export", "--input",
                 str(output / "NetworkLib-tests.trace"), "--toc",
                 "--output", str(output / "toc.xml")],
                stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120,
            )
        report.update(inspect_trace(output / "toc.xml", test_start, test_end))
    except (OSError, subprocess.SubprocessError, ET.ParseError, ValueError, TypeError) as error:
        report["problems"] = [f"Cannot validate trace: {error}"]
    report["valid"] = not report["problems"]
    (output / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
    if not report["valid"]:
        print("::error::Invalid Instruments capture: " + "; ".join(report["problems"]), flush=True)
    else:
        print(f"Trace validated: {report['duration_seconds']:.1f}s, "
              f"{len(report['xctest_processes'])} xctest processes", flush=True)
    return report["valid"]


def main():
    command = sys.argv[1:]
    if not command:
        raise SystemExit("Usage: record-test-trace.py command [arguments...]")
    output = Path(os.environ["RUNNER_TEMP"]) / "SystemTrace"
    output.mkdir(parents=True, exist_ok=True)
    log_path = output / "xctrace.log"
    process = None
    with log_path.open("w") as log:
        try:
            process = subprocess.Popen(
                ["xcrun", "xctrace", "record", "--template", "System Trace",
                 "--all-processes", "--time-limit", "600s", "--window", "600s", "--no-prompt",
                 "--output", str(output / "NetworkLib-tests.trace")],
                stdout=log, stderr=subprocess.STDOUT,
            )
            deadline = time.monotonic() + 30
            while process.poll() is None and time.monotonic() < deadline:
                if "Starting recording" in log_path.read_text(errors="replace"):
                    break
                time.sleep(0.5)
            else:
                print("::warning::Instruments did not confirm startup within 30 seconds. Tests will run anyway.", flush=True)
        except OSError as error:
            log.write(f"Unable to start Instruments: {error}\n")
            log.flush()
            print(f"::warning::Unable to start Instruments: {error}", flush=True)

        test_start = time.time()
        try:
            result = subprocess.run(command)
        finally:
            test_end = time.time()
            if process is not None:
                stop_recording(process, log)
        valid = validate_trace(output, test_start, test_end)
        # Preserve test failures; a passing test run with an unusable trace is a capture failure.
        return result.returncode if result.returncode else (0 if valid else 2)


if __name__ == "__main__":
    sys.exit(main())
