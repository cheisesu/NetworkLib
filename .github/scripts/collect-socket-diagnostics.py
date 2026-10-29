"""Collect traces from macOS test runners and CoreSimulator clones, including failed runs."""
import os
from pathlib import Path
import shutil
import tempfile


def collect():
    output = Path(os.environ["RUNNER_TEMP"]) / "SocketDiagnostics"
    output.mkdir(parents=True, exist_ok=True)
    directories = {
        Path(os.environ["RUNNER_TEMP"]) / "NetworkLibDiagnostics",
        Path(tempfile.gettempdir()) / "NetworkLibDiagnostics",
        Path(os.environ.get("TMPDIR", "/tmp")) / "NetworkLibDiagnostics",
        Path("/tmp/NetworkLibDiagnostics"),
    }
    devices = Path.home() / "Library/Developer/CoreSimulator/Devices"
    for pattern in (
        "*/data/tmp/NetworkLibDiagnostics",
        "*/data/Containers/Data/*/*/tmp/NetworkLibDiagnostics",
        "*/data/private/var/tmp/NetworkLibDiagnostics",
    ):
        directories.update(devices.glob(pattern))
    sources = sorted({p.resolve() for d in directories for p in d.glob("*.jsonl")})
    manifest = []
    for index, source in enumerate(sources):
        destination = output / f"{index}-{source.name}"
        shutil.copy2(source, destination)
        manifest.append(f"{destination.name}\t{source}")
    (output / "manifest.txt").write_text(
        "\n".join(manifest) + "\n" if manifest else
        "No traces found. Check NETWORKLIB_DIAGNOSTICS in the test plan and runner stderr for the trace path.\n"
    )
    print(f"Collected {len(sources)} socket trace files into {output}")


if __name__ == "__main__":
    collect()
