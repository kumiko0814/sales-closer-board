-- ============================================================
-- セールス クローザー ダッシュボード テーブル定義
-- Supabase ダッシュボード → SQL Editor に丸ごと貼って RUN するだけ
-- （ナーチャリング共有ボード等と同じ Supabase プロジェクトに相乗り。
--   既存テーブルには一切触れません。プレフィックス sc_ で分離）
-- ============================================================
-- ★このSQLを実行すると:
--   ・許可アドレスでログインした人「だけ」が読み書きできる
--   ・ログインしていない人(anon)は 1文字も読めない・書けない
-- ★個人情報保護：
--   クローザー実名・メール・目標値は、この公開SQLには含めません。
--   別途お渡しする「SEED（非公開）」を Supabase に貼って投入してください。
-- ============================================================

-- 1. クローザー名簿（タブの元。ここに居る人だけダッシュボードに出る）
CREATE TABLE IF NOT EXISTS sc_closers (
  id          TEXT PRIMARY KEY,             -- 英字スラッグ（例: honda / shibayama）
  name        TEXT NOT NULL,                -- 表示名（例: 本田理恵）
  slack_id    TEXT DEFAULT '',              -- Slackメンション用 U... （任意）
  team        TEXT DEFAULT 'closer',        -- closer / trainee など（任意）
  active      BOOLEAN DEFAULT TRUE,          -- false にすると非表示（辞めた人）
  sort_order  BIGINT DEFAULT 100,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 月間成約目標（クローザー×年月。closer_id='__team__' はチーム全体の上書き目標）
CREATE TABLE IF NOT EXISTS sc_targets (
  closer_id     TEXT NOT NULL,
  ym            TEXT NOT NULL,               -- 'YYYY-MM'
  target_deals  INTEGER DEFAULT 0,           -- 月間 成約目標数（件）
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (closer_id, ym)
);

-- 3. 日次報告（1クローザー×1日で1行。同日再送信は上書き）
CREATE TABLE IF NOT EXISTS sc_reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  closer_id     TEXT NOT NULL,
  report_date   DATE NOT NULL DEFAULT CURRENT_DATE,
  -- フロー（その日の実績）
  meetings      INTEGER DEFAULT 0,           -- 面談数
  instant_close INTEGER DEFAULT 0,           -- 即決数
  closed        INTEGER DEFAULT 0,           -- 成約数（入金完了ベース）
  -- パイプライン（現在のストック＝スナップショット）
  p_before      INTEGER DEFAULT 0,           -- 面談前
  p_after       INTEGER DEFAULT 0,           -- 面談後〜判断前
  p_verbal      INTEGER DEFAULT 0,           -- 口頭合意〜入金前
  p_loan        INTEGER DEFAULT 0,           -- ローン申請中
  p_sched       INTEGER DEFAULT 0,           -- 日程調整中
  p_resched     INTEGER DEFAULT 0,           -- リスケ
  p_cooloff     INTEGER DEFAULT 0,           -- クーリングオフ対応中
  note          TEXT DEFAULT '',             -- ネクストアクション／所感
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (closer_id, report_date)
);

-- 4. 口頭合意など「個別案件」進捗（顧客ごと。任意入力・後追い用）
CREATE TABLE IF NOT EXISTS sc_deals (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  closer_id   TEXT NOT NULL,
  customer    TEXT NOT NULL,                 -- 顧客名（ニックネーム可）
  deal_date   DATE,                          -- 面談／合意日
  status      TEXT DEFAULT '口頭合意〜入金前',  -- 口頭合意〜入金前 / ローン申請中 / 入金完了 / 辞退 など
  memo        TEXT DEFAULT '',
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 5. アクセス管理（ここに登録されたメールだけ入れる）
CREATE TABLE IF NOT EXISTS sc_access (
  email      TEXT PRIMARY KEY,
  role_hint  TEXT DEFAULT 'closer',          -- owner / exec / closer の目安
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- RLS：許可アドレスでログインした人だけ CRUD 可（anonは全拒否）
-- ------------------------------------------------------------
ALTER TABLE sc_closers ENABLE ROW LEVEL SECURITY;
ALTER TABLE sc_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE sc_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE sc_deals   ENABLE ROW LEVEL SECURITY;
ALTER TABLE sc_access  ENABLE ROW LEVEL SECURITY;

-- 認証ユーザーは「自分のメールの行」だけ読める（自分が許可対象か確認用）
DROP POLICY IF EXISTS "sc_access_self" ON sc_access;
CREATE POLICY "sc_access_self" ON sc_access FOR SELECT TO authenticated
  USING (email = lower(auth.jwt() ->> 'email'));

-- データ4テーブル：ログインメールが sc_access に登録されていれば全操作OK
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['sc_closers','sc_targets','sc_reports','sc_deals']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS "sc_members" ON %I;', t);
    EXECUTE format(
      'CREATE POLICY "sc_members" ON %I FOR ALL TO authenticated '
      || 'USING (EXISTS (SELECT 1 FROM sc_access a WHERE a.email = lower(auth.jwt() ->> ''email''))) '
      || 'WITH CHECK (EXISTS (SELECT 1 FROM sc_access a WHERE a.email = lower(auth.jwt() ->> ''email'')));',
      t);
  END LOOP;
END $$;

-- 完了！ このあと、別途お渡しする SEED（非公開：名簿・メール・目標）を貼って RUN → index.html を開く
