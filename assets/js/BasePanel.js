/**
 * WebView2 面板与 AHK 通讯的共享薄封装（通过 https://app.local/ 加载）。
 * 在 payload 上附加 v，AHK 端可忽略未知字段；与仅含 type 的旧消息兼容。
 */
(function (g) {
  'use strict';

  var PROTO = 1;

  function normalizePayload(obj) {
    if (!obj || typeof obj !== 'object' || Array.isArray(obj)) return obj;
    var payload = Object.assign({ v: PROTO }, obj);
    payload.timestamp = Date.now();
    if (payload.action === undefined && payload.type !== undefined)
      payload.action = payload.type;
    return payload;
  }

  function postToAhk(obj) {
    if (!window.chrome || !window.chrome.webview) return;
    window.chrome.webview.postMessage(normalizePayload(obj));
  }

  g.BasePanel = {
    PROTO_VERSION: PROTO,
    postToAhk: postToAhk
  };

  if (window.chrome && window.chrome.webview) {
    window.chrome.webview.addEventListener('message', function (ev) {
      var d = ev.data;
      if (typeof d === 'string') {
        try {
          d = JSON.parse(d);
        } catch (e) {
          return;
        }
      }
      if (!d || d.type !== 'RESET_STATE') return;
      try {
        if (typeof window.onWebViewResetState === 'function') window.onWebViewResetState();
      } catch (e) {}
    });
  }
})(typeof globalThis !== 'undefined' ? globalThis : window);
