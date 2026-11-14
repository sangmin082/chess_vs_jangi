#!/usr/bin/env python3
"""앱 소스의 한국어 문자열 리터럴을 모아 문자열 카탈로그 키 형태로 출력한다 (번역 누락 점검용)."""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "ChessVsJanggi"
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')
INTERPOLATION = re.compile(r"\\\(([^()]*)\)")
HANGUL = re.compile(r"[가-힣]")
INTEGER_HINTS = ("count", "quietHalfMoves")


def keys():
    found = set()
    for folder in ("Views", "Online"):
        for path in sorted((ROOT / folder).glob("*.swift")):
            for line in path.read_text(encoding="utf-8").splitlines():
                code = line.split("//")[0]
                for literal in LITERAL.findall(code):
                    if not HANGUL.search(literal):
                        continue
                    key = INTERPOLATION.sub(
                        lambda m: "%lld" if any(h in m.group(1) for h in INTEGER_HINTS) else "%@", literal)
                    found.add(key.replace('\\"', '"'))
    return sorted(found)


if __name__ == "__main__":
    sys.stdout.write("\n".join(keys()) + "\n")
