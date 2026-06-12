"""
스펙 마이그레이션: 공통 스펙 → 별도 칼럼 / 나머지 → detail_specs

실행 전 Supabase SQL Editor에서 migrate_specs_schema.sql 먼저 실행할 것.

실행:
    python tools/migrate_specs.py
"""
import sys, json, os, re, time
sys.stdout.reconfigure(encoding='utf-8')
from supabase import create_client

SUPABASE_URL = "https://fdugmidipljoesfsshzn.supabase.co"
SUPABASE_KEY = os.environ.get(
    "SUPABASE_SERVICE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkdWdtaWRpcGxqb2VzZnNzaHpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5ODMwMjksImV4cCI6MjA5NjU1OTAyOX0.pxTJHby6s_dvz7K8rciy4efdykaCdZ7BRXEMW44POrw"
)
TABLE   = "lg_products"
IN_FILE = os.path.join(os.path.dirname(__file__), "lg_products_with_specs.json")
BATCH   = 50

# ── 공통 스펙 키 (여러 카테고리에서 사용) ───────────────────────────
# 추출 후 detail_specs에서 제거할 키 목록
COMMON_KEYS = {
    "color":        ["색상", "색상 (청소기 본체)"],
    "energy_grade": ["에너지 소비효율등급"],
    "size_mm":      ["제품 크기 (WxHxD, mm)", "크기 (WxHxD, mm)"],
    "weight_kg":    ["무게 (kg)", "무게 (Kg)"],
    "thinq_wifi":   ["ThinQ(Wi-Fi)", "ThinQ(Wi-Fi) 연결"],
    "up_appliance": ["UP 가전"],
}
# 카테고리별 핵심 스펙 키
CAT_KEYS = {
    "capacity_l":      ["전체 용량 (L)", "용량 (L)"],       # 냉장고
    "dry_capacity_kg": ["건조 용량 (kg)"],                  # 건조기
    "suction_w":       ["최대흡입력 (W)"],                   # 청소기
    "power_w":         ["소비전력 (W)", "정격입력 (W)"],     # 공기청정기/정수기
}
ALL_EXTRACTED = (
    {k for keys in COMMON_KEYS.values() for k in keys} |
    {k for keys in CAT_KEYS.values() for k in keys}
)


def _pick(specs: dict, candidates: list):
    for k in candidates:
        if k in specs:
            return specs[k]
    return None

def _bool(v) -> bool | None:
    if v is None: return None
    return "O" in str(v) or "있음" in str(v) or "Yes" in str(v)

def _num(v) -> float | None:
    if v is None: return None
    m = re.search(r"[\d,.]+", str(v))
    if not m: return None
    try: return float(m.group().replace(",", ""))
    except: return None


def transform(p: dict) -> dict:
    specs = p.get("specs", {})

    row = {"model_code": p["model_code"]}

    # 공통 칼럼
    row["color"]        = _pick(specs, COMMON_KEYS["color"])
    row["energy_grade"] = _pick(specs, COMMON_KEYS["energy_grade"])
    row["size_mm"]      = _pick(specs, COMMON_KEYS["size_mm"])
    row["weight_kg"]    = _pick(specs, COMMON_KEYS["weight_kg"])
    row["thinq_wifi"]   = _bool(_pick(specs, COMMON_KEYS["thinq_wifi"]))
    row["up_appliance"] = _bool(_pick(specs, COMMON_KEYS["up_appliance"]))

    # 카테고리별 핵심 칼럼
    row["capacity_l"]      = _num(_pick(specs, CAT_KEYS["capacity_l"]))
    row["dry_capacity_kg"] = _num(_pick(specs, CAT_KEYS["dry_capacity_kg"]))
    row["suction_w"]       = _num(_pick(specs, CAT_KEYS["suction_w"]))
    row["power_w"]         = _num(_pick(specs, CAT_KEYS["power_w"]))

    # 나머지 → detail_specs (추출된 키 제거)
    row["detail_specs"] = {k: v for k, v in specs.items() if k not in ALL_EXTRACTED}

    return row


def main():
    with open(IN_FILE, encoding="utf-8") as f:
        products = json.load(f)

    rows = [transform(p) for p in products if p.get("model_code")]
    print(f"마이그레이션 대상: {len(rows)}개")

    sb = create_client(SUPABASE_URL, SUPABASE_KEY)

    ok = fail = 0
    total = len(rows)
    for i, row in enumerate(rows, 1):
        try:
            sb.table(TABLE).update(row).eq("model_code", row["model_code"]).execute()
            ok += 1
            if i % 20 == 0 or i == total:
                print(f"  진행 {i}/{total} (성공 {ok}개)")
        except Exception as e:
            fail += 1
            print(f"  [{row['model_code']}] 오류 — {e}")
        time.sleep(0.05)

    print(f"\n완료: 성공 {ok}개 | 실패 {fail}개")

    # 샘플 출력
    sample = rows[0]
    print(f"\n[샘플: {sample['model_code']}]")
    for k,v in sample.items():
        if k not in ('model_code','detail_specs'):
            print(f"  {k}: {v}")
    print(f"  detail_specs 키 수: {len(sample.get('detail_specs',{}))}")


if __name__ == "__main__":
    main()
