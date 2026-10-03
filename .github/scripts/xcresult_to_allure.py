"""Convert an .xcresult bundle into Allure results (one JSON file per test case).

Uses Apple's `xcresulttool test-results` API so it keeps working across Xcode
releases; attachments such as failure screenshots are exported alongside.

Usage: xcresult_to_allure.py <bundle.xcresult> <allure-results-dir>
"""
import hashlib
import json
import mimetypes
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

STATUS = {"Passed": "passed", "Failed": "failed", "Skipped": "skipped", "Expected Failure": "passed"}


def xcresulttool(*args: str) -> dict:
    out = subprocess.run(["xcrun", "xcresulttool", *args], check=True, capture_output=True, text=True).stdout
    return json.loads(out)


def export_attachments(bundle: str, dest: Path) -> dict[str, list[dict]]:
    subprocess.run(
        ["xcrun", "xcresulttool", "export", "attachments", "--path", bundle, "--output-path", str(dest)],
        check=True, capture_output=True,
    )
    manifest = json.loads((dest / "manifest.json").read_text())
    return {entry["testIdentifier"]: entry["attachments"] for entry in manifest}


def test_cases(node: dict, bundle: str = "", suite: str = ""):
    kind = node["nodeType"]
    if kind == "Test Case":
        yield bundle, suite, node
        return
    if kind.endswith("test bundle"):
        bundle = node["name"]
    elif kind == "Test Suite":
        suite = node["name"]
    for child in node.get("children", []):
        yield from test_cases(child, bundle, suite)


def main(bundle: str, out_dir: str) -> None:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    summary = xcresulttool("get", "test-results", "summary", "--path", bundle)
    tests = xcresulttool("get", "test-results", "tests", "--path", bundle)
    device = tests["devices"][0]
    host = f'{device["deviceName"]} ({device["platform"]} {device["osVersion"]})'

    with tempfile.TemporaryDirectory() as tmp:
        attachments = export_attachments(bundle, Path(tmp))
        clock = int(summary["startTime"] * 1000)
        count = 0
        for root in tests["testNodes"]:
            for bundle_name, suite, case in test_cases(root):
                identifier = case["nodeIdentifier"]
                # Tests skipped before they start carry no duration at all.
                duration = int(case.get("durationInSeconds", 0) * 1000)
                messages = [c["name"] for c in case.get("children", []) if c["nodeType"].endswith("Message")]

                files = []
                for item in attachments.get(identifier, []):
                    source = f'{uuid.uuid4()}-attachment{Path(item["exportedFileName"]).suffix}'
                    shutil.copy(Path(tmp) / item["exportedFileName"], out / source)
                    files.append({
                        "name": "Failure screenshot" if item["isAssociatedWithFailure"] else item["suggestedHumanReadableName"],
                        "source": source,
                        "type": mimetypes.guess_type(source)[0] or "application/octet-stream",
                    })

                result = {
                    "uuid": str(uuid.uuid4()),
                    "historyId": hashlib.md5(identifier.encode()).hexdigest(),
                    "fullName": identifier,
                    "name": case["name"].removesuffix("()"),
                    "status": STATUS[case["result"]],
                    "statusDetails": {"message": "\n".join(messages)},
                    "stage": "finished",
                    "start": clock,
                    "stop": clock + duration,
                    "labels": [
                        {"name": "parentSuite", "value": bundle_name},
                        {"name": "suite", "value": suite},
                        {"name": "framework", "value": "XCTest"},
                        {"name": "language", "value": "swift"},
                        {"name": "host", "value": host},
                    ],
                    "attachments": files,
                }
                (out / f'{result["uuid"]}-result.json').write_text(json.dumps(result, ensure_ascii=False))
                clock += duration
                count += 1
    print(f"Converted {count} test cases from {bundle}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
