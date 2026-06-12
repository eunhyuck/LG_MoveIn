-- ① 공통 칼럼 추가
ALTER TABLE lg_products
  ADD COLUMN IF NOT EXISTS color           TEXT,           -- 색상
  ADD COLUMN IF NOT EXISTS energy_grade    TEXT,           -- 에너지 소비효율등급
  ADD COLUMN IF NOT EXISTS size_mm         TEXT,           -- 크기 (WxHxD, mm)
  ADD COLUMN IF NOT EXISTS weight_kg       TEXT,           -- 무게 (kg)
  ADD COLUMN IF NOT EXISTS thinq_wifi      BOOLEAN,        -- ThinQ(Wi-Fi)
  ADD COLUMN IF NOT EXISTS up_appliance    BOOLEAN,        -- UP 가전
  ADD COLUMN IF NOT EXISTS capacity_l      NUMERIC,        -- 냉장고 전체 용량 (L)
  ADD COLUMN IF NOT EXISTS dry_capacity_kg NUMERIC,        -- 건조기 건조 용량 (kg)
  ADD COLUMN IF NOT EXISTS suction_w       NUMERIC,        -- 청소기 최대흡입력 (W)
  ADD COLUMN IF NOT EXISTS power_w         NUMERIC,        -- 공기청정기 소비전력 (W)
  ADD COLUMN IF NOT EXISTS detail_specs    JSONB;          -- 나머지 스펙
