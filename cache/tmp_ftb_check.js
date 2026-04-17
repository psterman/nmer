
(function () {
  var LS = 'niuma_chat_drawer_config_v2',
    LEGACY_LS = 'niuma_chat_drawer_config_v1',
    SESSIONS_LS = 'niuma_chat_sessions_v1',
    NIUMA_HISTORY_LS = 'niuma_chat_history_v1',
    NIUMA_HISTORY_API = '/api/niuma/history',
    SP = '浣犳槸涓€涓搮闀?AHK v2銆佽嚜鍔ㄥ寲鑴氭湰鍜屾闈㈠伐浣滄祦鐨勫姪鎵嬨€?,
    P = {
      openai: { label: 'OpenAI', transport: 'openai', baseUrl: 'https://api.openai.com/v1', model: 'gpt-4.1-mini', models: ['gpt-4.1-mini', 'gpt-4.1', 'gpt-4o-mini', 'gpt-4o'] },
      codex: { label: 'Codex', transport: 'openai', baseUrl: 'https://api.openai.com/v1', model: 'gpt-4.1-mini', models: ['gpt-4.1-mini', 'gpt-4.1', 'gpt-4o-mini', 'gpt-4o'] },
      codex_cli: { label: 'Codex CLI锛坱tyd锛?, transport: 'cli', baseUrl: 'http://127.0.0.1:7681', model: 'codex', models: ['codex'] },
      kimi: { label: 'Kimi', transport: 'openai', baseUrl: 'https://api.moonshot.cn/v1', model: 'moonshot-v1-8k', models: ['moonshot-v1-8k', 'moonshot-v1-32k', 'kimi-k2-0711-preview'] },
      qwen: { label: 'Qwen', transport: 'openai', baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1', model: 'qwen-plus', models: ['qwen-plus', 'qwen-turbo', 'qwen-max', 'qwen3-coder-plus'] },
      deepseek: { label: 'DeepSeek', transport: 'openai', baseUrl: 'https://api.deepseek.com/v1', model: 'deepseek-chat', models: ['deepseek-chat', 'deepseek-reasoner'] },
      claude: { label: 'Claude', transport: 'anthropic', baseUrl: 'https://api.anthropic.com', model: 'claude-3-5-sonnet-latest', models: ['claude-3-5-sonnet-latest', 'claude-3-7-sonnet-latest', 'claude-3-5-haiku-latest'] },
      gemini: { label: 'Gemini', transport: 'gemini', baseUrl: 'https://generativelanguage.googleapis.com/v1beta', model: 'gemini-2.5-flash', models: ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash'] },
      glm: { label: 'GLM', transport: 'openai', baseUrl: 'https://open.bigmodel.cn/api/paas/v4', model: 'glm-4-plus', models: ['glm-4-plus', 'glm-4-air', 'glm-4-flash'] },
      siliconflow: { label: '纭呭熀娴佸姩', transport: 'openai', baseUrl: 'https://api.siliconflow.cn/v1', model: 'Qwen/Qwen2.5-7B-Instruct', models: ['Qwen/Qwen2.5-7B-Instruct', 'deepseek-ai/DeepSeek-V3', 'THUDM/glm-4-9b-chat'] },
      minimax: { label: 'MiniMax', transport: 'openai', baseUrl: 'https://api.minimax.chat/v1', model: 'abab6.5s-chat', models: ['abab6.5s-chat', 'MiniMax-M1', 'MiniMax-Text-01'] },
      zhipu: { label: '鏅鸿氨', transport: 'openai', baseUrl: 'https://open.bigmodel.cn/api/paas/v4', model: 'glm-4-plus', models: ['glm-4-plus', 'glm-4-air', 'glm-4-flash'] },
      ollama: { label: 'Ollama', transport: 'openai', baseUrl: 'http://127.0.0.1:11434/v1', model: 'llama3.1:8b', models: ['llama3.1:8b', 'qwen2.5:7b', 'deepseek-r1:7b', 'gemma3:4b'] },
      openclaw: { label: 'OpenClaw', transport: 'openclaw', baseUrl: 'http://127.0.0.1:18789', model: 'gateway', models: ['gateway'] }
    },
    ICON_PRIMARY = 'aiicons/',
    ICON_SECOND = 'lib/images/',
    ICON_FALLBACK = 'lib/images/chat-ai-fallback.svg',
    PROVIDER_ICON_EXTS = ['.png', '.jpg', '.jpeg', '.svg', '.webp'],
    PROVIDER_ICON_BASES = {
      openai: ['ChatGPT', 'chatgpt', 'openai'],
      codex: ['codex', 'Codex', 'ChatGPT', 'openai'],
      codex_cli: ['codex', 'Codex', 'terminal', 'cli', 'ChatGPT', 'openai'],
      kimi: ['kimi', 'Kimi', 'moonshot'],
      qwen: ['qwen', 'Qwen'],
      deepseek: ['DeepSeek', 'deepseek'],
      claude: ['Claude', 'claude'],
      gemini: ['gemini', 'Gemini'],
      glm: ['glm', 'GLM'],
      siliconflow: ['siliconflow', '纭呭熀娴佸姩'],
      minimax: ['minimax', 'MiniMax'],
      zhipu: ['zhipu', 'Zhipu'],
      ollama: ['ollama', 'Ollama'],
      openclaw: ['openclaw', 'OpenClaw']
    },
    KEYMETA = {
      openai: { keyLabel: 'OpenAI API Key', keyPlaceholder: 'sk-...', keyHint: '浠呬繚瀛樺埌銆孫penAI銆嶆Ы浣嶏紱涓?Kimi銆丏eepSeek 绛夊瘑閽ヤ簰涓嶈鐩栥€? },
      codex: { keyLabel: 'OpenAI API Key', keyPlaceholder: 'sk-...', keyHint: 'Codex 榛樿璧?OpenAI 瀹樻柟鎺ュ彛锛涘浣犱娇鐢ㄥ叾浠栧吋瀹?baseUrl锛屽彲鍦ㄤ笅鏂规敼 Base URL 涓?Model銆? },
      codex_cli: { keyLabel: '鏃犻渶 API Key', keyPlaceholder: '鏈ā寮忎笉浣跨敤 API Key', keyHint: '鐐瑰嚮鍙戦€佷細鎵撳紑 ttyd Web 缁堢锛堟湰鏈?`http://127.0.0.1:7681/`锛夛紝杩涘叆 Codex CLI 涓撳睘瀵硅瘽銆? },
      kimi: { keyLabel: 'Kimi锛圡oonshot锛堿PI Key', keyPlaceholder: 'Moonshot 瀵嗛挜', keyHint: 'Authorization: Bearer锛涘崟鐙繚瀛樺湪銆孠imi銆嶆Ы浣嶃€? },
      qwen: { keyLabel: 'DashScope API Key', keyPlaceholder: '闃块噷浜戠櫨鐐?/ DashScope', keyHint: '閫氫箟鍗冮棶鍏煎 OpenAI 鎺ュ彛锛涘瘑閽ヤ粎瀛樸€孮wen銆嶆Ы浣嶃€? },
      deepseek: { keyLabel: 'DeepSeek API Key', keyPlaceholder: 'DeepSeek 瀵嗛挜', keyHint: '鍗曠嫭淇濆瓨鍦ㄣ€孌eepSeek銆嶆Ы浣嶃€? },
      claude: { keyLabel: 'Anthropic API Key', keyPlaceholder: 'sk-ant-...', keyHint: '璇锋眰澶?x-api-key锛涘崟鐙繚瀛樺湪銆孋laude銆嶆Ы浣嶏紙涓?OpenAI 瀵嗛挜涓嶅悓锛夈€? },
      gemini: { keyLabel: 'Google AI API Key', keyPlaceholder: 'AIza...', keyHint: '瀵嗛挜浠?query 鍙傛暟 key= 浼犻€掞紱鍗曠嫭淇濆瓨鍦ㄣ€孏emini銆嶆Ы浣嶃€? },
      glm: { keyLabel: '鏅鸿氨 BigModel API Key', keyPlaceholder: 'BigModel 瀵嗛挜', keyHint: '涓庛€屾櫤璋便€嶆Ы浣嶅垎绂讳繚瀛橈紱鍧囦负 OpenAI 鍏煎浣嗗瘑閽ヤ笉鍚屻€? },
      siliconflow: { keyLabel: '纭呭熀娴佸姩 API Key', keyPlaceholder: '纭呭熀娴佸姩瀵嗛挜', keyHint: '鍗曠嫭淇濆瓨鍦ㄣ€岀鍩烘祦鍔ㄣ€嶆Ы浣嶃€? },
      minimax: { keyLabel: 'MiniMax API Key', keyPlaceholder: 'MiniMax 瀵嗛挜', keyHint: '鍗曠嫭淇濆瓨鍦ㄣ€孧iniMax銆嶆Ы浣嶃€? },
      zhipu: { keyLabel: '鏅鸿氨 API Key', keyPlaceholder: '鏅鸿氨寮€鏀惧钩鍙板瘑閽?, keyHint: '鍗曠嫭淇濆瓨鍦ㄣ€屾櫤璋便€嶆Ы浣嶏紙涓?GLM BigModel 鍙～涓嶅悓瀵嗛挜锛夈€? },
      ollama: { keyLabel: 'Ollama API Key锛堝彲閫夛級', keyPlaceholder: '鏈湴榛樿鍙暀绌?, keyHint: '鏈湴 Ollama 榛樿鏃犻渶 API Key锛涘鍚敤閴存潈鍙湪姝ゅ～鍐欍€? },
      openclaw: {
        keyLabel: 'Gateway Token',
        keyPlaceholder: '涓?openclaw dashboard 涓?token 涓€鑷?,
        keyHint: '涔熷彲鐣欑┖锛屼粎鎶婂甫 #token= 鐨勫畬鏁存帶鍒跺彴鍦板潃濉湪 Base URL锛涜蛋鏈満 WebSocket锛屼笌 OpenAI HTTP 鏃犲叧銆?
      }
    },
    PROMPT_BUILTIN = [
      { id: '_ahk', name: '榛樿 路 AHK / 鑷姩鍖?, text: SP },
      { id: '_empty', name: '绌猴紙涓嶈绯荤粺鎻愮ず锛?, text: '' },
      { id: '_code', name: '浠ｇ爜瀹℃煡', text: '浣犳槸涓ヨ皑鐨勪唬鐮佸鏌ュ姪鎵嬨€傛寚鍑洪棶棰樸€侀闄╀笌鍙敼杩涘锛岀粰鍑哄叿浣撲慨鏀瑰缓璁紝閬垮厤绌鸿瘽銆? },
      { id: '_zh', name: '绠€鏄庝腑鏂囧姪鎵?, text: '璇风敤绠€鏄庛€佸噯纭殑涓枃鍥炵瓟銆傞渶瑕佹椂鍒嗘潯璇存槑锛涗笉纭畾澶勮鏍囨槑鍋囪銆? },
      { id: '_en', name: 'Concise English', text: 'You are a concise technical assistant. Answer clearly; use bullet points when helpful.' }
    ];

  function $(id) {
    return document.getElementById(id);
  }

  function normalizeProviderId(pid) {
    pid = String(pid || '').trim();
    if (pid === 'llama') return 'ollama';
    return pid;
  }

  var _tpl = $('ftb-toolbar-tpl');
  var _th = _tpl ? _tpl.innerHTML : '';
  var DEFAULT_TOOLBAR_ACTIONS = ['Search', 'Record', 'Prompt', 'NewPrompt', 'Screenshot', 'Settings', 'VirtualKeyboard'];
  function normalizeToolbarActions(actions) {
    var src = Array.isArray(actions) ? actions : DEFAULT_TOOLBAR_ACTIONS;
    var allow = { Search:1, Record:1, Prompt:1, NewPrompt:1, Screenshot:1, Settings:1, VirtualKeyboard:1 };
    var out = [];
    var seen = {};
    src.forEach(function (x) {
      var id = String(x || '').trim();
      if (!id || !allow[id] || seen[id]) return;
      seen[id] = 1;
      out.push(id);
    });
    if (!out.length) out = DEFAULT_TOOLBAR_ACTIONS.slice();
    return out;
  }
  function buildToolbarHtmlByActions(actions) {
    var wrap = document.createElement('div');
    wrap.innerHTML = _th;
    var map = {};
    Array.prototype.slice.call(wrap.querySelectorAll('.tb[data-action]')).forEach(function (el) {
      map[el.getAttribute('data-action') || ''] = el.outerHTML;
    });
    return normalizeToolbarActions(actions).map(function (id) { return map[id] || ''; }).join('');
  }
  function rebuildToolbarButtons(actions) {
    state.toolbarMode = 'legacy';
    state.toolbarActions = normalizeToolbarActions(actions);
    var html = buildToolbarHtmlByActions(state.toolbarActions);
    $('collapsedBtns').innerHTML = html;
    $('drawerBtns').innerHTML = html;
    bindSearchDnD();
    if (state.activeAction) sel(state.activeAction);
    queueCollapsedLayout(0);
  }

  function escAttr(s) {
    return String(s || '')
      .replace(/&/g, '&amp;')
      .replace(/"/g, '&quot;')
      .replace(/</g, '&lt;');
  }

  var TOOLBAR_SVG_PARTS = {
    search:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>',
    record:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21l3.8-1 10-10a2.3 2.3 0 0 0-3.3-3.3l-10 10L3 21z"/><path d="M12.9 4.9l3.3 3.3"/></svg>',
    prompt:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M12 3c4.97 0 9 3.58 9 8 0 1.8-.67 3.47-1.8 4.82L20 21l-5.02-1.67A10.53 10.53 0 0 1 12 20c-4.97 0-9-3.58-9-8s4.03-9 9-9Z"/></svg>',
    notepad:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3h11a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"/><path d="M8 7h8"/><path d="M8 11h8"/><path d="M8 15h5"/></svg>',
    screenshot:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><path d="M4 7h4l2-2h4l2 2h4v12H4z"/><circle cx="12" cy="13" r="3.5"/></svg>',
    settings:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>',
    keyboard:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2.5" y="5" width="19" height="14" rx="2.5"/><path d="M6 9h1"/><path d="M9 9h1"/><path d="M12 9h1"/><path d="M15 9h1"/><path d="M18 9h1"/><path d="M6 12h1"/><path d="M9 12h1"/><path d="M12 12h1"/><path d="M15 12h1"/><path d="M18 12h1"/><path d="M7 15h10"/></svg>',
    clipboard:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="8" y="2" width="8" height="4" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/></svg>',
    comments:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/></svg>',
    list:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 6h13"/><path d="M8 12h13"/><path d="M8 18h13"/><path d="M3 6h.01"/><path d="M3 12h.01"/><path d="M3 18h.01"/></svg>',
    window:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M9 3v18"/></svg>',
    robot:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="8" width="14" height="10" rx="2"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/><circle cx="9.5" cy="13" r="1" fill="currentColor" stroke="none"/><circle cx="14.5" cy="13" r="1" fill="currentColor" stroke="none"/><path d="M9 18v2"/><path d="M15 18v2"/></svg>',
    bolt:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/></svg>',
    star:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 2 2.4 7.4h7.6l-6 4.6 2.3 7-6.3-4.6-6.3 4.6 2.3-7-6-4.6h7.6z"/></svg>',
    circle:
      '<svg viewBox="0 0 24 24" fill="none" stroke-width="2"><circle cx="12" cy="12" r="9"/></svg>',
  };

  var TOOLBAR_CMD_TO_KEY = {
    sc_activate_search: 'search',
    qa_clipboard: 'clipboard',
    hub_capsule: 'notepad',
    ch_b: 'prompt',
    pqp_capture: 'bolt',
    ch_t: 'screenshot',
    qa_config: 'settings',
    sys_show_vk: 'keyboard',
    ftb_scratchpad: 'notepad',
    ftb_screenshot: 'screenshot',
    ftb_cursor_menu: 'bolt',
  };

  var FA_SUFFIX_TO_KEY = {
    'magnifying-glass': 'search',
    clipboard: 'clipboard',
    comments: 'comments',
    lightbulb: 'prompt',
    'note-sticky': 'notepad',
    camera: 'screenshot',
    gear: 'settings',
    keyboard: 'keyboard',
    list: 'list',
    'window-restore': 'window',
    robot: 'robot',
    bolt: 'bolt',
    star: 'star',
    circle: 'circle',
    layer: 'list',
    'layer-group': 'list',
    terminal: 'keyboard',
    sliders: 'settings',
    code: 'bolt',
    'wand-magic-sparkles': 'prompt',
  };

  function extractFaSuffix(iconClass) {
    var parts = String(iconClass || '')
      .trim()
      .split(/\s+/);
    var suf = '';
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i];
      if (p === 'fa-solid' || p === 'fa-brands' || p === 'fa-regular') continue;
      if (p.indexOf('fa-') === 0) suf = p.slice(3);
    }
    return suf || 'circle';
  }

  function toolbarFallbackKey(cmdId, iconClass) {
    var key = TOOLBAR_CMD_TO_KEY[String(cmdId || '').trim()];
    if (!key) {
      var suf = extractFaSuffix(iconClass);
      key = FA_SUFFIX_TO_KEY[suf] || 'bolt';
    }
    return key || 'bolt';
  }

  function toolbarIconSvgHtml(cmdId, iconClass, iconPath) {
    var fbKey = toolbarFallbackKey(cmdId, iconClass);
    if (iconPath) {
      return (
        '<span class="tb-ico">' +
        '<img class="tb-ico-img" src="' +
        escAttr(iconPath) +
        '" data-fallback-key="' +
        escAttr(fbKey) +
        '" alt="">' +
        '</span>'
      );
    }
    var inner = TOOLBAR_SVG_PARTS[fbKey] || TOOLBAR_SVG_PARTS.bolt;
    return '<span class="tb-ico">' + inner + '</span>';
  }

  function attachToolbarIconFallback(root) {
    if (!root) return;
    root.querySelectorAll('img.tb-ico-img[data-fallback-key]').forEach(function (img) {
      if (img.dataset.fbBound === '1') return;
      img.dataset.fbBound = '1';
      var useFallback = function () {
        var wrap = img.parentElement;
        if (!wrap) return;
        var k = String(img.getAttribute('data-fallback-key') || '').trim() || 'bolt';
        wrap.innerHTML = TOOLBAR_SVG_PARTS[k] || TOOLBAR_SVG_PARTS.bolt;
      };
      img.addEventListener('error', useFallback, { once: true });
      if (img.complete && (!img.naturalWidth || !img.naturalHeight)) useFallback();
    });
  }

  function rebuildToolbarCmdButtons(items) {
    state.toolbarMode = 'cmd';
    var arr = Array.isArray(items) ? items : [];
    var html = '';
    arr.forEach(function (it) {
      var cid = String((it && it.cmdId) || '').trim();
      if (!cid) return;
      var nm = escAttr((it && it.name) || cid);
      var ic = String((it && it.iconClass) || 'fa-solid fa-circle');
      var ip = String((it && it.iconPath) || '').trim();
      if (ic.indexOf('fa-') === 0 && ic.indexOf('fa-solid') === -1 && ic.indexOf('fa-brands') === -1 && ic.indexOf('fa-regular') === -1)
        ic = 'fa-solid ' + ic;
      var bucket = 'Search';
      if (cid === 'sc_activate_search') bucket = 'Search';
      else if (cid === 'qa_clipboard' || cid === 'ch_b' || cid === 'pqp_capture' || cid === 'hub_capsule') bucket = 'Prompt';
      var sd = bucket === 'Search' ? ' data-search-drop="1"' : '';
      html +=
        '<button type="button" class="tb" title="' +
        nm +
        '" data-cmd-id="' +
        escAttr(cid) +
        '" data-drop-bucket="' +
        bucket +
        '"' +
        sd +
        '>' +
        toolbarIconSvgHtml(cid, ic, ip) +
        '<span class="dot"></span></button>';
    });
    if (!html)
      html =
        '<span class="hint" style="display:flex;align-items:center;padding:8px 10px;font-size:11px;color:var(--muted)">鏃犲伐鍏锋爮鍛戒护锛堣鍦?KeyBinder 涓厤缃級</span>';
    $('collapsedBtns').innerHTML = html;
    $('drawerBtns').innerHTML = html;
    attachToolbarIconFallback($('collapsedBtns'));
    attachToolbarIconFallback($('drawerBtns'));
    bindSearchDnD();
    if (state.activeCmdId) sel(state.activeCmdId);
    queueCollapsedLayout(0);
  }

  var stage = $('stage'),
    backdrop = $('backdrop'),
    panel = $('panel'),
    dclose = $('drawer-close'),
    chatSearch = $('chat-search'),
    chatSet = $('chat-settings'),
    chatExportMd = $('chat-export-md'),
    chatExportJson = $('chat-export-json'),
    sessionTabsEl = $('sessionTabs'),
    msgs = $('msgs'),
    empty = $('empty'),
    input = $('input'),
    send = $('send'),
    chatStatus = $('chat-status'),
    settings = $('settings'),
    sbg = document.querySelector('.sbg'),
    sclose = $('settings-close'),
    ssave = $('saveCfg'),
    cfgStatus = $('config-status'),
    ph = $('providerHint'),
    provider = $('provider'),
    apiKey = $('apiKey'),
    baseUrl = $('baseUrl'),
    model = $('model'),
    modelPreset = $('modelPreset'),
    systemPrompt = $('systemPrompt'),
    apiKeyLabel = $('apiKeyLabel'),
    apiKeyKeyHint = $('apiKeyKeyHint'),
    promptBuiltin = $('promptBuiltin'),
    promptTplApply = $('promptTplApply'),
    promptImportBtn = $('promptImportBtn'),
    promptImportFile = $('promptImportFile'),
    providerDdBtn = $('providerDdBtn'),
    providerDdMenu = $('providerDdMenu'),
    providerDdIcon = $('providerDdIcon'),
    providerDdLabel = $('providerDdLabel'),
    modelDdBtn = $('modelDdBtn'),
    modelDdMenu = $('modelDdMenu'),
    modelDdIcon = $('modelDdIcon'),
    modelDdLabel = $('modelDdLabel'),
    resetCfg = $('resetCfg'),
    collapsedRoot = $('collapsedRoot'),
    resizeGrip = $('resizeGrip'),
    newSessionPick = $('newSessionPick'),
    newSessionPickBg = $('newSessionPickBg'),
    newSessionPickClose = $('newSessionPickClose'),
    newSessionGrid = $('newSessionGrid');

  function tbEls() {
    return document.querySelectorAll('.tb[data-action], .tb[data-cmd-id]');
  }
  function searchEls() {
    return document.querySelectorAll('.tb[data-action=Search], .tb[data-search-drop="1"]');
  }

  var state = {
    drawer: false,
    compact: false,
    settings: false,
    sendingBySession: {},
    needSetup: false,
    nspick: false,
    activeAction: '',
    apiKeys: {},
    sessions: [],
    activeSessionId: '',
    chatSearchKeyword: '',
    chatSearchCursor: -1,
    toolbarActions: DEFAULT_TOOLBAR_ACTIONS.slice(),
    niumaHistoryStore: { version: 1, sessions: {}, updatedAt: null },
    niumaHistoryLoaded: false,
    dynamicModels: {},
    dynamicModelsFetchedAt: {}
  };
  var toolbarVisibleSynced = false;
  var toolbarRevealTimer = 0;
  var collapsedLayoutTimer = 0;
  var DEBUG_HUD = false;
  var debugLines = [];
  var debugSeq = 0;

  function dbg(tag, msg, cls) {
    if (!DEBUG_HUD) return;
    var hud = document.getElementById('debugHud');
    if (!hud) return;
    debugSeq += 1;
    var ts = new Date();
    var t = String(ts.getHours()).padStart(2, '0') + ':' + String(ts.getMinutes()).padStart(2, '0') + ':' + String(ts.getSeconds()).padStart(2, '0');
    var text = t + ' ' + String(tag || '') + ' ' + String(msg || '');
    debugLines.push({ text: text, cls: cls || '' });
    if (debugLines.length > 3) debugLines.shift();
    hud.innerHTML = debugLines
      .map(function (it) {
        var c = it.cls ? 'row ' + it.cls : 'row';
        return '<div class="' + c + '">' + esc(it.text) + '</div>';
      })
      .join('');
    hud.scrollTop = hud.scrollHeight;
  }

  (function initDebugHudVisibility() {
    var hud = document.getElementById('debugHud');
    if (hud && !DEBUG_HUD) hud.style.display = 'none';
  })();

  function revealToolbarSync() {
    if (toolbarVisibleSynced) return;
    toolbarVisibleSynced = true;
    document.body.classList.add('ftb-ready');
  }

  function scheduleToolbarReveal(ms) {
    if (toolbarVisibleSynced) return;
    if (toolbarRevealTimer) clearTimeout(toolbarRevealTimer);
    toolbarRevealTimer = setTimeout(revealToolbarSync, ms);
  }

  function post(m) {
    try {
      if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        dbg('S', (m && m.type ? m.type : '?'));
        window.chrome.webview.postMessage(JSON.stringify(m));
      }
    } catch (e) {}
  }

  function postCollapsedLayout(force) {
    if (state.drawer) return;
    if (!collapsedRoot) return;
    var r = collapsedRoot.getBoundingClientRect();
    var w = Math.ceil(Math.max(r.width || 0, collapsedRoot.scrollWidth || 0));
    var h = Math.ceil(r.height || 0);
    if (w <= 0 || h <= 0) return;
    if (!force && state._lastCollapsedW === w && state._lastCollapsedH === h) return;
    state._lastCollapsedW = w;
    state._lastCollapsedH = h;
    post({ type: 'collapsed_layout', width: w, height: h });
  }

  function queueCollapsedLayout(delay) {
    if (collapsedLayoutTimer) clearTimeout(collapsedLayoutTimer);
    collapsedLayoutTimer = setTimeout(function () {
      postCollapsedLayout(false);
    }, Math.max(0, Number(delay) || 0));
  }

  function sel(a) {
    var s = String(a || '');
    state.activeAction = s;
    if (state.toolbarMode === 'cmd') state.activeCmdId = s;
    document.querySelectorAll('.tb').forEach(function (b) {
      var match = b.dataset.action === s || String(b.dataset.cmdId || '') === s;
      b.classList.toggle('selected', match);
    });
  }

  function pulse(v) {
    searchEls().forEach(function (el) {
      el.classList.toggle('pulse', !!v);
    });
  }

  function dragOver(v) {
    searchEls().forEach(function (el) {
      el.classList.toggle('drag-over', !!v);
    });
  }

  function loading(v) {
    searchEls().forEach(function (el) {
      el.classList.toggle('loading', !!v);
    });
  }

  function setCompact(v) {
    state.compact = !!v;
    document.body.classList.toggle('ftb-compact', state.compact);
    queueCollapsedLayout(0);
  }

  function scrollMsgsToLatest() {
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        if (!msgs) return;
        msgs.scrollTop = msgs.scrollHeight;
      });
    });
  }

  function scale(v) {
    v = Number(v);
    if (!isFinite(v) || v <= 0) v = 1;
    document.documentElement.style.setProperty('--ui', String(v));
    queueCollapsedLayout(0);
  }

  function setDrawer(v) {
    state.drawer = !!v;
    document.body.classList.toggle('drawer-open', state.drawer);
    stage.setAttribute('aria-hidden', state.drawer ? 'false' : 'true');
    panel.setAttribute('aria-hidden', state.drawer ? 'false' : 'true');
    post({ type: 'drawer_state', open: state.drawer });
    if (!state.drawer) {
      setSettings(false);
      setNspick(false);
      queueCollapsedLayout(0);
      return;
    }
    scrollMsgsToLatest();
    if (state.needSetup) setSettings(true);
  }

  function setNspick(v) {
    state.nspick = !!v;
    document.body.classList.toggle('nspick-open', state.nspick);
    if (newSessionPick) newSessionPick.setAttribute('aria-hidden', state.nspick ? 'false' : 'true');
  }

  function setSettings(v) {
    state.settings = !!v;
    if (state.settings) setNspick(false);
    document.body.classList.toggle('settings-open', state.settings);
    settings.setAttribute('aria-hidden', state.settings ? 'false' : 'true');
    if (state.settings) {
      syncProviderDdUi();
      syncModelDdUi();
    }
  }

  function esc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function ahk(code) {
    var h = esc(code);
    h = h.replace(/(^|\n)(\s*;.*)/g, function (m, p1, p2) {
      return p1 + '<span class="hl-comment">' + p2 + '</span>';
    });
    h = h.replace(/("(?:[^"\\]|\\.)*")/g, '<span class="hl-string">$1</span>');
    h = h.replace(/('(?:[^'\\]|\\.)*')/g, '<span class="hl-string">$1</span>');
    h = h.replace(/\b(\d+(?:\.\d+)?)\b/g, '<span class="hl-number">$1</span>');
    h = h.replace(/\b(global|local|static|if|else|try|catch|return|switch|case|default|for|while|loop|break|continue|class|extends|throw)\b/g, '<span class="hl-keyword">$1</span>');
    h = h.replace(/\b(Map|Array|Gui|Error|Integer|Float|String|Trim|Format|RegExMatch|SetTimer|Send|Sleep|FileRead|FileAppend|IniRead|IniWrite)\b/g, '<span class="hl-builtins">$1</span>');
    h = h.replace(/\b([A-Za-z_][A-Za-z0-9_]*)\b(?=\s*:=)/g, '<span class="hl-var">$1</span>');
    return h;
  }

  /** API 甯歌繑鍥?<br> / 宸茶浆涔夌殑鎹㈣锛屽厛鎹㈡垚 \n 鍐嶈蛋 Markdown锛岄伩鍏嶅睆涓婃樉绀哄瓧闈㈤噺 <br> */
  function preMarkdownForChat(s) {
    s = String(s || '').replace(/\r\n/g, '\n');
    s = s.replace(/<br\s*\/?>/gi, '\n');
    s = s.replace(/&lt;\s*br\s*\/?\s*&gt;/gi, '\n');
    return s;
  }

  function inline(t) {
    var h = esc(t);
    h = h.replace(/`([^`]+)`/g, '<code class="inline">$1</code>')
      .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
      .replace(/\*([^*]+)\*/g, '<em>$1</em>')
      .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noreferrer">$1</a>');
    return h;
  }

  function md(src) {
    src = String(src || '').replace(/\r\n/g, '\n');
    var out = [],
      rx = /```(\w+)?\n([\s\S]*?)```/g,
      last = 0,
      m;
    while ((m = rx.exec(src))) {
      if (m.index > last) out.push({ t: 'text', c: src.slice(last, m.index) });
      out.push({ t: 'code', l: (m[1] || '').toLowerCase(), c: m[2] });
      last = rx.lastIndex;
    }
    if (last < src.length) out.push({ t: 'text', c: src.slice(last) });
    return out
      .map(function (b) {
        if (b.t === 'code') {
          var hi = b.l === 'ahk' || b.l === 'autohotkey' || b.l === 'autohotkeyv2' ? ahk(b.c) : esc(b.c);
          return '<pre><code>' + hi + '</code></pre>';
        }
        return b.c
          .split(/\n{2,}/)
          .map(function (chunk) {
            var t = chunk.trim();
            if (!t) return '';
            if (/^\s*>\s?/.test(t)) return '<blockquote>' + inline(t.replace(/^\s*>\s?/gm, '').replace(/\n/g, '<br>')) + '</blockquote>';
            if (/^\s*[-*]\s+/m.test(t)) {
              var items = t
                .split('\n')
                .map(function (line) {
                  return line.replace(/^\s*[-*]\s+/, '').trim();
                })
                .filter(Boolean);
              return '<ul>' + items.map(function (i) { return '<li>' + inline(i) + '</li>'; }).join('') + '</ul>';
            }
            if (/^#{1,3}\s+/.test(t)) {
              var lv = t.match(/^#+/)[0].length,
                cl = t.replace(/^#{1,3}\s+/, '');
              return '<h' + lv + '>' + inline(cl) + '</h' + lv + '>';
            }
            return '<p>' + inline(t.replace(/\n/g, '<br>')) + '</p>';
          })
          .join('');
      })
      .join('');
  }

  function genId() {
    return 's' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  }

  function activeSession() {
    var list = state.sessions,
      id = state.activeSessionId;
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === id) return list[i];
    }
    return list[0] || null;
  }

  function providerTransport(pid) {
    pid = normalizeProviderId(pid);
    var p = pid && P[pid] ? P[pid] : P.openai;
    return String(p.transport || 'openai');
  }

  function isCliSession(s) {
    if (!s) return false;
    return providerTransport(s.provider) === 'cli';
  }

  function defaultCliBaseForProvider(pid) {
    pid = normalizeProviderId(pid);
    var p = pid && P[pid] ? P[pid] : null;
    if (!p) return '';
    return String((p.baseUrl || '').trim()).trim();
  }

  function normalizeCliUrl(rawUrl, pid) {
    var fallback = defaultCliBaseForProvider(pid);
    var raw = String((rawUrl || '').trim()).trim();
    if (!raw) raw = fallback;
    if (!raw) return '';
    try {
      var u = new URL(raw.indexOf('://') >= 0 ? raw : 'http://' + raw);
      var host = (u.hostname || '127.0.0.1').trim();
      var port = parseInt(u.port || '', 10);
      if (!isFinite(port) || port <= 0 || port > 65535) {
        var fu = null;
        try {
          fu = new URL(fallback.indexOf('://') >= 0 ? fallback : 'http://' + fallback);
        } catch (e2) {}
        port = fu && fu.port ? parseInt(fu.port, 10) : 7681;
      }
      return 'http://' + host + ':' + String(port) + '/';
    } catch (e) {
      return fallback || '';
    }
  }

  function cliUrlForSession(s) {
    if (!s) return '';
    var pid = normalizeProviderId(s.provider);
    var p = pid && P[pid] ? P[pid] : null;
    if (!p) return '';
    return normalizeCliUrl((s.baseUrl || '').trim() || (p.baseUrl || ''), pid);
  }

  function ensureCliLaunchedForSession(s) {
    if (!s || !s.id) return;
    if (s._cliBooted) return;
    s._cliBooted = true;
    try {
      post({ type: 'niuma_cli_open', engine: s.provider });
    } catch (e) {}
  }

  function reloadCliFrameWithRetry(url) {
    var fr = $('cliFrame');
    if (!fr || !url) return;
    var rounds = [0, 420, 1100, 2100];
    rounds.forEach(function (ms) {
      setTimeout(function () {
        try {
          fr.dataset.src = url;
          fr.src = url;
        } catch (e) {}
      }, ms);
    });
  }

  function syncChatViewMode() {
    var s = activeSession();
    var on = isCliSession(s);
    document.body.classList.toggle('cli-mode', !!on);
    try {
      var titleEl = $('cliTitle');
      if (titleEl) {
        var pl = (s && P[s.provider] ? P[s.provider].label : (s && s.provider ? s.provider : 'CLI'));
        titleEl.textContent = pl + ' 路 ttyd';
      }
    } catch (e) {}
    if (!on) return;
    ensureCliLaunchedForSession(s);
    var url = cliUrlForSession(s);
    reloadCliFrameWithRetry(url);
  }

  function normalizeRole(role) {
    var r = String(role || '').toLowerCase().trim();
    if (r === 'assistant' || r === 'ai') return 'assistant';
    if (r === 'human' || r === 'user') return 'user';
    return '';
  }

  function ensureIsoTime(ts) {
    if (!ts) return new Date().toISOString();
    var t = new Date(ts);
    if (isNaN(t.getTime())) return new Date().toISOString();
    return t.toISOString();
  }

  /** 浠?Gateway / 鎸佷箙鍖?JSON 涓彇鍑哄彲灞曠ず姝ｆ枃锛堝惈 parts[]銆佸祵濂?content锛?*/
  function ocExtractMessageContentForHistory(m) {
    if (!m || typeof m !== 'object') return '';
    /* 鍕垮湪 content==="" 鏃舵彁鍓嶈繑鍥烇細缃戝叧甯告妸姝ｆ枃鏀惧湪 text / parts锛宑ontent 浠呭崰浣嶇┖涓?*/
    var strFields = ['content', 'text', 'message', 'body', 'input', 'output', 'prompt', 'value'];
    for (var si = 0; si < strFields.length; si++) {
      var sf = m[strFields[si]];
      if (typeof sf === 'string' && sf.trim()) return sf.trim();
    }
    var acc = [];
    if (m.content != null && typeof m.content !== 'string') ocCollectTextDeep(m.content, acc);
    if (!acc.length && m.message != null && typeof m.message !== 'string') ocCollectTextDeep(m.message, acc);
    if (!acc.length && Array.isArray(m.parts)) {
      for (var pi = 0; pi < m.parts.length; pi++) {
        var p = m.parts[pi];
        if (p && typeof p === 'object') ocCollectTextDeep(p, acc);
      }
    }
    if (acc.length) return acc.join('\n').trim();
    return '';
  }

  function normalizeHistoryItem(m) {
    if (!m || typeof m !== 'object') return null;
    var role = normalizeRole(m.role || m.type || m.actor);
    if (!role) return null;
    var content = ocExtractMessageContentForHistory(m);
    if (!content) return null;
    return { role: role, content: content, ts: ensureIsoTime(m.ts || m.timestamp || m.createdAt || m.updatedAt) };
  }

  function historyItemKey(m) {
    var sec = '';
    try {
      sec = Math.floor(new Date(m.ts || 0).getTime() / 1000) || '';
    } catch (e) {}
    return [m.role || '', m.content || '', sec].join('|');
  }

  function mergeHistoryList(base, extra) {
    var out = [],
      seen = {};
    (Array.isArray(base) ? base : []).forEach(function (m) {
      var n = normalizeHistoryItem(m);
      if (!n) return;
      var k = historyItemKey(n);
      if (seen[k]) return;
      seen[k] = 1;
      out.push(n);
    });
    (Array.isArray(extra) ? extra : []).forEach(function (m) {
      var n = normalizeHistoryItem(m);
      if (!n) return;
      var k = historyItemKey(n);
      if (seen[k]) return;
      seen[k] = 1;
      out.push(n);
    });
    return out;
  }

  function getOpenClawSessionKey(s) {
    if (s) {
      var own = String(s.gatewaySessionKey || '').trim();
      if (own) return own;
    }
    try {
      var lk = String(localStorage.getItem('openclaw2_lastSessionKey') || '').trim();
      if (lk) return lk;
    } catch (e) {}
    return 'main';
  }

  function historyStoreKeyForSession(s) {
    if (!s) return '';
    if (s.provider === 'openclaw') return 'openclaw:' + getOpenClawSessionKey(s);
    return 'local:' + String(s.id || '');
  }

  function loadNiumaHistoryStoreFromLocal() {
    var raw = null;
    try {
      raw = localStorage.getItem(NIUMA_HISTORY_LS);
    } catch (e) {}
    if (!raw) return { version: 1, sessions: {}, updatedAt: null };
    try {
      var obj = JSON.parse(raw);
      if (!obj || typeof obj !== 'object') throw new Error('invalid');
      if (!obj.sessions || typeof obj.sessions !== 'object') obj.sessions = {};
      return obj;
    } catch (e2) {
      return { version: 1, sessions: {}, updatedAt: null };
    }
  }

  function saveNiumaHistoryStoreToLocal() {
    try {
      localStorage.setItem(NIUMA_HISTORY_LS, JSON.stringify(state.niumaHistoryStore || { version: 1, sessions: {}, updatedAt: null }));
    } catch (e) {}
  }

  function pushSessionHistoryToStore(s) {
    if (!s) return;
    if (!state.niumaHistoryStore || typeof state.niumaHistoryStore !== 'object') state.niumaHistoryStore = { version: 1, sessions: {}, updatedAt: null };
    if (!state.niumaHistoryStore.sessions || typeof state.niumaHistoryStore.sessions !== 'object') state.niumaHistoryStore.sessions = {};
    var key = historyStoreKeyForSession(s);
    if (!key) return;
    var merged = mergeHistoryList(state.niumaHistoryStore.sessions[key] || [], s.history || []);
    state.niumaHistoryStore.sessions[key] = merged.slice(-400);
    state.niumaHistoryStore.updatedAt = new Date().toISOString();
    saveNiumaHistoryStoreToLocal();
    fetch(NIUMA_HISTORY_API, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data: state.niumaHistoryStore })
    }).catch(function () {});
  }

  function pullStoreHistoryToSession(s) {
    if (!s) return;
    if (!state.niumaHistoryStore || !state.niumaHistoryStore.sessions) return;
    var key = historyStoreKeyForSession(s);
    if (!key) return;
    var arr = state.niumaHistoryStore.sessions[key];
    if ((!Array.isArray(arr) || !arr.length) && s.provider === 'openclaw') {
      var sk = getOpenClawSessionKey(s);
      var collected = [];
      state.sessions.forEach(function (x) {
        if (!x || x.id === s.id || x.provider !== 'openclaw') return;
        if (getOpenClawSessionKey(x) !== sk) return;
        collected = mergeHistoryList(collected, x.history || []);
      });
      arr = collected;
    }
    if (!Array.isArray(arr) || !arr.length) return;
    s.history = mergeHistoryList(s.history || [], arr).slice(-400);
  }

  function loadNiumaHistoryStore() {
    state.niumaHistoryStore = loadNiumaHistoryStoreFromLocal();
    state.niumaHistoryLoaded = true;
    fetch(NIUMA_HISTORY_API, { method: 'GET', cache: 'no-store' })
      .then(function (r) {
        if (!r.ok) throw new Error('history api');
        return r.json();
      })
      .then(function (body) {
        var data = body && body.data ? body.data : body;
        if (!data || typeof data !== 'object' || !data.sessions || typeof data.sessions !== 'object') return;
        if (!state.niumaHistoryStore.sessions || typeof state.niumaHistoryStore.sessions !== 'object') state.niumaHistoryStore.sessions = {};
        Object.keys(data.sessions).forEach(function (k) {
          state.niumaHistoryStore.sessions[k] = mergeHistoryList(state.niumaHistoryStore.sessions[k] || [], data.sessions[k] || []).slice(-400);
        });
        state.niumaHistoryStore.updatedAt = data.updatedAt || state.niumaHistoryStore.updatedAt || new Date().toISOString();
        saveNiumaHistoryStoreToLocal();
      })
      .catch(function () {});
  }

  function persistSessions() {
    try {
      localStorage.setItem(
        SESSIONS_LS,
        JSON.stringify({ v: 1, activeSessionId: state.activeSessionId, sessions: state.sessions })
      );
    } catch (e) {
      cstat('鏈湴瀛樺偍鍙兘宸叉弧锛岃瀵煎嚭鍚庡垹闄ら儴鍒嗗璇濇爣绛俱€?, 'error');
    }
  }

  function loadSessions() {
    var raw = null;
    try {
      raw = localStorage.getItem(SESSIONS_LS);
    } catch (e) {}
    state.sessions = [];
    state.activeSessionId = '';
    if (!raw) return;
    var data;
    try {
      data = JSON.parse(raw);
    } catch (e) {
      return;
    }
    if (!data || !Array.isArray(data.sessions)) return;
    state.sessions = data.sessions.map(function (s) {
      var sp = normalizeProviderId(s.provider);
      var pid = sp && P[sp] ? sp : 'openai';
      var gk = String(s.gatewaySessionKey || '').trim();
      return {
        id: s.id || genId(),
        provider: pid,
        model: s.model || '',
        baseUrl: s.baseUrl || '',
        gatewaySessionKey: pid === 'openclaw' ? gk || 'main' : '',
        history: Array.isArray(s.history)
          ? s.history.map(function (m) {
              var n = normalizeHistoryItem(m);
              if (!n) return null;
              return {
                role: n.role,
                content: n.content,
                ts: n.ts
              };
            }).filter(Boolean)
          : []
      };
    });
    state.activeSessionId = data.activeSessionId || (state.sessions[0] && state.sessions[0].id) || '';
  }

  function createSessionFromForm() {
    var pv = normalizeProviderId(provider.value);
    var pid = pv && P[pv] ? pv : 'openai';
    var p = P[pid] || P.openai;
    return {
      id: genId(),
      provider: pid,
      model: model.value.trim() || p.model,
      baseUrl: p.transport === 'cli' ? normalizeCliUrl(baseUrl.value, pid) : baseUrl.value.trim(),
      gatewaySessionKey: pid === 'openclaw' ? 'main' : '',
      history: []
    };
  }

  function ensureSessions() {
    if (state.sessions.length === 0) {
      var s = createSessionFromForm();
      state.sessions.push(s);
      state.activeSessionId = s.id;
      persistSessions();
    } else if (!state.activeSessionId || !activeSession()) {
      state.activeSessionId = state.sessions[0].id;
    }
  }

  function syncFormFromSession(s) {
    if (!s) return;
    var sp = normalizeProviderId(s.provider);
    var pid = sp && P[sp] ? sp : 'openai';
    provider.value = pid;
    fillModels(pid, s.model);
    var p = P[pid] || P.openai;
    model.value = s.model || p.model;
    if (p.transport === 'cli') baseUrl.value = normalizeCliUrl((s.baseUrl || '').trim() || p.baseUrl, pid);
    else baseUrl.value = (s.baseUrl || '').trim() || p.baseUrl;
    hint(pid);
    apiKey.value = (state.apiKeys && state.apiKeys[pid]) || '';
    refreshApiKeyField(pid);
    provider.dataset.prevProv = pid;
    syncProviderDdUi();
  }

  function syncSessionFromForm(s) {
    if (!s) return;
    var pv = normalizeProviderId(provider.value);
    var pid = pv && P[pv] ? pv : 'openai';
    var p = P[pid] || P.openai;
    s.provider = pid;
    s.model = model.value.trim() || p.model;
    s.baseUrl = p.transport === 'cli' ? normalizeCliUrl(baseUrl.value, pid) : baseUrl.value.trim();
    if (pid !== 'openclaw') s.gatewaySessionKey = '';
    else if (!String(s.gatewaySessionKey || '').trim()) s.gatewaySessionKey = 'main';
  }

  function providerIconUrlList(pid) {
    pid = pid && P[pid] ? pid : 'openai';
    var bases = PROVIDER_ICON_BASES[pid];
    if (!bases || !bases.length) bases = [pid];
    var list = [];
    bases.forEach(function (base) {
      PROVIDER_ICON_EXTS.forEach(function (ext) {
        list.push(ICON_SECOND + base + ext);
      });
    });
    list.push(ICON_PRIMARY + pid + '.svg');
    list.push(ICON_SECOND + pid + '.svg');
    list.push(ICON_FALLBACK);
    var seen = {},
      out = [];
    list.forEach(function (u) {
      if (!seen[u]) {
        seen[u] = 1;
        out.push(u);
      }
    });
    return out;
  }

  function bindProviderIconImg(img, pid, extraClass) {
    img.alt = '';
    img.loading = 'lazy';
    img.className = 'stab-ico-img' + (extraClass ? ' ' + extraClass : '');
    var urls = providerIconUrlList(pid);
    var idx = 0;
    img.onerror = function () {
      idx += 1;
      if (idx < urls.length) {
        this.src = urls[idx];
      } else {
        this.onerror = null;
      }
    };
    img.removeAttribute('src');
    img.src = urls[0];
  }

  function refreshApiKeyField(pid) {
    var km = KEYMETA[pid] || {},
      lab = apiKeyLabel,
      kh = apiKeyKeyHint;
    if (lab) lab.textContent = km.keyLabel || 'API Key';
    apiKey.placeholder = km.keyPlaceholder || '濉啓瀵嗛挜';
    try {
      var p = P[pid] || {};
      var isCli = p && p.transport === 'cli';
      apiKey.disabled = !!isCli;
      apiKey.setAttribute('aria-disabled', isCli ? 'true' : 'false');
      apiKey.style.opacity = isCli ? '0.6' : '';
      if (baseUrl) {
        baseUrl.readOnly = !!isCli;
        baseUrl.setAttribute('aria-readonly', isCli ? 'true' : 'false');
        baseUrl.style.opacity = isCli ? '0.75' : '';
        if (isCli) baseUrl.value = normalizeCliUrl(baseUrl.value, pid);
      }
    } catch (e) {}
    if (kh) {
      if (km.keyHint) {
        kh.textContent = km.keyHint;
        kh.style.display = '';
      } else {
        kh.textContent = '';
        kh.style.display = 'none';
      }
    }
  }

  function migrateApiKeysFromStorage(d) {
    state.apiKeys = {};
    if (d.apiKeys && typeof d.apiKeys === 'object') {
      Object.keys(d.apiKeys).forEach(function (k) {
        var nk = normalizeProviderId(k);
        if (d.apiKeys[k] != null) state.apiKeys[nk] = String(d.apiKeys[k]);
      });
    }
    if (!Object.keys(state.apiKeys).length && d.apiKey) {
      var dp = normalizeProviderId(d.provider);
      var lk = dp && P[dp] ? dp : 'openai';
      state.apiKeys[lk] = String(d.apiKey);
    }
  }

  function fillPromptBuiltinSelect() {
    if (!promptBuiltin) return;
    var opts = '<option value="">鈥?鍐呯疆妯＄増 鈥?/option>';
    PROMPT_BUILTIN.forEach(function (t) {
      opts += '<option value="' + esc(t.id) + '">' + esc(t.name) + '</option>';
    });
    promptBuiltin.innerHTML = opts;
    promptBuiltin.value = '';
  }

  function applySelectedPromptBuiltin() {
    if (!promptBuiltin || !promptBuiltin.value) {
      sstat('璇峰厛鍦ㄥ垪琛ㄤ腑閫夋嫨涓€涓唴缃ā鐗堛€?, 'error');
      return;
    }
    var id = promptBuiltin.value,
      found = null;
    for (var i = 0; i < PROMPT_BUILTIN.length; i++) {
      if (PROMPT_BUILTIN[i].id === id) {
        found = PROMPT_BUILTIN[i];
        break;
      }
    }
    if (!found) return;
    systemPrompt.value = found.text;
    saveCfg(false);
    sstat('宸插簲鐢ㄦā鐗堬細' + found.name, 'success');
  }

  function shortModel(m) {
    m = String(m || '').trim();
    if (!m) return '鈥?;
    var tail = m.replace(/^.*\//, '');
    if (tail.length > 9) return tail.slice(0, 7) + '鈥?;
    return tail;
  }

  function tabTitleForSession(s) {
    var pl = (P[s.provider] || {}).label || s.provider || '';
    return pl + ' 路 ' + shortModel(s.model);
  }

  function renderSessionTabs() {
    if (!sessionTabsEl) return;
    sessionTabsEl.innerHTML = '';
    state.sessions.forEach(function (s) {
      var wrap = document.createElement('div');
      wrap.className = 'stab' + (s.id === state.activeSessionId ? ' active' : '');
      wrap.setAttribute('role', 'tab');
      wrap.dataset.sessionId = s.id;
      wrap.setAttribute('title', tabTitleForSession(s));
      var ico = document.createElement('span');
      ico.className = 'stab-ico';
      ico.setAttribute('aria-hidden', 'true');
      var im = document.createElement('img');
      bindProviderIconImg(im, s.provider);
      ico.appendChild(im);
      var t = document.createElement('span');
      t.className = 'stab-t';
      t.textContent = shortModel(s.model);
      var x = document.createElement('button');
      x.type = 'button';
      x.className = 'stab-x';
      x.setAttribute('aria-label', '鍏抽棴鏍囩');
      x.textContent = '脳';
      x.setAttribute('data-close-session', s.id);
      wrap.appendChild(ico);
      wrap.appendChild(t);
      wrap.appendChild(x);
      sessionTabsEl.appendChild(wrap);
    });
    var addBtn = document.createElement('button');
    addBtn.type = 'button';
    addBtn.className = 'stab-add';
    addBtn.id = 'sessionTabAdd';
    addBtn.textContent = '+';
    addBtn.setAttribute('title', '閫夋嫨 AI 鏂板缓瀵硅瘽');
    addBtn.setAttribute('aria-label', '閫夋嫨 AI 鏂板缓瀵硅瘽');
    sessionTabsEl.appendChild(addBtn);
    refreshSendUi();
    syncChatViewMode();
  }

  function emptyState() {
    var s = activeSession();
    empty.style.display = s && s.history.length ? 'none' : '';
  }

  function appendMessageDom(role, content, ts) {
    var w = document.createElement('article');
    w.className = 'm ' + role;
    var title = role === 'user' ? 'User' : 'Assistant';
    var timeStr = ts
      ? (function () {
          try {
            return new Date(ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
          } catch (e) {
            return '';
          }
        })()
      : new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    var normalized = preMarkdownForChat(content);
    var bodyHtml = md(normalized);
    if (!String(bodyHtml || '').replace(/\s/g, '') && String(normalized || '').trim())
      bodyHtml = '<p>' + esc(normalized).replace(/\n/g, '<br>') + '</p>';
    w.innerHTML =
      '<div class="mh"><span>' +
      title +
      '</span><span>' +
      timeStr +
      '</span></div><div class="mb">' +
      bodyHtml +
      '</div>';
    msgs.appendChild(w);
  }

  function rebuildMsgList() {
    msgs.querySelectorAll('article.m').forEach(function (n) {
      n.remove();
    });
    var s = activeSession();
    if (!s) {
      emptyState();
      return;
    }
    if (isCliSession(s)) {
      // CLI 妯″紡涓嶆覆鏌撴皵娉″巻鍙诧紙鐙珛缁堢鐣岄潰锛?      emptyState();
      syncChatViewMode();
      return;
    }
    s.history.forEach(function (item) {
      if (!item || !item.role) return;
      var raw = item.content != null ? String(item.content) : '';
      var disp = raw.trim() ? raw : ocExtractMessageContentForHistory(item);
      if (!String(disp || '').trim()) disp = '锛堟棤姝ｆ枃锛?;
      appendMessageDom(item.role, disp, item.ts);
    });
    emptyState();
    scrollMsgsToLatest();
    syncChatViewMode();
  }

  function add(role, content) {
    var s = activeSession();
    if (!s) return;
    var ts = new Date().toISOString();
    var n = normalizeHistoryItem({ role: role, content: content, ts: ts });
    if (!n) return;
    s.history.push(n);
    persistSessions();
    pushSessionHistoryToStore(s);
    emptyState();
    appendMessageDom(n.role, n.content, n.ts);
    scrollMsgsToLatest();
    renderSessionTabs();
  }

  function clearChatSearchHit() {
    msgs.querySelectorAll('article.m.search-hit').forEach(function (n) {
      n.classList.remove('search-hit');
    });
  }

  function runChatSearchPrompt() {
    var kw = prompt('鎼滅储鑱婂ぉ璁板綍', state.chatSearchKeyword || '');
    if (kw == null) return;
    kw = String(kw || '').trim();
    if (!kw) {
      state.chatSearchKeyword = '';
      state.chatSearchCursor = -1;
      clearChatSearchHit();
      cstat('宸叉竻绌烘悳绱㈠叧閿瘝');
      return;
    }
    var all = Array.prototype.slice.call(msgs.querySelectorAll('article.m'));
    var matched = all.filter(function (node) {
      return String(node.textContent || '').toLowerCase().indexOf(kw.toLowerCase()) >= 0;
    });
    if (!matched.length) {
      clearChatSearchHit();
      state.chatSearchKeyword = kw;
      state.chatSearchCursor = -1;
      cstat('鏈壘鍒帮細' + kw, 'error');
      return;
    }
    if (state.chatSearchKeyword !== kw) state.chatSearchCursor = -1;
    state.chatSearchKeyword = kw;
    state.chatSearchCursor = (state.chatSearchCursor + 1) % matched.length;
    clearChatSearchHit();
    var target = matched[state.chatSearchCursor];
    target.classList.add('search-hit');
    try {
      target.scrollIntoView({ behavior: 'smooth', block: 'center' });
    } catch (_) {
      target.scrollIntoView();
    }
    cstat('鎼滅储鍛戒腑 ' + (state.chatSearchCursor + 1) + '/' + matched.length + '锛? + kw, 'success');
  }

  function switchSession(id) {
    if (id === state.activeSessionId) return;
    var cur = activeSession();
    syncSessionFromForm(cur);
    pushSessionHistoryToStore(cur);
    persistSessions();
    state.activeSessionId = id;
    var target = activeSession();
    pullStoreHistoryToSession(target);
    syncFormFromSession(target);
    rebuildMsgList();
    renderSessionTabs();
    updateNeedSetup();
    refreshSendUi();
    if (target && target.provider === 'openclaw') hydrateOpenClawHistoryForSession(target, false);
    syncChatViewMode();
  }

  function fillNewSessionGrid() {
    if (!newSessionGrid) return;
    newSessionGrid.innerHTML = '';
    Object.keys(P).forEach(function (k) {
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'ns-item';
      btn.dataset.pickProvider = k;
      var ico = document.createElement('span');
      ico.className = 'stab-ico';
      ico.setAttribute('aria-hidden', 'true');
      var im = document.createElement('img');
      bindProviderIconImg(im, k);
      ico.appendChild(im);
      var lab = document.createElement('span');
      lab.className = 'ns-lab';
      lab.textContent = P[k].label;
      btn.appendChild(ico);
      btn.appendChild(lab);
      newSessionGrid.appendChild(btn);
    });
  }

  function openNewSessionPick() {
    setSettings(false);
    setNspick(true);
    fillNewSessionGrid();
  }

  function closeNewSessionPick() {
    setNspick(false);
  }

  function createSessionWithProvider(pid) {
    if (!pid || !P[pid]) return;
    var cur = activeSession();
    syncSessionFromForm(cur);
    saveCfg(false);
    var p = P[pid];
    var s = {
      id: genId(),
      provider: pid,
      model: p.model,
      baseUrl: p.baseUrl,
      gatewaySessionKey: pid === 'openclaw' ? getOpenClawSessionKey(null) : '',
      history: []
    };
    state.sessions.push(s);
    state.activeSessionId = s.id;
    pullStoreHistoryToSession(s);
    persistSessions();
    syncFormFromSession(s);
    rebuildMsgList();
    renderSessionTabs();
    updateNeedSetup();
    closeNewSessionPick();
    cstat('宸叉墦寮€銆? + p.label + '銆嶆柊瀵硅瘽', 'success');
    if (pid === 'openclaw') hydrateOpenClawHistoryForSession(s, true);
    syncChatViewMode();
  }

  function removeSession(id) {
    if (state.sessions.length <= 1) {
      cstat('鑷冲皯淇濈暀涓€涓璇濇爣绛俱€?, 'error');
      return;
    }
    var cur = activeSession();
    if (cur && cur.id === id) syncSessionFromForm(cur);
    var idx = -1;
    for (var i = 0; i < state.sessions.length; i++) {
      if (state.sessions[i].id === id) {
        idx = i;
        break;
      }
    }
    if (idx < 0) return;
    state.sessions.splice(idx, 1);
    if (state.activeSessionId === id) {
      state.activeSessionId = state.sessions[Math.max(0, idx - 1)].id;
      syncFormFromSession(activeSession());
      rebuildMsgList();
    }
    persistSessions();
    renderSessionTabs();
  }

  function downloadBlob(filename, text, mime) {
    var blob = new Blob([text], { type: mime || 'text/plain;charset=utf-8' });
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    a.click();
    URL.revokeObjectURL(a.href);
  }

  function exportMarkdown() {
    var s = activeSession();
    if (!s || !s.history.length) {
      cstat('褰撳墠鏍囩娌℃湁娑堟伅鍙鍑恒€?, 'error');
      return;
    }
    syncSessionFromForm(s);
    var lines = [];
    lines.push('# NiuMa Chat 瀵煎嚭');
    lines.push('');
    lines.push('- 鏈嶅姟鍟? ' + ((P[s.provider] || {}).label || s.provider));
    lines.push('- 妯″瀷: ' + s.model);
    lines.push('- 瀵煎嚭鏃堕棿: ' + new Date().toLocaleString());
    lines.push('');
    s.history.forEach(function (m) {
      lines.push('## ' + (m.role === 'user' ? '鐢ㄦ埛' : '鍔╂墜') + ' 路 ' + (m.ts || ''));
      lines.push('');
      lines.push(m.content);
      lines.push('');
    });
    downloadBlob('niuma-chat-' + s.id + '.md', lines.join('\n'), 'text/markdown;charset=utf-8');
    cstat('宸插鍑?Markdown銆?, 'success');
  }

  function exportJson() {
    var s = activeSession();
    if (!s || !s.history.length) {
      cstat('褰撳墠鏍囩娌℃湁娑堟伅鍙鍑恒€?, 'error');
      return;
    }
    syncSessionFromForm(s);
    var payload = {
      exportedAt: new Date().toISOString(),
      session: {
        id: s.id,
        provider: s.provider,
        providerLabel: (P[s.provider] || {}).label || s.provider,
        model: s.model,
        baseUrl: s.baseUrl,
        history: s.history
      }
    };
    downloadBlob('niuma-chat-' + s.id + '.json', JSON.stringify(payload, null, 2), 'application/json;charset=utf-8');
    cstat('宸插鍑?JSON銆?, 'success');
  }

  function cstat(t, m) {
    chatStatus.textContent = t;
    chatStatus.className = 'st' + (m === 'error' ? ' error' : m === 'success' ? ' success' : '');
  }

  function isSessionSending(id) {
    if (!id) return false;
    return !!(state.sendingBySession && state.sendingBySession[id]);
  }

  function refreshSendUi() {
    var sid = state.activeSessionId || (activeSession() && activeSession().id) || '';
    var sending = isSessionSending(sid);
    var s = activeSession();
    if (isCliSession(s)) {
      // CLI 妯″紡闅愯棌 composer锛屾湰鎸夐挳涓嶄綔涓轰富瑕佸叆鍙ｏ紱淇濇寔绂佺敤閬垮厤璇Е
      send.disabled = true;
      send.textContent = 'CLI 妯″紡';
      return;
    }
    send.disabled = sending;
    send.textContent = sending ? '鍙戦€佷腑...' : '鍙戦€佹秷鎭?;
  }

  function setSessionSending(id, v) {
    if (!id) return;
    if (!state.sendingBySession) state.sendingBySession = {};
    if (v) state.sendingBySession[id] = true;
    else delete state.sendingBySession[id];
    refreshSendUi();
  }

  function cstatForSession(sid, t, m) {
    if (state.activeSessionId === sid) cstat(t, m);
  }

  function sstat(t, m) {
    cfgStatus.textContent = t;
    cfgStatus.className = 'st' + (m === 'error' ? ' error' : m === 'success' ? ' success' : '');
  }

  function fillProviders() {
    provider.innerHTML = Object.keys(P)
      .map(function (k) {
        return '<option value="' + k + '">' + P[k].label + '</option>';
      })
      .join('');
    buildProviderDdMenu();
    syncProviderDdUi();
  }

  function buildProviderDdMenu() {
    if (!providerDdMenu) return;
    providerDdMenu.innerHTML = '';
    Object.keys(P).forEach(function (k) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'dd-item';
      b.setAttribute('role', 'option');
      b.dataset.value = k;
      var im = document.createElement('img');
      bindProviderIconImg(im, k, 'dd-icon');
      var sp = document.createElement('span');
      sp.className = 'dd-label';
      sp.textContent = P[k].label;
      b.appendChild(im);
      b.appendChild(sp);
      b.addEventListener('click', function (e) {
        e.stopPropagation();
        provider.value = k;
        var ev = new Event('change', { bubbles: true });
        provider.dispatchEvent(ev);
        closeProviderDd();
      });
      providerDdMenu.appendChild(b);
    });
  }

  function syncProviderDdUi() {
    var pv = normalizeProviderId(provider.value);
    var k = pv && P[pv] ? pv : 'openai';
    var p = P[k] || P.openai;
    if (providerDdLabel) providerDdLabel.textContent = p.label;
    if (providerDdIcon) bindProviderIconImg(providerDdIcon, k, 'dd-icon');
    if (providerDdMenu) {
      providerDdMenu.querySelectorAll('.dd-item').forEach(function (el) {
        el.classList.toggle('dd-active', el.dataset.value === k);
      });
    }
  }

  function closeProviderDd() {
    if (providerDdMenu) providerDdMenu.hidden = true;
    if (providerDdBtn) providerDdBtn.setAttribute('aria-expanded', 'false');
  }

  function closeModelDd() {
    if (modelDdMenu) modelDdMenu.hidden = true;
    if (modelDdBtn) modelDdBtn.setAttribute('aria-expanded', 'false');
  }

  function toggleProviderDd() {
    if (!providerDdMenu) return;
    var open = providerDdMenu.hidden;
    closeModelDd();
    providerDdMenu.hidden = !open;
    if (providerDdBtn) providerDdBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
  }

  function toggleModelDd() {
    if (!modelDdMenu) return;
    var open = modelDdMenu.hidden;
    closeProviderDd();
    modelDdMenu.hidden = !open;
    if (modelDdBtn) modelDdBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
    if (open) ensureDynamicModelsForActiveProvider();
  }

  function uniqStrings(arr) {
    var out = [],
      seen = {};
    (arr || []).forEach(function (x) {
      var v = String(x || '').trim();
      if (!v || seen[v]) return;
      seen[v] = 1;
      out.push(v);
    });
    return out;
  }

  function getPresetModels(pid) {
    var p = P[pid] || P.openai;
    var staticModels = Array.isArray(p.models) ? p.models : [];
    var dynamicModels = (state.dynamicModels && state.dynamicModels[pid]) || [];
    return uniqStrings([].concat(dynamicModels, staticModels));
  }

  function modelListUrl(base) {
    var b = String(base || '').trim().replace(/\/+$/, '');
    if (!b) return '';
    return b + '/models';
  }

  function collectModelIdsDeep(v, out) {
    if (!v) return;
    if (Array.isArray(v)) {
      v.forEach(function (it) {
        collectModelIdsDeep(it, out);
      });
      return;
    }
    if (typeof v === 'string') {
      var s = v.trim();
      if (s) out.push(s);
      return;
    }
    if (typeof v !== 'object') return;
    var cand = [v.id, v.model, v.name, v.model_id, v.modelId];
    cand.forEach(function (x) {
      if (typeof x === 'string' && x.trim()) out.push(x.trim());
    });
    if (v.data) collectModelIdsDeep(v.data, out);
    if (v.models) collectModelIdsDeep(v.models, out);
    if (v.result) collectModelIdsDeep(v.result, out);
    if (v.items) collectModelIdsDeep(v.items, out);
  }

  async function fetchDynamicModels(pid) {
    pid = normalizeProviderId(pid);
    if (!(pid && P[pid])) return [];
    var prov = P[pid];
    if (prov.transport !== 'openai') return [];
    var url = modelListUrl(baseUrl.value || prov.baseUrl);
    if (!url) return [];
    var headers = { 'Content-Type': 'application/json' };
    var key = getApiKeyForProvider(pid);
    if (key) headers.Authorization = 'Bearer ' + key;
    var resp = await fetch(url, { method: 'GET', headers: headers });
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    var body = await resp.json().catch(function () { return {}; });
    var ids = [];
    collectModelIdsDeep(body, ids);
    return uniqStrings(ids).slice(0, 200);
  }

  async function ensureDynamicModelsForActiveProvider(force) {
    var pid = normalizeProviderId(provider.value);
    if (!(pid && P[pid])) return;
    var now = Date.now();
    var ttlMs = 5 * 60 * 1000;
    if (!force) {
      var at = (state.dynamicModelsFetchedAt && state.dynamicModelsFetchedAt[pid]) || 0;
      if (at && now - at < ttlMs) return;
    }
    try {
      var list = await fetchDynamicModels(pid);
      if (!state.dynamicModels) state.dynamicModels = {};
      if (!state.dynamicModelsFetchedAt) state.dynamicModelsFetchedAt = {};
      if (list && list.length) state.dynamicModels[pid] = list;
      state.dynamicModelsFetchedAt[pid] = now;
      if (normalizeProviderId(provider.value) === pid) {
        fillModels(pid, model.value.trim());
      }
    } catch (e) {
      if (!state.dynamicModelsFetchedAt) state.dynamicModelsFetchedAt = {};
      state.dynamicModelsFetchedAt[pid] = now;
    }
  }

  function fillModels(pid, sel) {
    var p = P[pid] || P.openai,
      o = ['<option value="">鎵嬪姩杈撳叆</option>'];
    getPresetModels(pid).forEach(function (m) {
      o.push('<option value="' + esc(m) + '">' + esc(m) + '</option>');
    });
    modelPreset.innerHTML = o.join('');
    var preset = getPresetModels(pid);
    modelPreset.value = sel && preset.indexOf(sel) >= 0 ? sel : '';
    buildModelDdMenu(pid);
    syncModelDdUi();
  }

  function buildModelDdMenu(pid) {
    if (!modelDdMenu) return;
    var p = P[pid] || P.openai;
    modelDdMenu.innerHTML = '';
    function addItem(val, label) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'dd-item';
      b.setAttribute('role', 'option');
      b.dataset.value = val;
      var im = document.createElement('img');
      bindProviderIconImg(im, pid, 'dd-icon');
      var sp = document.createElement('span');
      sp.className = 'dd-label';
      sp.textContent = label;
      b.appendChild(im);
      b.appendChild(sp);
      b.addEventListener('click', function (e) {
        e.stopPropagation();
        modelPreset.value = val;
        if (val) model.value = val;
        modelPreset.dispatchEvent(new Event('change', { bubbles: true }));
        closeModelDd();
      });
      modelDdMenu.appendChild(b);
    }
    addItem('', '鎵嬪姩杈撳叆');
    getPresetModels(pid).forEach(function (m) {
      addItem(m, m);
    });
  }

  function syncModelDdUi() {
    var pv = normalizeProviderId(provider.value);
    var k = pv && P[pv] ? pv : 'openai';
    var mp = modelPreset.value;
    var label = mp ? mp : '鎵嬪姩杈撳叆';
    if (modelDdLabel) modelDdLabel.textContent = label;
    if (modelDdIcon) bindProviderIconImg(modelDdIcon, k, 'dd-icon');
    if (modelDdMenu) {
      modelDdMenu.querySelectorAll('.dd-item').forEach(function (el) {
        el.classList.toggle('dd-active', el.dataset.value === mp);
      });
    }
  }

  function hint(pid) {
    var p = P[pid] || P.openai,
      m = {
        openai: 'OpenAI 鍏煎 chat/completions',
        anthropic: 'Anthropic messages 鎺ュ彛',
        gemini: 'Gemini generateContent 鎺ュ彛',
        openclaw: 'OpenClaw Gateway WebSocket锛坈onnect + chat.send锛?
      };
    var transportLabel = pid === 'ollama' ? '鏈湴 Ollama锛圤penAI 鍏煎 chat/completions锛? : (m[p.transport] || p.transport);
    ph.textContent =
      p.label +
      ' 榛樿璧?' +
      transportLabel +
      '銆傚浣犱娇鐢ㄤ腑杞珯銆佸弽鍚戜唬鐞嗘垨绉佹湁缃戝叧锛屼篃鍙互鐩存帴瑕嗙洊 Base URL 鍜?Model銆?;
  }

  function applyProvider(pid, keep) {
    pid = normalizeProviderId(pid);
    if (!(pid && P[pid])) pid = 'openai';
    var p = P[pid] || P.openai;
    provider.value = pid;
    fillModels(pid, model.value.trim());
    hint(pid);
    if (p.transport === 'cli') baseUrl.value = normalizeCliUrl(p.baseUrl, pid);
    else if (!keep || !baseUrl.value.trim()) baseUrl.value = p.baseUrl;
    if (!keep || !model.value.trim()) model.value = p.model;
    if (!systemPrompt.value.trim()) systemPrompt.value = SP;
    syncProviderDdUi();
  }

  function getApiKeyForProvider(pid) {
    pid = normalizeProviderId(pid);
    pid = pid && P[pid] ? pid : 'openai';
    return ((state.apiKeys && state.apiKeys[pid]) || '').trim();
  }

  function openClawEndpointFromCfg(cfg) {
    var raw = (cfg.baseUrl || '').trim();
    var token = (cfg.apiKey || '').trim();
    var host = '127.0.0.1';
    var port = 18789;
    try {
      var u = new URL(raw.indexOf('://') >= 0 ? raw : 'http://' + raw);
      host = u.hostname || host;
      if (u.port) port = parseInt(u.port, 10) || port;
      if (u.hash && u.hash.indexOf('token=') >= 0) {
        var sp = new URLSearchParams(u.hash.replace(/^#/, '?'));
        var ht = (sp.get('token') || '').trim();
        if (ht) token = ht;
      }
    } catch (e) {}
    if (!token || !host) return { ok: false };
    return { ok: true, host: host, port: port, token: token };
  }

  function updateNeedSetup() {
    var s = activeSession();
    if (!s) {
      state.needSetup = true;
      return;
    }
    var sp = normalizeProviderId(s.provider);
    var p = P[sp] || P.openai;
    var url = (s.baseUrl || '').trim() || baseUrl.value.trim() || p.baseUrl;
    var m = (s.model || '').trim() || model.value.trim();
    var k = getApiKeyForProvider(sp);
    if (p.transport === 'openclaw') {
      state.needSetup = !openClawEndpointFromCfg({ baseUrl: url, apiKey: k, provider: sp }).ok;
      return;
    }
    if (sp === 'ollama') {
      state.needSetup = !url || !m;
      return;
    }
    state.needSetup = !k || !url || !m;
  }

  function loadCfg() {
    var d = {};
    try {
      d = JSON.parse(localStorage.getItem(LS) || localStorage.getItem(LEGACY_LS) || '{}') || {};
    } catch (e) {
      d = {};
    }
    migrateApiKeysFromStorage(d);
    systemPrompt.value = Object.prototype.hasOwnProperty.call(d, 'systemPrompt') ? String(d.systemPrompt) : SP;
    loadNiumaHistoryStore();

    loadSessions();

    if (state.sessions.length === 0) {
      var dp = normalizeProviderId(d.provider);
      var pid = dp && P[dp] ? dp : 'openai';
      provider.value = pid;
      applyProvider(pid, true);
      if (d.baseUrl) baseUrl.value = d.baseUrl;
      if (d.model) model.value = d.model;
      fillModels(pid, model.value.trim());
      var s0 = createSessionFromForm();
      state.sessions = [s0];
      state.activeSessionId = s0.id;
      persistSessions();
      apiKey.value = state.apiKeys[pid] || '';
      refreshApiKeyField(pid);
      provider.dataset.prevProv = pid;
    } else {
      ensureSessions();
      state.sessions.forEach(function (sx) {
        pullStoreHistoryToSession(sx);
      });
      syncFormFromSession(activeSession());
      fillModels(provider.value, model.value.trim());
    }

    state.sessions.forEach(function (sx) {
      pushSessionHistoryToStore(sx);
    });

    updateNeedSetup();
    sstat(state.needSetup ? '棣栨浣跨敤璇峰厛瀹屾垚 API 璁剧疆銆? : '閰嶇疆涓庡璇濆凡浠庢湰鍦版仮澶嶃€?, state.needSetup ? '' : 'success');
    renderSessionTabs();
    rebuildMsgList();
    refreshSendUi();
    var sAct = activeSession();
    if (sAct && normalizeProviderId(sAct.provider) === 'openclaw') hydrateOpenClawHistoryForSession(sAct, false);
    ensureDynamicModelsForActiveProvider();
  }

  function saveCfg(ok) {
    var cur = activeSession();
    syncSessionFromForm(cur);
    var pv = normalizeProviderId(provider.value);
    var pid = pv && P[pv] ? pv : 'openai';
    if (!state.apiKeys) state.apiKeys = {};
    state.apiKeys[pid] = apiKey.value.trim();
    var d = {
      provider: pid,
      apiKeys: state.apiKeys,
      baseUrl: baseUrl.value.trim(),
      model: model.value.trim(),
      systemPrompt: systemPrompt.value.trim()
    };
    localStorage.setItem(LS, JSON.stringify(d));
    persistSessions();
    updateNeedSetup();
    sstat(ok ? '璁剧疆宸蹭繚瀛樺埌鏈湴銆? : '閰嶇疆浼氳嚜鍔ㄤ繚瀛樺埌鏈湴銆?, ok ? 'success' : '');
    renderSessionTabs();
    return d;
  }

  function reset() {
    localStorage.removeItem(LS);
    localStorage.removeItem(LEGACY_LS);
    localStorage.removeItem(SESSIONS_LS);
    state.apiKeys = {};
    apiKey.value = '';
    systemPrompt.value = SP;
    applyProvider('openai', false);
    fillModels('openai', model.value.trim());
    refreshApiKeyField('openai');
    state.sessions = [];
    state.activeSessionId = '';
    loadCfg();
    state.needSetup = true;
    sstat('宸查噸缃細鍚勬湇鍔″晢瀵嗛挜涓庡璇濆凡娓呯┖锛岃鍒嗗埆濉啓銆?, '');
    setSettings(true);
  }

  function buildSendCfg() {
    var s = activeSession();
    if (!s) return null;
    syncSessionFromForm(s);
    var sp = normalizeProviderId(s.provider);
    var pid = sp && P[sp] ? sp : 'openai';
    var p = P[pid] || P.openai;
    var bu = (s.baseUrl || '').trim() || p.baseUrl;
    return {
      provider: pid,
      model: (s.model || '').trim() || p.model,
      baseUrl: bu,
      apiKey: getApiKeyForProvider(pid),
      systemPrompt: systemPrompt.value.trim()
    };
  }

  function oaUrl(u) {
    u = String(u || '').replace(/\/+$/, '');
    if (/\/chat\/completions$/i.test(u)) return u;
    if (/\/v\d+(?:\.\d+)?$/i.test(u)) return u + '/chat/completions';
    return u + '/chat/completions';
  }

  function claudeUrl(u) {
    u = String(u || '').replace(/\/+$/, '');
    if (/\/v1\/messages$/i.test(u)) return u;
    if (/\/v1$/i.test(u)) return u + '/messages';
    return u + '/v1/messages';
  }

  function geminiUrl(u, m, k) {
    u = String(u || '').replace(/\/+$/, '');
    var p = '/models/' + encodeURIComponent(m) + ':generateContent?key=' + encodeURIComponent(k);
    if (/\/v1beta$/i.test(u) || /\/v1$/i.test(u)) return u + p;
    return u + '/v1beta' + p;
  }

  function norm(c) {
    if (typeof c === 'string') return c;
    if (Array.isArray(c))
      return c
        .map(function (p) {
          if (typeof p === 'string') return p;
          if (p && typeof p.text === 'string') return p.text;
          return '';
        })
        .join('\n')
        .trim();
    return '';
  }

  function oaMsgs(cfg) {
    var m = [];
    if (cfg.systemPrompt) m.push({ role: 'system', content: cfg.systemPrompt });
    var h = activeSession() ? activeSession().history : [];
    h.forEach(function (i) {
      m.push({ role: i.role, content: i.content });
    });
    return m;
  }

  function claudeMsgs() {
    var h = activeSession() ? activeSession().history : [];
    return h.map(function (i) {
      return { role: i.role === 'assistant' ? 'assistant' : 'user', content: i.content };
    });
  }

  function geminiMsgs() {
    var h = activeSession() ? activeSession().history : [];
    return h.map(function (i) {
      return { role: i.role === 'assistant' ? 'model' : 'user', parts: [{ text: i.content }] };
    });
  }

  async function reqOpenAI(cfg) {
    var h = { 'Content-Type': 'application/json' };
    if (cfg.apiKey) h.Authorization = 'Bearer ' + cfg.apiKey;
    var r = await fetch(oaUrl(cfg.baseUrl), {
      method: 'POST',
      headers: h,
      body: JSON.stringify({ model: cfg.model, messages: oaMsgs(cfg), temperature: 0.7 })
    });
    if (!r.ok) throw new Error('HTTP ' + r.status + ': ' + (await r.text()));
    var d = await r.json(),
      c = '';
    try {
      c = norm(d.choices[0].message.content);
    } catch (e) {
      c = '';
    }
    if (!c) throw new Error('鍝嶅簲涓病鏈夊彲鏄剧ず鐨勫唴瀹广€?);
    return c;
  }

  async function reqClaude(cfg) {
    var r = await fetch(claudeUrl(cfg.baseUrl), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-api-key': cfg.apiKey, 'anthropic-version': '2023-06-01' },
      body: JSON.stringify({
        model: cfg.model,
        system: cfg.systemPrompt || '',
        max_tokens: 2048,
        messages: claudeMsgs()
      })
    });
    if (!r.ok) throw new Error('HTTP ' + r.status + ': ' + (await r.text()));
    var d = await r.json(),
      c = '';
    try {
      c = (d.content || [])
        .map(function (p) {
          return p && p.type === 'text' ? p.text || '' : '';
        })
        .join('\n')
        .trim();
    } catch (e) {
      c = '';
    }
    if (!c) throw new Error('鍝嶅簲涓病鏈夊彲鏄剧ず鐨勫唴瀹广€?);
    return c;
  }

  async function reqGemini(cfg) {
    var body = { contents: geminiMsgs(), generationConfig: { temperature: 0.7 } };
    if (cfg.systemPrompt) body.systemInstruction = { parts: [{ text: cfg.systemPrompt }] };
    var r = await fetch(geminiUrl(cfg.baseUrl, cfg.model, cfg.apiKey), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    if (!r.ok) throw new Error('HTTP ' + r.status + ': ' + (await r.text()));
    var d = await r.json(),
      c = '';
    try {
      var parts = (((d.candidates || [])[0] || {}).content || {}).parts || [];
      c = parts
        .map(function (p) {
          return p && typeof p.text === 'string' ? p.text : '';
        })
        .join('\n')
        .trim();
    } catch (e) {
      c = '';
    }
    if (!c) throw new Error('鍝嶅簲涓病鏈夊彲鏄剧ず鐨勫唴瀹广€?);
    return c;
  }

  function ocExtractText(v) {
    if (v == null) return '';
    if (typeof v === 'object')
      return String(v.text || v.content || v.message || v.body || v.value || '').trim();
    var s = String(v).trim();
    if (!s) return '';
    try {
      var o = JSON.parse(s);
      if (o && typeof o === 'object') return String(o.text || o.content || o.message || s).trim();
    } catch (e) {}
    return s;
  }

  function ocCollectTextDeep(v, out) {
    if (v == null) return;
    if (typeof v === 'string') {
      var t = v.trim();
      if (t) out.push(t);
      return;
    }
    if (Array.isArray(v)) {
      for (var i = 0; i < v.length; i++) ocCollectTextDeep(v[i], out);
      return;
    }
    if (typeof v === 'object') {
      if (typeof v.text === 'string' && v.text.trim()) out.push(v.text.trim());
      if (typeof v.message === 'string' && v.message.trim()) out.push(v.message.trim());
      if (typeof v.content === 'string' && v.content.trim()) out.push(v.content.trim());
      if (typeof v.body === 'string' && v.body.trim()) out.push(v.body.trim());
      if (typeof v.value === 'string' && v.value.trim()) out.push(v.value.trim());
      if (v.content && typeof v.content !== 'string') ocCollectTextDeep(v.content, out);
      if (v.delta) ocCollectTextDeep(v.delta, out);
      if (v.output) ocCollectTextDeep(v.output, out);
      if (v.response) ocCollectTextDeep(v.response, out);
      if (v.result) ocCollectTextDeep(v.result, out);
      if (v.data) ocCollectTextDeep(v.data, out);
      if (v.payload) ocCollectTextDeep(v.payload, out);
      if (v.message && typeof v.message !== 'string') ocCollectTextDeep(v.message, out);
      if (v.parts) ocCollectTextDeep(v.parts, out);
      if (v.output_text) ocCollectTextDeep(v.output_text, out);
      if (v.assistant) ocCollectTextDeep(v.assistant, out);
      if (Array.isArray(v.choices)) {
        for (var c = 0; c < v.choices.length; c++) {
          var ch = v.choices[c];
          if (ch && typeof ch === 'object') {
            ocCollectTextDeep(ch.message || ch.delta || ch, out);
          }
        }
      }
    }
  }

  /** OpenClaw broadcast("chat", payload)锛氭鏂囧湪 message.content[].text锛岃€岄潪鏃х増 response.text */
  function ocExtractChatEventPayload(pl) {
    if (!pl || typeof pl !== 'object') return '';
    if (pl.state === 'error') return '';
    var msg =
      pl.message ||
      pl.assistant ||
      pl.assistantMessage ||
      pl.data ||
      pl.response ||
      pl.result ||
      pl.output ||
      pl.delta ||
      pl.payload;
    if (msg == null) msg = pl;
    if (typeof msg === 'string') return String(msg).trim();
    var acc = [];
    ocCollectTextDeep(msg, acc);
    if (acc.length) return acc.join('\n').trim();
    acc = [];
    ocCollectTextDeep(pl, acc);
    if (acc.length) return acc.join('\n').trim();
    return ocExtractText(msg) || ocExtractText(pl);
  }

  /**
   * 涓?openclaw2 鎺у埗鍙颁竴鑷达細椤跺眰甯镐负 type:event + payload.event===chat锛?   * 鑰岄潪 msg.event===chat锛堝惁鍒?NiuMa 姘歌繙绛変笉鍒?final锛?5s 瓒呮椂锛夈€?   */
  function ocGetChatBroadcastPayload(msg) {
    if (!msg || typeof msg !== 'object') return null;
    if (msg.payload != null && typeof msg.payload === 'object' && msg.event === 'chat') return msg.payload;
    var t = msg.type,
      e = msg.event;
    var isEventEnvelope =
      t === 'event' ||
      t === 'push' ||
      t === 'notification' ||
      t === 'broadcast' ||
      e === 'event' ||
      e === 'push' ||
      e === 'notification' ||
      e === 'broadcast';
    if (!isEventEnvelope) return null;
    var w = msg.payload || msg.params;
    if (!w || typeof w !== 'object') return null;
    var inner = String(w.event || w.type || '').toLowerCase();
    if (inner !== 'chat') return null;
    if (w.payload != null && typeof w.payload === 'object') return w.payload;
    return w;
  }

  function ocGetChatSideResultPayload(msg) {
    if (!msg || typeof msg !== 'object') return null;
    if (msg.payload != null && typeof msg.payload === 'object' && msg.event === 'chat.side_result') return msg.payload;
    var t = msg.type,
      e = msg.event;
    var isEventEnvelope =
      t === 'event' ||
      t === 'push' ||
      t === 'notification' ||
      t === 'broadcast' ||
      e === 'event' ||
      e === 'push' ||
      e === 'notification' ||
      e === 'broadcast';
    if (!isEventEnvelope) return null;
    var w = msg.payload || msg.params;
    if (!w || typeof w !== 'object') return null;
    var inner = String(w.event || w.type || '').toLowerCase();
    if (inner !== 'chat.side_result') return null;
    if (w.payload != null && typeof w.payload === 'object') return w.payload;
    return w;
  }

  function ocIsChatFinalState(pl) {
    if (!pl || typeof pl !== 'object') return false;
    var s = pl.state;
    if (s === 'final' || s === 'done' || s === 'completed' || s === 'finished') return true;
    if (pl.done === true || pl.finished === true) return true;
    return false;
  }

  function extractGatewayHistoryMessages(res) {
    if (!res) return [];
    if (Array.isArray(res)) return res;
    if (Array.isArray(res.messages)) return res.messages;
    if (Array.isArray(res.history)) return res.history;
    if (Array.isArray(res.data)) return res.data;
    if (Array.isArray(res.items)) return res.items;
    if (res.result && typeof res.result === 'object') return extractGatewayHistoryMessages(res.result);
    if (res.data && typeof res.data === 'object') return extractGatewayHistoryMessages(res.data);
    if (res.payload && typeof res.payload === 'object') return extractGatewayHistoryMessages(res.payload);
    return [];
  }

  function mapGatewayHistoryItem(m) {
    if (!m || typeof m !== 'object') return null;
    var role = normalizeRole(m.role || m.type || m.actor);
    if (!role) return null;
    var content = ocExtractMessageContentForHistory(m);
    if (!content) return null;
    return { role: role, content: content, ts: ensureIsoTime(m.ts || m.timestamp || m.createdAt || m.updatedAt) };
  }

  function openClawRpc(cfg, method, params, timeoutMs) {
    var ep = openClawEndpointFromCfg(cfg);
    if (!ep.ok) return Promise.reject(new Error('Gateway token missing'));
    var wsUrl = 'ws://' + ep.host + ':' + ep.port + '/?token=' + encodeURIComponent(ep.token);
    var to = Math.max(3000, Number(timeoutMs) || 12000);
    return new Promise(function (resolve, reject) {
      var ws;
      try {
        ws = new WebSocket(wsUrl);
      } catch (e) {
        reject(e);
        return;
      }
      var done = false,
        seq = 0,
        connected = false,
        connectSent = false,
        rpcId = '';
      var timer = setTimeout(function () {
        finishErr(new Error('OpenClaw RPC timeout: ' + method));
      }, to);

      function finishOk(val) {
        if (done) return;
        done = true;
        clearTimeout(timer);
        try {
          ws.close();
        } catch (e) {}
        resolve(val);
      }
      function finishErr(err) {
        if (done) return;
        done = true;
        clearTimeout(timer);
        try {
          ws.close();
        } catch (e) {}
        reject(err);
      }
      function sendConnect() {
        if (connectSent) return;
        connectSent = true;
        seq += 1;
        var cid = 'connect-' + seq;
        ws.send(
          JSON.stringify({
            type: 'req',
            id: cid,
            method: 'connect',
            params: {
              minProtocol: 3,
              maxProtocol: 3,
              client: { id: 'openclaw-control-ui', version: 'niuma', platform: 'web', mode: 'webchat', instanceId: 'niuma-rpc-' + Date.now() },
              role: 'operator',
              scopes: ['operator.admin', 'operator.approvals', 'operator.pairing', 'operator.read', 'operator.write'],
              caps: [],
              auth: { token: ep.token }
            }
          })
        );
      }
      function sendRpc() {
        if (!connected || rpcId) return;
        seq += 1;
        rpcId = 'rpc-' + seq;
        ws.send(JSON.stringify({ type: 'req', id: rpcId, method: method, params: params || {} }));
      }
      ws.onopen = function () {
        sendConnect();
      };
      ws.onerror = function () {
        finishErr(new Error('OpenClaw websocket error'));
      };
      ws.onclose = function () {
        if (!done) finishErr(new Error('OpenClaw websocket closed'));
      };
      ws.onmessage = function (e) {
        var msg = null;
        try {
          msg = JSON.parse(e.data);
        } catch (ex) {
          return;
        }
        var ev = msg.event || msg.type || msg.method || '';
        if (ev === 'connect.challenge') {
          connectSent = false;
          sendConnect();
          return;
        }
        if (typeof msg.id === 'string' && msg.id.indexOf('connect-') === 0) {
          if (msg.error || msg.ok === false) {
            finishErr(new Error((msg.error && msg.error.message) || 'connect failed'));
            return;
          }
          connected = true;
          sendRpc();
          return;
        }
        if (!connected && ev === 'hello-ok') {
          connected = true;
          sendRpc();
          return;
        }
        if (rpcId && msg.id === rpcId) {
          if (msg.error || msg.ok === false) {
            finishErr(new Error((msg.error && msg.error.message) || 'rpc failed'));
            return;
          }
          var body = msg.result !== undefined ? msg.result : msg.payload !== undefined ? msg.payload : msg;
          finishOk(body);
        }
      };
    });
  }

  async function hydrateOpenClawHistoryForSession(s, force) {
    if (!s || s.provider !== 'openclaw') return;
    if (s._historyHydrating) return;
    if (s._historyHydrated && !force) return;
    s._historyHydrating = true;
    try {
      pullStoreHistoryToSession(s);
      if (s.id === state.activeSessionId) rebuildMsgList();
      var cfg = {
        provider: s.provider,
        baseUrl: (s.baseUrl || '').trim() || (P.openclaw && P.openclaw.baseUrl) || '',
        apiKey: getApiKeyForProvider('openclaw')
      };
      var ep = openClawEndpointFromCfg(cfg);
      if (ep.ok) {
        var sk = getOpenClawSessionKey(s);
        s.gatewaySessionKey = sk;
        try {
          localStorage.setItem('openclaw2_lastSessionKey', sk);
        } catch (e0) {}
        var rpcRes = await openClawRpc(cfg, 'chat.history', { sessionKey: sk, limit: 100 }, 10000);
        var gw = extractGatewayHistoryMessages(rpcRes).map(mapGatewayHistoryItem).filter(Boolean);
        /* 鏈湴浼樺厛锛氶伩鍏嶇綉鍏?chat.history 鍗犱綅椤癸紙content 绌恒€佷粎鏈?id锛変笌鍒氬彂閫佹潯鐩悓 key 鏃剁洊浣忔湰鍦版鏂?*/
        if (gw.length) s.history = mergeHistoryList(s.history || [], gw).slice(-400);
      }
      pushSessionHistoryToStore(s);
      persistSessions();
      if (s.id === state.activeSessionId) rebuildMsgList();
      s._historyHydrated = true;
    } catch (e) {
    } finally {
      s._historyHydrating = false;
    }
  }

  async function reqOpenClaw(cfg) {
    var ep = openClawEndpointFromCfg(cfg);
    if (!ep.ok) throw new Error('缂哄皯 Gateway Token锛氳濉啓瀵嗛挜锛屾垨灏嗗甫 #token= 鐨勬帶鍒跺彴鍦板潃濉叆 Base URL銆?);
    var wsUrl = 'ws://' + ep.host + ':' + ep.port + '/?token=' + encodeURIComponent(ep.token);
    var h = activeSession() ? activeSession().history : [];
    var last = h[h.length - 1];
    if (!last || last.role !== 'user') throw new Error('鍐呴儴閿欒锛氱己灏戠敤鎴锋秷鎭€?);
    var msgText = String(last.content != null ? last.content : '');
    if (!msgText.trim()) msgText = ocExtractMessageContentForHistory(last);
    if (!String(msgText || '').trim()) throw new Error('涓婁竴鏉＄敤鎴锋秷鎭鏂囦负绌猴紝璇烽噸鏂拌緭鍏ュ悗鍙戦€併€?);
    if (cfg.systemPrompt && h.length === 1) {
      msgText = '銆愮郴缁熸彁绀恒€慭n' + cfg.systemPrompt + '\n\n' + msgText;
    }
    var s0 = activeSession();
    var sessionKey = getOpenClawSessionKey(s0);
    if (s0) s0.gatewaySessionKey = sessionKey;
    try {
      localStorage.setItem('openclaw2_lastSessionKey', sessionKey);
    } catch (e) {}
    var instanceId = 'niuma-' + Date.now() + '-' + Math.random().toString(36).slice(2, 11);

    return new Promise(function (resolve, reject) {
      var ws;
      try {
        ws = new WebSocket(wsUrl);
      } catch (e) {
        reject(new Error('鏃犳硶寤虹珛 WebSocket锛? + (e && e.message ? e.message : String(e))));
        return;
      }
      var seq = 0;
      var settled = false;
      var authenticated = false;
      var challengeReceived = false;
      var connectSent = false;
      var chatMsgId = '';
      var pendingText = '';
      var finalizeTimer = null;
      var hardTimeout = setTimeout(function () {
        settleReject(new Error('OpenClaw 鍝嶅簲瓒呮椂锛?5s锛夈€?));
      }, 45000);

      function cleanup() {
        clearTimeout(hardTimeout);
        if (finalizeTimer) clearTimeout(finalizeTimer);
      }

      function settleResolve(val) {
        if (settled) return;
        settled = true;
        cleanup();
        try {
          ws.close();
        } catch (e) {}
        resolve(val);
      }

      function settleReject(err) {
        if (settled) return;
        settled = true;
        cleanup();
        try {
          ws.close();
        } catch (e) {}
        reject(err);
      }

      function armFinalize() {
        if (finalizeTimer) clearTimeout(finalizeTimer);
        finalizeTimer = setTimeout(function () {
          var t = pendingText.trim();
          if (t) settleResolve(t);
          else settleReject(new Error('鍝嶅簲涓病鏈夊彲鏄剧ず鐨勫唴瀹广€?));
        }, 1200);
      }

      function fail(err) {
        settleReject(err);
      }

      function okDone() {
        var t = pendingText.trim();
        if (t) settleResolve(t);
        else settleReject(new Error('鍝嶅簲涓病鏈夊彲鏄剧ず鐨勫唴瀹广€?));
      }

      function sendConnectOnce() {
        if (connectSent) return;
        connectSent = true;
        seq += 1;
        var cid = 'connect-' + seq;
        var params = {
          minProtocol: 3,
          maxProtocol: 3,
          client: {
            /* 椤讳笌 Gateway 鐨?openclaw-control-ui 涓€鑷达細webchat id 浼氬湪鏃犺澶囪韩浠芥椂琚?clearUnboundScopes 娓呯┖ scopes锛屽鑷?chat.send 鎶?missing scope: operator.write */
            id: 'openclaw-control-ui',
            version: 'niuma',
            platform: typeof navigator !== 'undefined' ? navigator.platform || 'web' : 'web',
            mode: 'webchat',
            instanceId: instanceId
          },
          role: 'operator',
          scopes: ['operator.admin', 'operator.approvals', 'operator.pairing', 'operator.read', 'operator.write'],
          caps: [],
          userAgent: typeof navigator !== 'undefined' ? navigator.userAgent || '' : '',
          locale: typeof navigator !== 'undefined' ? navigator.language || 'zh-CN' : 'zh-CN',
          auth: { token: ep.token }
        };
        try {
          ws.send(JSON.stringify({ type: 'req', id: cid, method: 'connect', params: params }));
        } catch (e) {
          fail(new Error('鍙戦€佽璇佽姹傚け璐ワ細' + (e && e.message ? e.message : String(e))));
        }
      }

      function sendChatMsg() {
        seq += 1;
        chatMsgId = 'msg-' + seq;
        try {
          ws.send(
            JSON.stringify({
              type: 'req',
              id: chatMsgId,
              method: 'chat.send',
              params: {
                message: msgText,
                idempotencyKey: chatMsgId,
                sessionKey: sessionKey
              }
            })
          );
        } catch (e) {
          fail(new Error('鍙戦€佸璇濆け璐ワ細' + (e && e.message ? e.message : String(e))));
        }
      }

      function onFrame(msg) {
        var ev = msg.event || msg.type || msg.method || '';

        if (ev === 'connect.challenge') {
          challengeReceived = true;
          connectSent = false;
          sendConnectOnce();
          return;
        }

        if (typeof msg.id === 'string' && msg.id.indexOf('connect-') === 0) {
          if (msg.error || msg.ok === false) {
            var em = (msg.error && msg.error.message) || 'Gateway 璁よ瘉澶辫触';
            fail(new Error(String(em)));
            return;
          }
          if (msg.result !== undefined || msg.ok === true) {
            authenticated = true;
            sendChatMsg();
          }
          return;
        }

        if (!authenticated && ev === 'hello-ok') {
          authenticated = true;
          sendChatMsg();
          return;
        }

        if (!authenticated) return;

        /* chat.send 鍏堣繑鍥?type:res锛堜粎 started锛夛紝鍔╂墜姝ｆ枃鐢?broadcast("chat") 鎺ㄩ€?*/
        if (msg.type === 'res' && msg.id === chatMsgId) {
          if (msg.error || msg.ok === false) {
            var er0 = (msg.error && msg.error.message) || JSON.stringify(msg.error || {});
            fail(new Error(String(er0)));
            return;
          }
          return;
        }

        if (msg.id === chatMsgId && msg.error && msg.type !== 'res') {
          var er = (msg.error && msg.error.message) || JSON.stringify(msg.error);
          fail(new Error(String(er)));
          return;
        }

        var plChat = ocGetChatBroadcastPayload(msg);
        if (plChat) {
          var pl = plChat;
          if (pl.state === 'error') {
            fail(new Error(String(pl.errorMessage || 'OpenClaw 瀵硅瘽鍑洪敊')));
            return;
          }
          var chatTxt = ocExtractChatEventPayload(pl);
          if (chatTxt) {
            /* delta锛氬彲鑳芥槸澧為噺鐗囨锛堥渶鎷兼帴锛夋垨姣忓抚鍏ㄩ噺蹇収锛堥渶鏁存鏇挎崲锛?*/
            if (pl.state === 'delta') {
              if (pendingText && chatTxt.length >= pendingText.length && chatTxt.indexOf(pendingText) === 0)
                pendingText = chatTxt;
              else pendingText += chatTxt;
            } else pendingText = chatTxt;
          }
          if (ocIsChatFinalState(pl)) {
            if (!pendingText.trim()) {
              var fallback = ocExtractText(
                pl.errorMessage || pl.stopReason || pl.reason || pl.status || pl.message || ''
              );
              if (fallback) pendingText = fallback;
            }
            if (!pendingText.trim()) {
              try {
                var dbg = JSON.stringify(pl);
                if (dbg && dbg.length > 2 && dbg.length < 8000)
                  pendingText =
                    '锛圙ateway 杩斿洖浜?final 浣嗘湭瑙ｆ瀽鍑烘鏂囷紝璇峰崌绾ц剼鏈垨鏍稿 Gateway 鐗堟湰銆傚師濮?payload 鎽樿锛塡n' +
                    dbg.slice(0, 4000);
              } catch (e3) {}
            }
            okDone();
            return;
          }
          if (pl.state === 'delta' && chatTxt) armFinalize();
          /* 閮ㄥ垎 Gateway 鍙帹 text/content锛屾棤 state */
          if (pl.state == null && chatTxt) armFinalize();
          return;
        }

        var sidePl = ocGetChatSideResultPayload(msg);
        if (sidePl) {
          var side = sidePl;
          var st = ocExtractText(side.text || side.message || side.content || '');
          if (!st && side.btw && typeof side.btw.question === 'string') st = side.btw.question.trim();
          if (st) {
            pendingText = st;
            armFinalize();
          }
          return;
        }

        var respPayload = msg.payload || (msg.result !== undefined && typeof msg.result === 'object' ? msg.result : null);
        /* 涓?openclaw2锛氭祦寮忓抚甯稿甫 msg.result 鑰岄潪 ev===response锛屼笖鍙兘鏃?id */
        var isResp =
          ev === 'response' ||
          ev === 'chat.response' ||
          (msg.result !== undefined && typeof msg.result === 'object' && respPayload) ||
          (msg.id === chatMsgId && respPayload);

        if (isResp && respPayload) {
          var piece =
            ocExtractText(respPayload.text || respPayload.content || respPayload.message || '') ||
            ocExtractChatEventPayload(respPayload);
          if (piece) pendingText += piece;
          if (respPayload.done || respPayload.finish_reason || respPayload.finished) {
            okDone();
            return;
          }
          if (piece) armFinalize();
          return;
        }

        if (ev === 'error' || msg.error) {
          var emsg = ocExtractText((msg.payload && msg.payload.message) || (msg.error && msg.error.message) || msg.error);
          fail(new Error(emsg || '鏈嶅姟绔敊璇?));
          return;
        }

        var rest = msg.payload || msg.params || {};
        var rt =
          ocExtractText(rest.text || rest.content || rest.message || '') || ocExtractChatEventPayload(rest);
        if (rt && (msg.id === chatMsgId || msg.id == null || msg.id === '')) {
          pendingText += rt;
          armFinalize();
        }

        /* 鍏滃簳锛氫俊灏佹湭鏍?chat 浣?payload 宸叉槸娴佸紡缁撴瀯锛堜粎鍦ㄦ湰杩炴帴宸插彂 chat.send 鍚庯級 */
        if (chatMsgId) {
          var silentEv = { health: 1, tick: 1, ping: 1, pong: 1, heartbeat: 1, typing: 1 };
          if (!silentEv[ev]) {
            var guess = msg.payload || msg.params;
            if (
              guess &&
              typeof guess === 'object' &&
              (guess.state === 'delta' ||
                guess.state === 'final' ||
                guess.state === 'done' ||
                guess.state === 'completed' ||
                guess.state === 'error')
            ) {
              if (guess.state === 'error') {
                fail(new Error(String(guess.errorMessage || 'OpenClaw 瀵硅瘽鍑洪敊')));
                return;
              }
              var gt = ocExtractChatEventPayload(guess);
              if (gt) {
                if (guess.state === 'delta') {
                  if (pendingText && gt.length >= pendingText.length && gt.indexOf(pendingText) === 0) pendingText = gt;
                  else pendingText += gt;
                } else pendingText = gt;
                if (ocIsChatFinalState(guess)) okDone();
                else armFinalize();
                return;
              }
            }
          }
        }
      }

      ws.onmessage = function (e) {
        var msg;
        try {
          msg = JSON.parse(e.data);
        } catch (ex) {
          return;
        }
        try {
          onFrame(msg);
        } catch (ex2) {
          fail(new Error(ex2 && ex2.message ? ex2.message : String(ex2)));
        }
      };

      ws.onopen = function () {
        setTimeout(function () {
          if (!authenticated && !challengeReceived) sendConnectOnce();
        }, 450);
      };

      ws.onerror = function () {
        settleReject(new Error('WebSocket 閿欒锛堣纭 OpenClaw Gateway 宸插湪鏈満 ' + ep.host + ':' + ep.port + ' 杩愯锛夈€?));
      };

      ws.onclose = function (e) {
        if (settled) return;
        if (authenticated && pendingText.trim()) {
          settleResolve(pendingText.trim());
          return;
        }
        settleReject(new Error('杩炴帴宸插叧闂紙code ' + e.code + '锛夈€?));
      };
    });
  }

  async function sendChat() {
    var s = activeSession();
    if (!s || !s.id) return;
    var sid = s.id;
    if (isSessionSending(sid)) {
      cstatForSession(sid, '璇ユ爣绛句粛鍦ㄧ瓑寰呬笂涓€娆″搷搴旓紝璇风◢鍊欍€?, 'error');
      return;
    }
    var text = input.value.trim();
    if (!text) return;
    saveCfg(false);
    var cfg = buildSendCfg();
    if (!cfg) return;
    var p0 = P[cfg.provider] || P.openai;
    if (p0.transport === 'cli') {
      // CLI 鍘熺敓鐣岄潰锛氫笉渚濊禆 Base URL / Model 鏍￠獙锛岀偣鍑诲嵆鎵撳紑涓撳睘缁堢
      add('user', text);
      input.value = '';
      cstatForSession(sid, '姝ｅ湪鎵撳紑 CLI 涓撳睘浼氳瘽绐楀彛...');
      post({ type: 'niuma_cli_open', engine: cfg.provider });
      return;
    }
    if (!cfg.baseUrl || !cfg.model) {
      cstatForSession(sid, '璇峰厛鍦ㄨ缃噷濉啓 Base URL 鍜?Model銆?, 'error');
      setSettings(true);
      return;
    }
    if (p0.transport !== 'openclaw' && cfg.provider !== 'ollama' && !cfg.apiKey) {
      cstatForSession(sid, '璇峰厛鍦ㄨ缃噷濉啓 API Key銆丅ase URL 鍜?Model銆?, 'error');
      setSettings(true);
      return;
    }
    if (p0.transport === 'openclaw' && !openClawEndpointFromCfg(cfg).ok) {
      cstatForSession(sid, 'OpenClaw锛氳鍦ㄣ€孏ateway Token銆嶅～鍐?token锛屾垨灏嗗甫 #token= 鐨勫畬鏁存帶鍒跺彴鍦板潃濉叆 Base URL銆?, 'error');
      setSettings(true);
      return;
    }
    add('user', text);
    input.value = '';
    setSessionSending(sid, true);
    cstatForSession(sid, '姝ｅ湪璇锋眰妯″瀷鍝嶅簲...');
    try {
      var p = P[cfg.provider] || P.openai,
        content = '';
      if (p.transport === 'anthropic') content = await reqClaude(cfg);
      else if (p.transport === 'gemini') content = await reqGemini(cfg);
      else if (p.transport === 'openclaw') content = await reqOpenClaw(cfg);
      else content = await reqOpenAI(cfg);
      add('assistant', content);
      cstatForSession(sid, '鍝嶅簲瀹屾垚銆?, 'success');
    } catch (err) {
      cstatForSession(sid, '璇锋眰澶辫触锛? + (err && err.message ? err.message : '鏈煡閿欒'), 'error');
    } finally {
      setSessionSending(sid, false);
    }
  }

  var suppressClickUntil = 0;
  var screenshotLastClick = 0;
  function shouldSuppressClick() {
    return Date.now() < suppressClickUntil;
  }

  document.getElementById('app').addEventListener('click', function (e) {
    if (shouldSuppressClick()) {
      e.preventDefault();
      e.stopPropagation();
      return;
    }
    var b = e.target.closest('.tb');
    if (!b) return;
    e.stopPropagation();
    var cid = b.dataset.cmdId;
    if (cid) {
      cid = String(cid);
      if (cid === 'ch_t') {
        if (Date.now() - screenshotLastClick < 2000) return;
        screenshotLastClick = Date.now();
      }
      sel(cid);
      post({ type: 'toolbar_cmd', cmdId: cid });
      return;
    }
    var a = b.dataset.action;
    if (!a) return;
    a = String(a);
    if (a === 'Screenshot') {
      if (Date.now() - screenshotLastClick < 2000) return;
      screenshotLastClick = Date.now();
    }
    sel(a);
    post({ type: 'toolbar_toggle_action', action: a });
  });

  document.querySelectorAll('[data-logo-toggle]').forEach(function (el) {
    el.addEventListener('click', function (e) {
      if (shouldSuppressClick()) {
        e.preventDefault();
        e.stopPropagation();
        return;
      }
      e.stopPropagation();
      if (state.compact) {
        post({ type: 'exit_compact' });
        return;
      }
      setDrawer(!state.drawer);
    });
  });

  dclose.addEventListener('click', function () {
    setDrawer(false);
  });

  chatSet.addEventListener('click', function () {
    provider.dataset.prevProv = provider.value;
    setSettings(true);
  });

  if (chatSearch) {
    chatSearch.addEventListener('click', function () {
      runChatSearchPrompt();
    });
  }

  if (chatExportMd) chatExportMd.addEventListener('click', exportMarkdown);
  if (chatExportJson) chatExportJson.addEventListener('click', exportJson);

  if (promptTplApply) promptTplApply.addEventListener('click', applySelectedPromptBuiltin);
  if (promptImportBtn && promptImportFile) {
    promptImportBtn.addEventListener('click', function () {
      promptImportFile.click();
    });
  }
  if (promptImportFile) {
    promptImportFile.addEventListener('change', function () {
      var f = this.files && this.files[0];
      if (!f) return;
      var rd = new FileReader();
      rd.onload = function () {
        systemPrompt.value = String(rd.result || '');
        saveCfg(false);
        sstat('宸蹭粠鏂囦欢瀵煎叆锛? + f.name, 'success');
      };
      rd.onerror = function () {
        sstat('璇诲彇鏂囦欢澶辫触銆?, 'error');
      };
      rd.readAsText(f);
      this.value = '';
    });
  }

  if (newSessionPickBg) newSessionPickBg.addEventListener('click', closeNewSessionPick);
  if (newSessionPickClose) newSessionPickClose.addEventListener('click', closeNewSessionPick);
  if (newSessionPick) {
    newSessionPick.addEventListener('click', function (e) {
      var item = e.target.closest('.ns-item');
      if (item && item.dataset.pickProvider) createSessionWithProvider(item.dataset.pickProvider);
    });
  }

  if (sessionTabsEl) {
    sessionTabsEl.addEventListener('click', function (e) {
      var xbtn = e.target.closest('[data-close-session]');
      if (xbtn) {
        e.stopPropagation();
        removeSession(xbtn.getAttribute('data-close-session'));
        return;
      }
      if (e.target.id === 'sessionTabAdd' || e.target.closest('#sessionTabAdd')) {
        openNewSessionPick();
        return;
      }
      var stab = e.target.closest('.stab');
      if (stab && stab.dataset.sessionId) switchSession(stab.dataset.sessionId);
    });
  }

  backdrop.addEventListener('click', function (e) {
    if (e.target === backdrop) setDrawer(false);
  });

  stage.addEventListener('click', function (e) {
    if (e.target === stage) setDrawer(false);
  });

  sbg.addEventListener('click', function () {
    setSettings(false);
  });

  sclose.addEventListener('click', function () {
    setSettings(false);
  });

  ssave.addEventListener('click', function () {
    saveCfg(true);
    setSettings(false);
  });

  send.addEventListener('click', sendChat);

  input.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' && e.ctrlKey) {
      e.preventDefault();
      sendChat();
    }
  });

  var cliOpenBtn = $('cliOpenBtn');
  var cliRestartBtn = $('cliRestartBtn');
  var cliReloadBtn = $('cliReloadBtn');
  var cliPopBtn = $('cliPopBtn');
  if (cliOpenBtn) {
    cliOpenBtn.addEventListener('click', function () {
      var s = activeSession();
      if (!s || !isCliSession(s)) return;
      // 纭繚瀹夸富鍚姩 ttyd锛屽苟鎶?iframe 鎸囧悜鐩爣
      try {
        post({ type: 'niuma_cli_open', engine: s.provider });
      } catch (e) {}
      var url = cliUrlForSession(s);
      reloadCliFrameWithRetry(url);
    });
  }
  if (cliReloadBtn) {
    cliReloadBtn.addEventListener('click', function () {
      var fr = $('cliFrame');
      if (!fr) return;
      try {
        fr.src = fr.dataset.src || fr.src || 'about:blank';
      } catch (e) {}
    });
  }
  if (cliRestartBtn) {
    cliRestartBtn.addEventListener('click', function () {
      var s = activeSession();
      if (!s || !isCliSession(s)) return;
      try {
        post({ type: 'niuma_cli_restart', engine: s.provider });
      } catch (e) {}
      var url = cliUrlForSession(s);
      reloadCliFrameWithRetry(url);
    });
  }
  if (cliPopBtn) {
    cliPopBtn.addEventListener('click', function () {
      var s = activeSession();
      if (!s || !isCliSession(s)) return;
      var url = cliUrlForSession(s);
      if (!url) return;
      try {
        window.open(url, '_blank');
      } catch (e) {
        try {
          post({ type: 'niuma_cli_open', engine: s.provider });
        } catch (e2) {}
      }
    });
  }

  provider.addEventListener('focus', function () {
    this.dataset.prevProv = this.value;
  });

  provider.addEventListener('change', function () {
    var prev = normalizeProviderId(this.dataset.prevProv);
    if (prev && P[prev]) {
      if (!state.apiKeys) state.apiKeys = {};
      state.apiKeys[prev] = apiKey.value.trim();
    }
    var nextPid = normalizeProviderId(provider.value);
    applyProvider(nextPid, false);
    apiKey.value = (state.apiKeys && state.apiKeys[nextPid]) || '';
    refreshApiKeyField(nextPid);
    this.dataset.prevProv = nextPid;
    syncSessionFromForm(activeSession());
    persistSessions();
    renderSessionTabs();
    saveCfg(false);
    closeProviderDd();
    ensureDynamicModelsForActiveProvider();
  });

  modelPreset.addEventListener('change', function () {
    if (modelPreset.value) {
      model.value = modelPreset.value;
    }
    syncModelDdUi();
    syncSessionFromForm(activeSession());
    persistSessions();
    renderSessionTabs();
    saveCfg(false);
  });

  if (providerDdBtn) {
    providerDdBtn.addEventListener('click', function (e) {
      e.stopPropagation();
      toggleProviderDd();
    });
  }
  if (modelDdBtn) {
    modelDdBtn.addEventListener('click', function (e) {
      e.stopPropagation();
      toggleModelDd();
    });
  }
  document.addEventListener('click', function (e) {
    if (e.target.closest && (e.target.closest('#providerDd') || e.target.closest('#modelDd'))) return;
    closeProviderDd();
    closeModelDd();
  });

  function handleGlobalEscape(e) {
    var k = e.key || '';
    if (k !== 'Escape' && k !== 'Esc' && String(k).toLowerCase() !== 'escape') return;
    if (state.nspick) {
      e.preventDefault();
      e.stopPropagation();
      closeNewSessionPick();
      return;
    }
    if (state.settings) {
      e.preventDefault();
      e.stopPropagation();
      closeProviderDd();
      closeModelDd();
      setSettings(false);
      return;
    }
    if (state.drawer) {
      e.preventDefault();
      e.stopPropagation();
      setDrawer(false);
    }
  }
  // 鎹曡幏闃舵锛氱劍鐐瑰湪瀵硅瘽杈撳叆妗嗙瓑澶勬椂锛屽啋娉￠樁娈靛彲鑳芥敹涓嶅埌 Esc锛屼粛鑳藉叧闂?NiuMa Chat 鎶藉眽
  function handleGlobalNiumaHotkeys(e) {
    if (!state.drawer) return;
    if (!e.ctrlKey || e.altKey || e.metaKey) return;
    var key = String(e.key || '').toLowerCase();
    var code = String(e.code || '');

    if (key === 'n') {
      e.preventDefault();
      e.stopPropagation();
      if (!state.nspick) openNewSessionPick();
      return;
    }

    // Ctrl+W 鍏抽棴褰撳墠鏍囩锛堣嚦灏戜繚鐣欎竴涓級
    if (key === 'w') {
      var sid = state.activeSessionId || '';
      if (sid) {
        e.preventDefault();
        e.stopPropagation();
        removeSession(sid);
      }
      return;
    }

    // Ctrl+Delete 娓呯┖杈撳叆妗?    if (key === 'delete' || code === 'Delete') {
      e.preventDefault();
      e.stopPropagation();
      if (input) {
        input.value = '';
        try {
          input.dispatchEvent(new Event('input', { bubbles: true }));
        } catch (_) {}
      }
      return;
    }

    // Ctrl+1..8 鍒囨崲鏍囩锛氫紭鍏?code锛圖igit1..Digit8 / Numpad1..Numpad8锛?    var idx = -1;
    if (/^Digit[1-8]$/.test(code) || /^Numpad[1-8]$/.test(code)) {
      idx = parseInt(code.replace(/^\D+/, ''), 10) - 1;
    } else if (/^[1-8]$/.test(key)) {
      idx = parseInt(key, 10) - 1;
    }
    if (idx >= 0) {
      var tabs = Array.prototype.slice.call(document.querySelectorAll('#sessionTabs .stab[data-session-id]'));
      var target = tabs[idx];
      if (target && target.dataset && target.dataset.sessionId) {
        e.preventDefault();
        e.stopPropagation();
        switchSession(target.dataset.sessionId);
      }
      return;
    }
  }
  document.addEventListener('keydown', handleGlobalEscape, true);

  [apiKey, baseUrl, model, systemPrompt].forEach(function (el) {
    el.addEventListener('input', function () {
      saveCfg(false);
    });
  });

  resetCfg.addEventListener('click', reset);

  var dragT = 0;

  function dragHost() {
    var t = Date.now();
    if (t - dragT < 40) return;
    dragT = t;
    post({ type: 'drag_host' });
  }

  var longPressTimer = 0;
  var longPressTriggered = false;
  var longPressPointerId = null;
  var LONG_PRESS_MS = 260;

  function clearLongPressTimer() {
    if (longPressTimer) {
      clearTimeout(longPressTimer);
      longPressTimer = 0;
    }
  }

  function endLongPress() {
    clearLongPressTimer();
    if (longPressTriggered) {
      suppressClickUntil = Date.now() + 420;
    }
    longPressTriggered = false;
    longPressPointerId = null;
  }

  document.getElementById('app').addEventListener(
    'pointerdown',
    function (e) {
      if (e.button !== 0) return;
      if (e.target.closest('#resizeGrip')) return;
      longPressTriggered = false;
      longPressPointerId = e.pointerId;
      clearLongPressTimer();
      longPressTimer = setTimeout(function () {
        longPressTriggered = true;
        dragHost();
      }, LONG_PRESS_MS);
    },
    true
  );

  document.getElementById('app').addEventListener(
    'pointerup',
    function (e) {
      if (longPressPointerId !== null && e.pointerId === longPressPointerId) endLongPress();
    },
    true
  );

  document.getElementById('app').addEventListener(
    'pointercancel',
    function (e) {
      if (longPressPointerId !== null && e.pointerId === longPressPointerId) endLongPress();
    },
    true
  );

  collapsedRoot.addEventListener(
    'wheel',
    function (e) {
      e.preventDefault();
      post({ type: 'wheel', delta: e.deltaY > 0 ? -1 : 1 });
    },
    { passive: false }
  );

  function openHostContextMenuFromEvent(e) {
    if (!e) return;
    var tb = e.target && e.target.closest ? e.target.closest('.tb[data-cmd-id]') : null;
    if (tb) {
      var cid = String(tb.getAttribute('data-cmd-id') || '').trim();
      if (cid === 'ftb_cursor_menu') {
        e.preventDefault();
        e.stopPropagation();
        post({ type: 'toolbar_cmd_context', cmdId: cid, x: e.screenX, y: e.screenY });
        return;
      }
    }
    e.preventDefault();
    e.stopPropagation();
    post({ type: 'context_menu', x: e.screenX, y: e.screenY });
  }

  /* 鍙抽敭鑿滃崟鍦ㄦ姌鍙犳€?鎶藉眽鎬侀兘鍙Е鍙戯紙涔嬪墠鍙粦瀹?collapsedRoot锛屾墦寮€ niuma chat 鍚庝細澶辨晥锛?*/
  var appRoot = $('app');
  if (appRoot) {
    appRoot.addEventListener('contextmenu', openHostContextMenuFromEvent, true);
    appRoot.addEventListener(
      'pointerup',
      function (e) {
        if (e && e.button === 2) {
          post({ type: 'context_menu', x: e.screenX || 0, y: e.screenY || 0 });
        }
      },
      true
    );
  }

  var hdr = document.querySelector('.hdr');

  async function readDrop(dt) {
    if (!dt) return '';
    try {
      if (dt.items && dt.items.length) {
        for (var i = 0; i < dt.items.length; i++) {
          var it = dt.items[i];
          if (it.kind !== 'string') continue;
          var s = await new Promise(function (res) {
            try {
              it.getAsString(function (x) {
                res(x || '');
              });
            } catch (e2) {
              res('');
            }
          });
          if (s && String(s).trim()) return String(s).trim();
        }
      }
      return (dt.getData('text/plain') || dt.getData('Text') || dt.getData('text/uri-list') || '').trim();
    } catch (e) {
      return '';
    }
  }

  function findDropActionTarget(e) {
    var n = e && e.target ? e.target.closest('.tb') : null;
    if (n && n.getAttribute) {
      var b = n.getAttribute('data-drop-bucket');
      if (b) return b;
      return n.getAttribute('data-action') || 'Search';
    }
    return 'Search';
  }

  async function onDrop(e) {
    e.preventDefault();
    e.stopPropagation();
    var action = findDropActionTarget(e);
    tbEls().forEach(function (el) { el.classList.remove('drag-over'); });
    var t = await readDrop(e.dataTransfer);
    if (!t && e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files.length) t = (e.dataTransfer.files[0].name || '').trim();
    if (!t) return;
    loading(true);
    post({ type: 'drop_action', action: action, text: t });
  }

  function onDragOver(e) {
    e.preventDefault();
    e.stopPropagation();
    try {
      if (e.dataTransfer) e.dataTransfer.dropEffect = 'copy';
    } catch (e2) {}
    var action = findDropActionTarget(e);
    tbEls().forEach(function (el) {
      var da = el.getAttribute('data-drop-bucket') || el.getAttribute('data-action') || '';
      el.classList.toggle('drag-over', da === action);
    });
    if (String(action || '').toLowerCase() === 'search') dragOver(true);
  }

  function onDragLeave(e) {
    var rt = e.relatedTarget,
      ok = false;
    if (rt)
      searchEls().forEach(function (s) {
        if (s.contains(rt)) ok = true;
      });
    if (!ok) {
      dragOver(false);
      tbEls().forEach(function (el) { el.classList.remove('drag-over'); });
    }
  }

  function bindSearchDnD() {
    tbEls().forEach(function (search) {
      search.addEventListener('dragenter', function (e) {
        e.preventDefault();
      });
      search.addEventListener('dragover', onDragOver);
      search.addEventListener('dragleave', onDragLeave);
      search.addEventListener('drop', onDrop);
    });
  }

  rebuildToolbarButtons(state.toolbarActions);
  queueCollapsedLayout(0);
  /* 鍏滃簳锛氫粎褰?set_logo 闀挎椂闂存湭鍥炶皟鏃舵樉绀猴紝閬垮厤姘歌繙绌虹櫧 */
  scheduleToolbarReveal(1200);

  document.body.addEventListener('dragover', function (e) {
    e.preventDefault();
  });

  document.body.addEventListener('drop', function (e) {
    e.preventDefault();
    var onS = false;
    tbEls().forEach(function (s) {
      if (e.target === s || s.contains(e.target)) onS = true;
    });
    if (onS) return;
    onDrop(e);
  });

  if (window.chrome && window.chrome.webview) {
    window.chrome.webview.addEventListener('message', function (ev) {
      var d = ev.data;
      if (typeof d === 'string') {
        try {
          d = JSON.parse(d);
        } catch (_) {}
      }
      if (d && d.type) dbg('R', d.type, 'ok');
      if (!d || !d.type) return;
      if (d.type === 'ftb_debug') {
        dbg('H', d.msg || '', d.level === 'err' ? 'err' : 'ok');
        return;
      }
      if (d.type === 'SELECTION_CHANGE') {
        pulse(true);
        return;
      }
      if (d.type === 'SELECTION_CLEAR') {
        pulse(false);
        return;
      }
      if (d.type === 'drop_done') {
        loading(false);
        pulse(false);
        return;
      }
      if (d.type === 'set_scale') {
        scale(d.scale || 1);
        setCompact(!!d.compact);
        return;
      }
      if (d.type === 'set_toolbar_config') {
        rebuildToolbarButtons(d.actions || DEFAULT_TOOLBAR_ACTIONS);
        return;
      }
      if (d.type === 'set_toolbar_cmds') {
        rebuildToolbarCmdButtons(d.items || []);
        return;
      }
      if (d.type === 'set_logo') {
        var u = d.url || '';
        var imgs = Array.prototype.slice.call(document.querySelectorAll('.logo-btn .logo-img'));
        function paintThenReveal() {
          requestAnimationFrame(function () {
            requestAnimationFrame(revealToolbarSync);
            queueCollapsedLayout(0);
          });
        }
        if (!u || !imgs.length) {
          paintThenReveal();
          return;
        }
        var remain = imgs.length;
        imgs.forEach(function (im) {
          var done = false;
          function once() {
            if (done) return;
            done = true;
            remain--;
            if (remain <= 0) paintThenReveal();
          }
          im.onload = im.onerror = once;
          im.src = u;
          if (im.decode) {
            im.decode().then(once).catch(once);
          } else if (im.complete) {
            once();
          }
        });
        return;
      }
      if (d.type === 'set_selected') sel(d.action || '');
      if (d.type === 'niuma_compose_send') {
        var inText = String(d.text || '');
        if (!inText.trim()) return;
        var appendMode = d.append !== false;
        var shouldOpenDrawer = d.openDrawer !== false;
        var shouldSendNow = d.send !== false;
        if (shouldOpenDrawer) setDrawer(true);
        var base = String(input.value || '');
        if (appendMode && base.trim()) input.value = base.replace(/\s+$/, '') + '\n\n' + inText;
        else input.value = inText;
        try {
          input.dispatchEvent(new Event('input', { bubbles: true }));
        } catch (_) {}
        requestAnimationFrame(function () {
          try {
            input.focus();
            var end = input.value.length;
            input.setSelectionRange(end, end);
          } catch (_) {}
          if (shouldSendNow) sendChat();
        });
        return;
      }
    });
  }

  var rz = false,
    rzX = 0,
    rzW = 0;
  if (resizeGrip) {
    resizeGrip.addEventListener('pointerdown', function (e) {
      if (e.button !== 0) return;
      rz = true;
      rzX = e.clientX;
      rzW = document.documentElement.clientWidth;
      try {
        resizeGrip.setPointerCapture(e.pointerId);
      } catch (x) {}
    });
    resizeGrip.addEventListener('pointermove', function (e) {
      if (!rz) return;
      var nw = Math.max(380, Math.min(1200, rzW + (rzX - e.clientX)));
      post({ type: 'drawer_resize', width: nw });
    });
    resizeGrip.addEventListener('pointerup', function (e) {
      if (rz) {
        rz = false;
        post({ type: 'drawer_resize_done' });
        try {
          resizeGrip.releasePointerCapture(e.pointerId);
        } catch (x) {}
      }
    });
    resizeGrip.addEventListener('pointercancel', function () {
      if (rz) {
        rz = false;
        post({ type: 'drawer_resize_done' });
      }
    });
  }

  window.addEventListener('resize', function () {
    queueCollapsedLayout(60);
  });

  fillProviders();
  fillPromptBuiltinSelect();
  loadCfg();
  scale(1);
  setCompact(false);
  post({ type: 'toolbar_ready' });
  setTimeout(function () {
    postCollapsedLayout(true);
  }, 30);
  requestAnimationFrame(function () {
    requestAnimationFrame(function () {
      setTimeout(function () {
        post({ type: 'UI_FINISHED' });
      }, 16);
    });
  });
})();

