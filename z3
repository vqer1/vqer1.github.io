(function() {
  'use strict';

  // ===== 1. СИСТЕМА ОФЛАЙН-ЛИЦЕНЗИРОВАНИЯ =====
  var LIC_SALT = "Z01_SALT_2026_V5";

  function licHash(s) {
    var h = 5381;
    for (var i = 0; i < s.length; i++) {
      h = ((h << 5) + h) + s.charCodeAt(i);
      h = h & h;
    }
    return Math.abs(h).toString(16).toUpperCase();
  }

  // Фиксированный 6-значный ID ТВ (не затирается при сбросе демо z01)
  function getMyDeviceId() {
    var id = Lampa.Storage.get('z01_my_dev_id', '');
    if (!id) {
      id = Lampa.Utils.uid(6).toUpperCase();
      Lampa.Storage.set('z01_my_dev_id', id);
    }
    return id;
  }

  // Проверка ключа ГГММДД-ХХХХХ (5 символов после дефиса)
  function verifyLicense() {
    var key = (Lampa.Storage.get('z01_license_key', '') || '').trim().toUpperCase();
    if (!key) return { active: false, msg: 'Ключ не введен' };

    var match = key.match(/^(\d{2})(\d{2})(\d{2})-([A-F0-9]{5})$/);
    if (!match) return { active: false, msg: 'Неверный формат ключа' };

    var datePart = match[1] + match[2] + match[3];
    var signPart = match[4];
    var myDev = getMyDeviceId();

    var expectedSign = ('00000' + licHash(myDev + datePart + LIC_SALT)).slice(-5);
    if (signPart !== expectedSign) {
      return { active: false, msg: 'Ключ от другого устройства' };
    }

    var year = 2000 + parseInt(match[1], 10);
    var month = parseInt(match[2], 10) - 1;
    var day = parseInt(match[3], 10);
    var expTime = new Date(year, month, day, 23, 59, 59).getTime();

    if (Date.now() > expTime) {
      return { active: false, msg: 'Срок действия ключа истек' };
    }

    var daysLeft = Math.ceil((expTime - Date.now()) / 86400000);
    var dateFormatted = ('0' + day).slice(-2) + '.' + ('0' + (month + 1)).slice(-2) + '.' + year;
    return { active: true, days: daysLeft, date: dateFormatted };
  }

  function requireLicense(callback) {
    var lic = verifyLicense();
    if (lic.active) {
      if (callback) callback();
    } else {
      var devId = getMyDeviceId();
      var modalHtml = $('<div style="padding:1.5em;text-align:center;">' +
        '<div style="font-size:1.4em;margin-bottom:0.5em;color:#e74c3c;">🔒 Требуется активация</div>' +
        '<div style="font-size:1.05em;opacity:0.8;margin-bottom:1.2em;">' + lic.msg + '</div>' +
        '<div style="font-size:0.9em;opacity:0.6;margin-bottom:0.3em;">Ваш ID устройства:</div>' +
        '<div style="font-size:1.7em;font-weight:bold;color:#7cc4ff;background:rgba(255,255,255,0.08);padding:10px;border-radius:8px;margin-bottom:1.2em;letter-spacing:2px;user-select:all;">' + devId + '</div>' +
        '<div style="font-size:0.85em;opacity:0.7;">Отправьте этот ID для получения ключа, затем активируйте в Настройки &rarr; Z01 Лицензия.</div>' +
      '</div>');
      Lampa.Modal.open({
        title: '',
        html: modalHtml,
        onBack: function() {
          Lampa.Modal.close();
          Lampa.Controller.toggle('content');
        }
      });
    }
  }

  // ===== 2. АВТОМАТИЧЕСКИЙ СБРОС И РОТАЦИЯ ТРИАЛА Z01 =====
  var ZPREM_SERVER = (Lampa.Utils && Lampa.Utils.protocol ? Lampa.Utils.protocol() : 'http://') + 'prem.z01.online/';[cite: 7]
  var ZPREM_TRIAL_URL = (Lampa.Utils && Lampa.Utils.protocol ? Lampa.Utils.protocol() : 'http://') + 'oplata.z01.online/trial.php';[cite: 7]

  var unic_id = Lampa.Storage.get('lampac_unic_id', '');[cite: 7]
  if (!unic_id) {
    unic_id = Lampa.Utils.uid(8).toLowerCase();[cite: 7]
    Lampa.Storage.set('lampac_unic_id', unic_id);[cite: 7]
  }

  function resetZ01Uid() {
    unic_id = Lampa.Utils.uid(8).toLowerCase();[cite: 7]
    Lampa.Storage.set('lampac_unic_id', unic_id);[cite: 7]
    return unic_id;[cite: 7]
  }

  function getZ01Email() {
    var trialEmail = Lampa.Storage.get('z01_trial_email', '');[cite: 7]
    if (trialEmail) return trialEmail;[cite: 7]
    var email = 'z01_' + (Lampa.Storage.get('lampac_unic_id', '') || resetZ01Uid()) + '@gmail.com';[cite: 7]
    Lampa.Storage.set('z01_trial_email', email);[cite: 7]
    return email;[cite: 7]
  }

  function rotateZ01TrialEmail() {
    var newEmail = 'z01_' + Lampa.Utils.uid(8).toLowerCase() + '@gmail.com';[cite: 7]
    Lampa.Storage.set('z01_trial_email', newEmail);[cite: 7]
    return newEmail;[cite: 7]
  }

  function zpremResetTrial() {
    Lampa.Storage.set('zpremkey', '');[cite: 7]
    Lampa.Storage.set('zprem_expires', '');[cite: 7]
    Lampa.Storage.set('zprem_trial_used', '');[cite: 7]
    resetZ01Uid();[cite: 7]
    rotateZ01TrialEmail();[cite: 7]
  }

  function isZpremActive() {
    var key = Lampa.Storage.get('zpremkey', '');[cite: 7]
    var exp = Lampa.Storage.get('zprem_expires', '');[cite: 7]
    return !!(key && exp && (new Date(exp).getTime() - Date.now() > 0));[cite: 7]
  }

  function zpremTrial(callback) {
    if (!isZpremActive()) zpremResetTrial();[cite: 7]
    var email = getZ01Email();[cite: 7]
    var uid = Lampa.Storage.get('lampac_unic_id', '');[cite: 7]
    if (!email || !uid) { if (callback) callback(false); return; }[cite: 7]

    var net = new Lampa.Reguest();[cite: 7]
    net.timeout(10000);[cite: 7]

    function sendReq(e, u, attempts) {
      attempts = attempts || 0;[cite: 7]
      net.silent(ZPREM_TRIAL_URL + '?email=' + encodeURIComponent(e) + '&uid=' + encodeURIComponent(u), function(resp) {[cite: 7]
        try {
          if (typeof resp === 'string') resp = JSON.parse(resp);[cite: 7]
          if (resp.status === 'activated' && resp.zpremkey) {[cite: 7]
            Lampa.Storage.set('zpremkey', resp.zpremkey);[cite: 7]
            Lampa.Storage.set('zprem_expires', resp.expires_at);[cite: 7]
            if (resp.prem_url) Lampa.Storage.set('online_url', resp.prem_url);[cite: 7]
            Lampa.Storage.set('zprem_trial_used', '1');[cite: 7]
            Defined.localhost = ZPREM_SERVER;[cite: 7]
            if (callback) callback(true);[cite: 7]
          } else if (resp.status === 'already_used' && attempts < 3) {[cite: 7]
            sendReq(rotateZ01TrialEmail(), resetZ01Uid(), attempts + 1);[cite: 7]
          } else {
            if (callback) callback(false);[cite: 7]
          }
        } catch(err) { if (callback) callback(false); }[cite: 7]
      }, function() { if (callback) callback(false); });[cite: 7]
    }

    sendReq(email, uid, 0);[cite: 7]
  }

  function zpremAutoEnsure(callback) {
    if (!verifyLicense().active) {
      if (callback) callback(false);
      return;
    }
    if (isZpremActive()) {[cite: 7]
      Defined.localhost = ZPREM_SERVER;[cite: 7]
      if (callback) callback(true);[cite: 7]
      return;[cite: 7]
    }
    zpremTrial(function(ok) {[cite: 7]
      if (ok) Defined.localhost = ZPREM_SERVER;[cite: 7]
      if (callback) callback(ok);[cite: 7]
    });
  }

  // ===== 3. ES5 ПОЛИФИЛЫ =====
  if (!Array.prototype.find) {
    Array.prototype.find = function(callback, thisArg) {
      for (var i = 0; i < this.length; i++) {
        if (callback.call(thisArg, this[i], i, this)) return this[i];[cite: 7]
      }
      return undefined;[cite: 7]
    };
  }
  if (!Array.prototype.findIndex) {
    Array.prototype.findIndex = function(callback, thisArg) {
      for (var i = 0; i < this.length; i++) {
        if (callback.call(thisArg, this[i], i, this)) return i;[cite: 7]
      }
      return -1;[cite: 7]
    };
  }
  if (!Array.prototype.includes) {
    Array.prototype.includes = function(val) { return this.indexOf(val) !== -1; };[cite: 7]
  }
  if (!String.prototype.includes) {
    String.prototype.includes = function(val) { return this.indexOf(val) !== -1; };[cite: 7]
  }
  if (!String.prototype.startsWith) {
    String.prototype.startsWith = function(s, pos) {
      pos = pos || 0;[cite: 7]
      return this.indexOf(s, pos) === pos;[cite: 7]
    };
  }
  if (!String.prototype.endsWith) {
    String.prototype.endsWith = function(s, len) {
      if (len === undefined || len > this.length) len = this.length;[cite: 7]
      return this.substring(len - s.length, len) === s;[cite: 7]
    };
  }

  // ===== 4. ВЫБОР СЕРВЕРОВ Z01 =====
  var Z01_SERVERS = ['http://s1.z01.online/', 'http://s2.z01.online/', 'http://s3.z01.online/'];[cite: 7]
  var Z01_FALLBACK = 'http://z01.online/';[cite: 7]

  function z01Ping(url, callback) {
    var xhr = new XMLHttpRequest();[cite: 7]
    var done = false;[cite: 7]
    function finish(ok) { if (!done) { done = true; callback(ok); } }[cite: 7]
    try {
      xhr.open('GET', url, true);[cite: 7]
      xhr.timeout = 1500;[cite: 7]
      xhr.onload = function() { finish(xhr.status >= 200 && xhr.status < 400); };[cite: 7]
      xhr.onerror = function() { finish(false); };[cite: 7]
      xhr.ontimeout = function() { finish(false); };[cite: 7]
      xhr.send();[cite: 7]
    } catch (e) { finish(false); }[cite: 7]
  }

  function z01Shuffle(arr) {
    var copy = arr.slice();[cite: 7]
    for (var i = copy.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));[cite: 7]
      var tmp = copy[i]; copy[i] = copy[j]; copy[j] = tmp;[cite: 7]
    }
    return copy;[cite: 7]
  }

  function z01PickServer(callback) {
    var candidates = z01Shuffle(Z01_SERVERS);[cite: 7]
    function tryNext(index) {
      if (index >= candidates.length) { callback(Z01_FALLBACK); return; }[cite: 7]
      z01Ping(candidates[index], function(ok) {[cite: 7]
        if (ok) callback(candidates[index]);[cite: 7]
        else tryNext(index + 1);[cite: 7]
      });
    }
    tryNext(0);[cite: 7]
  }

  var Defined = { api: 'lampac', localhost: 'http://z01.online/', apn: '' };[cite: 7]
  var Z01_FREE = Z01_FALLBACK;[cite: 7]
  z01PickServer(function(server) {
    Z01_FREE = server;[cite: 7]
    if (Defined.localhost === Z01_FALLBACK) Defined.localhost = server;[cite: 7]
  });

  var zprem_dropped = false;[cite: 7]
  function zpremDrop(er) {
    if (zprem_dropped || !er || !er.accsdb || Defined.localhost !== ZPREM_SERVER) return false;[cite: 7]
    zprem_dropped = true;[cite: 7]
    Defined.localhost = Z01_FREE;[cite: 7]
    return true;[cite: 7]
  }

  function arrFind(list, test) {
    if (!list) return undefined;[cite: 7]
    for (var i = 0; i < list.length; i++) {
      if (test(list[i], i, list)) return list[i];[cite: 7]
    }
    return undefined;[cite: 7]
  }

  var balansers_with_search;[cite: 7]

  function getAndroidVersion() {
    if (Lampa.Platform.is('android')) {[cite: 7]
      try {
        var current = AndroidJS.appVersion().split('-');[cite: 7]
        return parseInt(current.pop());[cite: 7]
      } catch (e) { return 0; }[cite: 7]
    }
    return 0;[cite: 7]
  }

  var hostkey = 'https://z01.online'.replace('http://', '').replace('https://', '');[cite: 7]
  if (!window.rch_nws || !window.rch_nws[hostkey]) {[cite: 7]
    if (!window.rch_nws) window.rch_nws = {};[cite: 7]
    window.rch_nws[hostkey] = {[cite: 7]
      type: Lampa.Platform.is('android') ? 'apk' : Lampa.Platform.is('tizen') ? 'cors' : undefined,[cite: 7]
      startTypeInvoke: false,[cite: 7]
      rchRegistry: false,[cite: 7]
      apkVersion: getAndroidVersion()[cite: 7]
    };
  }

  window.rch_nws[hostkey].typeInvoke = function(host, call) { call(); };
  window.rch_nws[hostkey].Registry = function(client, startConnection) {
    client.invoke("RchRegistry", {[cite: 7]
      version: 154,[cite: 7]
      host: location.host,[cite: 7]
      rchtype: Lampa.Platform.is('android') ? 'apk' : Lampa.Platform.is('tizen') ? 'cors' : (window.rch_nws[hostkey].type || 'web'),[cite: 7]
      apkVersion: window.rch_nws[hostkey].apkVersion,[cite: 7]
      player: Lampa.Storage.field('player'),[cite: 7]
      account_email: getZ01Email(),[cite: 7]
      unic_id: Lampa.Storage.get('lampac_unic_id', ''),[cite: 7]
      profile_id: Lampa.Storage.get('lampac_profile_id', ''),[cite: 7]
      token: ''[cite: 7]
    });
    if (startConnection) startConnection();[cite: 7]
  };

  function rchRun(json, call) {
    if (typeof NativeWsClient == 'undefined') {[cite: 7]
      Lampa.Utils.putScript(["https://z01.online/js/nws-client-es5.js?v03022026"], function() {}, false, function() {[cite: 7]
        call();[cite: 7]
      }, true);[cite: 7]
    } else call();[cite: 7]
  }

  function account(url) {
    url = url + '';[cite: 7]
    if (url.indexOf('account_email=') == -1) {[cite: 7]
      var email = getZ01Email();[cite: 7]
      if (email) url = Lampa.Utils.addUrlComponent(url, 'account_email=' + encodeURIComponent(email));[cite: 7]
    }
    if (url.indexOf('uid=') == -1) {[cite: 7]
      var uid = Lampa.Storage.get('lampac_unic_id', '');[cite: 7]
      if (uid) url = Lampa.Utils.addUrlComponent(url, 'uid=' + encodeURIComponent(uid));[cite: 7]
    }
    return url;[cite: 7]
  }

  var synced_balansers = {};[cite: 7]
  function syncBalanser(name) {
    if (!name || synced_balansers[name] || !Lampa.Manifest || Lampa.Manifest.app_digital < 177 || !Lampa.Storage.sync) return;[cite: 7]
    synced_balansers[name] = true;[cite: 7]
    Lampa.Storage.sync('online_choice_' + name, 'object_object');[cite: 7]
  }

  var Network = Lampa.Reguest;[cite: 7]

  // ===== 5. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ И ИНТЕРФЕЙС Z01UI =====
  var Z01UI = {};[cite: 7]
  Z01UI.enabled = function() { return Lampa.Storage.get('z01_ui_mode', 'modern') !== 'classic'; };[cite: 7]
  Z01UI.REQUEST_TIMEOUT = 20000;[cite: 7]

  Z01UI.esc = function(str) {
    return (str === undefined || str === null ? '' : String(str))
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');[cite: 7]
  };

  Z01UI.isSeasonLabel = function(text) {
    text = String(text || '').trim();[cite: 7]
    return /^\d+\s*(-?[йя])?\s*(сезон|season)$/i.test(text) || /^(сезон|season)\s*\d+$/i.test(text);[cite: 7]
  };

  Z01UI.seasonNumber = function(title) {
    var match = String(title || '').match(/\d+/);[cite: 7]
    return match ? parseInt(match[0]) : 0;[cite: 7]
  };

  Z01UI.css = "<style>.mo{padding:0 0 3em 0}.mo-head{display:flex;align-items:center;padding:0 .2em .7em .2em}.mo-head__title{font-size:1.7em;font-weight:600;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}.mo-head__note{font-size:1.05em;opacity:.7;padding-left:1em}.mo-tiles{display:flex;flex-wrap:wrap;margin:0 -.45em}.mo-tile{width:25%;padding:0 .45em 1.1em .45em}.mo-tile__art{position:relative;padding-top:56%;background:rgba(255,255,255,.08);border-radius:.4em;overflow:hidden}.mo-tile__art img{position:absolute;top:0;left:0;width:100%;height:100%;object-fit:cover}.mo-tile.focus .mo-tile__art{box-shadow:0 0 0 .2em #fff}.mo-tile__title{font-size:1.05em;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;padding-top:.4em}.mo-line{display:flex;align-items:center;padding:.8em 1em;margin-bottom:.45em;background:rgba(255,255,255,.06);border-radius:.4em;cursor:pointer}.mo-line.focus{background:#fff;color:#000}@media screen and (max-width:900px){.mo-tile{width:50%}}</style>";

  // ===== 6. РЕГИСТРАЦИЯ ШАБЛОНОВ LAMPA =====
  function resetTemplates() {
    Lampa.Template.add('lampac_content_loading', "<div class=\"online-empty\"><div class=\"broadcast__scan\"><div></div></div><div class=\"online-empty__templates\"><div class=\"online-empty-template selector\"><div class=\"online-empty-template__ico\"></div><div class=\"online-empty-template__body\"></div></div><div class=\"online-empty-template\"><div class=\"online-empty-template__ico\"></div><div class=\"online-empty-template__body\"></div></div></div></div>");[cite: 7]
    Lampa.Template.add('lampac_prestige_full', "<div class=\"online-prestige online-prestige--full selector\"><div class=\"online-prestige__img\"><img alt=\"\"><div class=\"online-prestige__loader\"></div></div><div class=\"online-prestige__body\"><div class=\"online-prestige__head\"><div class=\"online-prestige__title\">{title}</div><div class=\"online-prestige__time\">{time}</div></div><div class=\"online-prestige__timeline\"></div><div class=\"online-prestige__footer\"><div class=\"online-prestige__info\">{info}</div><div class=\"online-prestige__quality\">{quality}</div></div></div></div>");[cite: 7]
    Lampa.Template.add('lampac_does_not_answer', "<div class=\"online-empty\"><div class=\"online-empty__title\">#{lampac_balanser_dont_work}</div><div class=\"online-empty__buttons\"><div class=\"online-empty__button selector cancel\">#{cancel}</div><div class=\"online-empty__button selector change\">#{lampac_change_balanser}</div></div></div>");[cite: 7]
  }

  // ===== 7. КОМПОНЕНТ ПЛЕЕРА И КАТАЛОГА =====
  function component(object) {
    var network = new Network();[cite: 7]
    var scroll = new Lampa.Scroll({ mask: true, over: true });[cite: 7]
    var files = new Lampa.Explorer(object);[cite: 7]
    var filter = new Lampa.Filter(object);[cite: 7]
    var sources = {};[cite: 7]
    var last;[cite: 7]
    var source;[cite: 7]
    var balanser;[cite: 7]
    var initialized;[cite: 7]
    var filter_sources = [];[cite: 7]
    var filter_find = { season: [], voice: [] };[cite: 7]
    var modern = Z01UI.enabled();
    var ui = {};
    var life_wait_times = 0;[cite: 7]
    var life_wait_timer;[cite: 7]

    this.uiFrame = function() {
      if (!ui.root) {
        ui.root = $('<div class="mo"></div>');
        ui.status = $('<div class="mo__status"></div>');
        ui.list = $('<div class="mo-list"></div>');
        ui.root.append(ui.status).append(ui.list);
      }
      if (!ui.root.parent().length) {
        scroll.clear();[cite: 7]
        scroll.append(ui.root);[cite: 7]
      }
      return ui.root;
    };

    function balanserName(j) {
      var bals = j.balanser;[cite: 7]
      var name = j.name.split(' ')[0];[cite: 7]
      return (bals || name).toLowerCase();[cite: 7]
    }

    this.initialize = function() {
      var _this = this;
      this.loading(true);[cite: 7]
      filter.onBack = function() { _this.start(); };[cite: 7]
      filter.onSelect = function(type, a, b) {
        if (type == 'sort') {[cite: 7]
          Lampa.Select.close();[cite: 7]
          _this.switchSource(a.source);[cite: 7]
        } else if (type == 'filter') {
          var url = filter_find[a.stype][b.index].url;[cite: 7]
          _this.reset();[cite: 7]
          _this.request(url);[cite: 7]
          setTimeout(Lampa.Select.close, 10);[cite: 7]
        }
      };

      scroll.body().addClass('torrent-list');[cite: 7]
      files.appendFiles(scroll.render());[cite: 7]
      files.appendHead(filter.render());[cite: 7]
      scroll.minus(files.render().find('.explorer__files-head'));[cite: 7]
      if (modern) {
        files.render().find('.explorer__files-head').css('display', 'none');[cite: 7]
        this.uiFrame();
      } else {
        scroll.body().append(Lampa.Template.get('lampac_content_loading'));[cite: 7]
      }
      Lampa.Controller.enable('content');[cite: 7]
      this.loading(false);[cite: 7]

      var askServer = function() {
        return _this.createSource().then(function() {
          _this.search();[cite: 7]
        })['catch'](function(e) {
          if (zpremDrop(e)) return askServer();[cite: 7]
          _this.empty();[cite: 7]
        });
      };
      this.externalids().then(askServer);[cite: 7]
    };

    this.externalids = function() {
      return new Promise(function(resolve) {
        if (!object.movie.imdb_id || !object.movie.kinopoisk_id) {[cite: 7]
          var query = ['id=' + encodeURIComponent(object.movie.id), 'serial=' + (object.movie.name ? 1 : 0)];[cite: 7]
          if (object.movie.imdb_id) query.push('imdb_id=' + object.movie.imdb_id);[cite: 7]
          if (object.movie.kinopoisk_id) query.push('kinopoisk_id=' + object.movie.kinopoisk_id);[cite: 7]
          var url = Defined.localhost + 'externalids?' + query.join('&');[cite: 7]
          network.timeout(10000);[cite: 7]
          network.silent(account(url), function(json) {[cite: 7]
            for (var name in json) object.movie[name] = json[name];[cite: 7]
            resolve();[cite: 7]
          }, function() { resolve(); }, false, {[cite: 7]
            headers: {'X-Kit-AesGcm': Lampa.Storage.get('aesgcmkey', ''), 'X-Zprem-Key': Lampa.Storage.get('zpremkey', '')}[cite: 7]
          });
        } else resolve();[cite: 7]
      });
    };

    this.switchSource = function(name) {
      if (!sources[name]) return;[cite: 7]
      balanser = name;[cite: 7]
      source = sources[name].url;[cite: 7]
      Lampa.Storage.set('online_balanser', name);[cite: 7]
      this.reset();[cite: 7]
      this.find();[cite: 7]
    };

    this.requestParams = function(url) {
      var query = ['id=' + encodeURIComponent(object.movie.id)];[cite: 7]
      if (object.movie.imdb_id) query.push('imdb_id=' + object.movie.imdb_id);[cite: 7]
      if (object.movie.kinopoisk_id) query.push('kinopoisk_id=' + object.movie.kinopoisk_id);[cite: 7]
      query.push('title=' + encodeURIComponent(object.movie.title || object.movie.name));[cite: 7]
      query.push('serial=' + (object.movie.name ? 1 : 0));[cite: 7]
      query.push('cub_id=' + Lampa.Utils.hash(getZ01Email()));[cite: 7]
      return url + (url.indexOf('?') >= 0 ? '&' : '?') + query.join('&');[cite: 7]
    };

    // Защищенный парсинг массива источников (исправляет json.forEach is not a function)
    this.startSource = function(json) {
      return new Promise(function(resolve, reject) {
        var list = [];
        if (Array.isArray(json)) list = json;
        else if (json && Array.isArray(json.online)) list = json.online;[cite: 7]

        list.forEach(function(j) {
          var name = balanserName(j);[cite: 7]
          sources[name] = { url: j.url, name: j.name, show: typeof j.show == 'undefined' ? true : j.show };[cite: 7]
          syncBalanser(name);[cite: 7]
        });

        filter_sources = Lampa.Arrays.getKeys(sources);[cite: 7]
        ['Filmix 4K VIP', 'HDRezka 4K VIP', 'KinoPub 4K VIP', 'Alloha 4K VIP'].forEach(function(n) {[cite: 7]
          var k = 'vip_' + n.toLowerCase().replace(/\s/g, '_');[cite: 7]
          if (!sources[k]) {[cite: 7]
            sources[k] = { name: n + ' [VIP]', url: '', show: true, vip: true };[cite: 7]
            filter_sources.push(k);[cite: 7]
          }
        });

        if (filter_sources.length) {
          balanser = filter_sources[0];[cite: 7]
          source = sources[balanser].url;[cite: 7]
          resolve(json);
        } else {
          reject();[cite: 7]
        }
      });
    };

    this.lifeSource = function() {
      var _this3 = this;
      return new Promise(function(resolve, reject) {
        var url = _this3.requestParams(Defined.localhost + 'lifeevents?memkey=' + (_this3.memkey || ''));[cite: 7]
        var fin = function() {
          network.timeout(3000);[cite: 7]
          network.silent(account(url), function(json) {[cite: 7]
            life_wait_times++;[cite: 7]
            if (json && Array.isArray(json.online) && json.online.length) {
              resolve(json.online);
            } else if (life_wait_times > 15 || (json && json.ready)) {[cite: 7]
              if (json && Array.isArray(json.online)) resolve(json.online);
              else reject();[cite: 7]
            } else {
              life_wait_timer = setTimeout(fin, 1000);[cite: 7]
            }
          }, function() {
            life_wait_times++;[cite: 7]
            if (life_wait_times > 15) reject();[cite: 7]
            else life_wait_timer = setTimeout(fin, 1000);[cite: 7]
          }, false, {
            headers: {'X-Kit-AesGcm': Lampa.Storage.get('aesgcmkey', ''), 'X-Zprem-Key': Lampa.Storage.get('zpremkey', '')}[cite: 7]
          });
        };
        fin();
      });
    };

    this.createSource = function() {
      var _this4 = this;
      return new Promise(function(resolve, reject) {
        var url = _this4.requestParams(Defined.localhost + 'lite/events?life=true');[cite: 7]
        network.timeout(15000);[cite: 7]
        network.silent(account(url), function(json) {[cite: 7]
          if (typeof json === 'string') json = Lampa.Arrays.decodeJson(json, {});
          if (!json || json.accsdb) return reject(json);[cite: 7]
          if (json.life) {[cite: 7]
            _this4.memkey = json.memkey;[cite: 7]
            _this4.lifeSource().then(_this4.startSource).then(resolve)["catch"](reject);[cite: 7]
          } else {
            _this4.startSource(json).then(resolve)["catch"](reject);[cite: 7]
          }
        }, reject, false, {
          headers: {'X-Kit-AesGcm': Lampa.Storage.get('aesgcmkey', ''), 'X-Zprem-Key': Lampa.Storage.get('zpremkey', '')}[cite: 7]
        });
      });
    };

    this.create = function() { return this.render(); };[cite: 7]
    this.search = function() {
      filter.set('sort', filter_sources.map(function(e) {[cite: 7]
        return { title: sources[e].name, source: e, selected: e == balanser };[cite: 7]
      }));
      this.find();[cite: 7]
    };
    this.find = function() { this.request(this.requestParams(source)); };[cite: 7]

    this.request = function(url) {
      var _this = this;
      network.timeout(20000);[cite: 7]
      network['native'](account(url), function(str) { _this.parse(str); }, function() { _this.empty(); }, false, {[cite: 7]
        dataType: 'text',[cite: 7]
        headers: {'X-Kit-AesGcm': Lampa.Storage.get('aesgcmkey', ''), 'X-Zprem-Key': Lampa.Storage.get('zpremkey', '')}[cite: 7]
      });
    };

    this.parseJsonDate = function(str, name) {
      try {
        var html = $('<div>' + str + '</div>');[cite: 7]
        var elems = [];[cite: 7]
        html.find(name).each(function() {[cite: 7]
          var item = $(this);[cite: 7]
          var data = JSON.parse(item.attr('data-json') || '{}');[cite: 7]
          if (item.attr('s')) data.season = parseInt(item.attr('s'));[cite: 7]
          if (item.attr('e')) data.episode = parseInt(item.attr('e'));[cite: 7]
          data.text = item.text();[cite: 7]
          data.active = item.hasClass('active');[cite: 7]
          elems.push(data);[cite: 7]
        });
        return elems;[cite: 7]
      } catch(e) { return []; }[cite: 7]
    };

    this.getFileUrl = function(file, call) {
      var _this = this;
      Lampa.Loading.start(function() {[cite: 7]
        Lampa.Loading.stop();[cite: 7]
        Lampa.Controller.toggle('content');[cite: 7]
        network.clear();[cite: 7]
      });
      network['native'](account(file.url), function(json) {[cite: 7]
        Lampa.Loading.stop();[cite: 7]
        if (json.rch) {[cite: 7]
          rchRun(json, function() { _this.getFileUrl(file, call); });[cite: 7]
        } else {
          call(json, json);[cite: 7]
        }
      }, function() {
        Lampa.Loading.stop();[cite: 7]
        call(false, {});[cite: 7]
      }, false, {
        headers: {'X-Kit-AesGcm': Lampa.Storage.get('aesgcmkey', ''), 'X-Zprem-Key': Lampa.Storage.get('zpremkey', '')}[cite: 7]
      });
    };

    this.parse = function(str) {
      var _this = this;
      try {
        var items = this.parseJsonDate(str, '.videos__item');[cite: 7]
        var buttons = this.parseJsonDate(str, '.videos__button');[cite: 7]

        var season_buttons = buttons.filter(function(b) { return Z01UI.isSeasonLabel(b.text); });[cite: 7]
        if (season_buttons.length > 1) {
          filter_find.season = season_buttons.map(function(b) { return { title: b.text, url: b.url }; });[cite: 7]
          buttons = buttons.filter(function(b) { return !Z01UI.isSeasonLabel(b.text); });[cite: 7]
        }

        if (buttons.length) {
          filter_find.voice = buttons.map(function(b) { return { title: b.text, url: b.url }; });[cite: 7]
        }

        var videos = items.filter(function(v) { return v.method == 'play' || v.method == 'call'; });[cite: 7]
        if (videos.length) {
          this.draw(videos);
        } else if (items.length && items[0].url) {[cite: 7]
          this.request(items[0].url);[cite: 7]
        } else {
          this.empty();[cite: 7]
        }
      } catch(e) { this.empty(); }[cite: 7]
    };

    this.draw = function(items) {
      var _this = this;
      if (!items.length) return this.empty();[cite: 7]
      scroll.clear();[cite: 7]
      var serial = object.movie.name ? true : false;[cite: 7]
      var list = modern ? ui.list.empty() : scroll.body();
      if (modern && serial) list.addClass('mo-tiles');

      if (modern) {
        this.uiFrame();
        ui.status.html('<div class="mo-head"><div class="mo-head__title">' + (object.movie.title || object.movie.name) + '</div><div class="mo-head__note">Серий: ' + items.length + '</div></div>');
      }

      items.forEach(function(element, idx) {
        var title = element.text || element.title || ('Серия ' + (idx + 1));
        var html;
        if (modern && serial) {
          html = $('<div class="mo-tile selector"><div class="mo-tile__art"><img alt=""><div class="mo-tile__num">' + ('0' + (element.episode || idx + 1)).slice(-2) + '</div></div><div class="mo-tile__title">' + Z01UI.esc(title) + '</div></div>');[cite: 7]
          var img = html.find('img')[0];[cite: 7]
          img.src = Lampa.TMDB.image('t/p/w300' + (object.movie.backdrop_path || object.movie.poster_path || ''));[cite: 7]
        } else {
          html = $('<div class="mo-line selector"><div style="font-size:1.15em;">' + Z01UI.esc(title) + '</div></div>');
        }

        html.on('hover:enter click', function() {
          requireLicense(function() {
            zpremAutoEnsure(function() {
              _this.getFileUrl(element, function(json, json_call) {
                if (json && json.url) {
                  Lampa.Player.play({
                    title: title,
                    url: json.url,
                    headers: json_call.headers || json.headers,
                    isonline: true
                  });[cite: 7]
                } else {
                  Lampa.Noty.show('Ссылка недоступна');
                }
              });
            });
          });
        }).on('hover:focus', function(e) {
          last = e.target;[cite: 7]
          scroll.update($(e.target), true);[cite: 7]
        });

        list.append(html);[cite: 7]
      });

      Lampa.Controller.enable('content');[cite: 7]
    };

    this.getChoice = function() { return { season: 0, voice: 0 }; };[cite: 7]
    this.saveChoice = function() {};[cite: 7]
    this.empty = function() {
      scroll.clear();[cite: 7]
      scroll.append('<div style="padding:3em;text-align:center;font-size:1.2em;opacity:0.6;">Ничего не найдено</div>');
      this.loading(false);[cite: 7]
    };
    this.reset = function() {
      scroll.clear();[cite: 7]
      scroll.body().append(Lampa.Template.get('lampac_content_loading'));[cite: 7]
    };
    this.loading = function(status) {
      if (status) this.activity.loader(true);[cite: 7]
      else { this.activity.loader(false); this.activity.toggle(); }[cite: 7]
    };
    this.start = function() {
      if (!initialized) { initialized = true; this.initialize(); }[cite: 7]
      Lampa.Controller.add('content', {[cite: 7]
        toggle: function() {
          Lampa.Controller.collectionSet(scroll.render(), files.render());[cite: 7]
          Lampa.Controller.collectionFocus(last || false, scroll.render());[cite: 7]
        },
        up: function() { Navigator.move('up'); },[cite: 7]
        down: function() { Navigator.move('down'); },[cite: 7]
        right: function() { Navigator.move('right'); },[cite: 7]
        left: function() { Navigator.move('left'); },[cite: 7]
        back: this.back.bind(this)[cite: 7]
      });
      Lampa.Controller.toggle('content');[cite: 7]
    };
    this.render = function() { return files.render(); };[cite: 7]
    this.back = function() { Lampa.Activity.backward(); };[cite: 7]
    this.pause = function() {};[cite: 7]
    this.stop = function() {};[cite: 7]
    this.destroy = function() {
      clearTimeout(life_wait_timer);[cite: 7]
      network.clear();[cite: 7]
      scroll.destroy();[cite: 7]
    };
  }

  // ===== 8. СТАРТ ПЛАГИНА И НАСТРОЙКИ =====
  function startPlugin() {
    window.lampac_z_plugin = true;[cite: 7]
    resetTemplates(); // Своевременная регистрация шаблонов

    var manifst = {
      type: 'video',[cite: 7]
      version: '2.0.2',
      name: 'Z01',[cite: 7]
      description: 'Онлайн просмотр',[cite: 7]
      component: 'lampac_z',[cite: 7]
      onContextMenu: function() { return { name: 'Смотреть онлайн', description: 'Z01' }; },[cite: 7]
      onContextLauch: function(object) {
        requireLicense(function() {
          resetTemplates();
          Lampa.Component.add('lampac_z', component);[cite: 7]
          Lampa.Activity.push({
            url: '',[cite: 7]
            title: 'Онлайн',[cite: 7]
            component: 'lampac_z',[cite: 7]
            movie: object,[cite: 7]
            page: 1[cite: 7]
          });
        });
      }
    };
    Lampa.Manifest.plugins = manifst;[cite: 7]

    var button = "<div class=\"full-start__button selector view--online lampac--button\"><svg width=\"128\" height=\"128\" viewBox=\"0 0 128 128\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\"><rect x=\"8\" y=\"8\" width=\"112\" height=\"112\" rx=\"32\" fill=\"white\" stroke=\"#2886fb\" stroke-width=\"12\"/><path d=\"M38 36h52L38 92h52\" stroke=\"#2886fb\" stroke-width=\"12\" stroke-linecap=\"round\" stroke-linejoin=\"round\" fill=\"none\"/></svg><span>Онлайн</span></div>";[cite: 7]

    function addButton(e) {
      if (e.render.find('.lampac--button').length) return;[cite: 7]
      var btn = $(button);
      btn.on('hover:enter click', function() {
        requireLicense(function() {
          resetTemplates();
          Lampa.Component.add('lampac_z', component);[cite: 7]
          Lampa.Activity.push({
            url: '',[cite: 7]
            title: 'Онлайн',[cite: 7]
            component: 'lampac_z',[cite: 7]
            movie: e.movie,[cite: 7]
            page: 1[cite: 7]
          });
        });
      });
      e.render.after(btn);[cite: 7]
    }

    Lampa.Listener.follow('full', function(e) {[cite: 7]
      if (e.type == 'complite') {[cite: 7]
        addButton({ render: e.object.activity.render().find('.view--torrent'), movie: e.data.movie });[cite: 7]
      }
    });

    $('body').append(Z01UI.css);

    // Настройки лицензии в Lampa
    Lampa.SettingsApi.addComponent({
      component: 'z01_premium',[cite: 7]
      icon: '<svg width="36" height="36" viewBox="0 0 128 128" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="8" y="8" width="112" height="112" rx="32" fill="none" stroke="white" stroke-width="12"/><path d="M38 36h52L38 92h52" stroke="white" stroke-width="12" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg>',[cite: 7]
      name: 'Z01 Лицензия'
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_premium',[cite: 7]
      param: { name: 'z01_devid_view', type: 'title', default: true },[cite: 7]
      field: { name: '...' },[cite: 7]
      onRender: function(item) {
        var devId = getMyDeviceId();
        item.find('.settings-param__name,.settings-param-title__text').text('ID вашего ТВ: ' + devId);
      }
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_premium',[cite: 7]
      param: { name: 'z01_lic_status', type: 'title', default: true },[cite: 7]
      field: { name: '...' },[cite: 7]
      onRender: function(item) {
        var lic = verifyLicense();
        var txt = lic.active ? ('● Подписка активна (до ' + lic.date + ', ' + lic.days + ' дн.)') : ('○ Статус: ' + lic.msg);
        item.find('.settings-param__name,.settings-param-title__text').text(txt);
      }
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_premium',[cite: 7]
      param: { name: 'z01_enter_key_btn', type: 'button', default: '' },[cite: 7]
      field: {
        name: 'Ввести ключ активации',
        description: 'Нажмите для ввода'
      },
      onRender: function(item) {
        var lic = verifyLicense();
        if (lic.active) {
          item.find('.settings-param__name').text('Обновить ключ');
          item.find('.settings-param__descr,.settings-param__status').text('Активен до ' + lic.date);
        } else {
          item.find('.settings-param__name').text('Ввести ключ активации');
          item.find('.settings-param__descr,.settings-param__status').text('Нажмите для открытия экранной клавиатуры');
        }
      },
      onChange: function() {
        Lampa.Input.edit({
          title: 'Код активации (12 символов)',
          value: Lampa.Storage.get('z01_license_key', ''),
          free: true,
          nosave: true
        }, function(val) {
          if (val) {
            Lampa.Storage.set('z01_license_key', val.trim().toUpperCase());
            var lic = verifyLicense();
            if (lic.active) {
              Lampa.Noty.show('Лицензия активирована до ' + lic.date);
              zpremAutoEnsure();
            } else {
              Lampa.Noty.show('Ошибка: ' + lic.msg);
            }
            try { Lampa.Settings.update(); } catch(e) {}
          }
        });
      }
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_premium',[cite: 7]
      param: {
        name: 'z01_ui_mode',[cite: 7]
        type: 'select',[cite: 7]
        values: { modern: 'Новый', classic: 'Классический' },[cite: 7]
        "default": 'modern'[cite: 7]
      },
      field: { name: 'Интерфейс', description: 'Стиль отображения серий и озвучек' }[cite: 7]
    });
  }

  // Фоновая проверка лицензии при старте
  if (verifyLicense().active) {
    zpremAutoEnsure();
  }

  if (!window.lampac_z_plugin) startPlugin();[cite: 7]
})();
