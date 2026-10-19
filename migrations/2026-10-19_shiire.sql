-- ============================================================
-- 2026-10-19 仕入れコース（別枠）の報告項目を追加
-- Supabase ダッシュボード → SQL Editor に丸ごと貼って RUN するだけ
-- ・ADD COLUMN IF NOT EXISTS なので、何度実行しても安全（既存データはそのまま）
-- ・DROP を使わないので、SQL Editor の「破壊的操作」確認ダイアログは出ません
-- ・未実行の間もボードは動きます（仕入れコースの内容は面談メモの先頭／日次報告メモの末尾に書き足して保存）
-- ・事前入力リンク: https://supabase.com/dashboard/project/<project-ref>/sql/new?content=<このSQLをURLエンコード>
-- ============================================================

-- 面談報告（顧客ごと）：仕入れコースの案内状況と、後日提案の予定
ALTER TABLE sc_deals ADD COLUMN IF NOT EXISTS shiire_status    TEXT DEFAULT '未案内';  -- 未案内 / 提案済み / 後日提案 / 提案しない / 仕入れコース成約
ALTER TABLE sc_deals ADD COLUMN IF NOT EXISTS shiire_plan_date DATE;                   -- 後日提案の予定日
ALTER TABLE sc_deals ADD COLUMN IF NOT EXISTS shiire_plan_time TEXT DEFAULT '';        -- 後日提案の時間帯：午前 / 昼 / 夕方 / 夜 / 未定
ALTER TABLE sc_deals ADD COLUMN IF NOT EXISTS shiire_note      TEXT DEFAULT '';        -- 提案しない理由・ひとこと
ALTER TABLE sc_deals ADD COLUMN IF NOT EXISTS shiire_at        DATE;                   -- 提案日（提案済み／成約にした日。提案数・成約数はこの日で数える）

-- 日次報告：仕入れコースの提案数・成約数（成約数 closed とは別枠）
ALTER TABLE sc_reports ADD COLUMN IF NOT EXISTS shiire_proposed INTEGER DEFAULT 0;     -- 仕入れコース 提案数
ALTER TABLE sc_reports ADD COLUMN IF NOT EXISTS shiire_closed   INTEGER DEFAULT 0;     -- 仕入れコース 成約数

-- 名簿管理パネル（集計タブの一番下・くみこ／清水さんのみ）から、ログイン許可メール（sc_access）を追加できるようにする
-- ・sc_access のポリシーから sc_access 自身を参照すると無限ループになるため、判定は SECURITY DEFINER 関数で行う
CREATE OR REPLACE FUNCTION sc_is_lead() RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM sc_access WHERE email = lower(auth.jwt() ->> 'email') AND role_hint IN ('owner','exec'));
$$;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='sc_access' AND policyname='sc_access_lead_write') THEN
    CREATE POLICY "sc_access_lead_write" ON sc_access FOR ALL TO authenticated
      USING (sc_is_lead()) WITH CHECK (sc_is_lead());
  END IF;
END $$;

-- 画面からすぐ使えるように API（PostgREST）のスキーマキャッシュを更新
NOTIFY pgrst, 'reload schema';

-- 確認（結果が 5 / 2 / 1 なら完了）
SELECT
  (SELECT count(*) FROM information_schema.columns WHERE table_name='sc_deals'   AND column_name LIKE 'shiire%') AS deals_cols,
  (SELECT count(*) FROM information_schema.columns WHERE table_name='sc_reports' AND column_name LIKE 'shiire%') AS report_cols,
  (SELECT count(*) FROM pg_policies WHERE policyname='sc_access_lead_write') AS policy;
