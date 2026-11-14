#!/usr/bin/env python3
"""App Store 가격을 정한다 (기준 국가 대한민국, 원화).

    python3 scripts/asc_price.py --bundle-id com.example.app --krw 1100

유료 앱은 App Store Connect → 비즈니스에서 "유료 앱 계약"이 활성 상태여야 한다.
환경 변수: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
"""

import argparse
import sys

from asc import call, find_app, summary


def price_point(app_id, krw):
    """대한민국 가격표에서 고객가가 krw인 가격 포인트 ID를 찾는다."""
    path = f"/v1/apps/{app_id}/appPricePoints"
    params = {"filter[territory]": "KOR", "limit": 200}
    while True:
        page = call("GET", path, params)
        for point in page["data"]:
            if float(point["attributes"]["customerPrice"]) == float(krw):
                return point["id"]
        cursor = page.get("meta", {}).get("paging", {}).get("nextCursor")
        if not cursor or "next" not in page.get("links", {}):
            return None
        params["cursor"] = cursor


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--krw", type=int, required=True)
    args = parser.parse_args()

    app = find_app(args.bundle_id)
    if app is None:
        sys.exit(f"::error::App Store Connect에 {args.bundle_id} 앱이 없습니다.")
    point = price_point(app["id"], args.krw)
    if point is None:
        sys.exit(f"::error::대한민국 가격표에 ₩{args.krw} 가격이 없습니다.")

    call("POST", "/v1/appPriceSchedules", body={
        "data": {
            "type": "appPriceSchedules",
            "relationships": {
                "app": {"data": {"type": "apps", "id": app["id"]}},
                "baseTerritory": {"data": {"type": "territories", "id": "KOR"}},
                "manualPrices": {"data": [{"type": "appPrices", "id": "${price}"}]},
            },
        },
        "included": [{
            "type": "appPrices",
            "id": "${price}",
            "attributes": {"startDate": None},
            "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": point}}},
        }],
    })
    summary(f"## 가격 설정 완료\n기준 국가 대한민국 ₩{args.krw:,} — 다른 국가는 애플이 환산한 가격으로 맞춰집니다.")


if __name__ == "__main__":
    main()
