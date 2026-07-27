// ============================================================
// セールス クローザー ダッシュボード  Supabase 設定
// ============================================================
// ナーチャリング共有ボード等と同じ Supabase プロジェクトに相乗り。
// くみこがやることは「setup.html の SQL を1回貼る」＋「SEEDを貼る」だけ。
// ============================================================

const SUPABASE_CONFIG = {
  url: 'https://inrvprlyobghviklulcv.supabase.co',
  anonKey: 'sb_publishable_ZrCNcsRHMci-l7Fns8QtIA_X22XZGJp',

  // フォーム送信時に Slack（マーケ03_セールス報告スレ）へ自動投稿するための
  // GAS Web App の /exec URL。未設定（空）なら Slack投稿はスキップ（ダッシュボードは通常動作）。
  // ※Slack Webhook本体は GAS 側の Script Property に保管。ここには公開OKな /exec URL のみ。
  slackRelayUrl: 'https://script.google.com/macros/s/AKfycbx5KAcSfdK_XVvLOX7-yZxeDhZMO83PebO7e50j9pkcAOAf55ogDDa11-7Pyzag-tqP/exec',

  get enabled(){ return !!(this.url && this.anonKey); }
};
