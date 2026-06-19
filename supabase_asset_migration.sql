-- =============================================
-- LG MoveIn - 에셋 컬럼 추가 마이그레이션
-- lg_products 테이블에 3D 에셋 / 이미지 에셋 컬럼 추가
-- 보유 모델에만 경로 업데이트
-- =============================================

-- 1. 컬럼 추가
ALTER TABLE lg_products
    ADD COLUMN IF NOT EXISTS model_3d_asset  TEXT,   -- GLB 파일명 (예: M876GBB231.glb)
    ADD COLUMN IF NOT EXISTS image_asset     TEXT;   -- 이미지 파일명 (예: M876GBB231.jpg)


-- 2. 이미지 에셋 보유 모델 업데이트 (41개)
UPDATE lg_products SET image_asset = model_code || '.jpg'
WHERE model_code IN (
    '1EG-20W',
    'A730WA',
    'AS155GWDL',
    'AS205NSJAM',
    'AS235DWSA',
    'AS356NSLLM',
    'AS520HA',
    'AX948BHE-BKOR1',
    'B95AWBTH',
    'D215MHH13',
    'DEE6BGE',
    'DFE6BGHE',
    'DUE5BGE',
    'DUE6EWL2E',
    'F19WDLPR',
    'FG24VNS-AKOR2',
    'FQ17GU1ED2',
    'FQ17GW1HD1',
    'FQ17GW1HD2',
    'FQ18GC3EK2',
    'FQ18GN7BP2',
    'FS065PSKA',
    'G646SVV091',
    'KX23ENERGNG',
    'KX25GFG-5EE',
    'M616GBB0M1',
    'M626GBB032',
    'M876GBB231',
    'RH10WTW',
    'S834MEE111',
    'S836MEE022',
    'SQ06ADACAJ-AKORY',
    'SQ06GA1WAJ-AKOR',
    'T17DX3A',
    'TR15WV5',
    'W2420EEZR',
    'WD120MCB',
    'WD220MHB',
    'WD523ACB',
    'WD525ACB',
    'WU923AS'
);


-- 3. 3D 에셋 보유 모델 업데이트 (38개)
UPDATE lg_products SET model_3d_asset = model_code || '.glb'
WHERE model_code IN (
    'A730WA',
    'AS155GWDL',
    'AS205NSJAM',
    'AS235DWSA',
    'AS356NSLLM',
    'AS520HA',
    'AX948BHE-BKOR1',
    'B95AWBTH',
    'D215MHH13',
    'DEE6BGE',
    'DFE6BGHE',
    'DUE5BGE',
    'DUE6EWL2E',
    'F19WDLPR',
    'FG24VNS-AKOR2',
    'FQ17GU1ED2',
    'FQ17GW1HD1',
    'FQ17GW1HD2',
    'FQ18GC3EK2',
    'FQ18GN7BP2',
    'FS065PSKA',
    'G646SVV091',
    'KX23ENERGNG',
    'KX25GFG-5EE',
    'M616GBB0M1',
    'M876GBB231',
    'RH10WTW',
    'S834MEE111',
    'S836MEE022',
    'SQ06ADACAJ-AKORY',
    'SQ06GA1WAJ-AKOR',
    'T17DX3A',
    'TR15WV5',
    'WD120MCB',
    'WD220MHB',
    'WD523ACB',
    'WD525ACB',
    'WU923AS'
);


-- 4. 가전 사용 여부 컬럼 추가 및 상태 정리
ALTER TABLE lg_products
    ADD COLUMN IF NOT EXISTS usage_status TEXT DEFAULT 'unused';

-- 에셋(이미지 또는 3D 모델)이 매핑되어 실제 사용 중인 가전들을 'used'로 표시
UPDATE lg_products
SET usage_status = 'used'
WHERE image_asset IS NOT NULL OR model_3d_asset IS NOT NULL;


-- 5. 확인 쿼리
SELECT
    model_code,
    name,
    category,
    usage_status,
    CASE WHEN image_asset IS NOT NULL THEN '✅' ELSE '❌' END AS has_image,
    CASE WHEN model_3d_asset IS NOT NULL THEN '✅' ELSE '❌' END AS has_3d
FROM lg_products
ORDER BY usage_status DESC, category, model_code;
