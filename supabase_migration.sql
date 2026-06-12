-- =============================================
-- LG MoveIn - 추가 마이그레이션
-- 기존 스키마 기준으로 아래 내용 추가 실행
-- =============================================


-- =============================================
-- A. LG 제품 카탈로그 (크롤링 데이터)
--    Vision LLM이 식별한 모델코드를 여기서 조회해
--    정확한 제품명 / 출시연도 / 신품가를 확인
-- =============================================

CREATE TABLE lg_products (
    product_id    BIGSERIAL    PRIMARY KEY,
    model_code    TEXT         NOT NULL,          -- 모델 코드 (예: WHDFV1, RT48K...)
    name          TEXT         NOT NULL,          -- 공식 제품명
    category      TEXT         NOT NULL,          -- 냉장고 / 세탁기 / 에어컨 등
    brand         TEXT         NOT NULL DEFAULT 'LG',
    release_year  TEXT,                           -- 출시 연도 (예: '2023')
    price_new_krw INTEGER,                        -- 신품 출시가 (원)
    images        TEXT[]       DEFAULT '{}',      -- 공식 제품 이미지 URL 배열
    specs         JSONB        DEFAULT '{}',      -- 스펙 (용량/크기/에너지등급 등 자유 형식)
    product_url   TEXT,                           -- LG 제품 상세 페이지 URL
    crawled_at    TIMESTAMPTZ,                    -- 크롤링 시각
    created_at    TIMESTAMP    DEFAULT NOW()
);

-- 모델코드 부분 일치 검색용 (Vision LLM 결과가 불완전할 수 있음)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_lg_products_model_trgm   ON lg_products USING gin (model_code gin_trgm_ops);
CREATE INDEX idx_lg_products_name_trgm    ON lg_products USING gin (name gin_trgm_ops);
CREATE INDEX idx_lg_products_category     ON lg_products (category);

-- RLS: 읽기는 전체 공개, 쓰기는 service_role만 (크롤러 업로드)
ALTER TABLE lg_products ENABLE ROW LEVEL SECURITY;
CREATE POLICY lgp_select ON lg_products FOR SELECT USING (true);


-- =============================================
-- B. trade_in 테이블 확장
--    기존 단순 트레이드인 레코드에
--    마켓 게시 기능 컬럼 추가
-- =============================================

-- 다중 이미지 (기존 image_url은 단일, 새 컬럼으로 추가)
ALTER TABLE trade_in
    ADD COLUMN IF NOT EXISTS image_urls     TEXT[]        DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS defects        TEXT[]        DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS price_min      DECIMAL(10,2),
    ADD COLUMN IF NOT EXISTS price_max      DECIMAL(10,2),
    ADD COLUMN IF NOT EXISTS listed_price   DECIMAL(10,2),
    ADD COLUMN IF NOT EXISTS price_basis    TEXT,         -- 견적 근거 (AI 생성)
    ADD COLUMN IF NOT EXISTS listing_title  VARCHAR(255),
    ADD COLUMN IF NOT EXISTS listing_body   TEXT,
    ADD COLUMN IF NOT EXISTS seller_memo    TEXT,         -- 판매자 직접 입력 메모
    ADD COLUMN IF NOT EXISTS views          INT           DEFAULT 0,
    ADD COLUMN IF NOT EXISTS listed_at      TIMESTAMP;    -- 마켓 게시 시각

-- listing_status 예상 값:
--   'draft'    : AI 분석 완료, 아직 미게시
--   'listed'   : 마켓 공개 게시 중
--   'reserved' : 예약 중
--   'sold'     : 거래 완료
--   'removed'  : 삭제/철회

-- RLS 수정: 게시된 매물은 전체 사용자가 조회 가능
DROP POLICY IF EXISTS ti_select ON trade_in;

CREATE POLICY ti_select ON trade_in
    FOR SELECT USING (
        listing_status = 'listed'          -- 공개 매물은 누구나 조회
        OR listing_status = 'reserved'
        OR listing_status = 'sold'
        OR schedule_id IN (                -- 본인 매물은 모든 상태 조회
            SELECT schedule_id FROM moving_schedule WHERE user_id = auth.uid()
        )
    );


-- =============================================
-- C. 중고 거래 채팅 (선택적 - 향후 구현 시)
--    "채팅으로 문의하기" 버튼 연동용
-- =============================================

-- CREATE TABLE trade_in_chat (
--     chat_id     BIGSERIAL PRIMARY KEY,
--     tradein_id  BIGINT    NOT NULL REFERENCES trade_in(tradein_id),
--     sender_id   UUID      NOT NULL REFERENCES users(user_id),
--     message     TEXT      NOT NULL,
--     created_at  TIMESTAMP DEFAULT NOW()
-- );
