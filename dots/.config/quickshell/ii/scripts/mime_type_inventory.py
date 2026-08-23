#!/usr/bin/env python3
"""Build a page-sized, user-facing MIME inventory in one Gio pass."""

import json
import os
from pathlib import Path

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio


DOCUMENTS = {
    "application/epub+zip", "application/pdf", "application/postscript",
    "application/rtf", "application/msword", "application/vnd.ms-excel",
    "application/vnd.ms-powerpoint", "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
}
ARCHIVES = {
    "application/zip", "application/x-7z-compressed", "application/vnd.rar",
    "application/x-rar", "application/x-tar", "application/gzip",
    "application/x-gzip", "application/x-bzip2", "application/x-bzip-compressed-tar",
    "application/x-xz", "application/x-xz-compressed-tar", "application/x-lzip",
}
PACKAGES = {
    "application/vnd.appimage", "application/x-apple-diskimage",
    "application/x-cd-image", "application/x-iso9660-image", "application/x-raw-disk-image",
    "application/x-rpm", "application/x-deb", "application/vnd.debian.binary-package",
}
OTHER = {
    "application/atom+xml", "application/ecmascript", "application/java-archive",
    "application/json", "application/json5", "application/ogg", "application/rdf+xml",
    "application/rss+xml", "application/sql", "application/toml", "application/typescript",
    "application/xhtml+xml", "application/xspf+xml", "application/xml", "application/yaml",
}
COMMON_X = {
    "audio/x-wav", "audio/x-matroska", "video/x-matroska", "video/x-msvideo",
    "image/x-icon", "image/x-ico",
}
SENSITIVE = {
    "application/x-desktop", "application/x-executable", "application/x-shellscript",
    "application/x-sharedlib", "application/x-pie-executable",
}


def read_globs():
    result = {}
    paths = [
        Path.home() / ".local/share/mime/globs2",
        Path("/usr/local/share/mime/globs2"),
        Path("/usr/share/mime/globs2"),
    ]
    for path in paths:
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for line in lines:
            fields = line.split(":", 2)
            if len(fields) != 3:
                continue
            try:
                priority = int(fields[0])
            except ValueError:
                priority = 0
            result.setdefault(fields[1], []).append((priority, fields[2]))
    return result


def simple_extension(glob):
    if not glob.startswith("*.") or any(char in glob[2:] for char in "[]?{}*/"):
        return ""
    suffix = glob[1:]
    if len(suffix) > 12 or not suffix[1:].replace(".", "").isalnum():
        return ""
    return suffix.lower()


def classify(mime):
    if mime.startswith("image/"):
        if mime.startswith("image/x-") and mime not in COMMON_X:
            return ""
        return "Images"
    if mime.startswith("audio/"):
        if mime.startswith("audio/x-") and mime not in COMMON_X:
            return ""
        return "Audio"
    if mime.startswith("video/"):
        if mime.startswith("video/x-") and mime not in COMMON_X:
            return ""
        return "Video"
    if mime.startswith("text/"):
        if mime.startswith("text/x-"):
            return ""
        return "Text & Code"
    if mime.startswith("font/"):
        return "Fonts"
    if mime in DOCUMENTS or mime.startswith("application/vnd.openxmlformats-officedocument.") or mime.startswith("application/vnd.ms-") or mime == "application/msword-template":
        return "Documents"
    if mime in ARCHIVES:
        return "Archives"
    if mime in PACKAGES:
        return "Packages & Disk Images"
    if mime in OTHER:
        return "Other"
    return ""


def candidate_ids(mime):
    seen = set()
    result = []
    for app in Gio.AppInfo.get_all_for_type(mime) or []:
        app_id = app.get_id()
        if app_id and app_id not in seen:
            seen.add(app_id)
            result.append(app_id)
    return result


def main():
    globs = read_globs()
    items = []
    for mime in Gio.content_types_get_registered():
        if mime.startswith("x-scheme-handler/") or mime.startswith("inode/") or mime in SENSITIVE:
            continue
        category = classify(mime)
        if not category:
            continue
        candidates = candidate_ids(mime)
        if not candidates:
            continue
        description = Gio.content_type_get_description(mime) or ""
        if not description or description == mime:
            continue
        extensions = []
        for _, glob in sorted(globs.get(mime, []), key=lambda value: (-value[0], value[1])):
            extension = simple_extension(glob)
            if extension and extension not in extensions:
                extensions.append(extension)
        # Keep the normal list useful: obscure application/* entries need a
        # recognizable filename pattern, while hierarchy types may stand on
        # their content family alone.
        if mime.startswith("application/") and not extensions:
            continue
        default = Gio.AppInfo.get_default_for_type(mime, False)
        items.append({
            "id": mime,
            "description": description,
            "extensions": extensions[:8],
            "category": category,
            "defaultId": default.get_id() if default else "",
            "candidateIds": candidates,
        })
    items.sort(key=lambda item: (item["category"], item["description"].casefold(), item["id"]))
    print(json.dumps({"version": 1, "items": items}, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
