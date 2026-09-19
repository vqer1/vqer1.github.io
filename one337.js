(function(){
  if(window.__alcopacAuthGate) return;
  window.__alcopacAuthGate=1;
  var LS_TOK='lampac_auth_token';
  var _srvHost='https://beta.l-vid.online';
  var _lo=window.location.origin||'';
  var origin=(_lo&&_lo!=='null'&&_lo.indexOf('http')===0&&_lo.indexOf('127.0.0.1')<0&&_lo.indexOf('localhost')<0)?_lo:_srvHost;

  // --- Helpers (Оригинальная система авторизации on.js) ---
  function getToken(){
    try{
      var ca=document.cookie.match(/(?:^|;\s*)alpac_token=([^;]*)/);
      if(ca)return decodeURIComponent(ca[1]);
      var cl=document.cookie.match(/(?:^|;\s*)lampac_token=([^;]*)/);
      if(cl)return decodeURIComponent(cl[1]);
    }catch(e){}
    try{var v=localStorage.getItem(LS_TOK);if(v)return v;}catch(e){}
    return '';
  }
  function saveToken(tok){
    if(!tok)return;
    var sas=(location.protocol==='https:'?';SameSite=None;Secure':';SameSite=Lax');
    try{
      document.cookie='lampac_token='+tok+';path=/;max-age=31536000'+sas;
      document.cookie='alpac_token='+tok+';path=/;max-age=31536000'+sas;
    }catch(e){}
    try{localStorage.setItem(LS_TOK,tok);}catch(e){}
  }
  function clearToken(){
    try{
      ['lampac_token','alpac_token'].forEach(function(n){
        document.cookie=n+'=;path=/;max-age=0';
        var d=location.hostname;
        document.cookie=n+'=;path=/;max-age=0;domain='+d;
        document.cookie=n+'=;path=/;max-age=0;domain=.'+d;
        var pts=d.split('.');if(pts.length>2)document.cookie=n+'=;path=/;max-age=0;domain=.'+pts.slice(-2).join('.');
      });
    }catch(e){}
    try{localStorage.removeItem(LS_TOK);}catch(e){}
  }
  function getUID(){
    try{var raw=localStorage.getItem('lampac_unic_id');if(raw){try{var p=JSON.parse(raw);if(typeof p==='string'&&p)return p;}catch(e){if(typeof raw==='string'&&raw)return raw;}
    }catch(e){}
    return '';
  }
  function ensureUID(){
    var u=getUID();
    if(u)return u;
    u='';var abc='abcdefghijklmnopqrstuvwxyz0123456789';
    for(var i=0;i<8;i++)u+=abc.charAt(Math.floor(Math.random()*abc.length));
    try{localStorage.setItem('lampac_unic_id',u);}catch(e){}
    try{localStorage.setItem('lampac_uid_backup',u);}catch(e){}
    return u;
  }
  function getCub(){
    try{var a=JSON.parse(localStorage.getItem('account')||'{}');if(a&&typeof a.token==='string'&&a.token)return a.token;}catch(e){}
    return '';
  }

  function fnv1a(str){
    var h=0x811c9dc5;
    for(var i=0;i<str.length;i++){h^=str.charCodeAt(i);h=Math.imul(h,0x01000193);}
    return (h>>>0).toString(16);
  }

  function getFingerprint(cb){
    var parts=[];
    try{parts.push('ua:'+navigator.userAgent);}catch(e){}
    try{parts.push('plt:'+navigator.platform);}catch(e){}
    try{parts.push('lang:'+(navigator.language||navigator.userLanguage||''));}catch(e){}
    try{parts.push('tz:'+Intl.DateTimeFormat().resolvedOptions().timeZone);}catch(e){}
    try{parts.push('scr:'+screen.width+'x'+screen.height+'x'+screen.colorDepth);}catch(e){}
    try{parts.push('dpr:'+(window.devicePixelRatio||1));}catch(e){}
    try{parts.push('cores:'+(navigator.hardwareConcurrency||0));}catch(e){}
    try{parts.push('mem:'+(navigator.deviceMemory||0));}catch(e){}
    try{parts.push('touch:'+(navigator.maxTouchPoints||0));}catch(e){}
    try{
      var c=document.createElement('canvas');var gl=c.getContext('webgl')||c.getContext('experimental-webgl');
      if(gl){
        var dbg=gl.getExtension('WEBGL_debug_renderer_info');
        if(dbg){parts.push('glv:'+gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL));parts.push('glr:'+gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL));}
        parts.push('glver:'+gl.getParameter(gl.VERSION));
        parts.push('glsl:'+gl.getParameter(gl.SHADING_LANGUAGE_VERSION));
      }
    }catch(e){}
    try{
      var cv=document.createElement('canvas');cv.width=240;cv.height=60;
      var cx=cv.getContext('2d');
      cx.textBaseline='alphabetic';cx.fillStyle='#f60';cx.fillRect(125,1,62,20);
      cx.fillStyle='#069';cx.font='11pt Arial';cx.fillText('Cwm fjord veg',2,15);
      cx.fillStyle='rgba(102,204,0,0.7)';cx.font='18pt Arial';cx.fillText('Cwm fjord veg',4,45);
      parts.push('cvs:'+cv.toDataURL().slice(-50));
    }catch(e){}
    try{
      var actx=new(window.OfflineAudioContext||window.webkitOfflineAudioContext)(1,44100,44100);
      var osc=actx.createOscillator();osc.type='triangle';osc.frequency.setValueAtTime(10000,actx.currentTime);
      var comp=actx.createDynamicsCompressor();
      comp.threshold.setValueAtTime(-50,actx.currentTime);comp.knee.setValueAtTime(40,actx.currentTime);
      comp.ratio.setValueAtTime(12,actx.currentTime);comp.attack.setValueAtTime(0,actx.currentTime);comp.release.setValueAtTime(0.25,actx.currentTime);
      osc.connect(comp);comp.connect(actx.destination);osc.start(0);
      actx.startRendering().then(function(buf){
        var d=buf.getChannelData(0);var sum=0;for(var i=4500;i<5000;i++)sum+=Math.abs(d[i]);
        parts.push('audio:'+sum.toFixed(6));
        cb(fnv1a(parts.join('|')));
      }).catch(function(){cb(fnv1a(parts.join('|')));});
      setTimeout(function(){cb(fnv1a(parts.join('|')));},1000);
    }catch(e){
      cb(fnv1a(parts.join('|')));
    }
  }

  function statusReq(qs,done,fail){
    var hosts=[];
    if(_srvHost)hosts.push(_srvHost);
    if(origin&&origin!==_srvHost)hosts.push(origin);
    var i=0;
    function next(){i++;if(i<hosts.length)attempt();else fail();}
    function attempt(){
      var x=new XMLHttpRequest();
      x.open('GET',hosts[i]+'/tg/auth/status?'+qs,true);
      try{x.withCredentials=true;}catch(e){}
      x.timeout=8000;
      x.onload=function(){
        if(x.status===200){
          var r=null;
          try{r=JSON.parse(x.responseText);}catch(e){}
          if(r){done(r);return;}
        }
        next();
      };
      x.onerror=next;
      x.ontimeout=next;
      x.send();
    }
    attempt();
  }

  function upgradeBundle(tok){
    try{if(tok&&window.alcopac_upgrade)window.alcopac_upgrade(tok);}catch(e){}
  }
  function checkToken(tok){
    var cub=getCub();
    var uid=ensureUID();
    statusReq('token='+encodeURIComponent(tok)+(uid?'&uid='+encodeURIComponent(uid):'')+(cub?'&cub='+encodeURIComponent(cub):''),function(r){
      if(r&&r.authorized){saveToken(r.token||tok);upgradeBundle(r.token||tok);return;}
      clearToken();
      if(r&&r.revoked){return;}
      try{var ls=localStorage.getItem(LS_TOK);if(ls&&ls!==tok){saveToken(ls);checkToken(ls);return;}}catch(e){}
      tryRecovery();
    },function(){});
  }
  var token=getToken();
  if(token){
    checkToken(token);
  } else {
    tryRecovery();
  }

  function tryRecovery(){
    var uid=getUID();
    var cub=getCub();
    if(uid||cub){
      if(!uid)uid=ensureUID();
      statusReq('uid='+encodeURIComponent(uid)+(cub?'&cub='+encodeURIComponent(cub):''),function(r){
        if(r&&r.authorized){saveToken(r.token||'');upgradeBundle(r.token);return;}
        tryFingerprint();
      },tryFingerprint);
    } else {
      tryFingerprint();
    }
  }

  function nativeIdSync(){
    try{if(window.webapis&&webapis.productinfo&&typeof webapis.productinfo.getDuid==='function')return 'tz:'+webapis.productinfo.getDuid();}catch(e){}
    try{if(window.AndroidJS&&typeof AndroidJS.getDeviceId==='function')return 'ad:'+AndroidJS.getDeviceId();}catch(e){}
    try{if(window.Android&&typeof Android.getDeviceId==='function')return 'ad:'+Android.getDeviceId();}catch(e){}
    return '';
  }
  function nativeId(cb){
    var s=nativeIdSync();
    if(s){cb(s);return;}
    var done=false;
    var finish=function(v){if(done)return;done=true;cb(v||'');};
    var t=setTimeout(function(){finish('');},1200);
    try{
      if(window.webOSDev&&typeof webOSDev.LGUDID==='function'){
        webOSDev.LGUDID({onSuccess:function(r){clearTimeout(t);finish(r&&r.id?'lg:'+r.id:'');},onFailure:function(){clearTimeout(t);finish('');}});
        return;
      }
      if(window.PalmServiceBridge){
        var b=new PalmServiceBridge();
        b.onservicecallback=function(msg){var r=null;try{r=JSON.parse(msg);}catch(e){}var ids=r&&r.idList;var id='';if(ids&&ids.length)id=ids[0].idValue||'';clearTimeout(t);finish(id?'lg:'+id:'');};
        b.call('luna://com.webos.service.sm/deviceid/getIDs',JSON.stringify({idType:['LGUDID']}));
        return;
      }
    }catch(e){}
    clearTimeout(t);finish('');
  }

  function stableFP(cb){
    var p=[];
    try{p.push((screen.width||0)+'x'+(screen.height||0));}catch(e){}
    try{p.push(screen.colorDepth||0);}catch(e){}
    try{p.push(window.devicePixelRatio||1);}catch(e){}
    try{p.push(navigator.hardwareConcurrency||0);}catch(e){}
    try{p.push(navigator.deviceMemory||0);}catch(e){}
    try{p.push(navigator.platform||'');}catch(e){}
    try{p.push(navigator.maxTouchPoints||0);}catch(e){}
    try{Intl.DateTimeFormat().resolvedOptions().timeZone&&p.push(Intl.DateTimeFormat().resolvedOptions().timeZone);}catch(e){}
    try{p.push((navigator.userAgent||'').replace(/[\d.]+/g,'').slice(0,120));}catch(e){}
    nativeId(function(nid){cb(nid?'n:'+fnv1a(p.join('|')+'|'+nid):'');});
  }
  function tryFingerprint(){
    getFingerprint(function(fp){
      stableFP(function(sfp){
        var cub=getCub();
        if(!fp&&!sfp&&!cub){showGate();return;}
        var qs=[];
        if(fp)qs.push('fp='+encodeURIComponent(fp));
        if(sfp)qs.push('sfp='+encodeURIComponent(sfp));
        if(cub)qs.push('cub='+encodeURIComponent(cub));
        var uid=ensureUID();
        if(uid)qs.push('uid='+encodeURIComponent(uid));
        statusReq(qs.join('&'),function(r){
          if(r&&r.authorized){saveToken(r.token||'');upgradeBundle(r.token);return;}
          showGate();
        },showGate);
      });
    });
  }

  function showGate(){
    var isApp=!!(window.Lampa||window.appready||window.AndroidJS||typeof webOS!=='undefined'||/Tizen|WebOS|HbbTV|SMART-TV/i.test(navigator.userAgent));
    if(!isApp){
      window.location.href=(_srvHost||origin)+'/tg/auth';
    }
  }
})();

