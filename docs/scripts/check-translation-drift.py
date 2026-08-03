#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""check-translation-drift.py — do the translated help pages still match the English one?

`check-translations.py` answers "does every language have every topic" and "is every UI string
marked translated". Neither notices when an English page grows a paragraph and eighteen translations
do not: the file exists, the strings are translated, and the gate stays green. After eight rounds of
editing help text across nineteen languages, that is the likely failure — and nobody would see it.

What is compared is only what should be *identical* regardless of language:

  * the heading outline (levels and their order),
  * how many paragraphs and list items there are,
  * every image target — a screenshot path is a path in every language,
  * every fenced code block's contents — code is not translated,
  * every inline `code span`'s contents, as a multiset.

Prose is never compared, and neither is length. A language may need two sentences where English needs
one, so only structure is held to account.

Deliberate deviations go in docs/metadata/translation-drift-allow.json as
`{"topic": {"lang": "why"}}`; they are reported as accepted rather than hidden.

Usage:
    docs/scripts/check-translation-drift.py [--write] [--topic viewing-files] [--lang de]
"""

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
HELP_EN = REPO / "docs/content/help"
ALLOW = REPO / "docs/metadata/translation-drift-allow.json"
REPORT = REPO / "docs/generated/translation-drift.md"

FENCE = re.compile(r"^```")
HEADING = re.compile(r"^(#{1,6})\s")
IMAGE = re.compile(r"!\[[^\]]*\]\(([^)]+)\)")
INLINE_CODE = re.compile(r"`([^`\n]+)`")
LIST_ITEM = re.compile(r"^\s*([-*+]|\d+\.)\s")


def shape(text: str) -> dict:
    """The language-independent skeleton of a help page."""
    headings, fences, lists, paragraphs = [], [], 0, 0
    in_fence, fence_body, blank = False, [], True
    for line in text.split("\n"):
        if FENCE.match(line.strip()):
            if in_fence:
                fences.append("\n".join(fence_body))
                fence_body, in_fence = [], False
            else:
                in_fence = True
            blank = True
            continue
        if in_fence:
            fence_body.append(line)
            continue
        stripped = line.strip()
        if not stripped:
            blank = True
            continue
        if m := HEADING.match(stripped):
            headings.append(len(m.group(1)))
            blank = True
            continue
        if LIST_ITEM.match(line):
            lists += 1
            blank = True
            continue
        # A paragraph is a run of non-blank, non-structural lines.
        if blank:
            paragraphs += 1
        blank = False
    return {
        "headings": headings,
        "paragraphs": paragraphs,
        "lists": lists,
        "images": IMAGE.findall(text),
        "fences": fences,
        # A multiset: order varies with grammar, presence should not.
        "code": sorted(INLINE_CODE.findall(text)),
    }


def differences(en: dict, other: dict) -> list:
    out = []
    if en["headings"] != other["headings"]:
        out.append(f"heading outline differs: {len(en['headings'])} vs {len(other['headings'])} "
                   f"({en['headings']} vs {other['headings']})")
    if en["paragraphs"] != other["paragraphs"]:
        out.append(f"{en['paragraphs']} paragraphs in English, {other['paragraphs']} here")
    if en["lists"] != other["lists"]:
        out.append(f"{en['lists']} list items in English, {other['lists']} here")
    if en["images"] != other["images"]:
        missing = [i for i in en["images"] if i not in other["images"]]
        extra = [i for i in other["images"] if i not in en["images"]]
        if missing:
            out.append("image(s) missing: " + ", ".join(missing))
        if extra:
            out.append("image(s) not in English: " + ", ".join(extra))
    if en["fences"] != other["fences"]:
        out.append(f"{len(en['fences'])} code block(s) in English, {len(other['fences'])} here"
                   if len(en["fences"]) != len(other["fences"])
                   else "code block contents differ — code is not translated")
    if en["code"] != other["code"]:
        missing = sorted(set(en["code"]) - set(other["code"]))
        if missing:
            out.append("inline code missing: " + ", ".join(f"`{c}`" for c in missing[:6])
                       + (" …" if len(missing) > 6 else ""))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="write docs/generated/translation-drift.md")
    ap.add_argument("--topic")
    ap.add_argument("--lang")
    args = ap.parse_args()

    allow = json.loads(ALLOW.read_text()) if ALLOW.exists() else {}
    langs = sorted(p.name[len("help-"):] for p in REPO.glob("docs/help-*") if p.is_dir())
    if args.lang:
        langs = [args.lang]

    findings, accepted, checked = [], 0, 0
    for en_file in sorted(HELP_EN.glob("*.md")):
        topic = en_file.stem
        if args.topic and topic != args.topic:
            continue
        en = shape(en_file.read_text(encoding="utf-8"))
        for lang in langs:
            path = REPO / f"docs/help-{lang}/{topic}.md"
            if not path.exists():
                continue          # existence is check-translations.py's job, not ours
            checked += 1
            diffs = differences(en, shape(path.read_text(encoding="utf-8")))
            if not diffs:
                continue
            if lang in allow.get(topic, {}):
                accepted += 1
                continue
            findings.append((topic, lang, diffs))

    lines = ["# Translation drift", "",
             "_Structure only — headings, paragraph and list counts, images, code. Prose is never",
             "compared. Generated by docs/scripts/check-translation-drift.py._", "",
             f"- Pages compared: **{checked}**  ·  drifted: **{len(findings)}**  ·  "
             f"accepted deviations: **{accepted}**", ""]
    if findings:
        lines += ["| Topic | Language | What differs |", "|---|---|---|"]
        for topic, lang, diffs in findings:
            lines.append(f"| {topic} | {lang} | " + "<br>".join(diffs) + " |")
    else:
        lines.append("Every translated page matches the English structure.")

    if args.write:
        REPORT.parent.mkdir(parents=True, exist_ok=True)
        REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"pages={checked} drifted={len(findings)} accepted={accepted}")
    for topic, lang, diffs in findings[:25]:
        print(f"  ⚠️  {topic} [{lang}]: {diffs[0]}")
    if len(findings) > 25:
        print(f"  … and {len(findings) - 25} more (see --write report)")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
