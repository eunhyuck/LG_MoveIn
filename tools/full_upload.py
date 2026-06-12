"""
전체 업로드 스크립트 — 871개 제품 + 스펙 마이그레이션 한 번에 처리

실행 전 Supabase SQL Editor에서:
    TRUNCATE TABLE lg_products RESTART IDENTITY;

실행:
    python tools/full_upload.py
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

# ── 공통 스펙 추출 키 ──────────────────────────────────────────
COMMON_KEYS = {
    "color":        ["색상", "색상 (청소기 본체)"],
    "energy_grade": ["에너지 소비효율등급"],
    "size_mm":      ["제품 크기 (WxHxD, mm)", "크기 (WxHxD, mm)"],
    "weight_kg":    ["무게 (kg)", "무게 (Kg)"],
    "thinq_wifi":   ["ThinQ(Wi-Fi)", "ThinQ(Wi-Fi) 연결"],
    "up_appliance": ["UP 가전"],
}
CAT_KEYS = {
    "capacity_l":      ["전체 용량 (L)", "용량 (L)"],
    "dry_capacity_kg": ["건조 용량 (kg)"],
    "suction_w":       ["최대흡입력 (W)"],
    "power_w":         ["소비전력 (W)", "정격입력 (W)"],
}
ALL_EXTRACTED = (
    {k for keys in COMMON_KEYS.values() for k in keys} |
    {k for keys in CAT_KEYS.values() for k in keys}
)

def _pick(specs, candidates):
    for k in candidates:
        if k in specs:
            return specs[k]
    return None

def _bool(v):
    if v is None: return None
    return "O" in str(v) or "있음" in str(v) or "Yes" in str(v)

def _num(v):
    if v is None: return None
    m = re.search(r"[\d,.]+", str(v))
    if not m: return None
    try: return float(m.group().replace(",", ""))
    except: return None

def _int(v):
    try: return int(v) if v is not None else None
    except: return None


def build_row(p: dict) -> dict:
    specs = p.get("specs", {})
    row = {
        "model_code":       p.get("model_code", ""),
        "name":             p.get("name", ""),
        "category":         p.get("category", ""),
        "brand":            p.get("brand", "LG"),
        "release_year":     _int(p.get("release_year")),
        "price_new_krw":    _int(p.get("price_new_krw")),
        "images":           p.get("images", []),
        "product_url":      p.get("product_url", ""),
        "crawled_at":       p.get("crawled_at", ""),
        # 공통 스펙 칼럼
        "color":            _pick(specs, COMMON_KEYS["color"]),
        "energy_grade":     _pick(specs, COMMON_KEYS["energy_grade"]),
        "size_mm":          _pick(specs, COMMON_KEYS["size_mm"]),
        "weight_kg":        _pick(specs, COMMON_KEYS["weight_kg"]),
        "thinq_wifi":       _bool(_pick(specs, COMMON_KEYS["thinq_wifi"])),
        "up_appliance":     _bool(_pick(specs, COMMON_KEYS["up_appliance"])),
        "capacity_l":       _num(_pick(specs, CAT_KEYS["capacity_l"])),
        "dry_capacity_kg":  _num(_pick(specs, CAT_KEYS["dry_capacity_kg"])),
        "suction_w":        _num(_pick(specs, CAT_KEYS["suction_w"])),
        "power_w":          _num(_pick(specs, CAT_KEYS["power_w"])),
        # 나머지 스펙 → JSONB
        "detail_specs":     {k: v for k, v in specs.items() if k not in ALL_EXTRACTED},
    }
    return row


def main():
    with open(IN_FILE, encoding="utf-8") as f:
        products = json.load(f)

    rows = [build_row(p) for p in products if p.get("model_code")]
    print(f"업로드 대상: {len(rows)}개")

    sb = create_client(SUPABASE_URL, SUPABASE_KEY)

    ok = fail = 0
    total_batches = (len(rows) + BATCH - 1) // BATCH
    for i in range(0, len(rows), BATCH):
        batch = rows[i:i+BATCH]
        bn = i // BATCH + 1
        try:
            sb.table(TABLE).insert(batch).execute()
            ok += len(batch)
            print(f"  배치 {bn}/{total_batches}: {len(batch)}개 완료 (누적 {ok}개)")
        except Exception as e:
            fail += len(batch)
            print(f"  배치 {bn}/{total_batches}: 오류 — {e}")
        time.sleep(0.3)

    print(f"\n완료: 성공 {ok}개 | 실패 {fail}개")
    if fail == 0:
        # 샘플 출력
        s = rows[0]
        print(f"\n[샘플: {s['model_code']}] {s['name'][:30]}")
        for k in ("category","energy_grade","capacity_l","thinq_wifi","color"):
            print(f"  {k}: {s.get(k)}")
        print(f"  detail_specs 키 수: {len(s.get('detail_specs',{}))}")


if __name__ == "__main__":
    main()
