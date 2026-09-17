"""Check the archived app and embedded WidgetKit extension before IPA packaging."""
import argparse
import plistlib
from pathlib import Path


def validate(app: Path) -> None:
    widget = app / "PlugIns" / "MinehutAnalyticsWidget.appex"
    metadata = []
    for bundle, kind in ((app, "APPL"), (widget, "XPC!")):
        with (bundle / "Info.plist").open("rb") as source:
            info = plistlib.load(source)
        executable = info.get("CFBundleExecutable", "")
        if not executable or Path(executable).name != executable or not (bundle / executable).is_file():
            raise ValueError(f"Missing executable in {bundle.name}")
        if info.get("CFBundlePackageType") != kind:
            raise ValueError(f"Unexpected package type in {bundle.name}")
        metadata.append(info)
    parent, extension = metadata
    if parent.get("CFBundleIdentifier") != "com.cjh3139.minehutanalytics":
        raise ValueError("Unexpected app identifier before sideload signing")
    if extension.get("CFBundleIdentifier") != "com.cjh3139.minehutanalytics.widget":
        raise ValueError("Widget identifier changed")
    if extension.get("NSExtension", {}).get("NSExtensionPointIdentifier") != "com.apple.widgetkit-extension":
        raise ValueError("Missing WidgetKit extension declaration")
    for key in ("CFBundleVersion", "CFBundleShortVersionString", "WorkerBaseURL"):
        if not parent.get(key) or parent.get(key) != extension.get(key):
            raise ValueError(f"App/widget {key} missing or mismatched")
    if not (widget / "Metadata.appintents" / "extract.actionsdata").is_file():
        raise ValueError("Widget App Intents metadata was not generated")
    print("Validated app, widget executable, identifiers, versions and App Intents metadata.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    validate(parser.parse_args().app)