// --- Модуль синхронизации Alloha с ab2024.ru ---
(function(){
  'use strict';
  var ALLOHA_HOST = 'https://ab2024.ru';

  function getActiveMovie() {
    var act = (typeof Lampa !== 'undefined' && Lampa.Activity && Lampa.Activity.active && Lampa.Activity.active()) || {};
    return act.movie || act.card || null;
  }

  function ensureExternalIds(movie, callback) {
    if (!movie) return callback ? callback() : null;
    if (movie.kinopoisk_id && movie.imdb_id) return callback ? callback() : null;

    var cacheKey = 'ext_ids_' + movie.id;
    var cached = null;
    try { cached = JSON.parse(localStorage.getItem(cacheKey)); } catch(e){}
    if (cached && (cached.kinopoisk_id || cached.imdb_id)) {
      if (cached.kinopoisk_id) movie.kinopoisk_id = cached.kinopoisk_id;
      if (cached.imdb_id) movie.imdb_id = cached.imdb_id;
      return callback ? callback() : null;
    }

    var params = [
      'id=' + encodeURIComponent(movie.id),
      'serial=' + (movie.name || movie.number_of_seasons ? 1 : 0)
    ];
    if (movie.imdb_id) params.push('imdb_id=' + encodeURIComponent(movie.imdb_id));
    if (movie.kinopoisk_id) params.push('kinopoisk_id=' + encodeURIComponent(movie.kinopoisk_id));

    var xhr = new XMLHttpRequest();
    xhr.open('GET', ALLOHA_HOST + '/externalids?' + params.join('&'), true);
    xhr.timeout = 4000;
    xhr.onload = function() {
      if (xhr.status === 200) {
        try {
          var res = JSON.parse(xhr.responseText);
          if (res) {
            if (res.kinopoisk_id) movie.kinopoisk_id = res.kinopoisk_id;
            if (res.imdb_id) movie.imdb_id = res.imdb_id;
            try { localStorage.setItem(cacheKey, JSON.stringify(res)); } catch(e){}
          }
        } catch(e) {}
      }
      if (callback) callback();
    };
    xhr.onerror = function() { if (callback) callback(); };
    xhr.ontimeout = function() { if (callback) callback(); };
    xhr.send();
  }

  function buildAllohaUrl(rawUrl, movie) {
    var base = ALLOHA_HOST + '/lite/alloha';
    var params = {};

    if (rawUrl && rawUrl.indexOf('?') !== -1) {
      var qs = rawUrl.substring(rawUrl.indexOf('?') + 1).split('&');
      for (var i = 0; i < qs.length; i++) {
        var pair = qs[i].split('=');
        if (pair[0]) params[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1] || '');
      }
    }

    if (movie && typeof movie === 'object') {
      if (movie.id && !params.id) params.id = movie.id;
      if (movie.kinopoisk_id) params.kinopoisk_id = movie.kinopoisk_id;
      if (movie.imdb_id) params.imdb_id = movie.imdb_id;
      var title = movie.title || movie.name || '';
      if (title) params.title = title;
      var origTitle = movie.original_title || movie.original_name || '';
      if (origTitle) params.original_title = origTitle;
      params.serial = (movie.name || movie.number_of_seasons ? 1 : 0);
      var year = (movie.release_date || movie.first_air_date || '').slice(0, 4);
      if (year) params.year = year;
    }

    delete params.rjson;
    params.rchtype = (window.AndroidJS || (typeof Lampa !== 'undefined' && Lampa.Platform && Lampa.Platform.is && Lampa.Platform.is('android'))) ? 'apk' : 'cors';

    var qParts = [];
    for (var k in params) {
      if (params.hasOwnProperty(k) && params[k] !== undefined && params[k] !== '') {
        qParts.push(encodeURIComponent(k) + '=' + encodeURIComponent(params[k]));
      }
    }
    return base + '?' + qParts.join('&');
  }

  function patchBalancersData(data, reqUrl) {
    if (!data) return data;
    var list = data.online || (Array.isArray(data) ? data : null);
    if (list && Array.isArray(list)) {
      var m = getActiveMovie();
      var cleanUrl = buildAllohaUrl(ALLOHA_HOST + '/lite/alloha', m);
      var allohaFound = false;

      for (var i = 0; i < list.length; i++) {
        var item = list[i];
        var name = (item.name || item.title || '').toLowerCase();
        if (name.indexOf('alloha') !== -1) {
          allohaFound = true;
          item.show = true;
          item.url = buildAllohaUrl(item.url, m);
        }
      }

      if (!allohaFound) {
        list.unshift({
          name: 'Alloha',
          url: cleanUrl,
          show: true
        });
      }
    }
    return data;
  }

  // Предзагрузка kinopoisk_id в момент открытия любой карточки фильма
  var initListener = setInterval(function() {
    if (typeof Lampa !== 'undefined' && Lampa.Listener) {
      clearInterval(initListener);
      Lampa.Listener.follow('full', function(e) {
        if (e.type === 'complite' && e.data && e.data.movie) {
          ensureExternalIds(e.data.movie);
        }
      });
    }
  }, 100);

  // Перехват XHR
  var origXOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url, async, user, pass) {
    if (typeof url === 'string') {
      if (url.indexOf('externalids') !== -1) {
        url = url.replace(/https?:\/\/beta\.l-vid\.online/i, ALLOHA_HOST);
      }
      if (url.indexOf('alloha') !== -1) {
        var m = getActiveMovie();
        url = buildAllohaUrl(url, m);
      }
    }
    this._reqUrl = url;
    return origXOpen.call(this, method, url, async, user, pass);
  };

  var origXSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.send = function(body) {
    var self = this;
    var url = this._reqUrl || '';
    if (url.indexOf('withsearch') !== -1 || url.indexOf('events') !== -1) {
      self.addEventListener('readystatechange', function() {
        if (self.readyState === 4 && self.status === 200) {
          try {
            var parsed = JSON.parse(self.responseText);
            var patched = patchBalancersData(parsed, url);
            var str = JSON.stringify(patched);
            Object.defineProperty(self, 'responseText', { value: str, configurable: true });
            Object.defineProperty(self, 'response', { value: str, configurable: true });
          } catch(e) {}
        }
      });
    }
    return origXSend.call(this, body);
  };

  // Хуки интерфейса Lampa (Alloha, отложенный поиск и эмодзи)
  var hookInterval = setInterval(function() {
    if (typeof Lampa === 'undefined') return;
    clearInterval(hookInterval);

    if (Lampa.Reguest) {
      var origSilent = Lampa.Reguest.prototype.silent;
      var origNative = Lampa.Reguest.prototype.native;

      function handleReq(fn, context, args) {
        var url = args[0];
        var success = args[1];
        var error = args[2];
        var post = args[3];
        var options = args[4];

        if (typeof url === 'string' && url.indexOf('alloha') !== -1) {
          var m = getActiveMovie();
          ensureExternalIds(m, function() {
            var cleanUrl = buildAllohaUrl(url, m);
            var wrappedSuccess = function(res) {
              var patched = patchBalancersData(res, cleanUrl);
              if (success) success(patched);
            };
            fn.call(context, cleanUrl, wrappedSuccess, error, post, options);
          });
          return;
        }

        if (typeof url === 'string' && url.indexOf('externalids') !== -1) {
          url = url.replace(/https?:\/\/beta\.l-vid\.online/i, ALLOHA_HOST);
          args[0] = url;
        }
        return fn.apply(context, args);
      }

      Lampa.Reguest.prototype.silent = function() {
        return handleReq(origSilent, this, arguments);
      };

      Lampa.Reguest.prototype.native = function() {
        return handleReq(origNative, this, arguments);
      };
    }

    var addEmoji = function(title) {
      if (typeof title !== 'string') return title;
      if (/^alloha$/i.test(title)) return '🍍 Alloha';
      if (/^filmix(?:tv)?$/i.test(title)) return '🎬 Filmix';
      return title;
    };

    if (Lampa.Filter && !Lampa.Filter.__alcopacEmoji) {
      Lampa.Filter.__alcopacEmoji = true;
      var origFilterSet = Lampa.Filter.prototype.set;
      Lampa.Filter.prototype.set = function(type, items) {
        if (items && Array.isArray(items)) {
          items.forEach(function(item) {
            if (item.title) item.title = addEmoji(item.title);
          });
        }
        origFilterSet.call(this, type, items);
      };
    }

    if (Lampa.Select && !Lampa.Select.__alcopacEmoji) {
      Lampa.Select.__alcopacEmoji = true;
      var origSelectShow = Lampa.Select.show;
      Lampa.Select.show = function(params) {
        if (params && params.items) {
          params.items.forEach(function(item) {
            if (item.title) item.title = addEmoji(item.title);
          });
        }
        origSelectShow.call(this, params);
      };
    }
  }, 50);
})();

