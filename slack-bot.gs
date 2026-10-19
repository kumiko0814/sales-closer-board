/**
 * セールス クローザー ダッシュボード → Slack 中継 Web App
 * ・マーケ03_セールス報告スレ（数値報告）の当日リマインダーのスレッドに返信
 * ・マーケ07_プロライン運営（面談報告）の当日リマインダーのスレッドに返信
 * payload で channel / reminder_key / text を切り替え。
 * ※非公開ディレクトリ(scripts/)。GitHubには push しません（Botトークンを含む）。
 */
var SLACK_BOT_TOKEN = PropertiesService.getScriptProperties().getProperty('SLACK_BOT_TOKEN') || ''; // 公開ミラーのためトークンは載せない（本番は scripts/closer-slack-relay/Code.gs）
var CHANNEL_ID      = 'C0AFE0AQFPE'; // 既定=#マーケ03_セールス報告スレ
var REMINDER_KEY    = '本日のセールス報告';

function doGet(e) { return _json({ ok: true, msg: 'closer-slack-relay alive' }); }

function doPost(e) {
  try {
    var p = JSON.parse(e.postData.contents);
    var channel = p.channel || CHANNEL_ID;
    var key = p.reminder_key || REMINDER_KEY;
    var threadTs = findTodayReminderTs_(channel, key); // 無ければ null → チャンネル通常投稿
    var res = postMessage_(channel, buildText(p), threadTs);
    return _json({ ok: res.ok, threaded: !!threadTs, error: res.error || '' });
  } catch (err) {
    return _json({ ok: false, error: String(err) });
  }
}

function postMessage_(channel, text, threadTs) {
  var payload = { channel: channel, text: text, unfurl_links: false, unfurl_media: false };
  if (threadTs) { payload.thread_ts = threadTs; payload.reply_broadcast = false; }
  var r = UrlFetchApp.fetch('https://slack.com/api/chat.postMessage', {
    method: 'post', contentType: 'application/json; charset=utf-8',
    headers: { Authorization: 'Bearer ' + SLACK_BOT_TOKEN },
    payload: JSON.stringify(payload), muteHttpExceptions: true
  });
  return JSON.parse(r.getContentText());
}

/** 指定チャンネルの当日リマインダー（key を含む当日メッセージ）の ts を返す */
function findTodayReminderTs_(channel, key) {
  try {
    var r = UrlFetchApp.fetch('https://slack.com/api/conversations.history?channel=' + channel + '&limit=80', {
      method: 'get', headers: { Authorization: 'Bearer ' + SLACK_BOT_TOKEN }, muteHttpExceptions: true
    });
    var d = JSON.parse(r.getContentText());
    if (!d.ok) return null;
    var today = Utilities.formatDate(new Date(), 'Asia/Tokyo', 'yyyy-MM-dd');
    for (var i = 0; i < d.messages.length; i++) {
      var m = d.messages[i];
      if ((m.text || '').indexOf(key) === -1) continue;
      var mday = Utilities.formatDate(new Date(parseFloat(m.ts) * 1000), 'Asia/Tokyo', 'yyyy-MM-dd');
      if (mday === today) return m.thread_ts || m.ts;
    }
    return null;
  } catch (err) { return null; }
}

function buildText(p) {
  var mention = p.slack_id ? ('<@' + p.slack_id + '> ') : '';
  if (p.text) { return p.text + (mention ? ('\n' + mention) : ''); }
  var d = p.date ? fmtDate(p.date) : '';
  var lines = [];
  lines.push('*【セールス報告】' + d + '　' + (p.closer || '') + '*　' + mention);
  lines.push('面談 ' + num(p.meetings) + ' / 即決 ' + num(p.instant) + ' / *成約 ' + num(p.closed) + '*');
  lines.push('■ パイプライン：' + (p.pipeline || 'なし'));
  // 仕入れコース（別枠・成約数には含めない）：どちらかが1以上のときだけ
  if (num(p.shiire_proposed) > 0 || num(p.shiire_closed) > 0) {
    lines.push('■ 仕入れコース：提案 ' + num(p.shiire_proposed) + ' / 成約 ' + num(p.shiire_closed));
  }
  if (p.note) lines.push('■ ネクストアクション：' + p.note);
  return lines.join('\n');
}

function num(v) { v = parseInt(v, 10); return isNaN(v) ? 0 : v; }
function fmtDate(s) {
  var a = s.split('-'), dt = new Date(+a[0], +a[1] - 1, +a[2]);
  var w = ['日','月','火','水','木','金','土'][dt.getDay()];
  return (+a[1]) + '/' + (+a[2]) + '(' + w + ')';
}
function _json(o) { return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON); }
