#!/usr/bin/env python3
"""ChessVsJanggi/Localizable.xcstrings 를 만든다 (원문 한국어 → 영어).

소스에서 한국어 문자열을 모아(extract_strings.py) 아래 번역표와 맞춰 본 뒤 카탈로그를 쓴다.
번역이 빠졌거나 남는 항목이 있으면 실패하므로, 문구를 바꾸면 이 표도 함께 고친다.
    python3 scripts/make_strings.py
"""
import json
import pathlib
import sys

from extract_strings import ROOT, keys

EN = {
    # 이름
    "체스 vs 장기": "Chess vs Janggi",
    "체스": "Chess",
    "장기": "Janggi",
    "킹": "King",
    "퀸": "Queen",
    "룩": "Rook",
    "비숍": "Bishop",
    "나이트": "Knight",
    "폰": "Pawn",
    "궁": "General",
    "차": "Chariot",
    "포": "Cannon",
    "마": "Horse",
    "상": "Elephant",
    "사": "Advisor",
    "졸": "Soldier",
    "쉬움": "Easy",
    "보통": "Normal",
    "어려움": "Hard",
    # 홈
    "서로 다른 두 군대, 하나의 판": "Two different armies, one board",
    "컴퓨터 대전": "vs Computer",
    "혼자서 한 판": "Play solo",
    "체스로 두기": "Play as Chess",
    "장기로 두기": "Play as Janggi",
    "온라인 대전": "Online",
    "방을 만들어 친구와 대결": "Create a room and play a friend",
    "규칙 한 장 보기": "Rules on one page",
    # 대국
    "컴퓨터 대전 · %@": "vs Computer · %@",
    "나 · %@": "You · %@",
    "컴퓨터 · %@": "Computer · %@",
    "상대 · %@": "Opponent · %@",
    "생각 중…": "Thinking…",
    "잡은 기물 %lld개": "%lld captured",
    "무르기": "Undo",
    "마지막 수 무르기": "Undo last move",
    "갈 수 있음": "Can move here",
    "선택됨": "Selected",
    "체크 — 킹을 지켜야 합니다": "Check — protect your king",
    "장군 — 궁을 지켜야 합니다": "Check — protect your general",
    "잡거나 폰을 밀지 않고 %lld수 — 50수가 되면 무승부":
        "%lld moves without a capture or pawn move — draw at 50",
    "승급": "Promotion",
    "폰이 끝줄에 닿았습니다. 바꿀 기물을 고르세요.": "Your pawn reached the last rank. Choose a piece.",
    "승리": "Victory",
    "패배": "Defeat",
    "무승부": "Draw",
    "체크메이트 — 체스가 장기의 궁을 잡았습니다.": "Checkmate — Chess has trapped the Janggi general.",
    "외통수 — 장기가 체스의 킹을 잡았습니다.": "Checkmate — Janggi has trapped the Chess king.",
    "둘 수 있는 수가 없어 무승부입니다.": "No legal moves — the game is a draw.",
    "같은 국면이 세 번 반복되어 무승부입니다.": "The same position occurred three times — draw.",
    "잡는 수도 폰의 전진도 없이 50수가 지나 무승부입니다.":
        "Fifty moves passed without a capture or pawn move — draw.",
    "한 판 더": "Play Again",
    "홈으로": "Home",
    "상대가 나갔습니다": "Opponent Left",
    "연결이 끊어져 대국을 계속할 수 없습니다.": "The connection was lost, so the game cannot continue.",
    # 온라인
    "친구와 한 판": "Play a Friend",
    "방을 만들어 코드를 공유하거나, 받은 코드로 입장하세요.":
        "Create a room and share its code, or join with a code you received.",
    "내 진영": "My side",
    "무작위": "Random",
    "체스 (선공)": "Chess (moves first)",
    "방 만들기": "Create Room",
    "방코드로 입장": "Join with a code",
    "입장": "Join",
    "입장하는 쪽은 방장이 고르지 않은 진영을 맡습니다.": "The player who joins takes the side the host did not pick.",
    "상대가 나가서 방이 닫혔습니다.": "Your opponent left and the room was closed.",
    "연결 중…": "Connecting…",
    "서버가 잠들어 있으면 깨우는 데 최대 1분 정도 걸릴 수 있어요.":
        "If the server is asleep, waking it can take up to a minute.",
    "방이 열렸습니다": "Room Open",
    "친구에게 이 코드를 보내주세요. 입장하는 즉시 대국이 시작됩니다.":
        "Send this code to a friend. The game starts as soon as they join.",
    "내 진영: %@": "My side: %@",
    "내 진영: 무작위 — 시작할 때 정해집니다": "My side: random — decided when the game starts",
    "체스 vs 장기에서 한 판 하자! 방코드: %@": "Play me in Chess vs Janggi! Room code: %@",
    "코드 공유하기": "Share Code",
    "상대를 기다리는 중…": "Waiting for opponent…",
    "취소": "Cancel",
    "매칭 완료": "Matched",
    "대국을 시작합니다.": "Starting the game.",
    "서버와 연결이 끊어졌습니다.": "Lost connection to the server.",
    "서버에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.": "Can't reach the server. Please try again shortly.",
    "존재하지 않는 방 코드입니다.": "That room code doesn't exist.",
    "방이 가득 찼습니다.": "The room is full.",
    "이미 방에 있습니다.": "You're already in a room.",
    "대국이 시작되지 않았습니다.": "The game hasn't started.",
    "잘못된 메시지 형식입니다.": "Malformed message.",
    "알 수 없는 오류": "Unknown error",
    # 규칙
    "규칙 한 장": "Rules on One Page",
    "장기판 위에서 체스 군대와 장기 군대가 싸웁니다. 모든 기물은 선이 만나는 점에 놓입니다.":
        "A chess army fights a janggi (Korean chess) army on a janggi board. Every piece sits on a point where lines cross.",
    "체스가 먼저 둡니다.": "Chess moves first.",
    "체스 기물은 체스 규칙대로, 장기 기물은 장기 규칙대로 움직입니다.":
        "Chess pieces move by chess rules; janggi pieces move by janggi rules.",
    "상대의 킹(궁)을 피할 수 없게 공격하면 승리합니다 — 체크메이트, 곧 외통수.":
        "Win by attacking the enemy king (or general) so it cannot escape — checkmate.",
    "자기 킹(궁)이 잡히는 수는 둘 수 없습니다.": "You may not make a move that leaves your own king (or general) in check.",
    "판이 넓어 체스는 비숍과 폰이 하나씩 더 많습니다(비숍 3, 폰 9). 장기는 대군입니다 — 졸 9개, 차 5대(포 줄에 3대 추가).":
        "On the wider board Chess gets one extra bishop and pawn (three bishops, nine pawns). Janggi fields a horde — nine soldiers and five chariots (three extra on the cannon row).",
    "빅장과 한수쉼은 없습니다. 앙파상도 없습니다.":
        "There is no facing-generals rule and no passing. There is no en passant either.",
    "둘 수가 없을 때, 같은 국면이 세 번 반복될 때, 잡는 수도 폰의 전진도 없이 50수가 지나면 무승부입니다.":
        "The game is a draw when there is no legal move, when a position repeats three times, or after fifty moves without a capture or pawn move.",
    "체스 기물": "Chess pieces",
    "어느 방향으로든 한 칸. 판 어디든 갈 수 있습니다. 캐슬링도 됩니다.":
        "One step in any direction, anywhere on the board. It can castle.",
    "가로·세로·대각선으로 원하는 만큼.": "Any distance along a line or a diagonal.",
    "가로·세로로 원하는 만큼.": "Any distance along a line.",
    "대각선으로 원하는 만큼.": "Any distance along a diagonal.",
    "날 일(日)자로 뜁니다. 막히지 않습니다.": "Jumps in an L shape. It cannot be blocked.",
    "앞으로 한 칸(첫 수는 두 칸도), 잡을 때는 대각선 앞으로. 끝줄에 닿으면 승급합니다.":
        "One step forward (two on its first move); captures diagonally forward. Promotes on the last rank.",
    "장기 기물": "Janggi pieces",
    "궁성 안에서 선을 따라 한 칸. 궁성 밖으로 나갈 수 없습니다.":
        "One step along a line inside the palace. It can never leave the palace.",
    "궁과 같습니다.": "Same as the general.",
    "가로·세로로 원하는 만큼. 궁성 안에서는 대각선도.":
        "Any distance along a line. Inside the palace, along the diagonals too.",
    "반드시 기물 하나를 넘어서 움직이고 잡습니다. 체스 기물도 넘을 수 있지만, 포는 넘지 못합니다.":
        "Must jump over exactly one piece to move or capture. It can jump chess pieces, but never another cannon.",
    "한 칸 직진 후 한 칸 대각선. 첫 칸이 막히면 못 갑니다.":
        "One step straight, then one diagonal. Blocked if the first point is occupied.",
    "한 칸 직진 후 두 칸 대각선. 지나는 칸이 막히면 못 갑니다.":
        "One step straight, then two diagonal. Blocked if any point on the way is occupied.",
    "앞이나 옆으로 한 칸. 뒤로는 못 갑니다.": "One step forward or sideways. It cannot move backward.",
}


def main():
    source = set(keys())
    missing = sorted(source - EN.keys())
    unused = sorted(EN.keys() - source)
    if missing or unused:
        for key in missing:
            print(f"번역 없음: {key}", file=sys.stderr)
        for key in unused:
            print(f"소스에 없음: {key}", file=sys.stderr)
        sys.exit(1)

    strings = {
        key: {"localizations": {"en": {"stringUnit": {"state": "translated", "value": EN[key]}}}}
        for key in sorted(source)
    }
    catalog = {"sourceLanguage": "ko", "strings": strings, "version": "1.0"}
    path = ROOT / "Localizable.xcstrings"
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"{path.name}: {len(strings)}개")


if __name__ == "__main__":
    main()