// --- Оригинальный Bootstrap IIFE on.js ---
(function () {
    'use strict';

    var FULL = false;
    var SELF_UPGRADE = true;
    var HOST = 'https://beta.l-vid.online';

    if (!window.lampa_settings) window.lampa_settings = {};
    if (!window.lampa_settings.disable_features) window.lampa_settings.disable_features = {};
    window.lampa_settings.disable_features.lgbt = true;

    function durableToken() {
        try {
            var m = document.cookie.match(/(?:^|;\s*)(?:alpac_token|lampac_token)=([^;]*)/);
            if (m && m[1]) return decodeURIComponent(m[1]);
        } catch (e) {}
        try { var v = localStorage.getItem('lampac_auth_token'); if (v) return v; } catch (e) {}
        var names = ['alpac_token', 'lampac_token'];
        for (var i = 0; i < names.length; i++) {
            try {
                var raw = localStorage.getItem(names[i]);
                if (!raw) continue;
                try { var p = JSON.parse(raw); if (typeof p === 'string' && p) return p; }
                catch (e) { if (raw) return raw; }
            } catch (e) {}
        }
        return '';
    }

    function putScript(src, onerror) {
        var s = document.createElement('script');
        s.src = src;
        if (onerror) s.onerror = onerror;
        (document.head || document.documentElement).appendChild(s);
    }

    if (!window.alcopac_upgrade) {
        window.alcopac_upgrade = function (tok) {
            if (!tok || window.alcopac_onjs_full) return;
            if (window.alcopac_upgrading === tok) return;
            window.alcopac_upgrading = tok;
            putScript(HOST + '/on/js/' + encodeURIComponent(tok), function () {
                if (window.alcopac_upgrade_fallback) window.alcopac_upgrade_fallback();
            });
        };
    }

    var LIST = [
      {"k":"online","o":0,"u":"https://beta.l-vid.online/online.js"},
      {"k":"catalog","o":1,"u":"https://beta.l-vid.online/catalog.js"},
      {"k":"account","o":0,"u":"https://beta.l-vid.online/account.js"},
      {"k":"server_widget","o":1,"u":"https://beta.l-vid.online/server_widget.js"}
    ];

    function optionalEnabled(key) {
        try {
            var v = Lampa.Storage.get('alcopac_plug_' + key, false);
            return v === true || v === 'true';
        } catch (e) { return false; }
    }

    function loadBundle() {
        var timer = setInterval(function () {
            if (typeof Lampa !== 'undefined') {
                clearInterval(timer);

                var unic_id = Lampa.Storage.get('lampac_unic_id', '');
                if (!unic_id) {
                    unic_id = Lampa.Utils.uid(8).toLowerCase();
                    Lampa.Storage.set('lampac_unic_id', unic_id);
                }

                var mtok = durableToken();
                if (mtok) {
                    try { if (Lampa.Storage.get('alpac_token', '') !== mtok) Lampa.Storage.set('alpac_token', mtok); } catch (e) {}
                    try { if (Lampa.Storage.get('lampac_token', '') !== mtok) Lampa.Storage.set('lampac_token', mtok); } catch (e) {}
                }

                window.alcopac_plugin_list = LIST;
                if (!window.alcopac_loaded_plugins) window.alcopac_loaded_plugins = {};
                var urls = [];
                for (var i = 0; i < LIST.length; i++) {
                    var p = LIST[i];
                    if (!p) continue;
                    if (typeof p === 'string') { urls.push(p); continue; }
                    if (window.alcopac_loaded_plugins[p.k]) continue;
                    if (p.o && !optionalEnabled(p.k)) continue;
                    window.alcopac_loaded_plugins[p.k] = true;
                    urls.push(p.u);
                }
                if (urls.length) Lampa.Utils.putScriptAsync(urls, function () {});
            }
        }, 200);
    }

    if (FULL) {
        if (window.alcopac_onjs_full) return;
        window.alcopac_onjs_full = true;
        window.alcopac_onjs = true;
        loadBundle();
        return;
    }

    if (window.alcopac_onjs) return;

    if (SELF_UPGRADE) {
        var tok = durableToken();
        if (tok) {
            window.alcopac_upgrade_fallback = function () {
                if (window.alcopac_onjs) return;
                window.alcopac_onjs = true;
                loadBundle();
            };
            window.alcopac_upgrade(tok);
            return;
        }
    }

    window.alcopac_onjs = true;
    loadBundle();
})();
