/**
 * セールス クローザー ダッシュボード → Slack 自動投稿ボット（GAS Web App）
 * ------------------------------------------------------------
 * ダッシュボードのフォーム送信を受け取り、マーケ03_セールス報告スレへ投稿します。
 * Slack Webhook はこのプロジェクトの「スクリプトプロパティ」に保管するため、
 * 公開リポジトリにもフロント側にも秘密情報は出ません。
 *
 * 【セットアップ手順】
 *  1) Slack で Incoming Webhook を作成
 *     - https://api.slack.com/apps → Create New App → From scratch
 *     - Incoming Webhooks を ON → Add New Webhook to Workspace
 *     - 投稿先チャンネルに「#マーケ03_セールス報告スレ」を選択 → Webhook URL をコピー
 *  2) このコードを新規 Apps Script プロジェクトに貼り付け
 *  3) プロジェクトの設定 → スクリプトプロパティに以下を追加
 *       キー:  SLACK_WEBHOOK_URL   値: （コピーした Webhook URL）
 *  4) デプロイ → 新しいデプロイ → 種類「ウェブアプリ」
 *       実行するユーザー: 自分 ／ アクセスできるユーザー: 全員
 *     → 発行された /exec URL を supabase_config.js の slackRelayUrl に貼る
 *  5) 一度 testPost() を実行して #マーケ03 に届くか確認
 */

function doPost(e) {
  try {
    var p = JSON.parse(e.postData.contents);
    var url = PropertiesService.getScriptProperties().getProperty('SLACK_WEBHOOK_URL');
    if (!url) return _json({ ok: false, error: 'SLACK_WEBHOOK_URL 未設定' });
    UrlFetchApp.fetch(url, {
      method: 'post',
      contentType: 'application/json',
      payload: JSON.stringify({ text: buildText(p) }),
      muteHttpExceptions: true
    });
    return _json({ ok: true });
  } catch (err) {
    return _json({ ok: false, error: String(err) });
  }
}

/** 投稿本文を組み立て（既存の報告スレのトーンに合わせる） */
function buildText(p) {
  var d = p.date ? fmtDate(p.date) : '';
  var mention = p.slack_id ? ('<@' + p.slack_id + '> ') : '';
  var lines = [];
  lines.push('*【セールス報告】' + d + '　' + (p.closer || '') + '*　' + mention);
  lines.push('面談 ' + num(p.meetings) + ' / 即決 ' + num(p.instant) + ' / *成約 ' + num(p.closed) + '*');
  lines.push('■ パイプライン：' + (p.pipeline || 'なし'));
  if (p.note) lines.push('■ ネクストアクション：' + p.note);
  return lines.join('\n');
}

function num(v){ v = parseInt(v, 10); return isNaN(v) ? 0 : v; }

function fmtDate(s) {
  var a = s.split('-');
  var dt = new Date(+a[0], +a[1] - 1, +a[2]);
  var w = ['日','月','火','水','木','金','土'][dt.getDay()];
  return (+a[1]) + '/' + (+a[2]) + '(' + w + ')';
}

function _json(o) {
  return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
}

/** 動作確認用：実行すると #マーケ03 にテスト投稿されます */
function testPost() {
  var url = PropertiesService.getScriptProperties().getProperty('SLACK_WEBHOOK_URL');
  UrlFetchApp.fetch(url, {
    method: 'post', contentType: 'application/json',
    payload: JSON.stringify({ text: buildText({
      closer: 'テスト太郎', date: '2026-07-27', meetings: 3, instant: 2, closed: 1,
      pipeline: '面談前1・口頭合意〜入金前4・リスケ2', note: '口頭合意◯◯さん明日入金予定'
    }) })
  });
}
