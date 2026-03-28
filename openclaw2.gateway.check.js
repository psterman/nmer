const OpenClawGateway=(function(){
  const LS_PORT='openclaw2_gateway_port';
  const LS_HOST='openclaw2_gateway_host';
  /** 鍙屽紑 OpenClaw 鏃讹細qclaw 甯哥敤 18790锛岄粯璁ゅ疄渚嬪父鐢?18789 */
  const LS_PROFILE='openclaw2_gateway_profile';
  const LS_RECENT_PORTS='openclaw2_gateway_recent_ports';
  const QCLAW_PORT=18790;
  const DEFAULT_PORT=18789;
  const DEFAULT_HOST='127.0.0.1';
  const EXTRA_PORTS=[18790,18889,3000,8080,5173,5174];
  let cachedPort=null;
  let cachedHost=null;
  const PROFILE_CANDIDATES=[
    {id:'default',label:'openclaw',ports:[DEFAULT_PORT],priority:100},
    {id:'qclaw',label:'qclaw',ports:[QCLAW_PORT],priority:95},
    {id:'alt-18889',label:'alt',ports:[18889],priority:60},
    {id:'dev-3000',label:'dev',ports:[3000],priority:25},
    {id:'dev-8080',label:'dev',ports:[8080],priority:20},
    {id:'dev-5173',label:'vite',ports:[5173],priority:18},
    {id:'dev-5174',label:'vite',ports:[5174],priority:17}
  ];
  function normalizeHost(v){
    const s=String(v||'').trim().replace(/^\[|\]$/g,'');
    return s||DEFAULT_HOST;
  }
  function loadRecentPorts(){
    try{
      const raw=localStorage.getItem(LS_RECENT_PORTS)||'';
      return raw.split(',').map(x=>parseInt(String(x).trim(),10)).filter(x=>Number.isFinite(x)&&x>0&&x<65536);
    }catch(_){return [];}
  }
  function saveRecentPort(port){
    const n=parseInt(String(port),10);
    if(!Number.isFinite(n)||n<=0||n>=65536)return;
    try{
      const arr=loadRecentPorts().filter(x=>x!==n);
      arr.unshift(n);
      localStorage.setItem(LS_RECENT_PORTS,arr.slice(0,8).join(','));
    }catch(_){}
  }
  function getProfileForPort(port){
    const n=parseInt(String(port),10);
    return PROFILE_CANDIDATES.find(item=>Array.isArray(item.ports)&&item.ports.includes(n))||null;
  }
  function describePort(port){
    const profile=getProfileForPort(port);
    return profile&&profile.label?profile.label:'custom';
  }
  function parsePortFromLocation(){
    try{
      const q=new URLSearchParams(window.location.search||'');
      const raw=q.get('gwPort')||q.get('gatewayPort')||q.get('openclaw_port')||q.get('openclawPort')||'';
      if(raw){
        const n=parseInt(String(raw).replace(/^:/,''),10);
        if(Number.isFinite(n)&&n>0&&n<65536)return n;
      }
      const gw=q.get('gateway')||q.get('gw')||'';
      if(gw){
        const s=String(gw).trim();
        if(/^\d+$/.test(s))return parseInt(s,10);
        try{
          const u=s.includes('://')?new URL(s):new URL('http://'+s);
          if(u.port){const p=parseInt(u.port,10);if(Number.isFinite(p)&&p>0)return p;}
        }catch(_){}
      }
      const h=window.location.hash||'';
      const m=h.match(/(?:^#|[?&])gw(?:Port)?=(\d{2,5})/);
      if(m)return parseInt(m[1],10);
      const prof=(q.get('profile')||q.get('gatewayProfile')||'').toLowerCase().replace(/^["']|["']$/g,'');
      const qcl=q.get('qclaw');
      const wantQclaw=prof==='qclaw'||qcl==='1'||qcl==='true'||String(qcl||'').toLowerCase()==='qclaw';
      if(wantQclaw){
        try{localStorage.setItem(LS_PROFILE,'qclaw');localStorage.setItem(LS_PORT,String(QCLAW_PORT));}catch(_){}
        return QCLAW_PORT;
      }
      if(prof==='default'||prof==='openclaw'){
        try{localStorage.removeItem(LS_PROFILE);}catch(_){}
      }
    }catch(_){}
    return null;
  }
  function loadInitialPort(){
    const fromUrl=parsePortFromLocation();
    if(fromUrl!=null){
      try{localStorage.setItem(LS_PORT,String(fromUrl));}catch(_){}
      return fromUrl;
    }
    try{
      if((localStorage.getItem(LS_PROFILE)||'').toLowerCase()==='qclaw'){
        const n=QCLAW_PORT;
        try{localStorage.setItem(LS_PORT,String(n));}catch(_){}
        return n;
      }
    }catch(_){}
    try{
      const s=localStorage.getItem(LS_PORT);
      if(s!=null){
        const n=parseInt(s,10);
        if(Number.isFinite(n)&&n>0&&n<65536)return n;
      }
    }catch(_){}
    return DEFAULT_PORT;
  }
  function getHost(){
    if(cachedHost)return cachedHost;
    try{
      const q=new URLSearchParams(window.location.search||'');
      const gw=q.get('gateway')||q.get('gw')||'';
      if(gw){
        try{
          const u=gw.includes('://')?new URL(gw):new URL('http://'+gw);
          if(u.hostname){
            cachedHost=normalizeHost(u.hostname);
            localStorage.setItem(LS_HOST,cachedHost);
            return cachedHost;
          }
        }catch(_){
          const m=String(gw).trim().match(/^([^:\/?#]+):\d{2,5}$/);
          if(m&&m[1]){
            cachedHost=normalizeHost(m[1]);
            localStorage.setItem(LS_HOST,cachedHost);
            return cachedHost;
          }
        }
      }
      cachedHost=normalizeHost(localStorage.getItem(LS_HOST)||DEFAULT_HOST);
      return cachedHost;
    }catch(_){return DEFAULT_HOST;}
  }
  function setHost(host){
    cachedHost=normalizeHost(host);
    try{localStorage.setItem(LS_HOST,cachedHost);}catch(_){}
    refreshSubtitle();
  }
  function getPort(){
    if(cachedPort==null)cachedPort=loadInitialPort();
    return cachedPort;
  }
  function setPort(p){
    const n=parseInt(String(p),10);
    if(!Number.isFinite(n)||n<=0||n>=65536)return;
    cachedPort=n;
    try{localStorage.setItem(LS_PORT,String(n));}catch(_){}
    try{
      if(n===QCLAW_PORT)localStorage.setItem(LS_PROFILE,'qclaw');
      else if((localStorage.getItem(LS_PROFILE)||'')==='qclaw'&&n!==QCLAW_PORT)localStorage.removeItem(LS_PROFILE);
    }catch(_){}
    saveRecentPort(n);
    refreshSubtitle();
  }
  /** 鎺у埗鍙帮細OpenClawGateway.setGatewayProfile('qclaw') 鍥哄畾 qclaw:18790锛?default' 娓呴櫎閰嶇疆妗?*/
  function setGatewayProfile(name){
    const p=String(name||'').toLowerCase();
    if(p==='qclaw'){
      cachedPort=QCLAW_PORT;
      try{localStorage.setItem(LS_PORT,String(QCLAW_PORT));localStorage.setItem(LS_PROFILE,'qclaw');}catch(_){}
    }else{
      try{localStorage.removeItem(LS_PROFILE);}catch(_){}
      if(p==='default'||p==='openclaw'){
        cachedPort=DEFAULT_PORT;
        try{localStorage.setItem(LS_PORT,String(DEFAULT_PORT));}catch(_){}
      }
    }
    refreshSubtitle();
  }
  function getDisplay(){return getHost()+':'+getPort();}
  /** 浠?localhost 鎵撳紑寮€鍙戞湇椤甸潰鏃讹紝fetch 鐩磋繛 127.0.0.1:缃戝叧绔彛浼氳Е鍙?CORS锛涙敼涓鸿蛋 Vite 鍚屾簮浠ｇ悊 /__openclaw/{port}/ */
  function useDevHttpProxy(){
    try{
      const h=window.location.hostname;
      if(h!=='localhost'&&h!=='127.0.0.1')return false;
      const p=String(window.location.port||'');
      if(p==='3000'||p==='5173'||p==='5174'||p==='')return true;
      return false;
    }catch(_){return false;}
  }
  function httpBase(){
    if(useDevHttpProxy()){
      try{
        return window.location.origin.replace(/\/$/,'')+'/__openclaw/'+getPort();
      }catch(_){}
    }
    return 'http://'+getDisplay();
  }
  function wsBase(){return 'ws://'+getDisplay();}
  function refreshSubtitle(){
    const el=document.getElementById('api-panel-subtitle');
    if(el)el.textContent=wsBase();
    try{
      const ep=document.getElementById('live-gateway-endpoint');
      if(ep)ep.textContent=getDisplay();
    }catch(_){}
  }
  async function probePort(port){
    const base=useDevHttpProxy()
      ? window.location.origin.replace(/\/$/,'')+'/__openclaw/'+port
      : 'http://'+getHost()+':'+port;
    const tryCors=async(path,opts={})=>{
      try{
        const ac=new AbortController();
        const tid=setTimeout(()=>ac.abort(),700);
        const r=await fetch(base+path,Object.assign({method:'GET',mode:'cors',signal:ac.signal},opts));
        clearTimeout(tid);
        if(r.ok)return 2;
        /* 浠?401/403 瑙嗕负銆屾湁鏈嶅姟涓斿彲鑳介渶閴存潈銆嶏紱404/405 鍦ㄤ换鎰忓崰浣嶆湇鍔′笂澶父瑙侊紝浼氳鍒や负缃戝叧鍦ㄧ嚎鑰岄攣姝婚敊璇鍙?*/
        if(r.status===401||r.status===403)return 1;
      }catch(_){}
      return 0;
    };
    let s=await tryCors('/api/channels/status');
    if(s>0)return true;
    s=await tryCors('/api/channels');
    if(s>0)return true;
    try{
      const ac=new AbortController();
      const tid=setTimeout(()=>ac.abort(),700);
      const r=await fetch(base+'/api/dialogue-token',{method:'POST',headers:{'Content-Type':'application/json'},mode:'cors',signal:ac.signal,body:JSON.stringify({source:'probe'})});
      clearTimeout(tid);
      if(r.ok)return true;
    }catch(_){}
    /* 宸茬Щ闄?no-cors GET /锛氫换鎰?HTTP 鏈嶅姟閮戒細銆屾垚鍔熴€嶏紝瀵艰嚧璇€夌鍙ｏ紙渚嬪绌虹鍙ｆ垨闈欐€佺珯锛?*/
    return false;
  }
  async function probeGatewayInstance(port){
    const n=parseInt(String(port),10);
    const host=getHost();
    const base=useDevHttpProxy()
      ? window.location.origin.replace(/\/$/,'')+'/__openclaw/'+n
      : 'http://'+host+':'+n;
    const startedAt=(typeof performance!=='undefined'&&performance.now)?performance.now():Date.now();
    const candidate=makeInstanceRecord({
      host,
      port:n,
      profileId:(getProfileForPort(n)||{}).id||'custom',
      profileLabel:describePort(n),
      current:n===getPort()
    });
    const inspect=async(path,opts={})=>{
      try{
        const ac=new AbortController();
        const tid=setTimeout(()=>ac.abort(),900);
        const r=await fetch(base+path,Object.assign({method:'GET',mode:'cors',signal:ac.signal},opts));
        clearTimeout(tid);
        const text=await r.text().catch(()=>'');
        let body=null;
        try{body=text?JSON.parse(text):null;}catch(_){}
        const elapsed=((typeof performance!=='undefined'&&performance.now)?performance.now():Date.now())-startedAt;
        return {status:r.status,text,body,path,latencyMs:Math.round(elapsed)};
      }catch(_){return null;}
    };
    const looksLikeGateway=hit=>{
      if(!hit)return false;
      if(hit.status===401||hit.status===403)return true;
      if(hit.status<200||hit.status>=300)return false;
      const body=hit.body;
      if(body&&typeof body==='object'){
        const keys=Object.keys(body);
        if(keys.some(k=>/channel|session|task|usage|gateway|openclaw/i.test(k)))return true;
        const nested=[body.result,body.payload,body.data].filter(v=>v&&typeof v==='object');
        if(nested.some(v=>Object.keys(v).some(k=>/channel|session|task|usage|gateway|openclaw/i.test(k))))return true;
      }
      return /openclaw|gateway|channel|session|task/i.test((hit.text||'').slice(0,200));
    };
    const hits=[
      await inspect('/api/channels/status'),
      await inspect('/api/channels'),
      await inspect('/api/tasks'),
      await inspect('/api/usage-cost'),
      await inspect('/api/dialogue-token',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({source:'probe'})})
    ].filter(Boolean);
    const hit=hits.find(looksLikeGateway)||hits.find(item=>item.status===401||item.status===403)||null;
    if(!hit)return makeInstanceRecord(candidate,{endpoint:host+':'+n,summary:'offline'});
    return makeInstanceRecord(candidate,{
      ok:looksLikeGateway(hit),
      online:true,
      requiresAuth:hit.status===401||hit.status===403,
      latencyMs:hit.latencyMs,
      endpoint:host+':'+n,
      summary:hit.status===401||hit.status===403?'auth required':'online'
    });
  }
  function buildProbePortList(){
    const preferred=getPort();
    const list=[];
    const add=(p)=>{const n=typeof p==='number'?p:parseInt(p,10);if(Number.isFinite(n)&&n>0&&n<65536&&!list.includes(n))list.push(n);};
    try{
      if((localStorage.getItem(LS_PROFILE)||'').toLowerCase()==='qclaw')add(QCLAW_PORT);
    }catch(_){}
    add(preferred);
    EXTRA_PORTS.forEach(add);
    loadRecentPorts().forEach(add);
    add(DEFAULT_PORT);
    try{
      const q=new URLSearchParams(window.location.search||'');
      const probeExtra=q.get('gwProbePorts')||q.get('openclaw_probe_ports')||'';
      probeExtra.split(/[,;\s]+/).forEach(function(s){const n=parseInt(String(s).trim(),10);add(n);});
    }catch(_){}
    return list;
  }
  function buildProbeCandidates(){
    const currentPort=getPort();
    const recentPorts=loadRecentPorts();
    const list=[];
    const seen=new Set();
    const add=(port,meta={})=>{
      const n=typeof port==='number'?port:parseInt(port,10);
      if(!Number.isFinite(n)||n<=0||n>=65536||seen.has(n))return;
      seen.add(n);
      const profile=getProfileForPort(n);
      list.push({
        host:getHost(),
        port:n,
        profileId:profile&&profile.id?profile.id:(meta.profileId||'custom'),
        profileLabel:profile&&profile.label?profile.label:(meta.profileLabel||describePort(n)),
        priority:(meta.priority||0)+(n===currentPort?40:0)+(recentPorts.includes(n)?12:0),
        source:meta.source||'probe'
      });
    };
    add(currentPort,{source:'current',priority:120});
    PROFILE_CANDIDATES.forEach(profile=>profile.ports.forEach(port=>add(port,{profileId:profile.id,profileLabel:profile.label,priority:profile.priority,source:'profile'})));
    EXTRA_PORTS.forEach(port=>add(port,{source:'extra',priority:10}));
    recentPorts.forEach(port=>add(port,{source:'recent',priority:45}));
    try{
      const q=new URLSearchParams(window.location.search||'');
      const probeExtra=q.get('gwProbePorts')||q.get('openclaw_probe_ports')||'';
      probeExtra.split(/[,;\s]+/).forEach(s=>add(s,{source:'query',priority:60}));
    }catch(_){}
    return list.sort((a,b)=>b.priority-a.priority||a.port-b.port);
  }
  function makeInstanceRecord(candidate,extra){
    return Object.assign({
      host:getHost(),
      port:getPort(),
      profileId:'custom',
      profileLabel:'custom',
      priority:0,
      source:'probe',
      current:false,
      ok:false,
      online:false,
      requiresAuth:false,
      latencyMs:null,
      endpoint:'',
      summary:''
    },candidate||{},extra||{});
  }
  function scoreInstance(instance){
    if(!instance)return -1;
    let score=Number(instance.priority||0);
    if(instance.current)score+=60;
    if(instance.ok)score+=80;
    if(instance.online)score+=20;
    if(instance.requiresAuth)score+=10;
    return score;
  }
  function chooseBestInstance(instances){
    const list=(Array.isArray(instances)?instances:[]).slice().sort((a,b)=>scoreInstance(b)-scoreInstance(a)||a.port-b.port);
    return list[0]||null;
  }
  async function autoDetectPort(){
    const instances=await scanOnlineGatewayPorts();
    const best=chooseBestInstance(instances);
    if(best&&best.online){
      if(best.port!==getPort())setPort(best.port);
      else refreshSubtitle();
      return best.port;
    }
    refreshSubtitle();
    return getPort();
  }
  /** 杩斿洖鍒楄〃涓疄闄呭搷搴?OpenClaw 鎺㈡祴璺緞鐨勭鍙ｏ紙鍙瀹炰緥鍚屾椂鍦ㄧ嚎锛?*/
  async function scanOnlineGatewayPorts(){
    const candidates=buildProbeCandidates();
    const online=[];
    for(const candidate of candidates){
      const info=await probeGatewayInstance(candidate.port);
      if(info&&info.online)online.push(Object.assign({},candidate,info));
    }
    return online.sort((a,b)=>scoreInstance(b)-scoreInstance(a)||a.port-b.port);
  }
  return{getHost,setHost,getPort,setPort,setGatewayProfile,getDisplay,httpBase,wsBase,autoDetectPort,scanOnlineGatewayPorts,probePort,probeGatewayInstance,refreshSubtitle,useDevHttpProxy,DEFAULT_PORT,DEFAULT_HOST,QCLAW_PORT,LS_PROFILE,buildProbeCandidates,chooseBestInstance,describePort,getProfileForPort};
  /* 鈹€鈹€ API 闈㈡澘锛氱綉鍏崇鍙ｅ垏鎹?+ 鎵弿澶氬疄渚?+ 妫€娴嬬粨鏋滀笅鎷夊垏鎹?鈹€鈹€ */
  window.__lastDiscoveredGateways=window.__lastDiscoveredGateways||[];
  function formatGatewayInstanceLabel(instance,L){
    if(!instance)return '';
    const bits=[instance.endpoint||((instance.host||OpenClawGateway.getHost())+':'+instance.port)];
    if(instance.profileLabel&&instance.profileLabel!=='custom')bits.push(instance.profileLabel);
    if(instance.current)bits.push(L==='zh'?'褰撳墠':'current');
    if(instance.requiresAuth)bits.push(L==='zh'?'闇€璁よ瘉':'auth');
    else if(Number.isFinite(instance.latencyMs))bits.push(instance.latencyMs+'ms');
    return bits.join(' 路 ');
  }
  function summarizeGatewayInstances(instances,L){
    return (Array.isArray(instances)?instances:[]).map(item=>formatGatewayInstanceLabel(item,L)).join('\n');
  }
  function fillDiscoveredGatewaysSelect(online){
    const disc=$("gateway-discovered");
    if(!disc)return;
    const L=state.lang||'zh';
    const t=i18n[L]||i18n.zh;
    const ph=t.gatewayDiscoveredPlaceholder||'';
    const cur=OpenClawGateway.getPort();
    let instances;
    if(Array.isArray(online)){
      instances=online.slice();
      window.__lastDiscoveredGateways=instances;
    }else{
      instances=(window.__lastDiscoveredGateways||[]).slice();
    }
    const seen=new Set();
    const sorted=[];
    instances.forEach(instance=>{
      const n=parseInt(instance&&instance.port,10);
      if(Number.isFinite(n)&&n>0&&n<65536&&!seen.has(n)){
        seen.add(n);
        sorted.push(Object.assign({},instance,{current:n===cur}));
      }
    });
    if(Number.isFinite(cur)&&cur>0&&cur<65536&&!seen.has(cur)){
      sorted.unshift({port:cur,host:OpenClawGateway.getHost(),endpoint:OpenClawGateway.getDisplay(),profileLabel:OpenClawGateway.describePort(cur),current:true,online:false,summary:'saved'});
    }
    sorted.sort((a,b)=>(b.current?1:0)-(a.current?1:0)||(a.port-b.port));
    disc.innerHTML='';
    const o0=document.createElement('option');
    o0.value='';
    o0.textContent=ph;
    disc.appendChild(o0);
    sorted.forEach(instance=>{
      const o=document.createElement('option');
      o.value=String(instance.port);
      o.textContent=formatGatewayInstanceLabel(instance,L);
      if(instance.current)o.selected=true;
      disc.appendChild(o);
    });
  }
  async function refreshDiscoveredGatewaysAsync(){
    try{
      const online=await OpenClawGateway.scanOnlineGatewayPorts();
      fillDiscoveredGatewaysSelect(online);
    }catch(_){ }
  }
  window.refreshDiscoveredGatewaysAsync=refreshDiscoveredGatewaysAsync;
  function applyGatewaySelection(port,opts={}){
    const n=parseInt(String(port),10);
    if(!Number.isFinite(n)||n<1||n>65535)return false;
    OpenClawGateway.setPort(n);
    OpenClawGateway.refreshSubtitle();
    syncGatewayPresetFromPort();
    fillDiscoveredGatewaysSelect();
    if(opts.reconnect!==false)ClawController.reconnect();
    const L=state.lang||'zh';
    const okMsg=(L==='zh'?'已切换到 ':'Switched to ')+OpenClawGateway.getDisplay();
    showGatewayNotify(okMsg,true);
    showApiResult(okMsg,true);
    return true;
  }

  function syncGatewayPresetFromPort(){
    const sel=$("gateway-preset");
    const inp=$("gateway-custom-port");
    if(!sel)return;
    const p=OpenClawGateway.getPort();
    const d=OpenClawGateway.DEFAULT_PORT,q=OpenClawGateway.QCLAW_PORT;
    if(p===q)sel.value='qclaw';
    else if(p===d)sel.value='default';
    else{
      sel.value='custom';
      if(inp){inp.classList.remove('hidden');inp.value=String(p);}
    }
    if(sel.value!=='custom'&&inp)inp.classList.add('hidden');
  }
  function updateGatewaySwitchUi(L){
    L=L||state.lang||'zh';
    const t=i18n[L]||i18n.zh;
    const git=$("gateway-inline-title");
    if(git&&t.gatewayInlineTitle)git.textContent=t.gatewayInlineTitle;
    const sel=$("gateway-preset");
    if(sel&&sel.options&&sel.options.length>=3){
      if(t.gatewayOptDefault)sel.options[0].text=t.gatewayOptDefault;
      if(t.gatewayOptQclaw)sel.options[1].text=t.gatewayOptQclaw;
      if(t.gatewayOptCustom)sel.options[2].text=t.gatewayOptCustom;
    }
    if(sel&&t.gatewaySwitchLabel)sel.setAttribute('aria-label',t.gatewaySwitchLabel);
    const disc=$("gateway-discovered");
    if(disc&&t.gatewayDiscoveredLabel)disc.setAttribute('aria-label',t.gatewayDiscoveredLabel);
    const cport=$("gateway-custom-port");
    if(cport&&t.gatewayPortPlaceholder)cport.placeholder=t.gatewayPortPlaceholder;
    const ba=$("btn-gateway-apply"),bp=$("btn-gateway-probe");
    if(ba)ba.textContent=t.gatewayApplyShort||t.gatewayApply;
    if(bp){
      bp.textContent=t.gatewayProbeShort||t.gatewayProbe;
      if(t.gatewayProbe)bp.title=t.gatewayProbe;
    }
    syncGatewayPresetFromPort();
    fillDiscoveredGatewaysSelect();
    try{const ep=$("live-gateway-endpoint");if(ep)ep.textContent=OpenClawGateway.getDisplay();}catch(_){}
  }
  window.updateGatewaySwitchUi=updateGatewaySwitchUi;
  const gwPreset=$("gateway-preset"),gwCustom=$("gateway-custom-port"),gwApply=$("btn-gateway-apply"),gwProbe=$("btn-gateway-probe");
  if(gwPreset){
    gwPreset.addEventListener('change',()=>{
      if(gwCustom){
        if(gwPreset.value==='custom')gwCustom.classList.remove('hidden');
        else gwCustom.classList.add('hidden');
      }
    });
  }
  if(gwApply){
    gwApply.addEventListener('click',()=>{
      const sel=$("gateway-preset");
      const inp=$("gateway-custom-port");
      if(!sel)return;
      const L=state.lang||'zh';
      if(sel.value==='default'){
        applyGatewaySelection(OpenClawGateway.DEFAULT_PORT);
        return;
      }
      if(sel.value==='qclaw'){
        applyGatewaySelection(OpenClawGateway.QCLAW_PORT);
        return;
      }
      const n=parseInt(inp&&inp.value||'',10);
      if(!Number.isFinite(n)||n<1||n>65535){
        const err=L==='zh'?'请输入有效端口 (1-65535)':'Invalid port (1-65535)';
        showGatewayNotify(err,false);
        showApiResult(err,false);
        return;
      }
      applyGatewaySelection(n);
    });
  }
  if(gwProbe){
    gwProbe.addEventListener('click',async ()=>{
      const L=state.lang||'zh';
      const scanning=L==='zh'?'正在扫描...':'Scanning...';
      showGatewayNotify(scanning,true);
      showApiResult(scanning,true);
      try{
        const online=await OpenClawGateway.scanOnlineGatewayPorts();
        fillDiscoveredGatewaysSelect(online);
        if(online.length){
          const msg=(L==='zh'?'已发现在线 OpenClaw 实例：':'Detected live OpenClaw instances:')+'\n'+summarizeGatewayInstances(online,L);
          showGatewayNotify(msg,true);
          showApiResult(msg,true);
          syncGatewayPresetFromPort();
        }else{
          const fail=L==='zh'?'未发现在线 OpenClaw，可通过 ?gwProbePorts=端口1,端口2 扩展扫描列表':'No OpenClaw found. Add ?gwProbePorts=port1,port2 to extend the scan list';
          showGatewayNotify(fail,false);
          showApiResult(fail,false);
        }
      }catch(e){
        const err=String(e&&e.message||e);
        showGatewayNotify(err,false);
        showApiResult(err,false);
      }
    });
  }
  const gwDisc=$("gateway-discovered");
  if(gwDisc){
    gwDisc.addEventListener('change',()=>{
      const v=(gwDisc.value||'').trim();
      if(!v)return;
      const n=parseInt(v,10);
      if(!Number.isFinite(n)||n<1||n>65535)return;
      applyGatewaySelection(n);
    });
  }
  updateGatewaySwitchUi(state.lang);
  setTimeout(()=>{if(typeof refreshDiscoveredGatewaysAsync==='function')void refreshDiscoveredGatewaysAsync();},1200);

  /* 鈹€鈹€ 璇█鍒囨崲 鈹€鈹€ */
  const btnZh=$("btn-lang-zh"),btnEn=$("btn-lang-en");
  if(btnZh)btnZh.addEventListener('click',()=>{const L='zh';state.metrics=processStats(state.payload||{},L);state.themes=themes(state.metrics,L);mountNav();renderTheme(state.idx);refreshDetails();applyLang(L);});
  if(btnEn)btnEn.addEventListener('click',()=>{const L='en';state.metrics=processStats(state.payload||{},L);state.themes=themes(state.metrics,L);mountNav();renderTheme(state.idx);refreshDetails();applyLang(L);});

  /* 鈹€鈹€ 鍒濆鍖栬繛鎺ワ細鍏堟帰娴?Gateway 绔彛锛屽啀鏃?token 鏃惰嚜鍔ㄨ幏鍙栧悗杩炴帴 鈹€鈹€ */
  (async function startConnect(){
    try{await OpenClawGateway.autoDetectPort();}catch(_){}
    if(ClawController.getSavedToken()){
