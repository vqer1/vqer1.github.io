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

  // Фиксированный 6-значный ID ТВ (НЕ стирается при сбросе демо z01)
  function getMyDeviceId() {
    var id = Lampa.Storage.get('z01_my_dev_id', '');
    if (!id) {
      id = Lampa.Utils.uid(6).toUpperCase();
      Lampa.Storage.set('z01_my_dev_id', id);
    }
    return id;
  }

  // Проверка ключа ГГММДД-ХХХХХ (12 символов, 5 знаков подписи)
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

  // ===== 2. ES5 ПОЛИФИЛЫ =====
  if (!Array.prototype.find) {
    Array.prototype.find = function(callback, thisArg) {
      for (var i = 0; i < this.length; i++) {
        if (callback.call(thisArg, this[i], i, this)) return this[i];[cite: 8]
      }
      return undefined;[cite: 8]
    };
  }
  if (!Array.prototype.findIndex) {
    Array.prototype.findIndex = function(callback, thisArg) {
      for (var i = 0; i < this.length; i++) {
        if (callback.call(thisArg, this[i], i, this)) return i;[cite: 8]
      }
      return -1;[cite: 8]
    };
  }
  if (!Array.prototype.includes) {
    Array.prototype.includes = function(val) { return this.indexOf(val) !== -1; };[cite: 8]
  }
  if (!String.prototype.includes) {
    String.prototype.includes = function(val) { return this.indexOf(val) !== -1; };[cite: 8]
  }
  if (!String.prototype.startsWith) {
    String.prototype.startsWith = function(s, pos) {
      pos = pos || 0;[cite: 8]
      return this.indexOf(s, pos) === pos;[cite: 8]
    };
  }
  if (!String.prototype.endsWith) {
    String.prototype.endsWith = function(s, len) {
      if (len === undefined || len > this.length) len = this.length;[cite: 8]
      return this.substring(len - s.length, len) === s;[cite: 8]
    };
  }
  if (typeof Promise === 'undefined') {
    window.Promise = function(executor) {
      var self = this;[cite: 8]
      self._state = 0;[cite: 8]
      self._value = undefined;[cite: 8]
      self._handlers = [];[cite: 8]
      function resolve(val) {
        if (self._state !== 0) return;[cite: 8]
        self._state = 1;[cite: 8]
        self._value = val;[cite: 8]
        self._handlers.forEach(function(h) { h.onFulfilled(val); });[cite: 8]
      }
      function reject(val) {
        if (self._state !== 0) return;[cite: 8]
        self._state = 2;[cite: 8]
        self._value = val;[cite: 8]
        self._handlers.forEach(function(h) { h.onRejected(val); });[cite: 8]
      }
      try { executor(resolve, reject); } catch(e) { reject(e); }[cite: 8]
    };
    window.Promise.prototype.then = function(onFulfilled, onRejected) {
      var self = this;[cite: 8]
      return new Promise(function(resolve, reject) {
        function handle(onFn, fallback) {
          return function(val) {
            try {
              var result = (typeof onFn === 'function') ? onFn(val) : fallback(val);[cite: 8]
              if (result && typeof result.then === 'function') result.then(resolve, reject);[cite: 8]
              else resolve(result);[cite: 8]
            } catch(e) { reject(e); }[cite: 8]
          };
        }
        var handler = {
          onFulfilled: handle(onFn, function(v) { return v; }),[cite: 8]
          onRejected: handle(onRejected, function(e) { throw e; })[cite: 8]
        };
        if (self._state === 1) setTimeout(function() { handler.onFulfilled(self._value); }, 0);[cite: 8]
        else if (self._state === 2) setTimeout(function() { handler.onRejected(self._value); }, 0);[cite: 8]
        else self._handlers.push(handler);[cite: 8]
      });
    };
    window.Promise.prototype['catch'] = function(onRejected) { return this.then(null, onRejected); };[cite: 8]
    window.Promise.resolve = function(val) { return new Promise(function(r) { r(val); }); };[cite: 8]
    window.Promise.reject = function(val) { return new Promise(function(_, r) { r(val); }); };[cite: 8]
  }

  // ===== 3. СЕРВЕРЫ Z01 =====
  var Z01_SERVERS = ['http://s1.z01.online/', 'http://s2.z01.online/', 'http://s3.z01.online/'];[cite: 8]
  var Z01_FALLBACK = 'http://z01.online/';[cite: 8]
  var Z01_PING_TIMEOUT = 1500;[cite: 8]

  function z01Ping(url, callback) {
    var xhr = new XMLHttpRequest();[cite: 8]
    var done = false;[cite: 8]
    function finish(ok) { if (!done) { done = true; callback(ok); } }[cite: 8]
    try {
      xhr.open('GET', url, true);[cite: 8]
      xhr.timeout = Z01_PING_TIMEOUT;[cite: 8]
      xhr.onload = function() { finish(xhr.status >= 200 && xhr.status < 400); };[cite: 8]
      xhr.onerror = function() { finish(false); };[cite: 8]
      xhr.ontimeout = function() { finish(false); };[cite: 8]
      xhr.send();[cite: 8]
    } catch (e) { finish(false); }[cite: 8]
  }

  function z01Shuffle(arr) {
    var copy = arr.slice();[cite: 8]
    for (var i = copy.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));[cite: 8]
      var tmp = copy[i]; copy[i] = copy[j]; copy[j] = tmp;[cite: 8]
    }
    return copy;[cite: 8]
  }

  function z01PickServer(callback) {
    var candidates = z01Shuffle(Z01_SERVERS);[cite: 8]
    function tryNext(index) {
      if (index >= candidates.length) { callback(Z01_FALLBACK); return; }[cite: 8]
      z01Ping(candidates[index], function(ok) {[cite: 8]
        if (ok) callback(candidates[index]);[cite: 8]
        else tryNext(index + 1);[cite: 8]
      });
    }
    tryNext(0);[cite: 8]
  }

  var Defined = { api: 'lampac', localhost: 'http://z01.online/', apn: '' };[cite: 8]
  var Z01_FREE = Z01_FALLBACK;[cite: 8]
  z01PickServer(function(server) {
    Z01_FREE = server;[cite: 8]
    if (Defined.localhost === Z01_FALLBACK) Defined.localhost = server;[cite: 8]
  });

  var ZPREM_SERVER = (Lampa.Utils && Lampa.Utils.protocol ? Lampa.Utils.protocol() : 'http://') + 'prem.z01.online/';[cite: 8]
  var ZPREM_CHECK_URL = (Lampa.Utils && Lampa.Utils.protocol ? Lampa.Utils.protocol() : 'http://') + 'oplata.z01.online/check.php';[cite: 8]
  var ZPREM_PAY_URL = 'https://oplata.z01.online/pay.php';[cite: 8]
  var ZPREM_TRIAL_URL = (Lampa.Utils && Lampa.Utils.protocol ? Lampa.Utils.protocol() : 'http://') + 'oplata.z01.online/trial.php';[cite: 8]

  var zprem_dropped = false;[cite: 8]
  function zpremDrop(er) {
    if (zprem_dropped || !er || !er.accsdb || Defined.localhost !== ZPREM_SERVER) return false;[cite: 8]
    zprem_dropped = true;[cite: 8]
    Defined.localhost = Z01_FREE;[cite: 8]
    return true;[cite: 8]
  }

  function arrFind(list, test) {
    if (!list) return undefined;[cite: 8]
    for (var i = 0; i < list.length; i++) {
      if (test(list[i], i, list)) return list[i];[cite: 8]
    }
    return undefined;[cite: 8]
  }

  var balansers_with_search;[cite: 8]

  // ===== 4. АВТОСБРОС ТРИАЛА Z01 (НЕ ТРОГАЕТ ЛИЦЕНЗИЮ ТВ) =====
  var unic_id = Lampa.Storage.get('lampac_unic_id', '');[cite: 8]
  if (!unic_id) {
    unic_id = Lampa.Utils.uid(8).toLowerCase();[cite: 8]
    Lampa.Storage.set('lampac_unic_id', unic_id);[cite: 8]
  }

  function resetZ01Uid() {
    unic_id = Lampa.Utils.uid(8).toLowerCase();[cite: 8]
    Lampa.Storage.set('lampac_unic_id', unic_id);[cite: 8]
    return unic_id;[cite: 8]
  }

  function getZ01Email() {
    var trialEmail = Lampa.Storage.get('z01_trial_email', '');[cite: 8]
    if (trialEmail) return trialEmail;[cite: 8]
    var email = Lampa.Storage.get('account_email', '');[cite: 8]
    if (!email) {
      email = 'z01_' + (Lampa.Storage.get('lampac_unic_id', '') || Lampa.Utils.uid(8).toLowerCase()) + '@gmail.com';[cite: 8]
      Lampa.Storage.set('z01_trial_email', email);[cite: 8]
    }
    return email;[cite: 8]
  }

  function rotateZ01TrialEmail() {
    var base = Lampa.Storage.get('account_email', '');[cite: 8]
    var newEmail = '';[cite: 8]
    if (base && base.indexOf('@') !== -1) {
      var parts = base.split('@');[cite: 8]
      var name = parts[0].split('+')[0];[cite: 8]
      newEmail = name + '+z' + Lampa.Utils.uid(5).toLowerCase() + '@' + parts[1];[cite: 8]
    } else {
      newEmail = 'z01_' + Lampa.Utils.uid(8).toLowerCase() + '@gmail.com';[cite: 8]
    }
    Lampa.Storage.set('z01_trial_email', newEmail);[cite: 8]
    return newEmail;[cite: 8]
  }

  function zpremResetTrial(quiet) {
    Lampa.Storage.set('zpremkey', '');[cite: 8]
    Lampa.Storage.set('zprem_expires', '');[cite: 8]
    Lampa.Storage.set('zprem_trial_used', '');[cite: 8]
    resetZ01Uid();[cite: 8]
    rotateZ01TrialEmail();[cite: 8]
    if (!quiet && typeof Lampa !== 'undefined' && Lampa.Noty) {
      Lampa.Noty.show('Демо-режим сброшен, можно активировать заново!');[cite: 8]
    }
  }
  window.zpremResetTrial = zpremResetTrial;[cite: 8]

  function zpremDaysText(days) {
    if (days <= 0) return 'истекла';[cite: 8]
    var n = Math.abs(days) % 100;[cite: 8]
    var n1 = n % 10;[cite: 8]
    if (n > 10 && n < 20) return days + ' дней';[cite: 8]
    if (n1 > 1 && n1 < 5) return days + ' дня';[cite: 8]
    if (n1 == 1) return days + ' день';[cite: 8]
    return days + ' дней';[cite: 8]
  }

  function isZpremActive() {
    var key = Lampa.Storage.get('zpremkey', '');[cite: 8]
    var exp = Lampa.Storage.get('zprem_expires', '');[cite: 8]
    return !!(key && exp && (new Date(exp).getTime() - Date.now() > 0));[cite: 8]
  }

  function zpremCheck(callback) {
    var email = getZ01Email();[cite: 8]
    if (!email) { if (callback) callback(false); return; }[cite: 8]
    var net = new Lampa.Reguest();[cite: 8]
    net.timeout(10000);[cite: 8]
    net.silent(ZPREM_CHECK_URL + '?email=' + encodeURIComponent(email), function(resp) {
      try {
        if (typeof resp === 'string') resp = JSON.parse(resp);[cite: 8]
        if (resp.status === 'active' && resp.zpremkey) {
          Lampa.Storage.set('zpremkey', resp.zpremkey);[cite: 8]
          Lampa.Storage.set('zprem_expires', resp.expires_at);[cite: 8]
          Defined.localhost = ZPREM_SERVER;[cite: 8]
          if (callback) callback(true);[cite: 8]
        } else {
          Lampa.Storage.set('zpremkey', '');[cite: 8]
          Lampa.Storage.set('zprem_expires', '');[cite: 8]
          if (callback) callback(false);[cite: 8]
        }
      } catch(e) { if (callback) callback(false); }[cite: 8]
    }, function() { if (callback) callback(false); });[cite: 8]
  }

  function zpremTrial(callback) {
    if (!isZpremActive()) zpremResetTrial(true);[cite: 8]
    var email = getZ01Email();[cite: 8]
    var uid = Lampa.Storage.get('lampac_unic_id', '');[cite: 8]
    if (!email || !uid) { if (callback) callback(false, 'no_data'); return; }[cite: 8]

    var net = new Lampa.Reguest();[cite: 8]
    net.timeout(10000);[cite: 8]

    function sendTrialRequest(e, u, attempts) {
      attempts = attempts || 0;[cite: 8]
      net.silent(ZPREM_TRIAL_URL + '?email=' + encodeURIComponent(e) + '&uid=' + encodeURIComponent(u), function(resp) {
        try {
          if (typeof resp === 'string') resp = JSON.parse(resp);[cite: 8]
          if (resp.status === 'activated' && resp.zpremkey) {
            Lampa.Storage.set('zpremkey', resp.zpremkey);[cite: 8]
            Lampa.Storage.set('zprem_expires', resp.expires_at);[cite: 8]
            if (resp.prem_url) Lampa.Storage.set('online_url', resp.prem_url);[cite: 8]
            Lampa.Storage.set('zprem_trial_used', '1');[cite: 8]
            Defined.localhost = ZPREM_SERVER;[cite: 8]
            if (callback) callback(true, 'activated');[cite: 8]
          } else if (resp.status === 'already_used' && attempts < 3) {
            sendTrialRequest(rotateZ01TrialEmail(), resetZ01Uid(), attempts + 1);[cite: 8]
          } else {
            if (callback) callback(false, resp.status || 'error');[cite: 8]
          }
        } catch(err) { if (callback) callback(false, 'parse_error'); }[cite: 8]
      }, function() {
        if (callback) callback(false, 'network_error');[cite: 8]
      });
    }

    sendTrialRequest(email, uid, 0);[cite: 8]
  }

  function zpremAutoEnsure(callback) {
    if (!verifyLicense().active) {
      if (callback) callback(false);
      return;
    }
    if (isZpremActive()) {
      Defined.localhost = ZPREM_SERVER;[cite: 8]
      if (callback) callback(true);[cite: 8]
      return;[cite: 8]
    }
    zpremTrial(function(ok) {
      if (ok) {
        Defined.localhost = ZPREM_SERVER;[cite: 8]
        if (callback) callback(true);[cite: 8]
      } else {
        if (callback) callback(false);[cite: 8]
      }
    });
  }

  function zpremActivate() {
    if (verifyLicense().active) {
      if (isZpremActive()) {
        Defined.localhost = ZPREM_SERVER;[cite: 8]
      } else {
        zpremAutoEnsure();[cite: 8]
      }
    }
  }

  window.zpremCheck = zpremCheck;[cite: 8]
  window.zpremDaysText = zpremDaysText;[cite: 8]
  window.zpremTrial = zpremTrial;[cite: 8]
  window.zpremAutoEnsure = zpremAutoEnsure;[cite: 8]

  function getAndroidVersion() {
    if (Lampa.Platform.is('android')) {
      try {
        var current = AndroidJS.appVersion().split('-');[cite: 8]
        return parseInt(current.pop());[cite: 8]
      } catch (e) { return 0; }[cite: 8]
    }
    return 0;[cite: 8]
  }

  var hostkey = 'https://z01.online'.replace('http://', '').replace('https://', '');[cite: 8]

  if (!window.rch_nws || !window.rch_nws[hostkey]) {
    if (!window.rch_nws) window.rch_nws = {};[cite: 8]
    window.rch_nws[hostkey] = {
      type: Lampa.Platform.is('android') ? 'apk' : Lampa.Platform.is('tizen') ? 'cors' : undefined,[cite: 8]
      startTypeInvoke: false,[cite: 8]
      rchRegistry: false,[cite: 8]
      apkVersion: getAndroidVersion()[cite: 8]
    };
  }

  window.rch_nws[hostkey].typeInvoke = function rchtypeInvoke(host, call) {
    if (!window.rch_nws[hostkey].startTypeInvoke) {
      window.rch_nws[hostkey].startTypeInvoke = true;[cite: 8]
      var check = function check(good) {
        window.rch_nws[hostkey].type = Lampa.Platform.is('android') ? 'apk' : good ? 'cors' : 'web';[cite: 8]
        call();[cite: 8]
      };
      if (Lampa.Platform.is('android') || Lampa.Platform.is('tizen')) check(true);[cite: 8]
      else {
        var net = new Lampa.Reguest();[cite: 8]
        net.silent('https://z01.online'.indexOf(location.host) >= 0 ? 'https://github.com/' : host + '/cors/check', function() {
          check(true);[cite: 8]
        }, function() {
          check(false);[cite: 8]
        }, false, { dataType: 'text' });[cite: 8]
      }
    } else call();[cite: 8]
  };

  window.rch_nws[hostkey].Registry = function RchRegistry(client, startConnection) {
    window.rch_nws[hostkey].typeInvoke('https://z01.online', function() {
      client.invoke("RchRegistry", {
        version: 154,[cite: 8]
        host: location.host,[cite: 8]
        rchtype: Lampa.Platform.is('android') ? 'apk' : Lampa.Platform.is('tizen') ? 'cors' : (window.rch_nws[hostkey].type || 'web'),[cite: 8]
        apkVersion: window.rch_nws[hostkey].apkVersion,[cite: 8]
        player: Lampa.Storage.field('player'),[cite: 8]
        account_email: getZ01Email(),[cite: 8]
        unic_id: Lampa.Storage.get('lampac_unic_id', ''),[cite: 8]
        profile_id: Lampa.Storage.get('lampac_profile_id', ''),[cite: 8]
        token: ''[cite: 8]
      });

      if (client._shouldReconnect && window.rch_nws[hostkey].rchRegistry) {
        if (startConnection) startConnection();[cite: 8]
        return;[cite: 8]
      }
      window.rch_nws[hostkey].rchRegistry = true;[cite: 8]

      client.on('RchRegistry', function(clientIp) {
        if (startConnection) startConnection();[cite: 8]
      });

      client.on("RchClient", function(rchId, url, data, headers, returnHeaders) {
        var network = new Lampa.Reguest();[cite: 8]
        var rchOrigin = (client && client.url) ? client.url.replace(/^ws(s?):\/\/([^\/?#]+).*/, 'http$1://$2') : 'https://z01.online';[cite: 8]

        function sendResult(uri, html) {
          $.ajax({
            url: rchOrigin + '/rch/' + uri + '?id=' + rchId,[cite: 8]
            type: 'POST',[cite: 8]
            data: html,[cite: 8]
            async: true,[cite: 8]
            cache: false,[cite: 8]
            contentType: false,[cite: 8]
            processData: false,[cite: 8]
            success: function(j) {},[cite: 8]
            error: function() { client.invoke("RchResult", rchId, ''); }[cite: 8]
          });
        }

        function result(html) {
          if (Lampa.Arrays.isObject(html) || Lampa.Arrays.isArray(html)) {
            html = JSON.stringify(html);[cite: 8]
          }
          if (typeof CompressionStream !== 'undefined' && html && html.length > 2000) {
            var compressionStream = new CompressionStream('gzip');[cite: 8]
            var encoder = new TextEncoder();[cite: 8]
            var readable = new ReadableStream({
              start: function(controller) {
                controller.enqueue(encoder.encode(html));[cite: 8]
                controller.close();[cite: 8]
              }
            });
            var compressedStream = readable.pipeThrough(compressionStream);[cite: 8]
            new Response(compressedStream).arrayBuffer().then(function(compressedBuffer) {
              var compressedArray = new Uint8Array(compressedBuffer);[cite: 8]
              if (compressedArray.length > html.length) {
                sendResult('result', html);[cite: 8]
              } else {
                sendResult('gzresult', new Blob([compressedArray], { type: 'application/octet-stream' }));[cite: 8]
              }
            })['catch'](function() { sendResult('result', html); });[cite: 8]
          } else {
            sendResult('result', html);[cite: 8]
          }
        }

        if (url == 'eval') result(eval(data));[cite: 8]
        else if (url == 'evalrun') eval(data);[cite: 8]
        else if (url == 'ping') result('pong');[cite: 8]
        else {
          network["native"](url, result, function(e) { result(''); }, data, {
            dataType: 'text',[cite: 8]
            timeout: 1000 * 8,[cite: 8]
            headers: headers,[cite: 8]
            returnHeaders: returnHeaders[cite: 8]
          });
        }
      });

      client.on('Connected', function(connectionId) { window.rch_nws[hostkey].connectionId = connectionId; });[cite: 8]
      client.on('Closed', function() {});[cite: 8]
      client.on('Error', function(err) {});[cite: 8]
    });
  };
  window.rch_nws[hostkey].typeInvoke('https://z01.online', function() {});[cite: 8]

  function rchInvoke(json, call) {
    if (window.nwsClient && window.nwsClient[hostkey] && window.nwsClient[hostkey]._shouldReconnect){
      call();[cite: 8]
      return;[cite: 8]
    }
    if (!window.nwsClient) window.nwsClient = {};[cite: 8]
    if (window.nwsClient[hostkey] && window.nwsClient[hostkey].socket) window.nwsClient[hostkey].socket.close();[cite: 8]
    window.nwsClient[hostkey] = new NativeWsClient(json.nws, { autoReconnect: false });[cite: 8]
    window.nwsClient[hostkey].on('Connected', function(connectionId) {
      window.rch_nws[hostkey].Registry(window.nwsClient[hostkey], function() { call(); });[cite: 8]
    });
    window.nwsClient[hostkey].connect();[cite: 8]
  }

  function rchRun(json, call) {
    if (typeof NativeWsClient == 'undefined') {
      Lampa.Utils.putScript(["https://z01.online/js/nws-client-es5.js?v03022026"], function() {}, false, function() {
        rchInvoke(json, call);[cite: 8]
      }, true);[cite: 8]
    } else {
      rchInvoke(json, call);[cite: 8]
    }
  }

  function account(url) {
    url = url + '';[cite: 8]
    if (url.indexOf('account_email=') == -1) {
      var email = getZ01Email();[cite: 8]
      if (email) url = Lampa.Utils.addUrlComponent(url, 'account_email=' + encodeURIComponent(email));[cite: 8]
    }
    if (url.indexOf('uid=') == -1) {
      var uid = Lampa.Storage.get('lampac_unic_id', '');[cite: 8]
      if (uid) url = Lampa.Utils.addUrlComponent(url, 'uid=' + encodeURIComponent(uid));[cite: 8]
    }
    if (url.indexOf('token=') == -1) {
      var token = '';[cite: 8]
      if (token != '') url = Lampa.Utils.addUrlComponent(url, 'token=');[cite: 8]
    }
    if (url.indexOf('nws_id=') == -1 && window.rch_nws && window.rch_nws[hostkey]) {
      var nws_id = window.rch_nws[hostkey].connectionId || Lampa.Storage.get('lampac_nws_id', '');[cite: 8]
      if (nws_id) url = Lampa.Utils.addUrlComponent(url, 'nws_id=' + encodeURIComponent(nws_id));[cite: 8]
    }
    return url;[cite: 8]
  }

  var synced_balansers = {};[cite: 8]
  function syncBalanser(name) {
    if (!name || synced_balansers[name] || !Lampa.Manifest || Lampa.Manifest.app_digital < 177 || !Lampa.Storage.sync) return;[cite: 8]
    synced_balansers[name] = true;[cite: 8]
    Lampa.Storage.sync('online_choice_' + name, 'object_object');[cite: 8]
  }

  var Network = Lampa.Reguest;[cite: 8]

  // ===== 5. UI МОДУЛЬ Z01 =====
  var Z01UI = {};[cite: 8]
  Z01UI.enabled = function() { return Lampa.Storage.get('z01_ui_mode', 'modern') !== 'classic'; };[cite: 8]
  Z01UI.REQUEST_TIMEOUT = 20000;[cite: 8]
  Z01UI.WATCHDOG = 24;[cite: 8]
  Z01UI.WATCHDOG_FIRST = 40;[cite: 8]

  Z01UI.esc = function(str) {
    return (str === undefined || str === null ? '' : String(str))
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');[cite: 8]
  };

  Z01UI.shortQuality = function(text) {
    if (!text) return '';[cite: 8]
    text = String(text);[cite: 8]
    var match = text.match(/(2160|1440|1080|720|576|480|360)\s*p?/i);[cite: 8]
    if (match) {
      var value = parseInt(match[1]);[cite: 8]
      if (value >= 2160) return '4K';[cite: 8]
      if (value >= 1080) return 'FHD';[cite: 8]
      if (value >= 720) return 'HD';[cite: 8]
      return 'SD';[cite: 8]
    }
    if (/4k|uhd/i.test(text)) return '4K';[cite: 8]
    if (/fhd/i.test(text)) return 'FHD';[cite: 8]
    if (/\bhd\b/i.test(text)) return 'HD';[cite: 8]
    return '';[cite: 8]
  };

  Z01UI.VOICE_KINDS = [
    { key: 'dub', title: 'z01_voice_dub', re: /дубляж|дублирован|\bdub\b|\bdubbing\b/i },[cite: 8]
    { key: 'mvo', title: 'z01_voice_mvo', re: /многоголос|\bmvo\b|\bpmvo\b/i },[cite: 8]
    { key: 'dvo', title: 'z01_voice_dvo', re: /двухголос|\bdvo\b/i },[cite: 8]
    { key: 'avo', title: 'z01_voice_avo', re: /авторск|одноголос|\bavo\b|\bvo\b/i },[cite: 8]
    { key: 'orig', title: 'z01_voice_orig', re: /оригинал|original|\beng\b|\bua\b|\bukr\b/i },[cite: 8]
    { key: 'sub', title: 'z01_voice_sub', re: /субтитр|sub(title)?s?\b/i }[cite: 8]
  ];[cite: 8]

  Z01UI.VOICE_STUDIOS = [
    { key: 'mvo', re: /lostfilm|лостфильм|tvshows|dniprofilm|невафильм|newstudio|newcomers|baibako|байбако|alexfilm|jaskier|coldfilm|колдфильм|hdrezka|rezkastudio|red head sound|sunshine|amedia|zakadry|закадры|linefilm|le-production|1win|kerob|profix|selena|октопус/i },[cite: 8]
    { key: 'dvo', re: /кубик в кубе|kubik|viruseproject|вирус|green ?tea|paradox/i },[cite: 8]
    { key: 'avo', re: /яроцк|гаврилов|володарск|сербин|горчаков|михал[её]в|живов|пучков|гоблин|кураж|дольск|есарев|карповск|визгунов/i }[cite: 8]
  ];[cite: 8]

  Z01UI.voiceKind = function(title) {
    var text = String(title || '');[cite: 8]
    var i;[cite: 8]
    for (i = 0; i < Z01UI.VOICE_KINDS.length; i++) {
      if (Z01UI.VOICE_KINDS[i].re.test(text)) return Z01UI.VOICE_KINDS[i].key;[cite: 8]
    }
    for (i = 0; i < Z01UI.VOICE_STUDIOS.length; i++) {
      if (Z01UI.VOICE_STUDIOS[i].re.test(text)) return Z01UI.VOICE_STUDIOS[i].key;[cite: 8]
    }
    return 'other';[cite: 8]
  };

  Z01UI.voiceKindTitle = function(key) {
    for (var i = 0; i < Z01UI.VOICE_KINDS.length; i++) {
      if (Z01UI.VOICE_KINDS[i].key == key) return Lampa.Lang.translate(Z01UI.VOICE_KINDS[i].title);[cite: 8]
    }
    return Lampa.Lang.translate('z01_voice_other');[cite: 8]
  };

  Z01UI.voiceGroups = function(list) {
    var order = [];[cite: 8]
    var map = {};[cite: 8]
    (list || []).forEach(function(entry, index) {
      var key = Z01UI.voiceKind(entry.title);[cite: 8]
      if (!map[key]) {
        map[key] = { key: key, title: Z01UI.voiceKindTitle(key), items: [] };[cite: 8]
        order.push(key);[cite: 8]
      }
      map[key].items.push({ index: index, title: entry.title, url: entry.url });[cite: 8]
    });
    var rank = function(key) {
      for (var i = 0; i < Z01UI.VOICE_KINDS.length; i++) {
        if (Z01UI.VOICE_KINDS[i].key == key) return i;[cite: 8]
      }
      return 90;[cite: 8]
    };
    order.sort(function(a, b) { return rank(a) - rank(b); });[cite: 8]
    return order.map(function(key) { return map[key]; });[cite: 8]
  };

  Z01UI.splitSourceName = function(name) {
    name = String(name || '');[cite: 8]
    var badge = '';[cite: 8]
    var match = name.match(/\s*[-~–]\s*(2160p?|1440p?|1080p?|720p?|480p?|4k|uhd|fhd|hd)\b[^,]*$/i);[cite: 8]
    if (match) {
      badge = Z01UI.shortQuality(match[1]);[cite: 8]
      if (badge) name = name.slice(0, match.index);[cite: 8]
    }
    return { name: name.replace(/\s+$/, ''), badge: badge };[cite: 8]
  };

  Z01UI.isSeasonLabel = function(text) {
    text = String(text || '').trim();[cite: 8]
    return /^\d+\s*(-?[йя])?\s*(сезон|season)$/i.test(text) || /^(сезон|season)\s*\d+$/i.test(text);[cite: 8]
  };

  Z01UI.MOVIE_ONLY = ['xvideocdnultra', 'xvideocdn60fps'];[cite: 8]
  Z01UI.isMovieOnlySource = function(key, title) {
    if (Z01UI.MOVIE_ONLY.indexOf(String(key || '').toLowerCase()) !== -1) return true;[cite: 8]
    return /^xvideocdn/i.test(key || '') && /ultra|60\s*\/?\s*120|60fps/i.test(title || '');[cite: 8]
  };

  Z01UI.payLink = function(answer) {
    if (!answer) return '';[cite: 8]
    var fields = ['url', 'link', 'pay', 'pay_url', 'payurl', 'buy', 'account'];[cite: 8]
    for (var i = 0; i < fields.length; i++) {
      var value = answer[fields[i]];[cite: 8]
      if (typeof value === 'string' && /^https?:\/\//i.test(value)) return value;[cite: 8]
    }
    var text = String(answer.msg || answer.message || answer.text || '');[cite: 8]
    var match = text.match(/https?:\/\/[^\s"'<>)]+/i);[cite: 8]
    return match ? match[0] : '';[cite: 8]
  };

  Z01UI.serverDenial = function(answer) {
    if (!answer || typeof answer !== 'object') return null;[cite: 8]
    var denied = !!(answer.accsdb || answer.blocked || answer.error || (typeof answer.code === 'number' && answer.code >= 300));[cite: 8]
    if (!denied) return null;[cite: 8]
    var text = String(answer.msg || answer.message || answer.text || '');[cite: 8]
    var own_image = /<img|qr-code|qrcode/i.test(text);[cite: 8]
    return {
      msg: text || Lampa.Lang.translate('z01_no_access_text'),[cite: 8]
      link: own_image ? '' : Z01UI.payLink(answer)[cite: 8]
    };
  };

  Z01UI.qrImage = function(link, size) {
    size = size || 300;[cite: 8]
    return 'https://api.qrserver.com/v1/create-qr-code/?size=' + size + 'x' + size + '&margin=10&data=' + encodeURIComponent(link);[cite: 8]
  };

  Z01UI.providerName = function(url) {
    var path = String(url || '').split('?')[0].split('#')[0];[cite: 8]
    var parts = path.split('/');[cite: 8]
    var last = '';[cite: 8]
    while (parts.length && !last) last = parts.pop();[cite: 8]
    return last;[cite: 8]
  };

  Z01UI.seasonNumber = function(title) {
    var match = String(title || '').match(/\d+/);[cite: 8]
    return match ? parseInt(match[0]) : 0;[cite: 8]
  };

  Z01UI.normName = function(text) {
    text = String(text === undefined || text === null ? '' : text).toLowerCase();[cite: 8]
    text = text.replace(/\u0451/g, '\u0435').replace(/[^0-9a-z\u0430-\u044f]+/g, ' ');[cite: 8]
    return text.replace(/^\s+/, '').replace(/\s+$/, '');[cite: 8]
  };

  Z01UI.nameParts = function(text) {
    var raw = String(text || '').split(/\s*[\/|]\s*/);[cite: 8]
    var out = [];[cite: 8]
    for (var i = 0; i < raw.length; i++) {
      var norm = Z01UI.normName(raw[i]);[cite: 8]
      if (norm) out.push(norm);[cite: 8]
    }
    return out;[cite: 8]
  };

  Z01UI.yearOf = function(value) {
    var match = String(value === undefined || value === null ? '' : value).match(/\d{4}/);[cite: 8]
    var year = match ? parseInt(match[0], 10) : 0;[cite: 8]
    return year > 1900 && year < 2200 ? year : 0;[cite: 8]
  };

  Z01UI.movieNames = function(movie) {
    var fields = ['title', 'name', 'original_title', 'original_name'];[cite: 8]
    var out = [];[cite: 8]
    for (var i = 0; i < fields.length; i++) {
      var parts = Z01UI.nameParts(movie && movie[fields[i]]);[cite: 8]
      for (var j = 0; j < parts.length; j++) {
        if (out.indexOf(parts[j]) === -1) out.push(parts[j]);[cite: 8]
      }
    }
    return out;[cite: 8]
  };

  Z01UI.matchScore = function(elem, movie) {
    if (!elem || !movie) return 0;[cite: 8]
    var mine = Z01UI.movieNames(movie);[cite: 8]
    var theirs = Z01UI.nameParts(elem.title || elem.text || '');[cite: 8]
    var score = 0;[cite: 8]
    for (var i = 0; i < theirs.length; i++) {
      for (var j = 0; j < mine.length; j++) {
        var a = theirs[i];[cite: 8]
        var b = mine[j];[cite: 8]
        var hit = 0;[cite: 8]
        if (a === b) hit = 60;[cite: 8]
        else if (a.length > 3 && b.length > 3 && (a.indexOf(b) === 0 || b.indexOf(a) === 0)) hit = 34;[cite: 8]
        else if (a.length > 5 && b.length > 5 && (a.indexOf(b) !== -1 || b.indexOf(a) !== -1)) hit = 22;[cite: 8]
        if (hit > score) score = hit;[cite: 8]
      }
    }
    var my_year = Z01UI.yearOf(movie.release_date || movie.first_air_date || movie.year);[cite: 8]
    var their_year = Z01UI.yearOf(elem.year || elem.start_date);[cite: 8]
    if (my_year && their_year) {
      var diff = Math.abs(my_year - their_year);[cite: 8]
      if (diff === 0) score += 34;[cite: 8]
      else if (diff === 1) score += 16;[cite: 8]
      else score -= 30;[cite: 8]
    }
    return score;[cite: 8]
  };

  Z01UI.rankSimilars = function(list, movie) {
    var ranked = [];[cite: 8]
    for (var i = 0; i < (list || []).length; i++) {
      ranked.push({ elem: list[i], index: i, score: Z01UI.matchScore(list[i], movie) });[cite: 8]
    }
    ranked.sort(function(a, b) { return b.score - a.score || a.index - b.index; });[cite: 8]
    var best = ranked[0];[cite: 8]
    var second = ranked[1];[cite: 8]
    var gap = best ? best.score - (second ? second.score : -100) : 0;[cite: 8]
    return {
      list: ranked,[cite: 8]
      best: best || null,[cite: 8]
      likely: !!(best && best.score >= 45 && gap >= 10),[cite: 8]
      sure: !!(best && best.score >= 70 && gap >= 25)[cite: 8]
    };
  };

  Z01UI.SEEN_PERCENT = 90;[cite: 8]
  Z01UI.isSeen = function(element, viewed) {
    if (!element) return false;[cite: 8]
    if (element.hash_behold && viewed && viewed.indexOf(element.hash_behold) !== -1) return true;[cite: 8]
    var line = element.timeline;[cite: 8]
    return !!(line && line.percent >= Z01UI.SEEN_PERCENT);[cite: 8]
  };

  Z01UI.QUALITY_RANK = { '4K': 4, 'FHD': 3, 'HD': 2, 'SD': 1 };[cite: 8]
  Z01UI.qualityRank = function(label) { return Z01UI.QUALITY_RANK[label] || 0; };[cite: 8]
  Z01UI.reachKey = function(movie) {
    if (!movie) return '';[cite: 8]
    return Lampa.Utils.hash(movie.original_name || movie.original_title || movie.name || movie.title || '');[cite: 8]
  };

  Z01UI.bestQuality = function(items) {
    var best = '';[cite: 8]
    for (var i = 0; i < (items || []).length; i++) {
      var item = items[i] || {};[cite: 8]
      var label = '';[cite: 8]
      var quality = item.quality || item.qualitys;[cite: 8]
      if (quality && typeof quality === 'object') label = Lampa.Arrays.getKeys(quality).join(' ');[cite: 8]
      else if (quality) label = String(quality);[cite: 8]
      var found = Z01UI.qualityFromText(label) || Z01UI.qualityFromText(item.title || item.text || '');[cite: 8]
      if (Z01UI.qualityRank(found) > Z01UI.qualityRank(best)) best = found;[cite: 8]
    }
    return best;[cite: 8]
  };

  Z01UI.qualityFromText = function(text) {
    text = String(text === undefined || text === null ? '' : text);[cite: 8]
    var best = '';[cite: 8]
    var re = /(?:^|[^\d])(2160|1440|1080|720|576|480)\s*p?(?![\d])/gi;[cite: 8]
    var found;[cite: 8]
    while ((found = re.exec(text))) {
      var label = Z01UI.shortQuality(found[1] + 'p');[cite: 8]
      if (Z01UI.qualityRank(label) > Z01UI.qualityRank(best)) best = label;[cite: 8]
    }
    if (/4k|uhd/i.test(text) && Z01UI.qualityRank('4K') > Z01UI.qualityRank(best)) best = '4K';[cite: 8]
    if (!best && /fhd/i.test(text)) best = 'FHD';[cite: 8]
    return best;[cite: 8]
  };

  Z01UI.knownQuality = function(name) { return Lampa.Storage.cache('z01_source_quality', 500, {})[name] || ''; };[cite: 8]
  Z01UI.rememberQuality = function(name, label) {
    if (!name || !label) return;[cite: 8]
    var all = Lampa.Storage.cache('z01_source_quality', 500, {});[cite: 8]
    if (Z01UI.qualityRank(label) <= Z01UI.qualityRank(all[name])) return;[cite: 8]
    all[name] = label;[cite: 8]
    Lampa.Storage.set('z01_source_quality', all);[cite: 8]
  };

  Z01UI.sourceBadge = function(name, parts) {
    return Z01UI.knownQuality(name) || (parts ? parts.badge : '');[cite: 8]
  };

  Z01UI.reachEntry = function(movie, season) {
    var all = Lampa.Storage.cache('z01_reach', 2000, {});[cite: 8]
    var mine = all[Z01UI.reachKey(movie)] || {};[cite: 8]
    var value = mine[season || 1];[cite: 8]
    if (typeof value === 'number') return { e: value, l: value, r: 2 };[cite: 8]
    if (value && typeof value === 'object') {
      return { e: parseInt(value.e, 10) || 0, l: parseInt(value.l, 10) || 0, r: parseInt(value.r, 10) || 0 };[cite: 8]
    }
    return { e: 0, l: 0, r: 0 };[cite: 8]
  };

  Z01UI.reached = function(movie, season) { return Z01UI.reachEntry(movie, season).e; };[cite: 8]
  Z01UI.setReach = function(movie, season, episode) {
    episode = parseInt(episode, 10) || 0;[cite: 8]
    var key = Z01UI.reachKey(movie);[cite: 8]
    if (!key) return;[cite: 8]
    var all = Lampa.Storage.cache('z01_reach', 2000, {});[cite: 8]
    var mine = all[key] || {};[cite: 8]
    mine[season || 1] = { e: episode, l: episode, r: episode ? 2 : 0 };[cite: 8]
    all[key] = mine;[cite: 8]
    Lampa.Storage.set('z01_reach', all);[cite: 8]
  };

  Z01UI.rememberReach = function(movie, season, episode) {
    episode = parseInt(episode, 10) || 0;[cite: 8]
    var key = Z01UI.reachKey(movie);[cite: 8]
    if (!episode || !key) return;[cite: 8]
    var entry = Z01UI.reachEntry(movie, season);[cite: 8]
    if (episode === entry.l || episode === entry.l + 1) entry.r = (entry.r || 0) + 1;[cite: 8]
    else entry.r = 1;[cite: 8]
    entry.l = episode;[cite: 8]
    if (!entry.e || entry.r >= 2 || episode === entry.e + 1) entry.e = episode;[cite: 8]
    var all = Lampa.Storage.cache('z01_reach', 2000, {});[cite: 8]
    var mine = all[key] || {};[cite: 8]
    mine[season || 1] = { e: entry.e, l: entry.l, r: entry.r };[cite: 8]
    all[key] = mine;[cite: 8]
    Lampa.Storage.set('z01_reach', all);[cite: 8]
  };

  Z01UI.episodeNumber = function(value) {
    var num = parseInt(value, 10);[cite: 8]
    if (!num && num !== 0) return String(value === undefined || value === null ? '' : value);[cite: 8]
    return num < 10 ? '0' + num : String(num);[cite: 8]
  };

  Z01UI.icon = {
    play: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"></path></svg>',[cite: 8]
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M4 12l5 5L20 6" stroke-linecap="round" stroke-linejoin="round"></path></svg>',[cite: 8]
    chevron: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6"><path d="M6 9l6 6 6-6" stroke-linecap="round" stroke-linejoin="round"></path></svg>',[cite: 8]
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="11" cy="11" r="7"></circle><path d="M20 20l-4-4" stroke-linecap="round"></path></svg>',[cite: 8]
    refresh: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M20 11a8 8 0 10-2.3 5.7" stroke-linecap="round"></path><path d="M20 4v7h-7" stroke-linecap="round" stroke-linejoin="round"></path></svg>',[cite: 8]
    warn: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M12 4l9 16H3z" stroke-linejoin="round"></path><path d="M12 10v4" stroke-linecap="round"></path><circle cx="12" cy="17" r="0.6" fill="currentColor"></circle></svg>'[cite: 8]
  };[cite: 8]

  Z01UI.css = [
    '<style>',[cite: 8]
    '.mo{padding:0 0 3em 0}',[cite: 8]
    '.mo *{-webkit-box-sizing:border-box;box-sizing:border-box}',[cite: 8]
    '.mo-head{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-ms-flex-align:center;align-items:center;padding:0 .2em .7em .2em}',[cite: 8]
    '.mo-head__art{position:relative;width:4.6em;height:6.6em;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0;margin-right:1.1em;background:rgba(255,255,255,.07);-webkit-border-radius:.35em;border-radius:.35em;overflow:hidden}',[cite: 8]
    '.mo-head__art img{position:absolute;top:0;left:0;width:100%;height:100%;-o-object-fit:cover;object-fit:cover;opacity:0;-webkit-transition:opacity .3s;transition:opacity .3s}',[cite: 8]
    '.mo-head__art--loaded img{opacity:1}',[cite: 8]
    '.mo-head__text{-webkit-box-flex:1;-webkit-flex:1 1 auto;-ms-flex:1 1 auto;flex:1 1 auto;min-width:0;padding-right:1em}',[cite: 8]
    '.mo-head__sub{font-size:1em;opacity:.45;line-height:1.3;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 8]
    '.mo-head__title{font-size:1.7em;font-weight:600;line-height:1.2;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 8]
    '.mo-head__note{font-size:1.05em;opacity:.7;white-space:nowrap;padding-bottom:.15em}',[cite: 8]
    '.mo-head__bar{position:relative;height:.25em;-webkit-border-radius:.25em;border-radius:.25em;background:rgba(255,255,255,.12);margin:0 .2em 1.4em .2em;overflow:hidden}',[cite: 8]
    '.mo-head__fill{position:absolute;left:0;top:0;bottom:0;background:#7cc4ff}',[cite: 8]
    '.mo-head--hidden{display:none}',[cite: 8]
    '.mo-panel{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-flex-wrap:wrap;-ms-flex-wrap:wrap;flex-wrap:wrap;margin:0 0 1.3em 0}',[cite: 8]
    '.mo-seg{position:relative;min-width:11em;max-width:24em;padding:.6em 2.2em .6em 1em;margin:0 .8em .6em 0;background:rgba(255,255,255,.08);-webkit-border-radius:.35em;border-radius:.35em;line-height:1.25}',[cite: 8]
    '.mo-seg__name{font-size:.75em;letter-spacing:.06em;text-transform:uppercase;opacity:.5}',[cite: 8]
    '.mo-seg__value{font-size:1.15em;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 8]
    '.mo-seg__mark{font-size:.68em;font-weight:600;padding:.1em .4em;margin-right:.5em;background:rgba(255,255,255,.2);-webkit-border-radius:.25em;border-radius:.25em;vertical-align:.15em}',[cite: 8]
    '.mo-seg__arrow{position:absolute;right:.9em;top:50%;margin-top:-.2em;width:0;height:0;border-left:.4em solid transparent;border-right:.4em solid transparent;border-top:.45em solid rgba(255,255,255,.55)}',[cite: 8]
    '.mo-seg.focus{background:#fff;color:#000}',[cite: 8]
    '.mo-seg.focus .mo-seg__name{opacity:.6}',[cite: 8]
    '.mo-seg.focus .mo-seg__mark{background:rgba(0,0,0,.15)}',[cite: 8]
    '.mo-seg.focus .mo-seg__arrow{border-top-color:rgba(0,0,0,.6)}',[cite: 8]
    '.mo-seg--open{background:rgba(124,196,255,.22)}',[cite: 8]
    '.mo-grid{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-flex-wrap:wrap;-ms-flex-wrap:wrap;flex-wrap:wrap;margin:0 -.3em 1.4em -.3em}',[cite: 8]
    '.mo-opt{width:25%;padding:0 .3em .6em .3em}',[cite: 8]
    '.mo-opt__in{position:relative;padding:.65em .8em;min-height:3.1em;background:rgba(255,255,255,.07);-webkit-border-radius:.35em;border-radius:.35em;line-height:1.3;overflow:hidden}',[cite: 8]
    '.mo-opt__label{display:block;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 8]
    '.mo-opt__note{display:block;font-size:.8em;opacity:.5;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 8]
    '.mo-opt.focus .mo-opt__in{background:#fff;color:#000}',[cite: 8]
    '.mo-opt.focus .mo-opt__note{opacity:.6}',[cite: 8]
    '.mo-opt--active .mo-opt__in{-webkit-box-shadow:inset 0 0 0 .12em #7cc4ff;box-shadow:inset 0 0 0 .12em #7cc4ff}',[cite: 8]
    '.mo-opt__tag{display:inline-block;min-width:2.4em;text-align:center;font-size:.7em;font-weight:600;background:rgba(255,255,255,.18);-webkit-border-radius:.25em;border-radius:.25em;padding:.1em .3em;margin-right:.5em;vertical-align:.15em}',[cite: 8]
    '.mo-opt.focus .mo-opt__tag{background:rgba(0,0,0,.14)}',[cite: 8]
    '.mo-tiles{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-flex-wrap:wrap;-ms-flex-wrap:wrap;flex-wrap:wrap;margin:0 -.45em}',[cite: 8]
    '.mo-tile{width:25%;padding:0 .45em 1.1em .45em}',[cite: 8]
    '.mo-tile__art{position:relative;padding-top:56%;background:rgba(255,255,255,.08);-webkit-border-radius:.4em;border-radius:.4em;overflow:hidden}',[cite: 8]
    '.mo-tile__art img{position:absolute;top:0;left:0;width:100%;height:100%;-o-object-fit:cover;object-fit:cover;opacity:0;-webkit-transition:opacity .3s;transition:opacity .3s}',[cite: 8]
    '.mo-tile__art--loaded img{opacity:1}',[cite: 8]
    '.mo-tile__num{position:absolute;left:.5em;top:.45em;font-size:1.1em;font-weight:700;padding:.05em .45em;background:rgba(0,0,0,.55);-webkit-border-radius:.25em;border-radius:.25em}',[cite: 8]
    '.mo-tile__tag{position:absolute;right:.5em;top:.45em;font-size:.72em;font-weight:600;padding:.15em .4em;background:rgba(0,0,0,.55);-webkit-border-radius:.25em;border-radius:.25em}',[cite: 8]
    '.mo-tile__time{position:absolute;right:.5em;bottom:.5em;font-size:.8em;padding:.1em .4em;background:rgba(0,0,0,.55);-webkit-border-radius:.25em;border-radius:.25em}',[cite: 8]
    '.mo-tile__check{position:absolute;left:.5em;bottom:.5em;width:1.5em;height:1.5em;padding:.25em;color:#0b0c12;background:#7bd88f;-webkit-border-radius:100%;border-radius:100%}',[cite: 8]
    '.mo-tile__check svg{width:100%;height:100%}',[cite: 8]
    '.mo-tile__line{position:absolute;left:0;right:0;bottom:0;height:.25em}',[cite: 8]
    '.mo-tile__line .time-line{display:block !important;height:100%;margin:0;background:rgba(0,0,0,.5)}',[cite: 8]
    '.mo-tile__line .time-line>div{background:#7cc4ff}',[cite: 8]
    '.mo-tile__body{padding:.5em .15em 0 .15em}',[cite: 8]
    '.mo-tile__title{font-size:1.05em;line-height:1.35;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 8]
    '.mo-tile__meta{font-size:.85em;opacity:.5;line-height:1.4;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 8]
    '.mo-tile__meta span+span:before{content:" · "}',[cite: 8]
    '.mo-tile--seen .mo-tile__art img{opacity:.45}',[cite: 8]
    '.mo-tile--seen .mo-tile__title{opacity:.6}',[cite: 8]
    '.mo-tile.focus .mo-tile__art{-webkit-box-shadow:0 0 0 .2em #fff;box-shadow:0 0 0 .2em #fff}',[cite: 8]
    '.mo-tile--current .mo-tile__art{-webkit-box-shadow:0 0 0 .16em #7cc4ff;box-shadow:0 0 0 .16em #7cc4ff}',[cite: 8]
    '.mo-tile.focus.mo-tile--current .mo-tile__art{-webkit-box-shadow:0 0 0 .2em #fff;box-shadow:0 0 0 .2em #fff}',[cite: 8]
    '.mo-tile--soon{opacity:.45}',[cite: 8]
    '.mo-line{position:relative;display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-ms-flex-align:center;align-items:center;padding:.6em 1em .65em .6em;margin-bottom:.45em;background:rgba(255,255,255,.06);-webkit-border-radius:.4em;border-radius:.4em}',[cite: 8]
    '.mo-line__art{position:relative;width:4.4em;height:4.4em;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0;margin-right:1em;background:rgba(255,255,255,.08);-webkit-border-radius:.3em;border-radius:.3em;overflow:hidden}',[cite: 8]
    '.mo-line__art img{position:absolute;top:0;left:0;width:100%;height:100%;-o-object-fit:cover;object-fit:cover;opacity:0;-webkit-transition:opacity .3s;transition:opacity .3s}',[cite: 8]
    '.mo-line__art--loaded img{opacity:1}',[cite: 8]
    '.mo-line__time{font-size:.9em;opacity:.6;margin-left:.7em}',[cite: 8]
    '.mo-line__line{position:absolute;left:6.2em;right:1em;bottom:.35em;height:.16em}',[cite: 8]
    '.mo-line__line .time-line{display:block !important;height:100%;margin:0;background:rgba(255,255,255,.14);-webkit-border-radius:.16em;border-radius:.16em;overflow:hidden}',[cite: 8]
    '.mo-line__line .time-line>div{background:#7cc4ff}',[cite: 8]
    '.mo-line.focus .mo-line__line .time-line{background:rgba(0,0,0,.15)}',[cite: 8]
    '.mo-line.focus{background:#fff;color:#000}',[cite: 8]
    '.mo-line--current{-webkit-box-shadow:inset .18em 0 0 #7cc4ff;box-shadow:inset .18em 0 0 #7cc4ff}',[cite: 8]
    '.mo-line__tag{font-size:.72em;font-weight:600;background:rgba(255,255,255,.18);-webkit-border-radius:.25em;border-radius:.25em;padding:.15em .45em;margin-left:.7em}',[cite: 8]
    '.mo-line.focus .mo-line__tag{background:rgba(0,0,0,.14)}',[cite: 8]
    '.mo-line__body{-webkit-box-flex:1;-webkit-flex:1 1 auto;-ms-flex:1 1 auto;flex:1 1 auto;min-width:0}',[cite: 8]
    '.mo-line__title{font-size:1.15em;line-height:1.35;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 8]
    '.mo-line__note{font-size:.85em;opacity:.55;line-height:1.4;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 8]
    '.mo-line__side{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-ms-flex-align:center;align-items:center;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0;padding-left:1em}',[cite: 8]
    '.mo-line--nav .mo-line__side:after{content:"›";font-size:1.5em;opacity:.6}',[cite: 8]
    '.mo-info{padding:1.4em .2em}',[cite: 8]
    '.mo-info__title{font-size:1.5em;font-weight:600;margin-bottom:.4em}',[cite: 8]
    '.mo-info__text{font-size:1.05em;line-height:1.5;opacity:.7;margin-bottom:1.1em;max-width:44em}',[cite: 8]
    '.mo-info__text img{max-width:12em;margin-top:.8em;display:block}',[cite: 8]
    '.mo-info__link{font-size:.95em;opacity:.5;word-break:break-all;margin-bottom:1em}',[cite: 8]
    '.mo-info__qr{margin-bottom:1.1em}',[cite: 8]
    '.mo-info__qr img{display:block;width:11em;height:11em;background:#fff;padding:.4em;-webkit-border-radius:.4em;border-radius:.4em}',[cite: 8]
    '.mo-info__acts{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-flex-wrap:wrap;-ms-flex-wrap:wrap;flex-wrap:wrap}',[cite: 8]
    '.mo-act{padding:.6em 1.4em;margin:0 .8em .6em 0;background:rgba(255,255,255,.12);-webkit-border-radius:.35em;border-radius:.35em;font-size:1.05em;white-space:nowrap}',[cite: 8]
    '.mo-act.focus{background:#fff;color:#000}',[cite: 8]
    '.mo-act>svg{width:1.1em;height:1.1em;margin-right:.5em;vertical-align:-.15em}',[cite: 8]
    '.mo-wait{width:100%;padding:.2em .2em 1.2em .2em}',[cite: 8]
    '.mo-wait__head{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-box-align:baseline;-webkit-align-items:baseline;-ms-flex-align:baseline;align-items:baseline;margin-bottom:.5em}',[cite: 8]
    '.mo-wait__title{font-size:1.25em;padding-right:.8em;-webkit-box-flex:1;-webkit-flex:1 1 auto;-ms-flex:1 1 auto;flex:1 1 auto}',[cite: 8]
    '.mo-wait__count{font-size:.95em;opacity:.55}',[cite: 8]
    '.mo-wait__bar{position:relative;height:.25em;width:100%;max-width:24em;-webkit-border-radius:.25em;border-radius:.25em;background:rgba(255,255,255,.12);overflow:hidden}',[cite: 8]
    '.mo-wait__fill{position:absolute;left:0;top:0;bottom:0;background:#7cc4ff;-webkit-transition:width .4s;transition:width .4s}',[cite: 8]
    '@media screen and (max-width:1300px){.mo-opt{width:33.333%}.mo-tile{width:33.333%}}',[cite: 8]
    '@media screen and (max-width:900px){.mo-opt{width:50%}.mo-tile{width:50%}.mo-head__title{font-size:1.4em}}',[cite: 8]
    '@media screen and (max-width:580px){.mo-opt{width:100%}.mo-seg{min-width:8em}}',[cite: 8]
    '</style>'[cite: 8]
  ].join('');[cite: 8]

  // ===== 6. ШАБЛОНЫ LAMPA =====
  function resetTemplates() {
    Lampa.Template.add('lampac_prestige_full', "<div class=\"online-prestige online-prestige--full selector\">\n            <div class=\"online-prestige__img\">\n                <img alt=\"\">\n                <div class=\"online-prestige__loader\"></div>\n            </div>\n            <div class=\"online-prestige__body\">\n                <div class=\"online-prestige__head\">\n                    <div class=\"online-prestige__title\">{title}</div>\n                    <div class=\"online-prestige__time\">{time}</div>\n                </div>\n\n                <div class=\"online-prestige__timeline\"></div>\n\n                <div class=\"online-prestige__footer\">\n                    <div class=\"online-prestige__info\">{info}</div>\n                    <div class=\"online-prestige__quality\">{quality}</div>\n                </div>\n            </div>\n        </div>");[cite: 8]
    Lampa.Template.add('lampac_content_loading', "<div class=\"online-empty\">\n            <div class=\"broadcast__scan\"><div></div></div>\n\t\t\t\n            <div class=\"online-empty__templates\">\n                <div class=\"online-empty-template selector\">\n                    <div class=\"online-empty-template__ico\"></div>\n                    <div class=\"online-empty-template__body\"></div>\n                </div>\n                <div class=\"online-empty-template\">\n                    <div class=\"online-empty-template__ico\"></div>\n                    <div class=\"online-empty-template__body\"></div>\n                </div>\n                <div class=\"online-empty-template\">\n                    <div class=\"online-empty-template__ico\"></div>\n                    <div class=\"online-empty-template__body\"></div>\n                </div>\n            </div>\n        </div>");[cite: 8]
    Lampa.Template.add('lampac_does_not_answer', "<div class=\"online-empty\">\n            <div class=\"online-empty__title\">\n                #{lampac_balanser_dont_work}\n            </div>\n            <div class=\"online-empty__time\">\n                #{lampac_balanser_timeout}\n            </div>\n            <div class=\"online-empty__buttons\">\n                <div class=\"online-empty__button selector cancel\">#{cancel}</div>\n                <div class=\"online-empty__button selector change\">#{lampac_change_balanser}</div>\n            </div>\n            <div class=\"online-empty__templates\">\n                <div class=\"online-empty-template\">\n                    <div class=\"online-empty-template__ico\"></div>\n                    <div class=\"online-empty-template__body\"></div>\n                </div>\n                <div class=\"online-empty-template\">\n                    <div class=\"online-empty-template__ico\"></div>\n                    <div class=\"online-empty-template__body\"></div>\n                </div>\n                <div class=\"online-empty-template\">\n                    <div class=\"online-empty-template__ico\"></div>\n                    <div class=\"online-empty-template__body\"></div>\n                </div>\n            </div>\n        </div>");[cite: 8]
    Lampa.Template.add('lampac_prestige_rate', "<div class=\"online-prestige-rate\">\n            <svg width=\"17\" height=\"16\" viewBox=\"0 0 17 16\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">\n                <path d=\"M8.39409 0.192139L10.99 5.30994L16.7882 6.20387L12.5475 10.4277L13.5819 15.9311L8.39409 13.2425L3.20626 15.9311L4.24065 10.4277L0 6.20387L5.79819 5.30994L8.39409 0.192139Z\" fill=\"#fff\"></path>\n            </svg>\n            <span>{rate}</span>\n        </div>");[cite: 8]
    Lampa.Template.add('lampac_prestige_folder', "<div class=\"online-prestige online-prestige--folder selector\">\n            <div class=\"online-prestige__folder\">\n                <svg viewBox=\"0 0 128 112\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">\n                    <rect y=\"20\" width=\"128\" height=\"92\" rx=\"13\" fill=\"white\"></rect>\n                    <path d=\"M29.9963 8H98.0037C96.0446 3.3021 91.4079 0 86 0H42C36.5921 0 31.9555 3.3021 29.9963 8Z\" fill=\"white\" fill-opacity=\"0.23\"></path>\n                    <rect x=\"11\" y=\"8\" width=\"106\" height=\"76\" rx=\"13\" fill=\"white\" fill-opacity=\"0.51\"></rect>\n                </svg>\n            </div>\n            <div class=\"online-prestige__body\">\n                <div class=\"online-prestige__head\">\n                    <div class=\"online-prestige__title\">{title}</div>\n                    <div class=\"online-prestige__time\">{time}</div>\n                </div>\n\n                <div class=\"online-prestige__footer\">\n                    <div class=\"online-prestige__info\">{info}</div>\n                </div>\n            </div>\n        </div>");[cite: 8]
    Lampa.Template.add('lampac_prestige_watched', "<div class=\"online-prestige online-prestige-watched selector\">\n            <div class=\"online-prestige-watched__icon\">\n                <svg width=\"21\" height=\"21\" viewBox=\"0 0 21 21\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">\n                    <circle cx=\"10.5\" cy=\"10.5\" r=\"9\" stroke=\"currentColor\" stroke-width=\"3\"/>\n                    <path d=\"M14.8477 10.5628L8.20312 14.399L8.20313 6.72656L14.8477 10.5628Z\" fill=\"currentColor\"/>\n                </svg>\n            </div>\n            <div class=\"online-prestige-watched__body\">\n                \n            </div>\n        </div>");[cite: 8]
  }

  // ===== 7. КОМПОНЕНТ ДВИЖКА (ИЗ РАБОЧЕГО Z2) =====
  function component(object) {
    var network = new Network();[cite: 8]
    var scroll = new Lampa.Scroll({ mask: true, over: true });[cite: 8]
    var files = new Lampa.Explorer(object);[cite: 8]
    var filter = new Lampa.Filter(object);[cite: 8]
    var sources = {};[cite: 8]
    var last;[cite: 8]
    var source;[cite: 8]
    var balanser;[cite: 8]
    var initialized;[cite: 8]
    var balanser_timer;[cite: 8]
    var images = [];[cite: 8]
    var number_of_requests = 0;[cite: 8]
    var number_of_requests_timer;[cite: 8]
    var life_wait_times = 0;[cite: 8]
    var life_wait_timer;[cite: 8]
    var filter_sources = {};[cite: 8]
    var filter_translate = {
      season: Lampa.Lang.translate('torrent_serial_season'),[cite: 8]
      voice: Lampa.Lang.translate('torrent_parser_voice'),[cite: 8]
      source: Lampa.Lang.translate('settings_rest_source')[cite: 8]
    };[cite: 8]
    var filter_find = { season: [], voice: [] };[cite: 8]

    if (balansers_with_search == undefined) {[cite: 8]
      network.timeout(10000);[cite: 8]
      network.silent(account('https://z01.online/lite/withsearch'), function(json) {[cite: 8]
        balansers_with_search = json;[cite: 8]
      }, function() { balansers_with_search = []; });[cite: 8]
    }

    function balanserName(j) {
      var bals = j.balanser;[cite: 8]
      var name = j.name.split(' ')[0];[cite: 8]
      return (bals || name).toLowerCase();[cite: 8]
    }

    function clarificationSearchAdd(value){
      var id = Lampa.Utils.hash(object.movie.number_of_seasons ? object.movie.original_name : object.movie.original_title);[cite: 8]
      var all = Lampa.Storage.get('clarification_search','{}');[cite: 8]
      all[id] = value;[cite: 8]
      Lampa.Storage.set('clarification_search',all);[cite: 8]
    }

    function clarificationSearchDelete(){
      var id = Lampa.Utils.hash(object.movie.number_of_seasons ? object.movie.original_name : object.movie.original_title);[cite: 8]
      var all = Lampa.Storage.get('clarification_search','{}');[cite: 8]
      delete all[id];[cite: 8]
      Lampa.Storage.set('clarification_search',all);[cite: 8]
    }

    var modern = Z01UI.enabled();[cite: 8]
    var ui = {};[cite: 8]
    var ui_items = [];[cite: 8]
    var ui_enter = null;[cite: 8]
    var ui_focus = '';[cite: 8]
    var ui_tried = {};[cite: 8]
    var ui_open = '';[cite: 8]
    var ui_nav = false;[cite: 8]
    var season_pinned = false;[cite: 8]
    var similar_list = null;[cite: 8]
    var similar_auto = false;[cite: 8]
    var similar_shown = false;[cite: 8]
    var last_origin = '';[cite: 8]
    var request_gen = 0;[cite: 8]
    var ui_watchdog;[cite: 8]
    var ui_load_timer;[cite: 8]
    var ui_load_started = 0;[cite: 8]
    var ui_load_found = 0;[cite: 8]
    var ui_load_percent = 0;[cite: 8]
    var ui_load_simple = false;[cite: 8]

    this.uiFrame = function() {
      if (!ui.root) {[cite: 8]
        ui.root = $('<div class="mo"></div>');[cite: 8]
        ui.status = $('<div class="mo__status"></div>');[cite: 8]
        ui.panel = $('<div class="mo__panel"></div>');[cite: 8]
        ui.list = $('<div class="mo-list"></div>');[cite: 8]
        ui.root.append(ui.status).append(ui.panel).append(ui.list);[cite: 8]
      }
      if (!ui.root.parent().length) {[cite: 8]
        scroll.clear();[cite: 8]
        scroll.append(ui.root);[cite: 8]
      }
      return ui.root;[cite: 8]
    };

    this.uiWaitBox = function(title) {
      var box = $('<div class="mo-wait"><div class="mo-wait__head"><div class="mo-wait__title"></div><div class="mo-wait__count"></div></div><div class="mo-wait__bar"><div class="mo-wait__fill"></div></div></div>');[cite: 8]
      box.find('.mo-wait__title').text(title);[cite: 8]
      return box;[cite: 8]
    };

    this.uiStatusPending = function() {
      if (!ui.status) return;[cite: 8]
      var box = ui.status.empty().removeClass('mo-head--hidden');[cite: 8]
      if (ui_nav || !object.movie.name) return box.addClass('mo-head--hidden');[cite: 8]
      var seasons = filter_find.season || [];[cite: 8]
      if (!seasons.length) return box.addClass('mo-head--hidden');[cite: 8]
      var choice = this.getChoice();[cite: 8]
      var title = (seasons[choice.season] || seasons[0]).title || '';[cite: 8]
      if (!title) return box.addClass('mo-head--hidden');[cite: 8]
      var head = $('<div class="mo-head"><div class="mo-head__text"><div class="mo-head__title"></div></div></div>');[cite: 8]
      head.find('.mo-head__title').text(title);[cite: 8]
      box.append(head);[cite: 8]
    };

    this.uiWaitStart = function(title, simple) {
      var _this = this;[cite: 8]
      this.uiStatusPending();[cite: 8]
      ui_load_started = Date.now();[cite: 8]
      ui_load_found = 0;[cite: 8]
      ui_load_percent = 0;[cite: 8]
      ui_load_simple = !!simple;[cite: 8]
      ui.load = this.uiWaitBox(title);[cite: 8]
      ui.list.empty().append(ui.load);[cite: 8]
      this.uiLoadingText();[cite: 8]
      clearInterval(ui_load_timer);[cite: 8]
      ui_load_timer = setInterval(function() { _this.uiLoadingText(); }, 1000);[cite: 8]
    };

    this.uiLoadingPanel = function() {
      this.uiFrame();[cite: 8]
      this.uiWatch(Z01UI.WATCHDOG_FIRST);[cite: 8]
      this.uiWaitStart(Lampa.Lang.translate('z01_loading_title'), false);[cite: 8]
    };

    this.uiLoadingText = function() {
      if (!ui.load || !ui.load.parent().length) return this.uiLoadingStop();[cite: 8]
      var seconds = Math.max(0, Math.round((Date.now() - ui_load_started) / 1000));[cite: 8]
      var text = (!ui_load_simple ? (ui_load_found ? Lampa.Lang.translate('z01_loading_found').replace('{n}', ui_load_found) : Lampa.Lang.translate('z01_loading_start')) + ' · ' : '') + seconds + Lampa.Lang.translate('z01_sec');[cite: 8]
      if (seconds >= 12 && ui_load_percent < 100) text += ' · ' + Lampa.Lang.translate('z01_loading_slow');[cite: 8]
      ui.load.find('.mo-wait__count').text(text);[cite: 8]
      var percent = Math.max(ui_load_percent, Math.min(90, seconds * 7));[cite: 8]
      ui.load.find('.mo-wait__fill').css('width', percent + '%');[cite: 8]
    };

    this.uiLoadingProgress = function(json, times) {
      if (!ui.load || !ui.load.parent().length) return;[cite: 8]
      var list = (json && json.online) || [];[cite: 8]
      var found = 0;[cite: 8]
      list.forEach(function(item) { if (item.show) found++; });[cite: 8]
      ui_load_found = found;[cite: 8]
      ui_load_percent = json && json.ready ? 100 : Math.min(95, Math.round((times / 15) * 100));[cite: 8]
      this.uiWatch(Z01UI.WATCHDOG_FIRST);[cite: 8]
      this.uiLoadingText();[cite: 8]
    };

    this.uiLoadingStop = function() {
      clearInterval(ui_load_timer);[cite: 8]
      ui_load_timer = null;[cite: 8]
      ui.load = null;[cite: 8]
    };

    this.uiWatch = function(seconds) {
      var _this = this;[cite: 8]
      clearTimeout(ui_watchdog);[cite: 8]
      if (!modern) return;[cite: 8]
      ui_watchdog = setTimeout(function() {
        if (Lampa.Activity.active().activity !== _this.activity) return;[cite: 8]
        network.clear();[cite: 8]
        _this.doesNotAnswer({ timeout: true });[cite: 8]
      }, (seconds || Z01UI.WATCHDOG) * 1000);[cite: 8]
    };

    this.uiWatchStop = function() {
      clearTimeout(ui_watchdog);[cite: 8]
      ui_watchdog = null;[cite: 8]
    };

    this.uiLoading = function() {
      this.uiFrame();[cite: 8]
      this.uiLoadingStop();[cite: 8]
      this.uiWatch();[cite: 8]
      request_gen++;[cite: 8]
      network.clear();[cite: 8]
      clearInterval(balanser_timer);[cite: 8]
      this.clearImages();[cite: 8]
      this.uiWaitStart(Lampa.Lang.translate('z01_loading_list'), true);[cite: 8]
      this.activity.loader(false);[cite: 8]
      this.activity.toggle();[cite: 8]
    };

    this.uiFocusTarget = function() { return last; };[cite: 8]
    this.uiFocusRestore = function(fallback) {
      var element = false;[cite: 8]
      if (ui_focus && ui.root) {[cite: 8]
        var found = ui.root.find('[data-mo-focus="' + ui_focus + '"]');[cite: 8]
        if (found.length) element = found[0];[cite: 8]
      }
      ui_focus = '';[cite: 8]
      if (!element && fallback) element = fallback;[cite: 8]
      if (element) last = element;[cite: 8]
    };

    this.uiPickResume = function(items) {
      if (!items || !items.length) return null;[cite: 8]
      var serial = object.movie.name ? true : false;[cite: 8]
      var viewed = Lampa.Storage.cache('online_view', 5000, []);[cite: 8]
      var i;[cite: 8]
      if (!serial) {
        var movie_choice = this.getChoice();[cite: 8]
        if (movie_choice.movie_view) {[cite: 8]
          for (i = 0; i < items.length; i++) {
            if (items[i].hash_behold == movie_choice.movie_view) return items[i];[cite: 8]
          }
        }
        var pref = Lampa.Storage.get('z01_voice_pref', '');[cite: 8]
        if (pref) {
          for (i = 0; i < items.length; i++) {
            if (Z01UI.voiceKind(items[i].title || items[i].text) == pref) return items[i];[cite: 8]
          }
        }
        return items[0];[cite: 8]
      }
      var choice = this.getChoice();[cite: 8]
      var season = items[0].season;[cite: 8]
      var reached = Z01UI.reached(object.movie, season);[cite: 8]
      if (!reached) {
        var mark = choice.episodes_view ? parseInt(choice.episodes_view[season], 10) : 0;[cite: 8]
        if (mark > reached) reached = mark;[cite: 8]
        var history = this.watched();[cite: 8]
        if (history && history.episode && (!history.season || history.season == season)) {[cite: 8]
          var last_seen = parseInt(history.episode, 10) || 0;[cite: 8]
          if (last_seen > reached) reached = last_seen;[cite: 8]
        }
        for (i = 0; i < items.length; i++) {
          if (Z01UI.isSeen(items[i], viewed)) {[cite: 8]
            var num = parseInt(items[i].episode, 10) || 0;[cite: 8]
            if (num > reached) reached = num;[cite: 8]
          }
        }
      }
      if (reached) {
        for (i = 0; i < items.length; i++) {
          if (items[i].episode == reached) {[cite: 8]
            var line = items[i].timeline;[cite: 8]
            if (line && line.percent > 0 && line.percent < 90) return items[i];[cite: 8]
            for (var j = i + 1; j < items.length; j++) {[cite: 8]
              if (!Z01UI.isSeen(items[j], viewed)) return items[j];[cite: 8]
            }
            return items[i + 1] || items[i];[cite: 8]
          }
        }
        var best = null;[cite: 8]
        for (i = 0; i < items.length; i++) {
          var value = parseInt(items[i].episode, 10) || 0;[cite: 8]
          if (value > reached && (!best || value < (parseInt(best.episode, 10) || 0))) best = items[i];[cite: 8]
        }
        if (best) return best;[cite: 8]
        return items[items.length - 1];[cite: 8]
      }
      for (i = 0; i < items.length; i++) {
        if (!Z01UI.isSeen(items[i], viewed)) return items[i];[cite: 8]
      }
      return items[0];[cite: 8]
    };

    this.uiStatus = function(items) {
      if (!ui.status) return;[cite: 8]
      var box = ui.status.empty().removeClass('mo-head--hidden');[cite: 8]
      var serial = object.movie.name ? true : false;[cite: 8]
      if (ui_nav || !items.length || !serial) return box.addClass('mo-head--hidden');[cite: 8]
      var viewed = Lampa.Storage.cache('online_view', 5000, []);[cite: 8]
      var seen = 0;[cite: 8]
      for (var i = 0; i < items.length; i++) {
        if (Z01UI.isSeen(items[i], viewed)) seen++;[cite: 8]
      }
      var title = '';[cite: 8]
      if (serial) {
        var seasons = filter_find.season || [];[cite: 8]
        var picked = seasons.length ? seasons[this.getChoice().season] || seasons[0] : null;[cite: 8]
        if (picked && picked.title) title = picked.title;[cite: 8]
        else {
          var season = items[0].season || this.seasonMemory() || 1;[cite: 8]
          title = Lampa.Lang.translate('torrent_serial_season') + ' ' + season;[cite: 8]
        }
      } else title = object.movie.title || object.movie.name || '';[cite: 8]
      var note = '';[cite: 8]
      if (serial && items.length > 1) {
        note = Lampa.Lang.translate('z01_season_progress').replace('{seen}', seen).replace('{total}', items.length);[cite: 8]
        if (seen < items.length) note += ' · ' + Lampa.Lang.translate('z01_season_left').replace('{left}', items.length - seen);[cite: 8]
      } else {
        var target = this.uiPickResume(items);[cite: 8]
        var line = target && target.timeline;[cite: 8]
        if (line && line.percent > 0 && line.duration > line.time) {[cite: 8]
          note = Lampa.Lang.translate('z01_left') + ' ' + Lampa.Utils.secondsToTime(line.duration - line.time, true);[cite: 8]
        }
      }
      var head = $('<div class="mo-head"><div class="mo-head__text"><div class="mo-head__title"></div><div class="mo-head__sub"></div></div><div class="mo-head__note"></div></div>');[cite: 8]
      head.find('.mo-head__title').text(title);[cite: 8]
      head.find('.mo-head__note').text(note);[cite: 8]
      if (!serial && object.movie.original_title && object.movie.original_title !== title) {[cite: 8]
        head.find('.mo-head__sub').text(object.movie.original_title);[cite: 8]
      }
      box.append(head);[cite: 8]
      if (serial && items.length > 1 && seen) {[cite: 8]
        var bar = $('<div class="mo-head__bar"><div class="mo-head__fill"></div></div>');[cite: 8]
        bar.find('.mo-head__fill').css('width', Math.round(seen / items.length * 100) + '%');[cite: 8]
        box.append(bar);[cite: 8]
      }
      return box;[cite: 8]
    };

    this.uiFallbackArt = function() {
      var movie = object.movie;[cite: 8]
      var path = function(value) { return (!value || value === 'undefined') ? '' : Lampa.TMDB.image('t/p/w300' + value); };[cite: 8]
      var art = path(movie.backdrop_path) || path(movie.poster_path);[cite: 8]
      if (!art && movie.img) {[cite: 8]
        art = movie.img;[cite: 8]
        if (art.indexOf('http') !== 0) art = '';[cite: 8]
      }
      return art || path(movie.img);[cite: 8]
    };

    this.uiSearch = function() {
      var native_search = filter.render().find('.filter--search');[cite: 8]
      if (native_search.length) return native_search.trigger('hover:enter');[cite: 8]
      if (Lampa.Input && Lampa.Input.edit) {[cite: 8]
        var enabled = Lampa.Controller.enabled().name;[cite: 8]
        Lampa.Input.edit({ value: object.search || '', free: true, nosave: true, title: Lampa.Lang.translate('search') }, function(value) {[cite: 8]
          Lampa.Controller.toggle(enabled);[cite: 8]
          if (value && filter.onSearch) filter.onSearch(value);[cite: 8]
        });
      }
    };

    this.uiRows = function() {
      var _this = this;[cite: 8]
      var panel = ui.panel.empty();[cite: 8]
      var bar = $('<div class="mo-panel"></div>');[cite: 8]

      var addSeg = function(key, name, value, mark) {
        var seg = $('<div class="mo-seg selector"><div class="mo-seg__name"></div><div class="mo-seg__value"></div><div class="mo-seg__arrow"></div></div>');[cite: 8]
        seg.attr('data-mo-focus', key);[cite: 8]
        seg.find('.mo-seg__name').text(name);[cite: 8]
        var box = seg.find('.mo-seg__value');[cite: 8]
        if (mark) box.append($('<span class="mo-seg__mark"></span>').text(mark));[cite: 8]
        box.append(document.createTextNode(value));[cite: 8]
        if (ui_open == key) seg.addClass('mo-seg--open');[cite: 8]
        seg.on('hover:enter', function() { _this.uiToggle(key); }).on('hover:focus', function(e) {[cite: 8]
          last = e.target;[cite: 8]
          scroll.update($(e.target), true);[cite: 8]
        });
        bar.append(seg);[cite: 8]
      };

      if (!object.balanser && sourceKeys().length && balanser) {[cite: 8]
        var info = sources[balanser] || {};[cite: 8]
        var parts = Z01UI.splitSourceName(info.name || balanser);[cite: 8]
        addSeg('source', Lampa.Lang.translate('lampac_balanser'), parts.name, Z01UI.sourceBadge(balanser, parts));[cite: 8]
      }

      var choice = this.getChoice();[cite: 8]
      var seasons = filter_find.season || [];[cite: 8]
      if (seasons.length > 1) {[cite: 8]
        addSeg('season', Lampa.Lang.translate('torrent_serial_season'), (seasons[choice.season] || seasons[0]).title, '');[cite: 8]
      }

      var voices = filter_find.voice || [];[cite: 8]
      if (voices.length > 1) {[cite: 8]
        addSeg('voice', Lampa.Lang.translate('torrent_parser_voice'), (voices[choice.voice] || voices[0]).title, '');[cite: 8]
      }

      if (similar_list && similar_list.length > 1 && !similar_shown) {[cite: 8]
        var back = $('<div class="mo-seg selector"><div class="mo-seg__name"></div><div class="mo-seg__value"></div></div>');[cite: 8]
        back.attr('data-mo-focus', 'variants');[cite: 8]
        back.find('.mo-seg__name').text(Lampa.Lang.translate('z01_similar_all'));[cite: 8]
        back.find('.mo-seg__value').text(similar_list.length);[cite: 8]
        back.on('hover:enter', function() {[cite: 8]
          var saved = similar_list;[cite: 8]
          similar_auto = true;[cite: 8]
          _this.uiSimilars(saved, true);[cite: 8]
        }).on('hover:focus', function(e) {[cite: 8]
          last = e.target;[cite: 8]
          scroll.update($(e.target), true);[cite: 8]
        });
        bar.append(back);[cite: 8]
      }

      if (bar.children().length) panel.append(bar);[cite: 8]

      if (ui_open == 'source' && !object.balanser) this.uiSourceRow();[cite: 8]
      else if (ui_open == 'season') this.uiOptionRow('season');[cite: 8]
      else if (ui_open == 'voice') this.uiOptionRow('voice');[cite: 8]
    };

    this.sourceOrder = function(names) {
      var rank = function(name) { return (name == balanser) ? -1 : ((sources[name] && sources[name].show) ? 0 : 1); };[cite: 8]
      var quality = function(name) {
        var info = sources[name] || {};[cite: 8]
        return Z01UI.qualityRank(Z01UI.sourceBadge(name, Z01UI.splitSourceName(info.name || name)));[cite: 8]
      };
      return names.map(function(name, index) { return { name: name, index: index }; }).sort(function(a, b) {[cite: 8]
        return (rank(a.name) - rank(b.name)) || (quality(b.name) - quality(a.name)) || (a.index - b.index);[cite: 8]
      }).map(function(entry) { return entry.name; });[cite: 8]
    };

    this.uiToggle = function(key) {
      var opening = ui_open != key;[cite: 8]
      ui_open = opening ? key : '';[cite: 8]
      ui_focus = key;[cite: 8]
      if (opening) {[cite: 8]
        var choice = this.getChoice();[cite: 8]
        if (key == 'source' && balanser) ui_focus = 'src:' + balanser;[cite: 8]
        else if (key == 'season') ui_focus = 'season:' + (choice.season || 0);[cite: 8]
        else if (key == 'voice') ui_focus = 'voice:' + (choice.voice || 0);[cite: 8]
      }
      this.uiRows();[cite: 8]
      this.uiFocusRestore(false);[cite: 8]
      Lampa.Controller.enable('content');[cite: 8]
    };

    this.uiPanelFocus = function() {
      if (!modern || !ui.panel) return false;[cite: 8]
      var seg = ui.panel.find('[data-mo-focus="source"]')[0] || ui.panel.find('.mo-seg')[0];[cite: 8]
      if (!seg) return false;[cite: 8]
      last = seg;[cite: 8]
      scroll.update($(seg), true);[cite: 8]
      Lampa.Controller.collectionFocus(seg, scroll.render());[cite: 8]
      return true;[cite: 8]
    };

    this.uiPanelFocused = function() { return (!modern || !ui.panel || !last) ? false : ui.panel.find(last).length > 0; };[cite: 8]
    this.uiUpFallback = function() { return (ui.root && last && ui.list && ui.list.find(last).length) ? this.uiPanelFocus() : false; };[cite: 8]

    this.uiOptionRow = function(type) {
      var _this = this;[cite: 8]
      var list = filter_find[type] || [];[cite: 8]
      var selected = this.getChoice()[type];[cite: 8]
      var grid = $('<div class="mo-grid"></div>');[cite: 8]
      var rows = [];[cite: 8]
      if (type == 'voice') {[cite: 8]
        Z01UI.voiceGroups(list).forEach(function(group) {[cite: 8]
          group.items.forEach(function(entry) {[cite: 8]
            rows.push({ index: entry.index, title: entry.title, note: group.title || '' });[cite: 8]
          });
        });
      } else {
        list.forEach(function(item, index) { rows.push({ index: index, title: item.title, note: '' }); });[cite: 8]
      }
      rows.forEach(function(entry) {
        var opt = $('<div class="mo-opt selector"><div class="mo-opt__in"><span class="mo-opt__label"></span><span class="mo-opt__note"></span></div></div>');[cite: 8]
        opt.attr('data-mo-focus', type + ':' + entry.index);[cite: 8]
        opt.find('.mo-opt__label').text(entry.title || '');[cite: 8]
        opt.find('.mo-opt__note').text(entry.note);[cite: 8]
        if (entry.index == selected) opt.addClass('mo-opt--active');[cite: 8]
        opt.on('hover:enter', function() { _this.uiSwitch(type, entry.index); }).on('hover:focus', function(e) {[cite: 8]
          last = e.target;[cite: 8]
          scroll.update($(e.target), true);[cite: 8]
        });
        grid.append(opt);[cite: 8]
      });
      ui.panel.append(grid);[cite: 8]
    };

    this.uiSwitch = function(type, index) {
      var choice = this.getChoice();[cite: 8]
      if (choice[type] == index && ui_open) {[cite: 8]
        ui_open = '';[cite: 8]
        ui_focus = type;[cite: 8]
        this.uiRows();[cite: 8]
        this.uiFocusRestore(false);[cite: 8]
        Lampa.Controller.enable('content');[cite: 8]
        return;[cite: 8]
      }
      choice[type] = index;[cite: 8]
      if (type == 'voice') {[cite: 8]
        var voice = filter_find.voice[index];[cite: 8]
        if (voice) {[cite: 8]
          choice.voice_name = voice.title;[cite: 8]
          Lampa.Storage.set('z01_voice_pref', Z01UI.voiceKind(voice.title));[cite: 8]
        }
      }
      if (type == 'season') {[cite: 8]
        var season = filter_find.season[index];[cite: 8]
        if (season) {[cite: 8]
          var number = Z01UI.seasonNumber(season.title);[cite: 8]
          if (number) this.seasonMemory(number);[cite: 8]
        }
        season_pinned = true;[cite: 8]
      }
      this.saveChoice(choice);[cite: 8]
      ui_open = '';[cite: 8]
      ui_focus = type;[cite: 8]
      this.uiLoading();[cite: 8]
      this.uiRows();[cite: 8]
      this.find();[cite: 8]
    };

    this.uiSourceMenu = function() { this.uiToggle('source'); };[cite: 8]

    this.uiSourceRow = function() {
      var _this = this;[cite: 8]
      var all = sourceKeys();[cite: 8]
      var visible = all.filter(function(name) {[cite: 8]
        var info = sources[name] || {};[cite: 8]
        return name == balanser || info.show || info.vip;[cite: 8]
      });
      var grid = $('<div class="mo-grid"></div>');[cite: 8]
      this.sourceOrder(visible).forEach(function(name) {[cite: 8]
        var info = sources[name] || {};[cite: 8]
        var parts = Z01UI.splitSourceName(info.name || name);[cite: 8]
        var opt = $('<div class="mo-opt selector"><div class="mo-opt__in"><span class="mo-opt__label"></span><span class="mo-opt__note"></span></div></div>');[cite: 8]
        opt.attr('data-mo-focus', 'src:' + name);[cite: 8]
        var label = opt.find('.mo-opt__label');[cite: 8]
        var tag = Z01UI.sourceBadge(name, parts);[cite: 8]
        if (info.vip) label.append('<span class="mo-opt__tag">VIP</span>');[cite: 8]
        else if (tag) label.append($('<span class="mo-opt__tag"></span>').text(tag));[cite: 8]
        label.append(document.createTextNode(parts.name));[cite: 8]
        if (name == balanser) opt.addClass('mo-opt--active');[cite: 8]
        opt.on('hover:enter', function() {[cite: 8]
          if (info.vip && !isZpremActive()) {
            Lampa.Noty.show('Активация VIP-доступа...');
            zpremAutoEnsure(function(ok) {
              if (ok) {
                ui_open = '';[cite: 8]
                _this.switchSource(name);[cite: 8]
              } else {
                _this.vipOffer({ title: info.name || name, source: name });[cite: 8]
              }
            });
            return;
          }
          ui_open = '';[cite: 8]
          if (name == balanser) {[cite: 8]
            ui_focus = 'source';[cite: 8]
            _this.uiRows();[cite: 8]
            _this.uiFocusRestore(false);[cite: 8]
            Lampa.Controller.enable('content');[cite: 8]
            return;[cite: 8]
          }
          _this.switchSource(name);[cite: 8]
        }).on('hover:focus', function(e) {[cite: 8]
          last = e.target;[cite: 8]
          scroll.update($(e.target), true);[cite: 8]
        });
        grid.append(opt);[cite: 8]
      });
      ui.panel.append(grid);[cite: 8]
    };

    this.switchSource = function(name) {
      if (!sources[name]) return;[cite: 8]
      if (!modern) {[cite: 8]
        object.lampac_custom_select = name;[cite: 8]
        return this.changeBalanser(name);[cite: 8]
      }
      object.lampac_custom_select = name;[cite: 8]
      balanser = name;[cite: 8]
      source = sources[name].url;[cite: 8]
      Lampa.Storage.set('online_balanser', name);[cite: 8]
      Lampa.Storage.set('active_balanser', name);[cite: 8]
      this.updateBalanser(name);[cite: 8]
      filter_find = { season: [], voice: [] };[cite: 8]
      ui_tried[name] = true;[cite: 8]
      ui_open = '';[cite: 8]
      season_pinned = false;[cite: 8]
      similar_list = null;[cite: 8]
      similar_auto = false;[cite: 8]
      ui_focus = 'source';[cite: 8]
      this.uiLoading();[cite: 8]
      this.uiRows();[cite: 8]
      var seg = ui.panel.find('[data-mo-focus="source"]')[0];[cite: 8]
      if (seg) last = seg;[cite: 8]
      this.find();[cite: 8]
      Lampa.Controller.toggle('content');[cite: 8]
    };

    var sourceKeys = function() { return Object.prototype.toString.call(filter_sources) === '[object Array]' ? filter_sources : []; };[cite: 8]

    this.nextSource = function() {
      var keys = sourceKeys().filter(function(name) {[cite: 8]
        if (!sources[name] || sources[name].vip || name === balanser || ui_tried[name]) return false;[cite: 8]
        return sources[name].show;[cite: 8]
      });
      return !keys.length ? '' : this.sourceOrder(keys)[0];[cite: 8]
    };

    this.uiNote = function(params) {
      this.uiFrame();[cite: 8]
      this.uiLoadingStop();[cite: 8]
      this.uiWatchStop();[cite: 8]
      var note = $('<div class="mo-info"><div class="mo-info__title"></div><div class="mo-info__text"></div><div class="mo-info__acts"></div></div>');[cite: 8]
      note.find('.mo-info__title').text(params.title || '');[cite: 8]
      note.find('.mo-info__text').html(params.text || '');[cite: 8]
      var acts = note.find('.mo-info__acts');[cite: 8]
      (params.actions || []).forEach(function(action) {[cite: 8]
        var button = $('<div class="mo-act selector"></div>');[cite: 8]
        if (action.icon) button.append(action.icon);[cite: 8]
        button.append($('<span></span>').text(action.title));[cite: 8]
        button.on('hover:enter', function() { action.handler(); }).on('hover:focus', function(e) {[cite: 8]
          last = e.target;[cite: 8]
          scroll.update($(e.target), true);[cite: 8]
        });
        acts.append(button);[cite: 8]
      });
      var link = params.qr || params.link || '';[cite: 8]
      if (link) {
        var qr = $('<div class="mo-info__qr"><img alt=""></div>');[cite: 8]
        qr.find('img').attr('src', Z01UI.qrImage(link));[cite: 8]
        note.find('.mo-info__text').after($('<div class="mo-info__link"></div>').text(link)).after(qr);[cite: 8]
      }
      ui.list.empty().append(note);[cite: 8]
      this.uiStatus([]);[cite: 8]
      this.uiRows();[cite: 8]
      this.loading(false);[cite: 8]
      last = acts.find('.mo-act')[0] || false;[cite: 8]
      Lampa.Controller.enable('content');[cite: 8]
      return note;[cite: 8]
    };

    this.markUpTo = function(element) {
      if (!element) return;[cite: 8]
      var upto = parseInt(element.episode, 10) || 0;[cite: 8]
      if (!upto) return;[cite: 8]
      var viewed = Lampa.Storage.cache('online_view', 5000, []);[cite: 8]
      var changed = false;[cite: 8]
      for (var i = 0; i < ui_items.length; i++) {[cite: 8]
        var item = ui_items[i];[cite: 8]
        var num = parseInt(item.episode, 10) || 0;[cite: 8]
        if (!num || !item.hash_behold) continue;[cite: 8]
        if (num <= upto) {[cite: 8]
          if (viewed.indexOf(item.hash_behold) === -1) {[cite: 8]
            viewed.push(item.hash_behold);[cite: 8]
            changed = true;[cite: 8]
          }
        } else {
          if (viewed.indexOf(item.hash_behold) !== -1) {[cite: 8]
            Lampa.Arrays.remove(viewed, item.hash_behold);[cite: 8]
            Lampa.Storage.remove('online_view', item.hash_behold);[cite: 8]
            changed = true;[cite: 8]
          }
          var line = item.timeline;[cite: 8]
          if (line && (line.percent || line.time)) {[cite: 8]
            line.percent = 0;[cite: 8]
            line.time = 0;[cite: 8]
            line.duration = 0;[cite: 8]
            Lampa.Timeline.update(line);[cite: 8]
          }
        }
      }
      if (changed) Lampa.Storage.set('online_view', viewed);[cite: 8]
      Z01UI.setReach(object.movie, element.season, upto);[cite: 8]
      var choice = this.getChoice();[cite: 8]
      if (element.season) choice.episodes_view[element.season] = upto;[cite: 8]
      this.saveChoice(choice);[cite: 8]
      this.uiRefreshMarks();[cite: 8]
    };

    this.uiDraw = function(items, params) {
      var _this = this;[cite: 8]
      params = params || {};[cite: 8]
      if (!items.length) return this.empty();[cite: 8]
      this.uiFrame();[cite: 8]
      this.uiLoadingStop();[cite: 8]
      this.uiWatchStop();[cite: 8]
      ui_items = items;[cite: 8]
      ui_enter = params.onEnter;[cite: 8]
      similar_shown = false;[cite: 8]
      if (!params.similars) Z01UI.rememberQuality(balanser, Z01UI.bestQuality(items));[cite: 8]
      var serial = object.movie.name ? true : false;[cite: 8]
      var title_count = {};[cite: 8]
      items.forEach(function(item) {[cite: 8]
        var text = item.text || item.title || '';[cite: 8]
        title_count[text] = (title_count[text] || 0) + 1;[cite: 8]
      });
      var looksEpisode = function(text) {
        return /сери|episode|эпізод|эпизод/i.test(String(text || '')) || /^\s*\d+\s*$/.test(String(text || ''));[cite: 8]
      };
      ui_nav = items.length > 1 && items.every(function(item) {[cite: 8]
        var text = item.text || item.title || '';[cite: 8]
        if (Z01UI.isSeasonLabel(text)) return true;[cite: 8]
        return serial && typeof item.episode === 'undefined' && !looksEpisode(text);[cite: 8]
      });
      var draw_gen = request_gen;[cite: 8]
      this.getEpisodes(items[0].season, function(episodes) {
        if (draw_gen !== request_gen) return;[cite: 8]
        var viewed = Lampa.Storage.cache('online_view', 5000, []);[cite: 8]
        var choice = _this.getChoice();[cite: 8]
        var fully = window.innerWidth > 580;[cite: 8]
        var list = ui.list.empty();[cite: 8]
        if (serial && !ui_nav) list.addClass('mo-tiles');[cite: 8]
        else list.removeClass('mo-tiles');[cite: 8]
        var focus_element = false;[cite: 8]
        var focus_mark = false;[cite: 8]
        var resume = _this.uiPickResume(items);[cite: 8]

        if (serial && items[0] && items[0].season) {[cite: 8]
          var shown_season = parseInt(items[0].season);[cite: 8]
          var wanted_season = _this.seasonMemory();[cite: 8]
          if (shown_season && (!wanted_season || shown_season == wanted_season || _this.seasonIndexByMemory() >= 0)) {[cite: 8]
            _this.seasonMemory(shown_season);[cite: 8]
          }
        }

        items.forEach(function(element, index) {
          var episode = serial && episodes.length && !params.similars ? arrFind(episodes, function(e) {[cite: 8]
            return e.episode_number == element.episode;[cite: 8]
          }) : false;
          var episode_num = element.episode || index + 1;[cite: 8]
          var voice_name = (!serial && (element.voice_name || element.text)) || choice.voice_name || (filter_find.voice[0] ? filter_find.voice[0].title : false) || element.voice_name || (serial ? Lampa.Lang.translate('z01_unknown') : element.text) || Lampa.Lang.translate('z01_unknown');[cite: 8]
          if (element.quality) {[cite: 8]
            element.qualitys = element.quality;[cite: 8]
            element.quality = Lampa.Arrays.getKeys(element.quality)[0];[cite: 8]
          }
          element.voice_name = voice_name;[cite: 8]
          var runtime = episode ? episode.runtime : object.movie.runtime;[cite: 8]
          element.time = runtime ? Lampa.Utils.secondsToTime(runtime * 60, true) : '';[cite: 8]
          var hash_timeline = Lampa.Utils.hash(element.season ? [element.season, element.season > 10 ? ':' : '', element.episode, object.movie.original_title].join('') : object.movie.original_title);[cite: 8]
          var hash_behold = Lampa.Utils.hash(element.season ? [element.season, element.season > 10 ? ':' : '', element.episode, object.movie.original_title, element.voice_name].join('') : object.movie.original_title + element.voice_name);[cite: 8]
          element.hash_behold = hash_behold;[cite: 8]
          element.hash_timeline = hash_timeline;[cite: 8]
          element.timeline = Lampa.Timeline.view(hash_timeline);[cite: 8]
          if (element.season) {[cite: 8]
            element.translate_episode_end = _this8.getLastEpisode(items);[cite: 8]
            element.translate_voice = element.voice_name;[cite: 8]
          }
          var data = { hash_timeline: hash_timeline, hash_behold: hash_behold };[cite: 8]
          var title = (episode ? episode.name : (element.text || element.title)) || object.movie.title || object.movie.name || '';[cite: 8]
          element.title = title;[cite: 8]
          var meta = [];[cite: 8]
          if (episode && episode.vote_average) meta.push('★ ' + parseFloat(episode.vote_average + '').toFixed(1));[cite: 8]
          if (episode && episode.air_date && fully) meta.push(Lampa.Utils.parseTime(episode.air_date).full);[cite: 8]
          else if (!episode && object.movie.release_date && fully && serial) meta.push(Lampa.Utils.parseTime(object.movie.release_date).full);[cite: 8]
          if (!serial && !ui_nav && voice_name && voice_name !== title && voice_name !== Lampa.Lang.translate('z01_unknown')) meta.push(voice_name);[cite: 8]
          element.__meta_base = meta.slice();[cite: 8]
          element.__own_line = !ui_nav && (serial || choice.movie_view === hash_behold);[cite: 8]
          var seen_line = element.timeline;[cite: 8]
          if (element.__own_line && seen_line && seen_line.percent > 0 && seen_line.duration > seen_line.time) {[cite: 8]
            meta.push(Lampa.Lang.translate('z01_left') + ' ' + Lampa.Utils.secondsToTime(seen_line.duration - seen_line.time, true));[cite: 8]
          }
          var tile = serial && !ui_nav;[cite: 8]
          var html;[cite: 8]
          if (tile) {
            html = $('<div class="mo-tile selector"><div class="mo-tile__art"><img alt=""><div class="mo-tile__num"></div><div class="mo-tile__line"></div></div><div class="mo-tile__body"><div class="mo-tile__title"></div><div class="mo-tile__meta"></div></div></div>');[cite: 8]
            html.find('.mo-tile__title').text(title);[cite: 8]
            html.find('.mo-tile__meta').html(meta.map(function(part) { return '<span>' + Z01UI.esc(part) + '</span>'; }).join(''));[cite: 8]
            html.find('.mo-tile__num').text(Z01UI.episodeNumber(episode_num));[cite: 8]
            var art_box = html.find('.mo-tile__art');[cite: 8]
            var badge = Z01UI.shortQuality(element.quality);[cite: 8]
            if (badge) art_box.append($('<div class="mo-tile__tag"></div>').text(badge));[cite: 8]
            if (element.time) art_box.append($('<div class="mo-tile__time"></div>').text(element.time));[cite: 8]
            if (element.timeline && element.__own_line) html.find('.mo-tile__line').append(Lampa.Timeline.render(element.timeline));[cite: 8]
            var art = episode && episode.still_path ? Lampa.TMDB.image('t/p/w300' + episode.still_path) : _this.uiFallbackArt();[cite: 8]
            if (art) {
              var img = html.find('img')[0];[cite: 8]
              img.onload = function() { art_box.addClass('mo-tile__art--loaded'); };[cite: 8]
              img.onerror = function() {};[cite: 8]
              img.src = art;[cite: 8]
              images.push(img);[cite: 8]
              element.thumbnail = art;[cite: 8]
            }
          } else {
            html = $('<div class="mo-line selector"><div class="mo-line__art"><img alt=""></div><div class="mo-line__body"><div class="mo-line__title"></div><div class="mo-line__note"></div></div><div class="mo-line__side"></div><div class="mo-line__line"></div></div>');[cite: 8]
            html.find('.mo-line__title').text(title);[cite: 8]
            html.find('.mo-line__note').text(meta.join(' · '));[cite: 8]
            var side_box = html.find('.mo-line__side');[cite: 8]
            var line_badge = Z01UI.shortQuality(element.quality);[cite: 8]
            if (line_badge) side_box.append($('<div class="mo-line__tag"></div>').text(line_badge));[cite: 8]
            if (element.time) side_box.append($('<div class="mo-line__time"></div>').text(element.time));[cite: 8]
            if (element.timeline && element.__own_line && element.timeline.percent > 0) {[cite: 8]
              html.find('.mo-line__line').append(Lampa.Timeline.render(element.timeline));[cite: 8]
            }
            if (ui_nav) {
              html.addClass('mo-line--nav');[cite: 8]
              html.find('.mo-line__art').remove();[cite: 8]
              html.find('.mo-line__line').remove();[cite: 8]
              side_box.empty();[cite: 8]
              if (title_count[title] > 1) {[cite: 8]
                var provider = Z01UI.providerName(element.url);[cite: 8]
                if (provider) html.find('.mo-line__note').text(provider);[cite: 8]
              }
            } else {
              var line_box = html.find('.mo-line__art');[cite: 8]
              var line_art = _this.uiFallbackArt();[cite: 8]
              if (line_art) {[cite: 8]
                var line_img = html.find('img')[0];[cite: 8]
                line_img.onload = function() { line_box.addClass('mo-line__art--loaded'); };[cite: 8]
                line_img.onerror = function() {};[cite: 8]
                line_img.src = line_art;[cite: 8]
                images.push(line_img);[cite: 8]
                element.thumbnail = line_art;[cite: 8]
              } else line_box.remove();[cite: 8]
            }
          }
          element.__html = html;[cite: 8]

          var addViewed = function() {
            if (!element.__html || !tile) return;[cite: 8]
            var row = element.__html;[cite: 8]
            row.addClass('mo-tile--seen');[cite: 8]
            if (!row.find('.mo-tile__check').length) {[cite: 8]
              row.find('.mo-tile__art').append('<div class="mo-tile__check">' + Z01UI.icon.check + '</div>');[cite: 8]
            }
          };
          if (!ui_nav && Z01UI.isSeen(element, viewed)) {[cite: 8]
            focus_mark = html;[cite: 8]
            addViewed();[cite: 8]
          }
          if (resume === element) {[cite: 8]
            html.addClass(tile ? 'mo-tile--current' : 'mo-line--current');[cite: 8]
            focus_element = html;[cite: 8]
          }

          element.mark = function() {
            viewed = Lampa.Storage.cache('online_view', 5000, []);[cite: 8]
            if (viewed.indexOf(hash_behold) == -1) {[cite: 8]
              viewed.push(hash_behold);[cite: 8]
              Lampa.Storage.set('online_view', viewed);[cite: 8]
              addViewed();[cite: 8]
            }
            choice = _this8.getChoice();[cite: 8]
            if (!serial) {
              choice.movie_view = hash_behold;[cite: 8]
            } else {
              choice.episodes_view[element.season] = episode_num;[cite: 8]
              Z01UI.rememberReach(object.movie, element.season, episode_num);[cite: 8]
            }
            _this8.saveChoice(choice);[cite: 8]
            var voice_name_text = choice.voice_name || element.voice_name || element.title;[cite: 8]
            if (voice_name_text.length > 30) voice_name_text = voice_name_text.slice(0, 30) + '...';[cite: 8]
            _this8.watched({[cite: 8]
              balanser: balanser,[cite: 8]
              balanser_name: Lampa.Utils.capitalizeFirstLetter(sources[balanser] ? sources[balanser].name.split(' ')[0] : balanser),[cite: 8]
              voice_id: choice.voice_id,[cite: 8]
              voice_name: voice_name_text,[cite: 8]
              episode: element.episode,[cite: 8]
              season: element.season[cite: 8]
            });
            _this8.uiRefreshMarks();[cite: 8]
          };
          element.unmark = function() {
            viewed = Lampa.Storage.cache('online_view', 5000, []);[cite: 8]
            if (viewed.indexOf(hash_behold) !== -1) {[cite: 8]
              Lampa.Arrays.remove(viewed, hash_behold);[cite: 8]
              Lampa.Storage.set('online_view', viewed);[cite: 8]
              Lampa.Storage.remove('online_view', hash_behold);[cite: 8]
            }
            if (element.__html) {[cite: 8]
              element.__html.removeClass('mo-tile--seen');[cite: 8]
              element.__html.find('.mo-tile__check').remove();[cite: 8]
            }
            _this8.uiRefreshMarks();[cite: 8]
          };
          element.timeclear = function() {
            element.timeline.percent = 0;[cite: 8]
            element.timeline.time = 0;[cite: 8]
            element.timeline.duration = 0;[cite: 8]
            Lampa.Timeline.update(element.timeline);[cite: 8]
            _this8.uiRefreshMarks();[cite: 8]
          };

          html.on('hover:enter', function() {
            if (ui_nav) {[cite: 8]
              if (!element.url) return;[cite: 8]
              ui_focus = '';[cite: 8]
              _this8.uiLoading();[cite: 8]
              _this8.request(element.url);[cite: 8]
              return;[cite: 8]
            }
            if (object.movie.id) Lampa.Favorite.add('history', object.movie, 100);[cite: 8]
            if (params.onEnter) params.onEnter(element, html, data);[cite: 8]
          }).on('hover:focus', function(e) {
            last = e.target;[cite: 8]
            if (params.onFocus) params.onFocus(element, html, data);[cite: 8]
            scroll.update($(e.target), true);[cite: 8]
          });

          if (!ui_nav) _this8.contextMenu({[cite: 8]
            html: html,[cite: 8]
            element: element,[cite: 8]
            onFile: function onFile(call) {[cite: 8]
              if (params.onContextMenu) params.onContextMenu(element, html, data, call);[cite: 8]
            },
            onClearAllMark: function onClearAllMark() {[cite: 8]
              items.forEach(function(elem) { elem.unmark(); });[cite: 8]
            },
            onClearAllTime: function onClearAllTime() {[cite: 8]
              items.forEach(function(elem) { elem.timeclear(); });[cite: 8]
            }
          });

          list.append(html);[cite: 8]
        });

        if (serial && episodes.length > items.length && !params.similars) {[cite: 8]
          episodes.slice(items.length).forEach(function(episode) {[cite: 8]
            var meta = [];[cite: 8]
            if (episode.vote_average) info.push(Lampa.Template.get('lampac_prestige_rate', {[cite: 8]
              rate: parseFloat(episode.vote_average + '').toFixed(1)[cite: 8]
            }, true));
            if (episode.air_date) info.push(Lampa.Utils.parseTime(episode.air_date).full);[cite: 8]
            var air = new Date((episode.air_date + '').replace(/-/g, '/'));[cite: 8]
            var days = Math.round((air.getTime() - Date.now()) / (24 * 60 * 60 * 1000));[cite: 8]
            var txt = Lampa.Lang.translate('full_episode_days_left') + ': ' + day;[cite: 8]
            var html = Lampa.Template.get('lampac_prestige_full', {[cite: 8]
              time: Lampa.Utils.secondsToTime((episode ? episode.runtime : object.movie.runtime) * 60, true),[cite: 8]
              info: info.length ? info.map(function(i) { return '<span>' + i + '</span>'; }).join('<span class="online-prestige-split">●</span>') : '',[cite: 8]
              title: episode.name,[cite: 8]
              quality: day > 0 ? txt : ''[cite: 8]
            });
            var loader = html.find('.online-prestige__loader');[cite: 8]
            var image = html.find('.online-prestige__img');[cite: 8]
            var season = items[0] ? items[0].season : 1;[cite: 8]
            html.find('.online-prestige__timeline').append(Lampa.Timeline.render(Lampa.Timeline.view(Lampa.Utils.hash([season, episode.episode_number, object.movie.original_title].join('')))));[cite: 8]
            var img = html.find('img')[0];[cite: 8]
            if (episode.still_path) {[cite: 8]
              img.onerror = function() { img.src = './img/img_broken.svg'; };[cite: 8]
              img.onload = function() {
                image.addClass('online-prestige__img--loaded');[cite: 8]
                loader.remove();[cite: 8]
                image.append('<div class="online-prestige__episode-number">' + ('0' + episode.episode_number).slice(-2) + '</div>');[cite: 8]
              };
              img.src = Lampa.TMDB.image('t/p/w300' + episode.still_path);[cite: 8]
              images.push(img);[cite: 8]
            } else {
              loader.remove();[cite: 8]
              image.append('<div class="online-prestige__episode-number">' + ('0' + episode.episode_number).slice(-2) + '</div>');[cite: 8]
            }
            html.on('hover:focus', function(e) {[cite: 8]
              last = e.target;[cite: 8]
              scroll.update($(e.target), true);[cite: 8]
            });
            html.css('opacity', '0.5');[cite: 8]
            scroll.append(html);[cite: 8]
          });
        }
        if (scroll_to_element) last = scroll_to_element[0];[cite: 8]
        else if (scroll_to_mark) last = scroll_to_mark[0];[cite: 8]
        Lampa.Controller.enable('content');[cite: 8]

        if (object.lampac_continue_episode) {[cite: 8]
          var target_ep = object.lampac_continue_episode;[cite: 8]
          delete object.lampac_continue_episode;[cite: 8]
          var target_item = arrFind(items, function(el) { return el.episode == target_ep; });[cite: 8]
          if (target_item && target_item.__html) {[cite: 8]
            setTimeout(function() {
              last = target_item.__html[0];[cite: 8]
              scroll.update(target_item.__html, true);[cite: 8]
              target_item.__html.trigger('hover:enter');[cite: 8]
            }, 300);
          }
        }
      });
    };

    this.contextMenu = function(params) {
      var _self = this;[cite: 8]
      params.html.on('hover:long', function() {[cite: 8]
        function show(extra) {
          var enabled = Lampa.Controller.enabled().name;[cite: 8]
          var menu = [];[cite: 8]
          if (Lampa.Platform.is('webos')) menu.push({ title: Lampa.Lang.translate('player_lauch') + ' - Webos', player: 'webos' });[cite: 8]
          if (Lampa.Platform.is('android')) menu.push({ title: Lampa.Lang.translate('player_lauch') + ' - Android', player: 'android' });[cite: 8]
          menu.push({ title: Lampa.Lang.translate('player_lauch') + ' - Lampa', player: 'lampa' });[cite: 8]
          menu.push({ title: Lampa.Lang.translate('lampac_video'), separator: true });[cite: 8]
          menu.push({ title: Lampa.Lang.translate('torrent_parser_label_title'), mark: true });[cite: 8]
          menu.push({ title: Lampa.Lang.translate('torrent_parser_label_cancel_title'), unmark: true });[cite: 8]
          if (params.element && params.element.episode) menu.push({ title: Lampa.Lang.translate('z01_mark_before'), markbefore: true });[cite: 8]
          menu.push({ title: Lampa.Lang.translate('time_reset'), timeclear: true });[cite: 8]
          if (extra) menu.push({ title: Lampa.Lang.translate('copy_link'), copylink: true });[cite: 8]
          if (window.lampac_online_context_menu) window.lampac_online_context_menu.push(menu, extra, params);[cite: 8]
          menu.push({ title: Lampa.Lang.translate('more'), separator: true });[cite: 8]
          if (Lampa.Account.logged() && params.element && typeof params.element.season !== 'undefined' && params.element.translate_voice) {[cite: 8]
            menu.push({ title: Lampa.Lang.translate('lampac_voice_subscribe'), subscribe: true });[cite: 8]
          }
          menu.push({ title: Lampa.Lang.translate('lampac_clear_all_marks'), clearallmark: true });[cite: 8]
          menu.push({ title: Lampa.Lang.translate('lampac_clear_all_timecodes'), timeclearall: true });[cite: 8]
          if (modern) menu.push({ title: Lampa.Lang.translate('z01_clarify'), clarify: true });[cite: 8]
          Lampa.Select.show({[cite: 8]
            title: Lampa.Lang.translate('title_action'),[cite: 8]
            items: menu,[cite: 8]
            onBack: function onBack() { Lampa.Controller.toggle(enabled); },[cite: 8]
            onSelect: function onSelect(a) {
              if (a.mark) params.element.mark();[cite: 8]
              if (a.unmark) params.element.unmark();[cite: 8]
              if (a.markbefore) _self.markUpTo(params.element);[cite: 8]
              if (a.timeclear) params.element.timeclear();[cite: 8]
              if (a.clearallmark) params.onClearAllMark();[cite: 8]
              if (a.timeclearall) params.onClearAllTime();[cite: 8]
              if (window.lampac_online_context_menu) window.lampac_online_context_menu.onSelect(a, params);[cite: 8]
              Lampa.Controller.toggle(enabled);[cite: 8]
              if (a.player) {[cite: 8]
                Lampa.Player.runas(a.player);[cite: 8]
                params.html.trigger('hover:enter');[cite: 8]
              }
              if (a.copylink) {[cite: 8]
                if (extra.quality) {[cite: 8]
                  var qual = [];[cite: 8]
                  for (var i in extra.quality) qual.push({ title: i, file: extra.quality[i] });[cite: 8]
                  Lampa.Select.show({[cite: 8]
                    title: Lampa.Lang.translate('settings_server_links'),[cite: 8]
                    items: qual,[cite: 8]
                    onBack: function onBack() { Lampa.Controller.toggle(enabled); },[cite: 8]
                    onSelect: function onSelect(b) {
                      Lampa.Utils.copyTextToClipboard(b.file, function() { Lampa.Noty.show(Lampa.Lang.translate('copy_secuses')); }, function() { Lampa.Noty.show(Lampa.Lang.translate('copy_error')); });[cite: 8]
                    }
                  });
                } else {
                  Lampa.Utils.copyTextToClipboard(extra.file, function() { Lampa.Noty.show(Lampa.Lang.translate('copy_secuses')); }, function() { Lampa.Noty.show(Lampa.Lang.translate('copy_error')); });[cite: 8]
                }
              }
              if (a.subscribe) {
                Lampa.Account.subscribeToTranslation({
                  card: object.movie,
                  season: params.element.season,
                  episode: params.element.translate_episode_end,
                  voice: params.element.translate_voice
                }, function() { Lampa.Noty.show(Lampa.Lang.translate('lampac_voice_success')); }, function() { Lampa.Noty.show(Lampa.Lang.translate('lampac_voice_error')); });
              }
              if (a.clarify) _self.uiSearch();
            }
          });
        }
        params.onFile(show);
      }).on('hover:focus', function() {
        if (Lampa.Helper) Lampa.Helper.show('online_file', Lampa.Lang.translate('helper_online_file'), params.html);
      });
    };

    this.uiRecoveryActions = function(extra) {
      var _this = this;
      var actions = [];
      var next = this.nextSource();
      if (next && !object.balanser) {
        actions.push({
          title: Lampa.Lang.translate('z01_try_source').replace('{name}', sources[next].name || next),
          icon: Z01UI.icon.play,
          handler: function() { _this.switchSource(next); }
        });
      }
      if (!object.balanser && sourceKeys().length > 1) {
        actions.push({
          title: Lampa.Lang.translate('z01_all_sources'),
          icon: Z01UI.icon.chevron,
          handler: function() { _this.uiSourceMenu(); }
        });
      }
      actions.push({
        title: Lampa.Lang.translate('z01_retry'),
        icon: Z01UI.icon.refresh,
        handler: function() {
          ui_focus = '';
          _this.uiLoading();
          _this.find();
        }
      });
      actions.push({
        title: Lampa.Lang.translate('z01_clarify'),
        icon: Z01UI.icon.search,
        handler: function() { _this.uiSearch(); }
      });
      return actions;
    };

    this.empty = function() {
      if (modern) {
        this.uiNote({
          title: Lampa.Lang.translate('empty_title_two'),
          text: Lampa.Lang.translate('z01_empty_text').replace('{name}', (sources[balanser] && sources[balanser].name) || balanser || ''),
          actions: this.uiRecoveryActions()
        });
        return;
      }
      var html = Lampa.Template.get('lampac_does_not_answer', {});
      html.find('.online-empty__buttons').remove();
      html.find('.online-empty__title').text(Lampa.Lang.translate('empty_title_two'));
      html.find('.online-empty__time').text(Lampa.Lang.translate('empty_text'));
      scroll.clear();
      scroll.append(html);
      this.loading(false);
    };

    this.noConnectToServer = function(er) {
      if (modern) {
        var denial = Z01UI.serverDenial(er);
        this.uiNote({
          qr: denial ? denial.link : '',
          title: Lampa.Lang.translate(denial ? 'z01_no_access' : 'title_error'),
          text: denial ? denial.msg : Lampa.Lang.translate('z01_no_server'),
          actions: [{
            title: Lampa.Lang.translate('z01_retry'),
            icon: Z01UI.icon.refresh,
            handler: function() { Lampa.Activity.replace(); }
          }]
        });
        return;
      }
      var html = Lampa.Template.get('lampac_does_not_answer', {});
      html.find('.cancel, .change').remove();
      html.find('.online-empty__title').text(Lampa.Lang.translate('title_error'));
      html.find('.online-empty__time').html(er && er.accsdb ? er.msg : Lampa.Lang.translate('lampac_does_not_answer_text').replace('{balanser}', (sources[balanser] && sources[balanser].name) || balanser || ''));
      scroll.clear();
      scroll.append(html);
      this.loading(false);
    };

    this.doesNotAnswer = function(er) {
      var _this9 = this;
      if (modern) {
        ui_tried[balanser] = true;
        clearInterval(balanser_timer);
        var denial = Z01UI.serverDenial(er);
        var auto = !object.balanser && !denial;
        var next = auto ? this.nextSource() : '';
        var tic = er && er.accsdb ? 10 : 6;
        var note = this.uiNote({
          qr: denial ? denial.link : '',
          title: denial ? Lampa.Lang.translate('z01_no_access') : Lampa.Lang.translate(er && er.timeout ? 'z01_timeout_title' : 'z01_empty_title'),
          text: denial ? denial.msg : next ?
            Lampa.Lang.translate('z01_auto_switch_text').replace('{name}', sources[next].name || next).replace('{sec}', '<span class="mo-info__timer">' + tic + '</span>') :
            Lampa.Lang.translate(er && er.timeout ? 'z01_timeout_text' : 'z01_empty_text').replace('{name}', (sources[balanser] && sources[balanser].name) || balanser || ''),
          actions: this.uiRecoveryActions({ reason: 'no_results' })
        });
        if (next) {
          balanser_timer = setInterval(function() {
            tic--;
            note.find('.mo-info__timer').text(tic);
            if (tic <= 0) {
              clearInterval(balanser_timer);
              if (Lampa.Activity.active().activity == _this9.activity) _this9.switchSource(next);
            }
          }, 1000);
        }
        return;
      }
      this.reset();
      var html = Lampa.Template.get('lampac_does_not_answer', { balanser: balanser });
      if(er && er.accsdb) html.find('.online-empty__title').html(er.msg);
      var tic = er && er.accsdb ? 10 : 5;
      html.find('.cancel').on('hover:enter', function() { clearInterval(balanser_timer); });
      html.find('.change').on('hover:enter', function() {
        clearInterval(balanser_timer);
        filter.render().find('.filter--sort').trigger('hover:enter');
      });
      scroll.clear();
      scroll.append(html);
      this.loading(false);
      balanser_timer = setInterval(function() {
        tic--;
        html.find('.timeout').text(tic);
        if (tic == 0) {
          clearInterval(balanser_timer);
          var keys = Lampa.Arrays.getKeys(sources);
          var indx = keys.indexOf(balanser);
          var next = keys[indx + 1];
          if (!next) next = keys[0];
          balanser = next;
          if (Lampa.Activity.active().activity == _this9.activity) _this9.changeBalanser(balanser);
        }
      }, 1000);
    };

    this.getLastEpisode = function(items) {
      var last_episode = 0;
      items.forEach(function(e) {
        if (typeof e.episode !== 'undefined') last_episode = Math.max(last_episode, parseInt(e.episode));
      });
      return last_episode;
    };

    this.start = function() {
      var _this = this;
      if (Lampa.Activity.active().activity !== this.activity) return;
      if (!initialized) {
        initialized = true;
        this.initialize();
      }
      Lampa.Background.immediately(Lampa.Utils.cardImgBackgroundBlur(object.movie));
      Lampa.Controller.add('content', {
        toggle: function toggle() {
          Lampa.Controller.collectionSet(scroll.render(), files.render());
          Lampa.Controller.collectionFocus(last || false, scroll.render());
        },
        gone: function gone() { clearTimeout(balanser_timer); },
        up: function up() {
          if (Navigator.canmove('up')) {
            Navigator.move('up');
            return;
          }
          if (modern && _this.uiUpFallback()) return;
          Lampa.Controller.toggle('head');
        },
        down: function down() {
          if (modern && !ui_open && ui_items.length > 1 && _this.uiPanelFocused()) {
            var target = _this.uiPickResume(ui_items);
            if (target && target.__html && target.__html.length) {
              last = target.__html[0];
              scroll.update(target.__html, true);
              Lampa.Controller.collectionFocus(last, scroll.render());
              return;
            }
          }
          Navigator.move('down');
        },
        right: function right() {
          if (Navigator.canmove('right')) Navigator.move('right');
          else if (!modern) filter.show(Lampa.Lang.translate('title_filter'), 'filter');
          else _this.uiPanelFocus();
        },
        left: function left() {
          if (Navigator.canmove('left')) Navigator.move('left');
          else Lampa.Controller.toggle('menu');
        },
        back: this.back.bind(this)
      });
      Lampa.Controller.toggle('content');
      this.uiRefreshMarks();
    };

    this.render = function() { return files.render(); };
    this.back = function() { Lampa.Activity.backward(); };

    var self_marks = this;
    var player_close = function() { self_marks.uiRefreshMarks(); };
    if (Lampa.Player && Lampa.Player.listener && Lampa.Player.listener.follow) {
      Lampa.Player.listener.follow('destroy', player_close);
    }

    this.pause = function() {};
    this.stop = function() {};
    this.destroy = function() {
      if (Lampa.Player && Lampa.Player.listener && Lampa.Player.listener.remove) {
        Lampa.Player.listener.remove('destroy', player_close);
      }
      network.clear();
      this.clearImages();
      files.destroy();
      scroll.destroy();
      clearInterval(balanser_timer);
      clearInterval(ui_load_timer);
      clearTimeout(ui_watchdog);
      clearTimeout(life_wait_timer);
    };
  }

  function isRuUser() {
    try {
      var lang = Lampa.Storage.field('language');
      if (lang) return lang === 'ru';
    } catch(e) {}
    try {
      var nl = (navigator.language || navigator.userLanguage || '').toLowerCase();
      return nl === 'ru' || nl.indexOf('ru-') === 0;
    } catch(e) {}
    return false;
  }

  function startPlugin() {
    window.lampac_z_plugin = true;
    var manifst = {
      type: 'video',
      version: '',
      name: 'Z01',
      description: 'Онлайн фильмы и сериалы',
      component: 'lampac_z',
      onContextMenu: function onContextMenu(object) {
        return { name: Lampa.Lang.translate('lampac_watch'), description: 'Онлайн фильмы и сериалы' };
      },
      onContextLauch: function onContextLauch(object) {
        requireLicense(function() {
          resetTemplates();
          Lampa.Component.add('lampac_z', component);
          var id = Lampa.Utils.hash(object.number_of_seasons ? object.original_name : object.original_title);
          var all = Lampa.Storage.get('clarification_search','{}');
          Lampa.Activity.push({
            url: '',
            title: Lampa.Lang.translate('title_online'),
            component: 'lampac_z',
            search: all[id] ? all[id] : object.title,
            search_one: object.title,
            search_two: object.original_title,
            movie: object,
            page: 1,
            clarification: all[id] ? true : false
          });
        });
      }
    };
    Lampa.Manifest.plugins = manifst;

    Lampa.Lang.add({
      lampac_continue_watch: { ru: 'Продолжить просмотр?', en: 'Continue watching?', uk: 'Продовжити перегляд?', zh: '继续观看？' },
      lampac_continue_yes: { ru: 'Продолжить', en: 'Continue', uk: 'Продовжити', zh: '继续' },
      lampac_continue_no: { ru: 'Выбрать серию', en: 'Choose episode', uk: 'Обрати серію', zh: '选择剧集' },
      lampac_watch: { ru: 'Смотреть онлайн', en: 'Watch online', uk: 'Дивитися онлайн', zh: '在线观看' },
      lampac_video: { ru: 'Видео', en: 'Video', uk: 'Відео', zh: '视频' },
      lampac_no_watch_history: { ru: 'Нет истории просмотра', en: 'No browsing history', ua: 'Немає історії перегляду', zh: '没有浏览历史' },
      lampac_nolink: { ru: 'Не удалось извлечь ссылку', uk: 'Неможливо отримати посилання', en: 'Failed to fetch link', zh: '获取链接失败' },
      lampac_balanser: { ru: 'Источник', uk: 'Джерело', en: 'Source', zh: '来源' },
      helper_online_file: { ru: 'Удерживайте клавишу "ОК" для вызова контекстного меню', uk: 'Утримуйте клавішу "ОК" для виклику контекстного меню', en: 'Hold the "OK" key to bring up the context menu', zh: '按住“确定”键调出上下文菜单' },
      title_online: { ru: 'Онлайн', uk: 'Онлайн', en: 'Online', zh: '在线的' },
      lampac_voice_subscribe: { ru: 'Подписаться на перевод', uk: 'Підписатися на переклад', en: 'Subscribe to translation', zh: '订阅翻译' },
      lampac_voice_success: { ru: 'Вы успешно подписались', uk: 'Ви успішно підписалися', en: 'You have successfully subscribed', zh: '您已成功订阅' },
      lampac_voice_error: { ru: 'Возникла ошибка', uk: 'Виникла помилка', en: 'An error has occurred', zh: '发生了错误' },
      lampac_clear_all_marks: { ru: 'Очистить все метки', uk: 'Очистити всі мітки', en: 'Clear all labels', zh: '清除所有标签' },
      lampac_clear_all_timecodes: { ru: 'Очистить все тайм-коды', uk: 'Очистити всі тайм-коди', en: 'Clear all timecodes', zh: '清除所有时间代码' },
      lampac_change_balanser: { ru: 'Изменить балансер', uk: 'Змінити балансер', en: 'Change balancer', zh: '更改平衡器' },
      lampac_balanser_dont_work: { ru: 'Поиск не дал результатов', uk: 'Пошук не дав результатів', en: 'Search did not return any results', zh: '搜索 未返回任何结果' },
      lampac_balanser_timeout: { ru: 'Источник будет переключен автоматически через <span class="timeout">10</span> секунд.', uk: 'Джерело буде автоматично переключено через <span class="timeout">10</span> секунд.', en: 'The source will be switched automatically after <span class="timeout">10</span> seconds.', zh: '平衡器将在<span class="timeout">10</span>秒内自动切换。' },
      lampac_does_not_answer_text: { ru: 'Поиск не дал результатов', uk: 'Пошук не дав результатів', en: 'Search did not return any results', zh: '搜索 未返回任何结果' },
      z01_continue: { ru: 'Продолжить', uk: 'Продовжити', en: 'Continue', zh: '继续' },
      z01_watch: { ru: 'Смотреть', uk: 'Дивитися', en: 'Watch', zh: '观看' },
      z01_clarify: { ru: 'Уточнить название', uk: 'Уточнити назву', en: 'Refine title', zh: '优化标题' },
      z01_retry: { ru: 'Повторить', uk: 'Повторити', en: 'Retry', zh: '重试' },
      z01_unknown: { ru: 'Неизвестно', uk: 'Невідомо', en: 'Unknown', zh: '未知' },
      z01_try_source: { ru: 'Попробовать {name}', uk: 'Спробувати {name}', en: 'Try {name}', zh: '尝试 {name}' },
      z01_all_sources: { ru: 'Все источники', uk: 'Усі джерела', en: 'All sources', zh: '所有来源' },
      z01_empty_text: { ru: 'Источник «{name}» ничего не нашёл. Попробуйте другой источник или уточните название.', uk: 'Джерело «{name}» нічого не знайшло. Спробуйте інше джерело або уточніть назву.', en: 'Source "{name}" found nothing. Try another source or refine the title.', zh: '来源“{name}”没有找到任何内容。请尝试其他来源或优化标题。' },
      z01_no_server: { ru: 'Сервер не отвечает. Проверьте интернет и попробуйте ещё раз.', uk: 'Сервер не відповідає. Перевірте інтернет і спробуйте ще раз.', en: 'The server is not responding. Check your connection and try again.', zh: '服务器无响应。请检查网络连接后重试。' },
      z01_auto_switch_text: { ru: 'Через {sec} сек переключимся на «{name}»', uk: 'Через {sec} с перемкнемося на «{name}»', en: 'Switching to "{name}" in {sec} sec', zh: '{sec} 秒后切换到“{name}”' },
      z01_season_progress: { ru: 'Просмотрено {seen} из {total}', uk: 'Переглянуто {seen} з {total}', en: 'Watched {seen} of {total}', zh: '已观看 {seen} / {total}' },
      z01_voice_dub: { ru: 'Дубляж', uk: 'Дубляж', en: 'Dubbing', zh: '配音' },
      z01_voice_mvo: { ru: 'Многоголосый', uk: 'Багатоголосий', en: 'Multi-voice', zh: '多人配音' },
      z01_voice_dvo: { ru: 'Двухголосый', uk: 'Двоголосий', en: 'Two-voice', zh: '双人配音' },
      z01_voice_avo: { ru: 'Авторский', uk: 'Авторський', en: 'Single-voice', zh: '单人配音' },
      z01_voice_orig: { ru: 'Оригинал', uk: 'Оригінал', en: 'Original', zh: '原声' },
      z01_voice_sub: { ru: 'Субтитры', uk: 'Субтитри', en: 'Subtitles', zh: '字幕' },
      z01_voice_other: { ru: 'Прочие', uk: 'Інші', en: 'Other', zh: '其他' },
      z01_empty_title: { ru: 'Поиск не дал результатов', uk: 'Пошук не дав результатів', en: 'Search did not return any results', zh: '搜索未返回任何结果' },
      z01_timeout_title: { ru: 'Источник не ответил', uk: 'Джерело не відповіло', en: 'The source did not respond', zh: '来源未响应' },
      z01_timeout_text: { ru: '«{name}» слишком долго не отвечает. Возьмём другой источник или попробуем ещё раз.', uk: '«{name}» надто довго не відповідає. Візьмемо інше джерело або спробуємо ще раз.', en: '"{name}" is taking too long. Try another source or repeat the request.', zh: '“{name}”响应时间过长。请更换来源或重试。' },
      z01_similar_best: { ru: 'Похоже, это он', uk: 'Схоже, це він', en: 'Looks like this one', zh: '应该是这部' },
      z01_similar_all: { ru: 'Варианты', uk: 'Варіанти', en: 'Other matches', zh: '其他结果' },
      z01_mark_before: { ru: 'Отметить всё до этой', uk: 'Позначити все до цієї', en: 'Mark everything up to this', zh: '标记此集之前全部' },
      z01_season_left: { ru: 'осталось {left}', uk: 'залишилось {left}', en: '{left} left', zh: '还剩 {left} 集' },
      z01_no_access: { ru: 'Нет доступа', uk: 'Немає доступу', en: 'No access', zh: '无访问权限' },
      z01_no_access_text: { ru: 'Сервер отказал в доступе', uk: 'Сервер відмовив у доступі', en: 'The server denied access', zh: '服务器拒绝访问' },
      z01_left: { ru: 'осталось', uk: 'залишилось', en: 'left', zh: '剩余' },
      z01_loading_title: { ru: 'Ищем, где посмотреть', uk: 'Шукаємо, де подивитися', en: 'Looking for sources', zh: '正在查找播放源' },
      z01_loading_list: { ru: 'Загружаем список', uk: 'Завантажуємо список', en: 'Loading the list', zh: '正在加载列表' },
      z01_loading_start: { ru: 'Опрашиваем источники', uk: 'Опитуємо джерела', en: 'Polling sources', zh: '正在查询来源' },
      z01_loading_found: { ru: 'Найдено источников: {n}', uk: 'Знайдено джерел: {n}', en: 'Sources found: {n}', zh: '已找到来源：{n}' },
      z01_loading_slow: { ru: 'отвечают медленно', uk: 'відповідають повільно', en: 'responding slowly', zh: '响应缓慢' },
      z01_sec: { ru: ' с', uk: ' с', en: 's', zh: ' 秒' },
      z01_ui_mode_name: { ru: 'Интерфейс', uk: 'Інтерфейс', en: 'Interface', zh: '界面' },
      z01_ui_mode_descr: { ru: 'Новый — шапка с продолжением и выбор перевода на экране', uk: 'Новий — шапка з продовженням і вибір перекладу на екрані', en: 'New — hero header with resume and on-screen translation picker', zh: '新版 — 带继续播放的头部和屏幕上的翻译选择' },
      z01_ui_modern: { ru: 'Новый', uk: 'Новий', en: 'New', zh: '新版' },
      z01_ui_classic: { ru: 'Классический', uk: 'Класичний', en: 'Classic', zh: '经典' }
    });

    // Меню Лицензии
    Lampa.SettingsApi.addComponent({
      component: 'z01_license',
      icon: '<svg width="36" height="36" viewBox="0 0 128 128" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="8" y="8" width="112" height="112" rx="32" fill="none" stroke="white" stroke-width="12"/><path d="M38 36h52L38 92h52" stroke="white" stroke-width="12" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg>',
      name: 'Z01 Лицензия'
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_license',
      param: { name: 'z01_devid_view', type: 'title', default: true },
      field: { name: '...' },
      onRender: function(item) {
        var devId = getMyDeviceId();
        item.find('.settings-param__name,.settings-param-title__text').text('ID вашего ТВ: ' + devId);
      }
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_license',
      param: { name: 'z01_lic_status', type: 'title', default: true },
      field: { name: '...' },
      onRender: function(item) {
        var lic = verifyLicense();
        var txt = lic.active ? ('● Подписка активна (до ' + lic.date + ', ' + lic.days + ' дн.)') : ('○ Статус: ' + lic.msg);
        item.find('.settings-param__name,.settings-param-title__text').text(txt);
      }
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_license',
      param: { name: 'z01_enter_key_btn', type: 'button', default: '' },
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
      component: 'z01_license',
      param: {
        name: 'z01_ui_mode',
        type: 'select',
        values: { modern: 'Новый', classic: 'Классический' },
        "default": 'modern'
      },
      field: { name: 'Интерфейс', description: 'Стиль отображения серий и озвучек' }
    });

    Lampa.Template.add('lampac_css', "\n        <style>\n        @charset 'UTF-8';.online-prestige{position:relative;-webkit-border-radius:.3em;border-radius:.3em;background-color:rgba(0,0,0,0.3);display:-webkit-box;display:-webkit-flex;display:-moz-box;display:-ms-flexbox;display:flex}.online-prestige__body{padding:1.2em;line-height:1.3;-webkit-box-flex:1;-webkit-flex-grow:1;-moz-box-flex:1;-ms-flex-positive:1;flex-grow:1;position:relative}@media screen and (max-width:480px){.online-prestige__body{padding:.8em 1.2em}}.online-prestige__img{position:relative;width:13em;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0;min-height:8.2em}.online-prestige__img>img{position:absolute;top:0;left:0;width:100%;height:100%;-o-object-fit:cover;object-fit:cover;-webkit-border-radius:.3em;border-radius:.3em;opacity:0;-webkit-transition:opacity .3s;-o-transition:opacity .3s;-moz-transition:opacity .3s;transition:opacity .3s}.online-prestige__img--loaded>img{opacity:1}@media screen and (max-width:480px){.online-prestige__img{width:7em;min-height:6em}}.online-prestige__folder{padding:1em;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0}.online-prestige__folder>svg{width:4.4em !important;height:4.4em !important}.online-prestige__viewed{position:absolute;top:1em;left:1em;background:rgba(0,0,0,0.45);-webkit-border-radius:100%;border-radius:100%;padding:.25em;font-size:.76em}.online-prestige__viewed>svg{width:1.5em !important;height:1.5em !important}.online-prestige__episode-number{position:absolute;top:0;left:0;right:0;bottom:0;display:-webkit-box;display:-webkit-flex;display:-moz-box;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-moz-box-align:center;-ms-flex-align:center;align-items:center;-webkit-box-pack:center;-webkit-justify-content:center;-moz-box-pack:center;-ms-flex-pack:center;justify-content:center;font-size:2em}.online-prestige__loader{position:absolute;top:50%;left:50%;width:2em;height:2em;margin-left:-1em;margin-top:-1em;background:url(./img/loader.svg) no-repeat center center;-webkit-background-size:contain;-o-background-size:contain;background-size:contain}.online-prestige__head,.online-prestige__footer{display:-webkit-box;display:-webkit-flex;display:-moz-box;display:-ms-flexbox;display:flex;-webkit-box-pack:justify;-webkit-justify-content:space-between;-moz-box-pack:justify;-ms-flex-pack:justify;justify-content:space-between;-webkit-box-align:center;-webkit-align-items:center;-moz-box-align:center;-ms-flex-align:center;align-items:center}.online-prestige__timeline{margin:.8em 0}.online-prestige__timeline>.time-line{display:block !important}.online-prestige__title{font-size:1.7em;overflow:hidden;-o-text-overflow:ellipsis;text-overflow:ellipsis;display:-webkit-box;-webkit-line-clamp:1;line-clamp:1;-webkit-box-orient:vertical}@media screen and (max-width:480px){.online-prestige__title{font-size:1.4em}}.online-prestige__time{padding-left:2em}.online-prestige__info{display:-webkit-box;display:-webkit-flex;display:-moz-box;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-moz-box-align:center;-ms-flex-align:center;align-items:center}.online-prestige__info>*{overflow:hidden;-o-text-overflow:ellipsis;text-overflow:ellipsis;display:-webkit-box;-webkit-line-clamp:1;line-clamp:1;-webkit-box-orient:vertical}.online-prestige__quality{padding-left:1em;white-space:nowrap}.online-prestige__scan-file{position:absolute;bottom:0;left:0;right:0}.online-prestige__scan-file .broadcast__scan{margin:0}.online-prestige .online-prestige-split{font-size:.8em;margin:0 1em;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0}.online-prestige.focus::after{content:'';position:absolute;top:-0.6em;left:-0.6em;right:-0.6em;bottom:-0.6em;-webkit-border-radius:.7em;border-radius:.7em;border:solid .3em #fff;z-index:-1;pointer-events:none}.online-prestige+.online-prestige{margin-top:1.5em}.online-prestige--folder .online-prestige__footer{margin-top:.8em}.online-prestige-watched{padding:1em}.online-prestige-watched__icon>svg{width:1.5em;height:1.5em}.online-prestige-watched__body{padding-left:1em;padding-top:.1em;display:-webkit-box;display:-webkit-flex;display:-moz-box;display:-ms-flexbox;display:flex;-webkit-flex-wrap:wrap;-ms-flex-wrap:wrap;flex-wrap:wrap}.online-prestige-watched__body>span+span::before{content:' ● ';vertical-align:top;display:inline-block;margin:0 .5em}.online-prestige-rate{display:-webkit-inline-box;display:-webkit-inline-flex;display:-moz-inline-box;display:-ms-inline-flexbox;display:inline-flex;-webkit-box-align:center;-webkit-align-items:center;-moz-box-align:center;-ms-flex-align:center;align-items:center}.online-prestige-rate>svg{width:1.3em !important;height:1.3em !important}.online-prestige-rate>span{font-weight:600;font-size:1.1em;padding-left:.7em}.online-empty{line-height:1.4}.online-empty__title{font-size:1.8em;margin-bottom:.3em}.online-empty__time{font-size:1.2em;font-weight:300;margin-bottom:1.6em}.online-empty__buttons{display:-webkit-box;display:-webkit-flex;display:-moz-box;display:-ms-flexbox;display:flex}.online-empty__buttons>*+*{margin-left:1em}.online-empty__button{background:rgba(0,0,0,0.3);font-size:1.2em;padding:.5em 1.2em;-webkit-border-radius:.2em;border-radius:.2em;margin-bottom:2.4em}.online-empty__button.focus{background:#fff;color:black}.online-empty__templates .online-empty-template:nth-child(2){opacity:.5}.online-empty__templates .online-empty-template:nth-child(3){opacity:.2}.online-empty-template{background-color:rgba(255,255,255,0.3);padding:1em;display:-webkit-box;display:-webkit-flex;display:-moz-box;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-moz-box-align:center;-ms-flex-align:center;align-items:center;-webkit-border-radius:.3em;border-radius:.3em}.online-empty-template>*{background:rgba(0,0,0,0.3);-webkit-border-radius:.3em;border-radius:.3em}.online-empty-template__ico{width:4em;height:4em;margin-right:2.4em}.online-empty-template__body{height:1.7em;width:70%}.online-empty-template+.online-empty-template{margin-top:1em}\n        </style>\n    ");
    $('body').append(Lampa.Template.get('lampac_css', {}, true));
    $('body').append(Z01UI.css);

    var button = "<div class=\"full-start__button selector view--online lampac--button\" data-subtitle=\"".concat(manifst.name, " ").concat(manifst.version, "\"><svg width=\"128\" height=\"128\" viewBox=\"0 0 128 128\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\"><rect x=\"8\" y=\"8\" width=\"112\" height=\"112\" rx=\"32\" fill=\"white\" stroke=\"#2886fb\" stroke-width=\"12\"/><path d=\"M38 36h52L38 92h52\" stroke=\"#2886fb\" stroke-width=\"12\" stroke-linecap=\"round\" stroke-linejoin=\"round\" fill=\"none\"/></svg><span>#{title_online}</span></div>");

    function addButton(e) {
      if (e.render.find('.lampac--button').length) return;
      var btn = $(Lampa.Lang.translate(button));
      btn.on('hover:enter', function() {
        requireLicense(function() {
          resetTemplates();
          Lampa.Component.add('lampac_z', component);
          
          var id = Lampa.Utils.hash(e.movie.number_of_seasons ? e.movie.original_name : e.movie.original_title);
          var all = Lampa.Storage.get('clarification_search','{}');
          
          var isSeries = e.movie.number_of_seasons || e.movie.name;
          var continueEnabled = true;
          var file_id = Lampa.Utils.hash(e.movie.number_of_seasons ? e.movie.original_name : e.movie.original_title);
          var watched = Lampa.Storage.cache('online_watched_last', 5000, {});
          var watchedData = watched[file_id];

          if (Z01UI.enabled()) {
            if (isSeries && watchedData && watchedData.balanser && watchedData.season && watchedData.episode) {
              var last_balanser_map = Lampa.Storage.cache('online_last_balanser', 3000, {});
              last_balanser_map[e.movie.id] = watchedData.balanser;
              Lampa.Storage.set('online_last_balanser', last_balanser_map);

              var resume_choice = Lampa.Storage.cache('online_choice_' + watchedData.balanser, 3000, {});
              if (!resume_choice[e.movie.id]) resume_choice[e.movie.id] = {};
              var resume_season = (parseInt(watchedData.season) || 1) - 1;
              if (resume_season < 0) resume_season = 0;
              resume_choice[e.movie.id].season = resume_season;
              if (watchedData.voice_name) resume_choice[e.movie.id].voice_name = watchedData.voice_name;
              Lampa.Storage.set('online_choice_' + watchedData.balanser, resume_choice);
            }

            Lampa.Activity.push({
              url: '',
              title: Lampa.Lang.translate('title_online'),
              component: 'lampac_z',
              search: all[id] ? all[id] : e.movie.title,
              search_one: e.movie.title,
              search_two: e.movie.original_title,
              movie: e.movie,
              page: 1,
              clarification: all[id] ? true : false
            });
            return;
          }

          if (isSeries && continueEnabled && watchedData && watchedData.season && watchedData.episode) {
            var line = [];
            if (watchedData.balanser_name) line.push(watchedData.balanser_name);
            if (watchedData.voice_name) line.push(watchedData.voice_name);
            line.push(Lampa.Lang.translate('torrent_serial_season') + ' ' + watchedData.season);
            line.push(Lampa.Lang.translate('torrent_serial_episode') + ' ' + watchedData.episode);

            Lampa.Select.show({
              title: Lampa.Lang.translate('lampac_continue_watch'),
              items: [
                { title: '▶ ' + Lampa.Lang.translate('lampac_continue_yes') + ' (' + line.join(' · ') + ')', continue_yes: true },
                { title: Lampa.Lang.translate('lampac_continue_no'), continue_no: true }
              ],
              onBack: function() {
                Lampa.Controller.toggle('content');
              },
              onSelect: function(sel) {
                Lampa.Select.close();

                if (sel.continue_yes && watchedData.balanser) {
                  var last_select_balanser = Lampa.Storage.cache('online_last_balanser', 3000, {});
                  last_select_balanser[e.movie.id] = watchedData.balanser;
                  Lampa.Storage.set('online_last_balanser', last_select_balanser);

                  var choiceData = Lampa.Storage.cache('online_choice_' + watchedData.balanser, 3000, {});
                  if (!choiceData[e.movie.id]) choiceData[e.movie.id] = {};
                  var seasonIdx = (parseInt(watchedData.season) || 1) - 1;
                  if (seasonIdx < 0) seasonIdx = 0;
                  choiceData[e.movie.id].season = seasonIdx;
                  if (watchedData.voice_name) choiceData[e.movie.id].voice_name = watchedData.voice_name;
                  Lampa.Storage.set('online_choice_' + watchedData.balanser, choiceData);

                  Lampa.Activity.push({
                    url: '',
                    title: Lampa.Lang.translate('title_online'),
                    component: 'lampac_z',
                    search: all[id] ? all[id] : e.movie.title,
                    search_one: e.movie.title,
                    search_two: e.movie.original_title,
                    movie: e.movie,
                    page: 1,
                    clarification: all[id] ? true : false,
                    lampac_continue_episode: parseInt(watchedData.episode) || 1
                  });
                } else {
                  Lampa.Activity.push({
                    url: '',
                    title: Lampa.Lang.translate('title_online'),
                    component: 'lampac_z',
                    search: all[id] ? all[id] : e.movie.title,
                    search_one: e.movie.title,
                    search_two: e.movie.original_title,
                    movie: e.movie,
                    page: 1,
                    clarification: all[id] ? true : false
                  });
                }
              }
            });
          } else {
            Lampa.Activity.push({
              url: '',
              title: Lampa.Lang.translate('title_online'),
              component: 'lampac_z',
              search: all[id] ? all[id] : e.movie.title,
              search_one: e.movie.title,
              search_two: e.movie.original_title,
              movie: e.movie,
              page: 1,
              clarification: all[id] ? true : false
            });
          }
        });
      });
      e.render.after(btn);
    }

    Lampa.Listener.follow('full', function(e) {
      if (e.type == 'complite') {
        addButton({
          render: e.object.activity.render().find('.view--torrent'),
          movie: e.data.movie
        });
      }
    });

    try {
      if (Lampa.Activity.active().component == 'full') {
        addButton({
          render: Lampa.Activity.activity.render().find('.view--torrent'),
          movie: Lampa.Activity.active().card
        });
      }
    } catch (e) {}

    if (Lampa.Manifest.app_digital >= 177) {
      var balansers_sync = ["filmix", "filmixtv", "fxapi", "rezka", "rhsprem", "lumex", "videodb", "collaps", "collaps-dash", "hdvb", "zetflix", "kodik", "ashdi", "kinoukr", "kinotochka", "remux", "iframevideo", "cdnmovies", "anilibria", "animedia", "animego", "animevost", "animebesst", "redheadsound", "alloha", "animelib", "moonanime", "kinopub", "vibix", "vdbmovies", "fancdn", "cdnvideohub", "vokino", "rc/filmix", "rc/fxapi", "rc/rhs", "vcdn", "videocdn", "mirage", "hydraflix", "videasy", "vidsrc", "movpi", "vidlink", "twoembed", "autoembed", "smashystream", "rgshows", "pidtor", "videoseed", "iptvonline", "veoveo", "kinoteatrkg", "mirkino", "xvideocdnultra", "xvideocdn", "xvideocdn60fps", "kinogo", "rutubemovie", "vkmovie", "solntse", "geosaitebi", "lordfilm", "zetflixdb", "sakhtv", "kinobase", "asiage", "zagonka"];
      balansers_sync.forEach(syncBalanser);
      Lampa.Storage.sync('online_watched_last', 'object_object');
      Lampa.Storage.sync('online_last_balanser', 'object_object');
      Lampa.Storage.sync('z01_season_last', 'object_object');
      Lampa.Storage.sync('z01_reach', 'object_object');
      Lampa.Storage.sync('online_view', 'object_array');
    }
  }

  // Автопроверка и активация демо при старте
  zpremActivate();

  if (!window.lampac_z_plugin) startPlugin();
})();
