(function (global) {
  'use strict';

  var STYLE_ID = 'nm-bottom-dock-style';
  var ROOT_ID = 'nm-bottom-dock';

  var ITEMS = [
    { id: 'niuma', title: '牛马 Chat', cmdId: 'ch_r', sceneId: 'ai', isLogo: true },
    { id: 'search', title: '搜索中心', cmdId: 'sc_activate_search', sceneId: 'search', icon: '<circle cx="11" cy="11" r="8"></circle><path d="m21 21-4.35-4.35"></path>' },
    { id: 'clipboard', title: '剪贴板', cmdId: 'qa_clipboard', sceneId: 'clipboard', icon: '<rect x="8" y="2" width="8" height="4" rx="1"></rect><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path>' },
    { id: 'prompts', title: '提示词', cmdId: 'ch_b', sceneId: 'prompts', icon: '<path d="M12 3c4.97 0 9 3.58 9 8 0 1.8-.67 3.47-1.8 4.82L20 21l-5.02-1.67A10.53 10.53 0 0 1 12 20c-4.97 0-9-8-9-8s4.03-9 9-9Z"></path>' },
    { id: 'scratchpad', title: '草稿本', cmdId: 'hub_capsule', sceneId: 'scratchpad', icon: '<path d="M6 3h11a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"></path><path d="M8 7h8"></path><path d="M8 11h8"></path><path d="M8 15h5"></path>' },
    { id: 'screenshot', title: '截图', cmdId: 'ch_t', sceneId: 'screenshot', icon: '<path d="M4 7h4l2-2h4l2 2h4v12H4z"></path><circle cx="12" cy="13" r="3.5"></circle>' },
    { id: 'settings', title: '设置', cmdId: 'qa_config', sceneId: 'settings', icon: '<circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path>' },
    { id: 'hotkeys', title: '快捷键', cmdId: 'sys_show_vk', sceneId: 'hotkeys', icon: '<rect x="2.5" y="5" width="19" height="14" rx="2.5"></rect><path d="M6 9h1M9 9h1M12 9h1M15 9h1M18 9h1M6 12h1M9 12h1M12 12h1M15 12h1M18 12h1M7 15h10"></path>' },
    { id: 'cursor', title: 'Cursor', cmdId: 'cursor_open', sceneId: 'cursor', icon: '<path d="M7 3l10 9-5 1.5L10 20z"></path><path d="m12 13 4 5"></path>' },
    { id: 'cloud', title: '云盘', cmdId: 'open_cloudplayer', sceneId: 'cloudplayer', always: true, icon: '<path d="M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"></path>' }
  ];

  function normalizeSceneId(v) {
    var s = String(v || '').trim().toLowerCase();
    if (s === 'notepad') return 'scratchpad';
    return s;
  }

  function ensureStyle() {
    if (document.getElementById(STYLE_ID)) return;
    var style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = '' +
      ':root{--nm-ui:1;}'+
      'body.nm-dock-mounted{padding-bottom:56px !important;}'+
      '#' + ROOT_ID + '{position:fixed;left:0;right:0;bottom:0;z-index:2147483000;display:flex;justify-content:center;pointer-events:none;}'+
      '#' + ROOT_ID + ' .nm-collapsed{position:relative;pointer-events:auto;display:flex;flex-direction:row;align-items:center;gap:calc(5px * var(--nm-ui));padding:calc(6px * var(--nm-ui)) calc(8px * var(--nm-ui));background:var(--toolbar-bg,#0a0a0a);border-radius:calc(10px * var(--nm-ui));max-width:min(980px,calc(100vw - 10px));overflow-x:auto;scrollbar-width:none;}'+
      '#' + ROOT_ID + ' .nm-collapsed::-webkit-scrollbar{display:none;}'+
      '#' + ROOT_ID + ' .logo-btn{flex-shrink:0;width:max(calc(42px * var(--nm-ui)),34px);height:max(calc(42px * var(--nm-ui)),34px);border:1px solid transparent;border-radius:calc(8px * var(--nm-ui));background:transparent;cursor:pointer;display:flex;align-items:center;justify-content:center;padding:4px;transition:background-color .2s cubic-bezier(.22,1,.36,1),border-color .2s cubic-bezier(.22,1,.36,1),transform .2s cubic-bezier(.22,1,.36,1),color .2s cubic-bezier(.22,1,.36,1);color:#ff6600;outline:none;position:relative;}'+
      '#' + ROOT_ID + ' .logo-btn:hover{background:rgba(255,102,0,.1);border-color:rgba(255,102,0,.32);}'+
      '#' + ROOT_ID + ' .logo-img{width:max(calc(30px * var(--nm-ui)),28px);height:max(calc(30px * var(--nm-ui)),28px);min-width:max(calc(28px * var(--nm-ui)),24px);min-height:max(calc(28px * var(--nm-ui)),24px);object-fit:contain;pointer-events:none;transform-origin:center;opacity:.98;}'+
      '#' + ROOT_ID + ' .icon-btns{display:flex;flex-direction:row;align-items:center;gap:calc(5px * var(--nm-ui));min-width:0;flex-wrap:nowrap;overflow-x:auto;}'+
      '#' + ROOT_ID + ' .icon-btns::-webkit-scrollbar{display:none;}'+
      '#' + ROOT_ID + ' .tb{width:calc(40px * var(--nm-ui));height:calc(40px * var(--nm-ui));display:flex;align-items:center;justify-content:center;border:1px solid transparent;border-radius:calc(8px * var(--nm-ui));cursor:pointer;position:relative;transition:background-color .2s cubic-bezier(.22,1,.36,1),border-color .2s cubic-bezier(.22,1,.36,1),transform .2s cubic-bezier(.22,1,.36,1),color .2s cubic-bezier(.22,1,.36,1);color:#ff6600;background:transparent;flex-shrink:0;font-size:0;line-height:0;overflow:hidden;}'+
      '#' + ROOT_ID + ' .tb .tb-ico{display:flex;align-items:center;justify-content:center;width:100%;height:100%;color:#ff6600;}'+
      '#' + ROOT_ID + ' .tb .tb-ico svg{width:calc(24px * var(--nm-ui));height:calc(24px * var(--nm-ui));stroke:currentColor;fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;pointer-events:none;}'+
      '#' + ROOT_ID + ' .tb:hover{background:rgba(255,102,0,.1);border-color:rgba(255,102,0,.28);}'+
      '#' + ROOT_ID + ' .dot{position:absolute;bottom:2px;left:50%;transform:translateX(-50%);width:5px;height:5px;border-radius:50%;background:#ff6600;opacity:0;pointer-events:none;}'+
      '#' + ROOT_ID + ' .selected .dot{opacity:1;}'+
      '#' + ROOT_ID + ' .selected{border-color:transparent !important;background:transparent !important;box-shadow:none !important;}'+
      '#' + ROOT_ID + ' [hidden]{display:none !important;}'+
      'body[data-theme="light"] #' + ROOT_ID + ' .nm-collapsed{background:#F7F7F7;border:1px solid #E5E5E5;box-shadow:0 2px 10px rgba(0,0,0,.06);}'+
      'body[data-theme="light"] #' + ROOT_ID + ' .tb,body[data-theme="light"] #' + ROOT_ID + ' .logo-btn{border-color:#E5E5E5;background:#FFFFFF;color:#E67E22;}'+
      'body[data-theme="light"] #' + ROOT_ID + ' .tb .tb-ico{color:#E67E22;}'+
      'body[data-theme="light"] #' + ROOT_ID + ' .tb:hover,body[data-theme="light"] #' + ROOT_ID + ' .logo-btn:hover{border-color:#D35400;background:#FFF3E8;color:#D35400;}'+
      'body[data-theme="light"] #' + ROOT_ID + ' .dot{background:#E67E22;}';
    document.head.appendChild(style);
  }

  function defaultPost(payload) {
    try {
      if (global.chrome && global.chrome.webview) global.chrome.webview.postMessage(payload);
    } catch (e) {}
  }

  function cloneSceneLayout(sceneToolbarLayout) {
    if (!Array.isArray(sceneToolbarLayout)) return [];
    var out = [];
    for (var i = 0; i < sceneToolbarLayout.length; i++) {
      var row = sceneToolbarLayout[i] || {};
      var sid = normalizeSceneId(row.sceneId);
      if (!sid) continue;
      out.push({
        sceneId: sid,
        visible_in_bar: row.visible_in_bar !== false,
        order_bar: Number.isFinite(Number(row.order_bar)) ? Number(row.order_bar) : -1
      });
    }
    return out;
  }

  function mount(opts) {
    opts = opts || {};
    if (document.getElementById(ROOT_ID)) return global.__nmDockInstance || null;

    ensureStyle();

    var post = typeof opts.post === 'function' ? opts.post : defaultPost;
    var sourceScene = normalizeSceneId(opts.sceneId || 'search');
    var logoUrl = String(opts.logoUrl || './牛马.png');

    document.body.classList.add('nm-dock-mounted');

    var root = document.createElement('div');
    root.id = ROOT_ID;

    var collapsed = document.createElement('div');
    collapsed.className = 'nm-collapsed';

    var iconBtns = document.createElement('div');
    iconBtns.className = 'icon-btns';

    var nodeById = Object.create(null);

    for (var i = 0; i < ITEMS.length; i++) {
      var item = ITEMS[i];
      var el;
      if (item.isLogo) {
        el = document.createElement('button');
        el.type = 'button';
        el.className = 'logo-btn';
        el.title = item.title;
        el.setAttribute('aria-label', item.title);
        el.dataset.itemId = item.id;
        el.dataset.sceneId = item.sceneId;

        var img = document.createElement('img');
        img.className = 'logo-img';
        img.alt = 'NiuMa';
        img.src = logoUrl;
        el.appendChild(img);

        var dot = document.createElement('span');
        dot.className = 'dot';
        el.appendChild(dot);

        collapsed.appendChild(el);
      } else {
        el = document.createElement('button');
        el.type = 'button';
        el.className = 'tb';
        el.title = item.title;
        el.setAttribute('aria-label', item.title);
        el.dataset.itemId = item.id;
        el.dataset.sceneId = item.sceneId;
        el.innerHTML = '<span class="tb-ico"><svg viewBox="0 0 24 24">' + item.icon + '</svg></span><span class="dot"></span>';
        iconBtns.appendChild(el);
      }

      (function (it, btn) {
        btn.addEventListener('click', function () {
          markActive(it.sceneId);
          post({ type: 'nmDockCmd', cmdId: it.cmdId, sceneId: it.sceneId, sourceScene: sourceScene });
        });
      })(item, el);

      nodeById[item.id] = el;
    }

    collapsed.appendChild(iconBtns);
    root.appendChild(collapsed);
    (opts.host || document.body).appendChild(root);

    function markActive(sceneId) {
      var sid = normalizeSceneId(sceneId || '');
      for (var k = 0; k < ITEMS.length; k++) {
        var it = ITEMS[k];
        var node = nodeById[it.id];
        if (!node) continue;
        node.classList.toggle('selected', normalizeSceneId(it.sceneId) === sid);
      }
    }

    function applyConfig(cfg) {
      var layout = cloneSceneLayout(cfg && cfg.sceneToolbarLayout);
      if (!layout.length) {
        markActive(sourceScene);
        return;
      }

      var byScene = Object.create(null);
      for (var i = 0; i < layout.length; i++) byScene[layout[i].sceneId] = layout[i];

      var ordered = [];
      for (var j = 0; j < ITEMS.length; j++) {
        var it = ITEMS[j];
        var node = nodeById[it.id];
        if (!node) continue;

        var row = byScene[normalizeSceneId(it.sceneId)];
        var visible = it.always ? true : (!row || row.visible_in_bar !== false);
        node.hidden = !visible;

        var ord = row && Number.isFinite(Number(row.order_bar)) ? Number(row.order_bar) : (100 + j);
        ordered.push({ node: node, order: ord, index: j, isLogo: !!it.isLogo });
      }

      ordered.sort(function (a, b) {
        if (a.order !== b.order) return a.order - b.order;
        return a.index - b.index;
      });

      for (var n = 0; n < ordered.length; n++) {
        if (ordered[n].isLogo) {
          collapsed.insertBefore(ordered[n].node, iconBtns);
        } else {
          iconBtns.appendChild(ordered[n].node);
        }
      }

      markActive(sourceScene);
    }

    function onHostMessage(msg) {
      if (!msg || typeof msg !== 'object') return;
      if (msg.type === 'nmDockConfig' && Array.isArray(msg.sceneToolbarLayout)) {
        applyConfig(msg);
        return;
      }
      if (msg.type === 'init' && Array.isArray(msg.sceneToolbarLayout)) {
        applyConfig(msg);
      }
      if (msg.type === 'nmDockSetActive' && msg.sceneId) {
        markActive(msg.sceneId);
      }
    }

    markActive(sourceScene);
    setTimeout(function () { post({ type: 'nmDockReady', sceneId: sourceScene }); }, 0);

    var api = { onHostMessage: onHostMessage, applyConfig: applyConfig, markActive: markActive, root: root };
    global.__nmDockInstance = api;
    return api;
  }

  global.NiumaBottomDock = { mount: mount };
})(window);
