"""
LG 제품 스펙 → Supabase 업로드 스크립트

실행 전 Supabase 대시보드에서 아래 SQL 실행 필요:
─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lg_products (
    model_code       TEXT PRIMARY KEY,
    name             TEXT,
    category         TEXT,
    brand            TEXT,
    release_year     INTEGER,
    price_new_krw    INTEGER,
    images           JSONB,
    product_url      TEXT,
    specs            JSONB,
    crawled_at       TEXT,
    updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- service_role 키로 실행하거나, 아래 RLS 정책 추가:
ALTER TABLE lg_products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon select" ON lg_products FOR SELECT USING (true);
CREATE POLICY "service insert" ON lg_products FOR INSERT WITH CHECK (true);
CREATE POLICY "service update" ON lg_products FOR UPDATE USING (true);
─────────────────────────────────────────────────────

실행:
    python tools/upload_specs_to_supabase.py

환경 변수로 service_role 키 지정 (선택):
    set SUPABASE_SERVICE_KEY=eyJ...
    python tools/upload_specs_to_supabase.py
"""

import sys, json, os, time
sys.stdout.reconfigure(encoding='utf-8')

from supabase import create_client

# ─── 설정 ──────────────────────────────────────────────────────────
SUPABASE_URL = "https://fdugmidipljoesfsshzn.supabase.co"

# service_role 키 환경변수로 받거나, 없으면 anon 키 사용
# (RLS 정책이 없는 경우 anon 키로는 INSERT 불가 → 위 SQL로 정책 추가 필요)
SUPABASE_KEY = os.environ.get(
    "SUPABASE_SERVICE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkdWdtaWRpcGxqb2VzZnNzaHpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA5ODMwMjksImV4cCI6MjA5NjU1OTAyOX0.pxTJHby6s_dvz7K8rciy4efdykaCdZ7BRXEMW44POrw"
)

TABLE      = "lg_products"
IN_FILE    = os.path.join(os.path.dirname(__file__), "lg_products_with_specs.json")
BATCH_SIZE = 50   # 한 번에 upsert할 행 수


# ─── 데이터 변환 ────────────────────────────────────────────────────

def to_row(p: dict) -> dict:
    """JSON 레코드 → Supabase 행"""
    return {
        "model_code":    p.get("model_code", ""),
        "name":          p.get("name", ""),
        "category":      p.get("category", ""),
        "brand":         p.get("brand", "LG"),
        "release_year":  _to_int(p.get("release_year")),
        "price_new_krw": _to_int(p.get("price_new_krw")),
        "images":        p.get("images", []),
        "product_url":   p.get("product_url", ""),
        "specs":         p.get("specs", {}),
        "crawled_at":    p.get("crawled_at", ""),
    }

def _to_int(v):
    try:
        return int(v) if v is not None else None
    except (ValueError, TypeError):
        return None


# ─── 업로드 ────────────────────────────────────────────────────────

def main():
    # 데이터 로드
    with open(IN_FILE, encoding="utf-8") as f:
        products = json.load(f)

    # 스펙 있는 제품만, 또는 model_code 있는 전체
    rows = [to_row(p) for p in products if p.get("model_code")]
    print(f"업로드 대상: {len(rows)}개")

    # 스펙 통계
    with_specs = sum(1 for p in products if p.get("specs"))
    print(f"  스펙 있음: {with_specs}개 | 스펙 없음: {len(rows)-with_specs}개")
    print()

    # Supabase 클라이언트
    sb = create_client(SUPABASE_URL, SUPABASE_KEY)

    # 배치 upsert
    ok = 0
    fail = 0
    for i in range(0, len(rows), BATCH_SIZE):
        batch = rows[i : i + BATCH_SIZE]
        batch_num = i // BATCH_SIZE + 1
        total_batches = (len(rows) + BATCH_SIZE - 1) // BATCH_SIZE

        try:
            res = (
                sb.table(TABLE)
                .insert(batch)
                .execute()
            )
            ok += len(batch)
            print(f"  배치 {batch_num}/{total_batches}: {len(batch)}개 완료 (누적 {ok}개)")
        except Exception as e:
            fail += len(batch)
            print(f"  배치 {batch_num}/{total_batches}: 오류 — {e}")

        time.sleep(0.3)  # rate limit 방지

    print()
    print(f"완료: 성공 {ok}개 | 실패 {fail}개")

    if fail > 0:
        print()
        print("[참고] 실패 시 체크사항:")
        print("  1. Supabase 대시보드 → Table Editor → lg_products 테이블 존재 여부")
        print("  2. RLS 정책 (위 SQL 참고) 또는 service_role 키 필요")
        print("     → set SUPABASE_SERVICE_KEY=eyJ...")
        print("        python tools/upload_specs_to_supabase.py")


if __name__ == "__main__":
    main()
