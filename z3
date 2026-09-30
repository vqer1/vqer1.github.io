(function() {
  'use strict';

  // ===== 1. СИСТЕМА ОФЛАЙН-ЛИЦЕНЗИРОВАНИЯ FX1 =====
  var LIC_SALT = "Z01_SALT_2026_V5";

  function licHash(s) {
    var h = 5381;
    for (var i = 0; i < s.length; i++) {
      h = ((h << 5) + h) + s.charCodeAt(i);
      h = h & h;
    }
    return Math.abs(h).toString(16).toUpperCase();
  }

  // Фиксированный 6-значный ID ТВ (НЕ сбрасывается при сбросах триала z01)
  function getMyDeviceId() {
    var id = Lampa.Storage.get('fx1_my_dev_id', '');
    if (!id) {
      id = Lampa.Utils.uid(6).toUpperCase();
      Lampa.Storage.set('fx1_my_dev_id', id);
    }
    return id;
  }

  // Проверка ключа ГГММДД-ХХХХХ (12 символов, ровно 5 знаков подписи)
  function verifyLicense() {
    var key = (Lampa.Storage.get('fx1_license_key', '') || '').trim().toUpperCase();
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
      return { active: false, msg: 'Срок действия подписки истек' };
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
        '<div style="font-size:1.5em;margin-bottom:0.4em;color:#e74c3c;font-weight:bold;">🔒 FX1 — Требуется активация</div>' +
        '<div style="font-size:1.05em;opacity:0.8;margin-bottom:1.2em;">' + lic.msg + '</div>' +
        '<div style="font-size:0.9em;opacity:0.6;margin-bottom:0.3em;">Ваш ID устройства:</div>' +
        '<div style="font-size:1.8em;font-weight:bold;color:#7cc4ff;background:rgba(255,255,255,0.08);padding:10px 15px;border-radius:8px;margin-bottom:1.2em;letter-spacing:2px;user-select:all;display:inline-block;">' + devId + '</div>' +
        '<div style="font-size:1.05em;margin-bottom:0.5em;color:#fff;">Для покупки или продления ключа пишите в Telegram:</div>' +
        '<div style="font-size:1.4em;font-weight:bold;color:#2886fb;margin-bottom:1.2em;">@Lopxh</div>' +
        '<div style="font-size:0.85em;opacity:0.6;">После получения ключа введите его в: Настройки &rarr; FX1 Лицензия</div>' +
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
  if (typeof Promise === 'undefined') {
    window.Promise = function(executor) {
      var self = this;[cite: 7]
      self._state = 0;[cite: 7]
      self._value = undefined;[cite: 7]
      self._handlers = [];[cite: 7]
      function resolve(val) {
        if (self._state !== 0) return;[cite: 7]
        self._state = 1;[cite: 7]
        self._value = val;[cite: 7]
        self._handlers.forEach(function(h) { h.onFulfilled(val); });[cite: 7]
      }
      function reject(val) {
        if (self._state !== 0) return;[cite: 7]
        self._state = 2;[cite: 7]
        self._value = val;[cite: 7]
        self._handlers.forEach(function(h) { h.onRejected(val); });[cite: 7]
      }
      try { executor(resolve, reject); } catch(e) { reject(e); }[cite: 7]
    };
    window.Promise.prototype.then = function(onFulfilled, onRejected) {
      var self = this;[cite: 7]
      return new Promise(function(resolve, reject) {
        function handle(onFn, fallback) {
          return function(val) {
            try {
              var result = (typeof onFn === 'function') ? onFn(val) : fallback(val);[cite: 7]
              if (result && typeof result.then === 'function') result.then(resolve, reject);[cite: 7]
              else resolve(result);[cite: 7]
            } catch(e) { reject(e); }[cite: 7]
          };
        }
        var handler = {
          onFulfilled: handle(onFulfilled, function(v) { return v; }),[cite: 7]
          onRejected: handle(onRejected, function(e) { throw e; })[cite: 7]
        };
        if (self._state === 1) setTimeout(function() { handler.onFulfilled(self._value); }, 0);[cite: 7]
        else if (self._state === 2) setTimeout(function() { handler.onRejected(self._value); }, 0);[cite: 7]
        else self._handlers.push(handler);[cite: 7]
      });
    };
    window.Promise.prototype['catch'] = function(onRejected) { return this.then(null, onRejected); };[cite: 7]
    window.Promise.resolve = function(val) { return new Promise(function(r) { r(val); }); };[cite: 7]
    window.Promise.reject = function(val) { return new Promise(function(_, r) { r(val); }); };[cite: 7]
  }

  // ===== 3. СЕРВЕРЫ =====
  var Z01_SERVERS = [
    'http://s1.z01.online/',
    'http://s2.z01.online/',
    'http://s3.z01.online/'
  ];[cite: 7]
  var Z01_FALLBACK = 'http://z01.online/';[cite: 7]
  var Z01_PING_TIMEOUT = 1500;[cite: 7]

  function z01Ping(url, callback) {
    var xhr = new XMLHttpRequest();[cite: 7]
    var done = false;[cite: 7]
    function finish(ok) {
      if (done) return;[cite: 7]
      done = true;[cite: 7]
      callback(ok);[cite: 7]
    }
    try {
      xhr.open('GET', url, true);[cite: 7]
      xhr.timeout = Z01_PING_TIMEOUT;[cite: 7]
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
      var tmp = copy[i];[cite: 7]
      copy[i] = copy[j];[cite: 7]
      copy[j] = tmp;[cite: 7]
    }
    return copy;[cite: 7]
  }

  function z01PickServer(callback) {
    var candidates = z01Shuffle(Z01_SERVERS);[cite: 7]
    function tryNext(index) {
      if (index >= candidates.length) {
        callback(Z01_FALLBACK);[cite: 7]
        return;[cite: 7]
      }
      z01Ping(candidates[index], function(ok) {
        if (ok) callback(candidates[index]);[cite: 7]
        else tryNext(index + 1);[cite: 7]
      });
    }
    tryNext(0);[cite: 7]
  }

  var Defined = {
    api: 'lampac',
    localhost: 'http://z01.online/',
    apn: ''
  };[cite: 7]

  var Z01_FREE = Z01_FALLBACK;[cite: 7]
  z01PickServer(function(server) {
    Z01_FREE = server;[cite: 7]
    if (Defined.localhost === Z01_FALLBACK) Defined.localhost = server;[cite: 7]
  });

  var ZPREM_SERVER = (Lampa.Utils && Lampa.Utils.protocol ? Lampa.Utils.protocol() : 'http://') + 'prem.z01.online/';[cite: 7]
  var ZPREM_CHECK_URL = (Lampa.Utils && Lampa.Utils.protocol ? Lampa.Utils.protocol() : 'http://') + 'oplata.z01.online/check.php';[cite: 7]
  var ZPREM_PAY_URL = 'https://oplata.z01.online/pay.php';[cite: 7]
  var ZPREM_TRIAL_URL = (Lampa.Utils && Lampa.Utils.protocol ? Lampa.Utils.protocol() : 'http://') + 'oplata.z01.online/trial.php';[cite: 7]

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

  // ===== 4. ФОНОВЫЙ ТРИАЛ Z01 (НЕ ТРОГАЕТ fx1_my_dev_id) =====
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
    var base = Lampa.Storage.get('account_email', '');[cite: 7]
    var newEmail = '';[cite: 7]
    if (base && base.indexOf('@') !== -1) {
      var parts = base.split('@');[cite: 7]
      var name = parts[0].split('+')[0];[cite: 7]
      newEmail = name + '+z' + Lampa.Utils.uid(5).toLowerCase() + '@' + parts[1];[cite: 7]
    } else {
      newEmail = 'z01_' + Lampa.Utils.uid(8).toLowerCase() + '@gmail.com';[cite: 7]
    }
    Lampa.Storage.set('z01_trial_email', newEmail);[cite: 7]
    return newEmail;[cite: 7]
  }

  function zpremResetTrial(quiet) {
    Lampa.Storage.set('zpremkey', '');[cite: 7]
    Lampa.Storage.set('zprem_expires', '');[cite: 7]
    Lampa.Storage.set('zprem_trial_used', '');[cite: 7]
    resetZ01Uid();[cite: 7]
    rotateZ01TrialEmail();[cite: 7]
    if (!quiet && typeof Lampa !== 'undefined' && Lampa.Noty) {
      Lampa.Noty.show('Демо-режим сброшен, можно активировать заново!');[cite: 7]
    }
  }
  window.zpremResetTrial = zpremResetTrial;[cite: 7]

  function isZpremActive() {
    var key = Lampa.Storage.get('zpremkey', '');[cite: 7]
    var exp = Lampa.Storage.get('zprem_expires', '');[cite: 7]
    if (key && exp) {
      return (new Date(exp).getTime() - Date.now()) > 0;[cite: 7]
    }
    return false;[cite: 7]
  }

  function zpremTrial(callback) {
    if (!isZpremActive()) {
      zpremResetTrial(true);[cite: 7]
    }
    var email = getZ01Email();[cite: 7]
    var uid = Lampa.Storage.get('lampac_unic_id', '');[cite: 7]
    if (!email || !uid) { if (callback) callback(false); return; }[cite: 7]

    var net = new Lampa.Reguest();[cite: 7]
    net.timeout(10000);[cite: 7]

    function sendTrialRequest(e, u, attempts) {
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
            var nextEmail = rotateZ01TrialEmail();[cite: 7]
            var nextUid = resetZ01Uid();[cite: 7]
            sendTrialRequest(nextEmail, nextUid, attempts + 1);[cite: 7]
          } else {
            if (callback) callback(false);[cite: 7]
          }
        } catch(err) { if (callback) callback(false); }[cite: 7]
      }, function() {
        if (callback) callback(false);[cite: 7]
      });
    }

    sendTrialRequest(email, uid, 0);[cite: 7]
  }

  function zpremAutoEnsure(callback) {
    if (!verifyLicense().active) {
      if (callback) callback(false);
      return;
    }
    if (isZpremActive()) {
      Defined.localhost = ZPREM_SERVER;[cite: 7]
      if (callback) callback(true);[cite: 7]
      return;[cite: 7]
    }
    zpremTrial(function(ok) {
      if (ok) {
        Defined.localhost = ZPREM_SERVER;[cite: 7]
        if (callback) callback(true);[cite: 7]
      } else {
        if (callback) callback(false);[cite: 7]
      }
    });
  }

  function zpremActivate() {
    if (verifyLicense().active) {
      if (isZpremActive()) {
        Defined.localhost = ZPREM_SERVER;[cite: 7]
      } else {
        zpremAutoEnsure();[cite: 7]
      }
    }
  }

  window.zpremTrial = zpremTrial;[cite: 7]
  window.zpremAutoEnsure = zpremAutoEnsure;[cite: 7]

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
    window.rch_nws[hostkey] = {
      type: Lampa.Platform.is('android') ? 'apk' : Lampa.Platform.is('tizen') ? 'cors' : undefined,[cite: 7]
      startTypeInvoke: false,[cite: 7]
      rchRegistry: false,[cite: 7]
      apkVersion: getAndroidVersion()[cite: 7]
    };
  }

  window.rch_nws[hostkey].typeInvoke = function rchtypeInvoke(host, call) {
    if (!window.rch_nws[hostkey].startTypeInvoke) {[cite: 7]
      window.rch_nws[hostkey].startTypeInvoke = true;[cite: 7]
      var check = function check(good) {
        window.rch_nws[hostkey].type = Lampa.Platform.is('android') ? 'apk' : good ? 'cors' : 'web';[cite: 7]
        call();[cite: 7]
      };
      if (Lampa.Platform.is('android') || Lampa.Platform.is('tizen')) check(true);[cite: 7]
      else {
        var net = new Lampa.Reguest();[cite: 7]
        net.silent('https://z01.online'.indexOf(location.host) >= 0 ? 'https://github.com/' : host + '/cors/check', function() {[cite: 7]
          check(true);[cite: 7]
        }, function() {
          check(false);[cite: 7]
        }, false, { dataType: 'text' });[cite: 7]
      }
    } else call();[cite: 7]
  };

  window.rch_nws[hostkey].Registry = function RchRegistry(client, startConnection) {
    window.rch_nws[hostkey].typeInvoke('https://z01.online', function() {[cite: 7]
      client.invoke("RchRegistry", {
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

      if (client._shouldReconnect && window.rch_nws[hostkey].rchRegistry) {[cite: 7]
        if (startConnection) startConnection();[cite: 7]
        return;[cite: 7]
      }
      window.rch_nws[hostkey].rchRegistry = true;[cite: 7]

      client.on('RchRegistry', function(clientIp) {[cite: 7]
        if (startConnection) startConnection();[cite: 7]
      });

      client.on("RchClient", function(rchId, url, data, headers, returnHeaders) {[cite: 7]
        var network = new Lampa.Reguest();[cite: 7]
        var rchOrigin = (client && client.url) ? client.url.replace(/^ws(s?):\/\/([^\/?#]+).*/, 'http$1://$2') : 'https://z01.online';[cite: 7]

        function sendResult(uri, html) {
          $.ajax({
            url: rchOrigin + '/rch/' + uri + '?id=' + rchId,[cite: 7]
            type: 'POST',[cite: 7]
            data: html,[cite: 7]
            async: true,[cite: 7]
            cache: false,[cite: 7]
            contentType: false,[cite: 7]
            processData: false,[cite: 7]
            success: function(j) {},[cite: 7]
            error: function() { client.invoke("RchResult", rchId, ''); }[cite: 7]
          });
        }

        function result(html) {
          if (Lampa.Arrays.isObject(html) || Lampa.Arrays.isArray(html)) {[cite: 7]
            html = JSON.stringify(html);[cite: 7]
          }
          if (typeof CompressionStream !== 'undefined' && html && html.length > 2000) {[cite: 7]
            var compressionStream = new CompressionStream('gzip');[cite: 7]
            var encoder = new TextEncoder();[cite: 7]
            var readable = new ReadableStream({
              start: function(controller) {[cite: 7]
                controller.enqueue(encoder.encode(html));[cite: 7]
                controller.close();[cite: 7]
              }
            });
            var compressedStream = readable.pipeThrough(compressionStream);[cite: 7]
            new Response(compressedStream).arrayBuffer().then(function(compressedBuffer) {[cite: 7]
              var compressedArray = new Uint8Array(compressedBuffer);[cite: 7]
              if (compressedArray.length > html.length) {[cite: 7]
                sendResult('result', html);[cite: 7]
              } else {
                sendResult('gzresult', new Blob([compressedArray], { type: 'application/octet-stream' }));[cite: 7]
              }
            })['catch'](function() { sendResult('result', html); });[cite: 7]
          } else {
            sendResult('result', html);[cite: 7]
          }
        }

        if (url == 'eval') result(eval(data));[cite: 7]
        else if (url == 'evalrun') eval(data);[cite: 7]
        else if (url == 'ping') result('pong');[cite: 7]
        else {
          network["native"](url, result, function(e) { result(''); }, data, {[cite: 7]
            dataType: 'text',[cite: 7]
            timeout: 1000 * 8,[cite: 7]
            headers: headers,[cite: 7]
            returnHeaders: returnHeaders[cite: 7]
          });
        }
      });

      client.on('Connected', function(connectionId) { window.rch_nws[hostkey].connectionId = connectionId; });[cite: 7]
      client.on('Closed', function() {});[cite: 7]
      client.on('Error', function(err) {});[cite: 7]
    });
  };
  window.rch_nws[hostkey].typeInvoke('https://z01.online', function() {});[cite: 7]

  function rchInvoke(json, call) {
    if (window.nwsClient && window.nwsClient[hostkey] && window.nwsClient[hostkey]._shouldReconnect){[cite: 7]
      call();[cite: 7]
      return;[cite: 7]
    }
    if (!window.nwsClient) window.nwsClient = {};[cite: 7]
    if (window.nwsClient[hostkey] && window.nwsClient[hostkey].socket) window.nwsClient[hostkey].socket.close();[cite: 7]
    window.nwsClient[hostkey] = new NativeWsClient(json.nws, { autoReconnect: false });[cite: 7]
    window.nwsClient[hostkey].on('Connected', function(connectionId) {[cite: 7]
      window.rch_nws[hostkey].Registry(window.nwsClient[hostkey], function() { call(); });[cite: 7]
    });
    window.nwsClient[hostkey].connect();[cite: 7]
  }

  function rchRun(json, call) {
    if (typeof NativeWsClient == 'undefined') {[cite: 7]
      Lampa.Utils.putScript(["https://z01.online/js/nws-client-es5.js?v03022026"], function() {}, false, function() {[cite: 7]
        rchInvoke(json, call);[cite: 7]
      }, true);[cite: 7]
    } else {
      rchInvoke(json, call);[cite: 7]
    }
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
    if (url.indexOf('token=') == -1) {[cite: 7]
      var token = '';[cite: 7]
      if (token != '') url = Lampa.Utils.addUrlComponent(url, 'token=');[cite: 7]
    }
    if (url.indexOf('nws_id=') == -1 && window.rch_nws && window.rch_nws[hostkey]) {[cite: 7]
      var nws_id = window.rch_nws[hostkey].connectionId || Lampa.Storage.get('lampac_nws_id', '');[cite: 7]
      if (nws_id) url = Lampa.Utils.addUrlComponent(url, 'nws_id=' + encodeURIComponent(nws_id));[cite: 7]
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

  // ===== 5. UI МОДУЛЬ Z01 =====
  var Z01UI = {};[cite: 7]
  Z01UI.enabled = function() { return Lampa.Storage.get('z01_ui_mode', 'modern') !== 'classic'; };[cite: 7]
  Z01UI.REQUEST_TIMEOUT = 20000;[cite: 7]
  Z01UI.WATCHDOG = 24;[cite: 7]
  Z01UI.WATCHDOG_FIRST = 40;[cite: 7]

  Z01UI.esc = function(str) {
    return (str === undefined || str === null ? '' : String(str))
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');[cite: 7]
  };

  Z01UI.shortQuality = function(text) {
    if (!text) return '';[cite: 7]
    text = String(text);[cite: 7]
    var match = text.match(/(2160|1440|1080|720|576|480|360)\s*p?/i);[cite: 7]
    if (match) {
      var value = parseInt(match[1]);[cite: 7]
      if (value >= 2160) return '4K';[cite: 7]
      if (value >= 1080) return 'FHD';[cite: 7]
      if (value >= 720) return 'HD';[cite: 7]
      return 'SD';[cite: 7]
    }
    if (/4k|uhd/i.test(text)) return '4K';[cite: 7]
    if (/fhd/i.test(text)) return 'FHD';[cite: 7]
    if (/\bhd\b/i.test(text)) return 'HD';[cite: 7]
    return '';[cite: 7]
  };

  Z01UI.VOICE_KINDS = [
    { key: 'dub', title: 'z01_voice_dub', re: /дубляж|дублирован|\bdub\b|\bdubbing\b/i },[cite: 7]
    { key: 'mvo', title: 'z01_voice_mvo', re: /многоголос|\bmvo\b|\bpmvo\b/i },[cite: 7]
    { key: 'dvo', title: 'z01_voice_dvo', re: /двухголос|\bdvo\b/i },[cite: 7]
    { key: 'avo', title: 'z01_voice_avo', re: /авторск|одноголос|\bavo\b|\bvo\b/i },[cite: 7]
    { key: 'orig', title: 'z01_voice_orig', re: /оригинал|original|\beng\b|\bua\b|\bukr\b/i },[cite: 7]
    { key: 'sub', title: 'z01_voice_sub', re: /субтитр|sub(title)?s?\b/i }[cite: 7]
  ];[cite: 7]

  Z01UI.VOICE_STUDIOS = [
    { key: 'mvo', re: /lostfilm|лостфильм|tvshows|dniprofilm|невафильм|newstudio|newcomers|baibako|байбако|alexfilm|jaskier|coldfilm|колдфильм|hdrezka|rezkastudio|red head sound|sunshine|amedia|zakadry|закадры|linefilm|le-production|1win|kerob|profix|selena|октопус/i },[cite: 7]
    { key: 'dvo', re: /кубик в кубе|kubik|viruseproject|вирус|green ?tea|paradox/i },[cite: 7]
    { key: 'avo', re: /яроцк|гаврилов|володарск|сербин|горчаков|михал[её]в|живов|пучков|гоблин|кураж|дольск|есарев|карповск|визгунов/i }[cite: 7]
  ];[cite: 7]

  Z01UI.voiceKind = function(title) {
    var text = String(title || '');[cite: 7]
    var i;[cite: 7]
    for (i = 0; i < Z01UI.VOICE_KINDS.length; i++) {
      if (Z01UI.VOICE_KINDS[i].re.test(text)) return Z01UI.VOICE_KINDS[i].key;[cite: 7]
    }
    for (i = 0; i < Z01UI.VOICE_STUDIOS.length; i++) {
      if (Z01UI.VOICE_STUDIOS[i].re.test(text)) return Z01UI.VOICE_STUDIOS[i].key;[cite: 7]
    }
    return 'other';[cite: 7]
  };

  Z01UI.voiceKindTitle = function(key) {
    for (var i = 0; i < Z01UI.VOICE_KINDS.length; i++) {
      if (Z01UI.VOICE_KINDS[i].key == key) return Lampa.Lang.translate(Z01UI.VOICE_KINDS[i].title);[cite: 7]
    }
    return Lampa.Lang.translate('z01_voice_other');[cite: 7]
  };

  Z01UI.voiceGroups = function(list) {
    var order = [];[cite: 7]
    var map = {};[cite: 7]
    (list || []).forEach(function(entry, index) {
      var key = Z01UI.voiceKind(entry.title);[cite: 7]
      if (!map[key]) {
        map[key] = { key: key, title: Z01UI.voiceKindTitle(key), items: [] };[cite: 7]
        order.push(key);[cite: 7]
      }
      map[key].items.push({ index: index, title: entry.title, url: entry.url });[cite: 7]
    });
    var rank = function(key) {
      for (var i = 0; i < Z01UI.VOICE_KINDS.length; i++) {
        if (Z01UI.VOICE_KINDS[i].key == key) return i;[cite: 7]
      }
      return 90;[cite: 7]
    };
    order.sort(function(a, b) { return rank(a) - rank(b); });[cite: 7]
    return order.map(function(key) { return map[key]; });[cite: 7]
  };

  Z01UI.splitSourceName = function(name) {
    name = String(name || '');[cite: 7]
    var badge = '';[cite: 7]
    var match = name.match(/\s*[-~–]\s*(2160p?|1440p?|1080p?|720p?|480p?|4k|uhd|fhd|hd)\b[^,]*$/i);[cite: 7]
    if (match) {
      badge = Z01UI.shortQuality(match[1]);[cite: 7]
      if (badge) name = name.slice(0, match.index);[cite: 7]
    }
    return { name: name.replace(/\s+$/, ''), badge: badge };[cite: 7]
  };

  Z01UI.isSeasonLabel = function(text) {
    text = String(text || '').trim();[cite: 7]
    return /^\d+\s*(-?[йя])?\s*(сезон|season)$/i.test(text) || /^(сезон|season)\s*\d+$/i.test(text);[cite: 7]
  };

  Z01UI.MOVIE_ONLY = ['xvideocdnultra', 'xvideocdn60fps'];[cite: 7]
  Z01UI.isMovieOnlySource = function(key, title) {
    if (Z01UI.MOVIE_ONLY.indexOf(String(key || '').toLowerCase()) !== -1) return true;[cite: 7]
    return /^xvideocdn/i.test(key || '') && /ultra|60\s*\/?\s*120|60fps/i.test(title || '');[cite: 7]
  };

  Z01UI.payLink = function(answer) {
    if (!answer) return '';[cite: 7]
    var fields = ['url', 'link', 'pay', 'pay_url', 'payurl', 'buy', 'account'];[cite: 7]
    for (var i = 0; i < fields.length; i++) {
      var value = answer[fields[i]];[cite: 7]
      if (typeof value === 'string' && /^https?:\/\//i.test(value)) return value;[cite: 7]
    }
    var text = String(answer.msg || answer.message || answer.text || '');[cite: 7]
    var match = text.match(/https?:\/\/[^\s"'<>)]+/i);[cite: 7]
    return match ? match[0] : '';[cite: 7]
  };

  Z01UI.serverDenial = function(answer) {
    if (!answer || typeof answer !== 'object') return null;[cite: 7]
    var denied = !!(answer.accsdb || answer.blocked || answer.error || (typeof answer.code === 'number' && answer.code >= 300));[cite: 7]
    if (!denied) return null;[cite: 7]
    var text = String(answer.msg || answer.message || answer.text || '');[cite: 7]
    var own_image = /<img|qr-code|qrcode/i.test(text);[cite: 7]
    return {
      msg: text || Lampa.Lang.translate('z01_no_access_text'),[cite: 7]
      link: own_image ? '' : Z01UI.payLink(answer)[cite: 7]
    };
  };

  Z01UI.qrImage = function(link, size) {
    size = size || 300;[cite: 7]
    return 'https://api.qrserver.com/v1/create-qr-code/?size=' + size + 'x' + size + '&margin=10&data=' + encodeURIComponent(link);[cite: 7]
  };

  Z01UI.providerName = function(url) {
    var path = String(url || '').split('?')[0].split('#')[0];[cite: 7]
    var parts = path.split('/');[cite: 7]
    var last = '';[cite: 7]
    while (parts.length && !last) last = parts.pop();[cite: 7]
    return last;[cite: 7]
  };

  Z01UI.seasonNumber = function(title) {
    var match = String(title || '').match(/\d+/);[cite: 7]
    return match ? parseInt(match[0]) : 0;[cite: 7]
  };

  Z01UI.normName = function(text) {
    text = String(text === undefined || text === null ? '' : text).toLowerCase();[cite: 7]
    text = text.replace(/\u0451/g, '\u0435').replace(/[^0-9a-z\u0430-\u044f]+/g, ' ');[cite: 7]
    return text.replace(/^\s+/, '').replace(/\s+$/, '');[cite: 7]
  };

  Z01UI.nameParts = function(text) {
    var raw = String(text || '').split(/\s*[\/|]\s*/);[cite: 7]
    var out = [];[cite: 7]
    for (var i = 0; i < raw.length; i++) {
      var norm = Z01UI.normName(raw[i]);[cite: 7]
      if (norm) out.push(norm);[cite: 7]
    }
    return out;[cite: 7]
  };

  Z01UI.yearOf = function(value) {
    var match = String(value === undefined || value === null ? '' : value).match(/\d{4}/);[cite: 7]
    var year = match ? parseInt(match[0], 10) : 0;[cite: 7]
    return year > 1900 && year < 2200 ? year : 0;[cite: 7]
  };

  Z01UI.movieNames = function(movie) {
    var fields = ['title', 'name', 'original_title', 'original_name'];[cite: 7]
    var out = [];[cite: 7]
    for (var i = 0; i < fields.length; i++) {
      var parts = Z01UI.nameParts(movie && movie[fields[i]]);[cite: 7]
      for (var j = 0; j < parts.length; j++) {
        if (out.indexOf(parts[j]) === -1) out.push(parts[j]);[cite: 7]
      }
    }
    return out;[cite: 7]
  };

  Z01UI.matchScore = function(elem, movie) {
    if (!elem || !movie) return 0;[cite: 7]
    var mine = Z01UI.movieNames(movie);[cite: 7]
    var theirs = Z01UI.nameParts(elem.title || elem.text || '');[cite: 7]
    var score = 0;[cite: 7]
    for (var i = 0; i < theirs.length; i++) {
      for (var j = 0; j < mine.length; j++) {
        var a = theirs[i];[cite: 7]
        var b = mine[j];[cite: 7]
        var hit = 0;[cite: 7]
        if (a === b) hit = 60;[cite: 7]
        else if (a.length > 3 && b.length > 3 && (a.indexOf(b) === 0 || b.indexOf(a) === 0)) hit = 34;[cite: 7]
        else if (a.length > 5 && b.length > 5 && (a.indexOf(b) !== -1 || b.indexOf(a) !== -1)) hit = 22;[cite: 7]
        if (hit > score) score = hit;[cite: 7]
      }
    }
    var my_year = Z01UI.yearOf(movie.release_date || movie.first_air_date || movie.year);[cite: 7]
    var their_year = Z01UI.yearOf(elem.year || elem.start_date);[cite: 7]
    if (my_year && their_year) {
      var diff = Math.abs(my_year - their_year);[cite: 7]
      if (diff === 0) score += 34;[cite: 7]
      else if (diff === 1) score += 16;[cite: 7]
      else score -= 30;[cite: 7]
    }
    return score;[cite: 7]
  };

  Z01UI.rankSimilars = function(list, movie) {
    var ranked = [];[cite: 7]
    for (var i = 0; i < (list || []).length; i++) {
      ranked.push({ elem: list[i], index: i, score: Z01UI.matchScore(list[i], movie) });[cite: 7]
    }
    ranked.sort(function(a, b) { return b.score - a.score || a.index - b.index; });[cite: 7]
    var best = ranked[0];[cite: 7]
    var second = ranked[1];[cite: 7]
    var gap = best ? best.score - (second ? second.score : -100) : 0;[cite: 7]
    return {
      list: ranked,[cite: 7]
      best: best || null,[cite: 7]
      likely: !!(best && best.score >= 45 && gap >= 10),[cite: 7]
      sure: !!(best && best.score >= 70 && gap >= 25)[cite: 7]
    };
  };

  Z01UI.SEEN_PERCENT = 90;[cite: 7]
  Z01UI.isSeen = function(element, viewed) {
    if (!element) return false;[cite: 7]
    if (element.hash_behold && viewed && viewed.indexOf(element.hash_behold) !== -1) return true;[cite: 7]
    var line = element.timeline;[cite: 7]
    return !!(line && line.percent >= Z01UI.SEEN_PERCENT);[cite: 7]
  };

  Z01UI.QUALITY_RANK = { '4K': 4, 'FHD': 3, 'HD': 2, 'SD': 1 };[cite: 7]
  Z01UI.qualityRank = function(label) { return Z01UI.QUALITY_RANK[label] || 0; };[cite: 7]
  Z01UI.reachKey = function(movie) {
    if (!movie) return '';[cite: 7]
    return Lampa.Utils.hash(movie.original_name || movie.original_title || movie.name || movie.title || '');[cite: 7]
  };

  Z01UI.bestQuality = function(items) {
    var best = '';[cite: 7]
    for (var i = 0; i < (items || []).length; i++) {
      var item = items[i] || {};[cite: 7]
      var label = '';[cite: 7]
      var quality = item.quality || item.qualitys;[cite: 7]
      if (quality && typeof quality === 'object') label = Lampa.Arrays.getKeys(quality).join(' ');[cite: 7]
      else if (quality) label = String(quality);[cite: 7]
      var found = Z01UI.qualityFromText(label) || Z01UI.qualityFromText(item.title || item.text || '');[cite: 7]
      if (Z01UI.qualityRank(found) > Z01UI.qualityRank(best)) best = found;[cite: 7]
    }
    return best;[cite: 7]
  };

  Z01UI.qualityFromText = function(text) {
    text = String(text === undefined || text === null ? '' : text);[cite: 7]
    var best = '';[cite: 7]
    var re = /(?:^|[^\d])(2160|1440|1080|720|576|480)\s*p?(?![\d])/gi;[cite: 7]
    var found;[cite: 7]
    while ((found = re.exec(text))) {
      var label = Z01UI.shortQuality(found[1] + 'p');[cite: 7]
      if (Z01UI.qualityRank(label) > Z01UI.qualityRank(best)) best = label;[cite: 7]
    }
    if (/4k|uhd/i.test(text) && Z01UI.qualityRank('4K') > Z01UI.qualityRank(best)) best = '4K';[cite: 7]
    if (!best && /fhd/i.test(text)) best = 'FHD';[cite: 7]
    return best;[cite: 7]
  };

  Z01UI.knownQuality = function(name) { return Lampa.Storage.cache('z01_source_quality', 500, {})[name] || ''; };[cite: 7]
  Z01UI.rememberQuality = function(name, label) {
    if (!name || !label) return;[cite: 7]
    var all = Lampa.Storage.cache('z01_source_quality', 500, {});[cite: 7]
    if (Z01UI.qualityRank(label) <= Z01UI.qualityRank(all[name])) return;[cite: 7]
    all[name] = label;[cite: 7]
    Lampa.Storage.set('z01_source_quality', all);[cite: 7]
  };

  Z01UI.sourceBadge = function(name, parts) {
    return Z01UI.knownQuality(name) || (parts ? parts.badge : '');[cite: 7]
  };

  Z01UI.reachEntry = function(movie, season) {
    var all = Lampa.Storage.cache('z01_reach', 2000, {});[cite: 7]
    var mine = all[Z01UI.reachKey(movie)] || {};[cite: 7]
    var value = mine[season || 1];[cite: 7]
    if (typeof value === 'number') return { e: value, l: value, r: 2 };[cite: 7]
    if (value && typeof value === 'object') {
      return { e: parseInt(value.e, 10) || 0, l: parseInt(value.l, 10) || 0, r: parseInt(value.r, 10) || 0 };[cite: 7]
    }
    return { e: 0, l: 0, r: 0 };[cite: 7]
  };

  Z01UI.reached = function(movie, season) { return Z01UI.reachEntry(movie, season).e; };[cite: 7]
  Z01UI.setReach = function(movie, season, episode) {
    episode = parseInt(episode, 10) || 0;[cite: 7]
    var key = Z01UI.reachKey(movie);[cite: 7]
    if (!key) return;[cite: 7]
    var all = Lampa.Storage.cache('z01_reach', 2000, {});[cite: 7]
    var mine = all[key] || {};[cite: 7]
    mine[season || 1] = { e: episode, l: episode, r: episode ? 2 : 0 };[cite: 7]
    all[key] = mine;[cite: 7]
    Lampa.Storage.set('z01_reach', all);[cite: 7]
  };

  Z01UI.rememberReach = function(movie, season, episode) {
    episode = parseInt(episode, 10) || 0;[cite: 7]
    var key = Z01UI.reachKey(movie);[cite: 7]
    if (!episode || !key) return;[cite: 7]
    var entry = Z01UI.reachEntry(movie, season);[cite: 7]
    if (episode === entry.l || episode === entry.l + 1) entry.r = (entry.r || 0) + 1;[cite: 7]
    else entry.r = 1;[cite: 7]
    entry.l = episode;[cite: 7]
    if (!entry.e || entry.r >= 2 || episode === entry.e + 1) entry.e = episode;[cite: 7]
    var all = Lampa.Storage.cache('z01_reach', 2000, {});[cite: 7]
    var mine = all[key] || {};[cite: 7]
    mine[season || 1] = { e: entry.e, l: entry.l, r: entry.r };[cite: 7]
    all[key] = mine;[cite: 7]
    Lampa.Storage.set('z01_reach', all);[cite: 7]
  };

  Z01UI.episodeNumber = function(value) {
    var num = parseInt(value, 10);[cite: 7]
    if (!num && num !== 0) return String(value === undefined || value === null ? '' : value);[cite: 7]
    return num < 10 ? '0' + num : String(num);[cite: 7]
  };

  Z01UI.icon = {
    play: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"></path></svg>',[cite: 7]
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M4 12l5 5L20 6" stroke-linecap="round" stroke-linejoin="round"></path></svg>',[cite: 7]
    chevron: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6"><path d="M6 9l6 6 6-6" stroke-linecap="round" stroke-linejoin="round"></path></svg>',[cite: 7]
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="11" cy="11" r="7"></circle><path d="M20 20l-4-4" stroke-linecap="round"></path></svg>',[cite: 7]
    refresh: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M20 11a8 8 0 10-2.3 5.7" stroke-linecap="round"></path><path d="M20 4v7h-7" stroke-linecap="round" stroke-linejoin="round"></path></svg>',[cite: 7]
    warn: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M12 4l9 16H3z" stroke-linejoin="round"></path><path d="M12 10v4" stroke-linecap="round"></path><circle cx="12" cy="17" r="0.6" fill="currentColor"></circle></svg>'[cite: 7]
  };[cite: 7]

  Z01UI.css = [
    '<style>',[cite: 7]
    '.mo{padding:0 0 3em 0}',[cite: 7]
    '.mo *{-webkit-box-sizing:border-box;box-sizing:border-box}',[cite: 7]
    '.mo-head{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-ms-flex-align:center;align-items:center;padding:0 .2em .7em .2em}',[cite: 7]
    '.mo-head__art{position:relative;width:4.6em;height:6.6em;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0;margin-right:1.1em;background:rgba(255,255,255,.07);-webkit-border-radius:.35em;border-radius:.35em;overflow:hidden}',[cite: 7]
    '.mo-head__art img{position:absolute;top:0;left:0;width:100%;height:100%;-o-object-fit:cover;object-fit:cover;opacity:0;-webkit-transition:opacity .3s;transition:opacity .3s}',[cite: 7]
    '.mo-head__art--loaded img{opacity:1}',[cite: 7]
    '.mo-head__text{-webkit-box-flex:1;-webkit-flex:1 1 auto;-ms-flex:1 1 auto;flex:1 1 auto;min-width:0;padding-right:1em}',[cite: 7]
    '.mo-head__sub{font-size:1em;opacity:.45;line-height:1.3;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 7]
    '.mo-head__title{font-size:1.7em;font-weight:600;line-height:1.2;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 7]
    '.mo-head__note{font-size:1.05em;opacity:.7;white-space:nowrap;padding-bottom:.15em}',[cite: 7]
    '.mo-head__bar{position:relative;height:.25em;-webkit-border-radius:.25em;border-radius:.25em;background:rgba(255,255,255,.12);margin:0 .2em 1.4em .2em;overflow:hidden}',[cite: 7]
    '.mo-head__fill{position:absolute;left:0;top:0;bottom:0;background:#7cc4ff}',[cite: 7]
    '.mo-head--hidden{display:none}',[cite: 7]
    '.mo-panel{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-flex-wrap:wrap;-ms-flex-wrap:wrap;flex-wrap:wrap;margin:0 0 1.3em 0}',[cite: 7]
    '.mo-seg{position:relative;min-width:11em;max-width:24em;padding:.6em 2.2em .6em 1em;margin:0 .8em .6em 0;background:rgba(255,255,255,.08);-webkit-border-radius:.35em;border-radius:.35em;line-height:1.25}',[cite: 7]
    '.mo-seg__name{font-size:.75em;letter-spacing:.06em;text-transform:uppercase;opacity:.5}',[cite: 7]
    '.mo-seg__value{font-size:1.15em;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 7]
    '.mo-seg__mark{font-size:.68em;font-weight:600;padding:.1em .4em;margin-right:.5em;background:rgba(255,255,255,.2);-webkit-border-radius:.25em;border-radius:.25em;vertical-align:.15em}',[cite: 7]
    '.mo-seg__arrow{position:absolute;right:.9em;top:50%;margin-top:-.2em;width:0;height:0;border-left:.4em solid transparent;border-right:.4em solid transparent;border-top:.45em solid rgba(255,255,255,.55)}',[cite: 7]
    '.mo-seg.focus{background:#fff;color:#000}',[cite: 7]
    '.mo-seg.focus .mo-seg__name{opacity:.6}',[cite: 7]
    '.mo-seg.focus .mo-seg__mark{background:rgba(0,0,0,.15)}',[cite: 7]
    '.mo-seg.focus .mo-seg__arrow{border-top-color:rgba(0,0,0,.6)}',[cite: 7]
    '.mo-seg--open{background:rgba(124,196,255,.22)}',[cite: 7]
    '.mo-grid{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-flex-wrap:wrap;-ms-flex-wrap:wrap;flex-wrap:wrap;margin:0 -.3em 1.4em -.3em}',[cite: 7]
    '.mo-opt{width:25%;padding:0 .3em .6em .3em}',[cite: 7]
    '.mo-opt__in{position:relative;padding:.65em .8em;min-height:3.1em;background:rgba(255,255,255,.07);-webkit-border-radius:.35em;border-radius:.35em;line-height:1.3;overflow:hidden}',[cite: 7]
    '.mo-opt__label{display:block;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 7]
    '.mo-opt__note{display:block;font-size:.8em;opacity:.5;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 7]
    '.mo-opt.focus .mo-opt__in{background:#fff;color:#000}',[cite: 7]
    '.mo-opt.focus .mo-opt__note{opacity:.6}',[cite: 7]
    '.mo-opt--active .mo-opt__in{-webkit-box-shadow:inset 0 0 0 .12em #7cc4ff;box-shadow:inset 0 0 0 .12em #7cc4ff}',[cite: 7]
    '.mo-opt__tag{display:inline-block;min-width:2.4em;text-align:center;font-size:.7em;font-weight:600;background:rgba(255,255,255,.18);-webkit-border-radius:.25em;border-radius:.25em;padding:.1em .3em;margin-right:.5em;vertical-align:.15em}',[cite: 7]
    '.mo-opt.focus .mo-opt__tag{background:rgba(0,0,0,.14)}',[cite: 7]
    '.mo-tiles{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-flex-wrap:wrap;-ms-flex-wrap:wrap;flex-wrap:wrap;margin:0 -.45em}',[cite: 7]
    '.mo-tile{width:25%;padding:0 .45em 1.1em .45em}',[cite: 7]
    '.mo-tile__art{position:relative;padding-top:56%;background:rgba(255,255,255,.08);-webkit-border-radius:.4em;border-radius:.4em;overflow:hidden}',[cite: 7]
    '.mo-tile__art img{position:absolute;top:0;left:0;width:100%;height:100%;-o-object-fit:cover;object-fit:cover;opacity:0;-webkit-transition:opacity .3s;transition:opacity .3s}',[cite: 7]
    '.mo-tile__art--loaded img{opacity:1}',[cite: 7]
    '.mo-tile__num{position:absolute;left:.5em;top:.45em;font-size:1.1em;font-weight:700;padding:.05em .45em;background:rgba(0,0,0,.55);-webkit-border-radius:.25em;border-radius:.25em}',[cite: 7]
    '.mo-tile__tag{position:absolute;right:.5em;top:.45em;font-size:.72em;font-weight:600;padding:.15em .4em;background:rgba(0,0,0,.55);-webkit-border-radius:.25em;border-radius:.25em}',[cite: 7]
    '.mo-tile__time{position:absolute;right:.5em;bottom:.5em;font-size:.8em;padding:.1em .4em;background:rgba(0,0,0,.55);-webkit-border-radius:.25em;border-radius:.25em}',[cite: 7]
    '.mo-tile__check{position:absolute;left:.5em;bottom:.5em;width:1.5em;height:1.5em;padding:.25em;color:#0b0c12;background:#7bd88f;-webkit-border-radius:100%;border-radius:100%}',[cite: 7]
    '.mo-tile__check svg{width:100%;height:100%}',[cite: 7]
    '.mo-tile__line{position:absolute;left:0;right:0;bottom:0;height:.25em}',[cite: 7]
    '.mo-tile__line .time-line{display:block !important;height:100%;margin:0;background:rgba(0,0,0,.5)}',[cite: 7]
    '.mo-tile__line .time-line>div{background:#7cc4ff}',[cite: 7]
    '.mo-tile__body{padding:.5em .15em 0 .15em}',[cite: 7]
    '.mo-tile__title{font-size:1.05em;line-height:1.35;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 7]
    '.mo-tile__meta{font-size:.85em;opacity:.5;line-height:1.4;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 7]
    '.mo-tile__meta span+span:before{content:" · "}',[cite: 7]
    '.mo-tile--seen .mo-tile__art img{opacity:.45}',[cite: 7]
    '.mo-tile--seen .mo-tile__title{opacity:.6}',[cite: 7]
    '.mo-tile.focus .mo-tile__art{-webkit-box-shadow:0 0 0 .2em #fff;box-shadow:0 0 0 .2em #fff}',[cite: 7]
    '.mo-tile--current .mo-tile__art{-webkit-box-shadow:0 0 0 .16em #7cc4ff;box-shadow:0 0 0 .16em #7cc4ff}',[cite: 7]
    '.mo-tile.focus.mo-tile--current .mo-tile__art{-webkit-box-shadow:0 0 0 .2em #fff;box-shadow:0 0 0 .2em #fff}',[cite: 7]
    '.mo-tile--soon{opacity:.45}',[cite: 7]
    '.mo-line{position:relative;display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-ms-flex-align:center;align-items:center;padding:.6em 1em .65em .6em;margin-bottom:.45em;background:rgba(255,255,255,.06);-webkit-border-radius:.4em;border-radius:.4em}',[cite: 7]
    '.mo-line__art{position:relative;width:4.4em;height:4.4em;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0;margin-right:1em;background:rgba(255,255,255,.08);-webkit-border-radius:.3em;border-radius:.3em;overflow:hidden}',[cite: 7]
    '.mo-line__art img{position:absolute;top:0;left:0;width:100%;height:100%;-o-object-fit:cover;object-fit:cover;opacity:0;-webkit-transition:opacity .3s;transition:opacity .3s}',[cite: 7]
    '.mo-line__art--loaded img{opacity:1}',[cite: 7]
    '.mo-line__time{font-size:.9em;opacity:.6;margin-left:.7em}',[cite: 7]
    '.mo-line__line{position:absolute;left:6.2em;right:1em;bottom:.35em;height:.16em}',[cite: 7]
    '.mo-line__line .time-line{display:block !important;height:100%;margin:0;background:rgba(255,255,255,.14);-webkit-border-radius:.16em;border-radius:.16em;overflow:hidden}',[cite: 7]
    '.mo-line__line .time-line>div{background:#7cc4ff}',[cite: 7]
    '.mo-line.focus .mo-line__line .time-line{background:rgba(0,0,0,.15)}',[cite: 7]
    '.mo-line.focus{background:#fff;color:#000}',[cite: 7]
    '.mo-line--current{-webkit-box-shadow:inset .18em 0 0 #7cc4ff;box-shadow:inset .18em 0 0 #7cc4ff}',[cite: 7]
    '.mo-line__tag{font-size:.72em;font-weight:600;background:rgba(255,255,255,.18);-webkit-border-radius:.25em;border-radius:.25em;padding:.15em .45em;margin-left:.7em}',[cite: 7]
    '.mo-line.focus .mo-line__tag{background:rgba(0,0,0,.14)}',[cite: 7]
    '.mo-line__body{-webkit-box-flex:1;-webkit-flex:1 1 auto;-ms-flex:1 1 auto;flex:1 1 auto;min-width:0}',[cite: 7]
    '.mo-line__title{font-size:1.15em;line-height:1.35;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 7]
    '.mo-line__note{font-size:.85em;opacity:.55;line-height:1.4;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',[cite: 7]
    '.mo-line__side{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-ms-flex-align:center;align-items:center;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0;padding-left:1em}',[cite: 7]
    '.mo-line--nav .mo-line__side:after{content:"›";font-size:1.5em;opacity:.6}',[cite: 7]
    '.mo-info{padding:1.4em .2em}',[cite: 7]
    '.mo-info__title{font-size:1.5em;font-weight:600;margin-bottom:.4em}',[cite: 7]
    '.mo-info__text{font-size:1.05em;line-height:1.5;opacity:.7;margin-bottom:1.1em;max-width:44em}',[cite: 7]
    '.mo-info__text img{max-width:12em;margin-top:.8em;display:block}',[cite: 7]
    '.mo-info__link{font-size:.95em;opacity:.5;word-break:break-all;margin-bottom:1em}',[cite: 7]
    '.mo-info__qr{margin-bottom:1.1em}',[cite: 7]
    '.mo-info__qr img{display:block;width:11em;height:11em;background:#fff;padding:.4em;-webkit-border-radius:.4em;border-radius:.4em}',[cite: 7]
    '.mo-info__acts{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-flex-wrap:wrap;-ms-flex-wrap:wrap;flex-wrap:wrap}',[cite: 7]
    '.mo-act{padding:.6em 1.4em;margin:0 .8em .6em 0;background:rgba(255,255,255,.12);-webkit-border-radius:.35em;border-radius:.35em;font-size:1.05em;white-space:nowrap}',[cite: 7]
    '.mo-act.focus{background:#fff;color:#000}',[cite: 7]
    '.mo-act>svg{width:1.1em;height:1.1em;margin-right:.5em;vertical-align:-.15em}',[cite: 7]
    '.mo-wait{width:100%;padding:.2em .2em 1.2em .2em}',[cite: 7]
    '.mo-wait__head{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-box-align:baseline;-webkit-align-items:baseline;-ms-flex-align:baseline;align-items:baseline;margin-bottom:.5em}',[cite: 7]
    '.mo-wait__title{font-size:1.25em;padding-right:.8em;-webkit-box-flex:1;-webkit-flex:1 1 auto;-ms-flex:1 1 auto;flex:1 1 auto}',[cite: 7]
    '.mo-wait__count{font-size:.95em;opacity:.55}',[cite: 7]
    '.mo-wait__bar{position:relative;height:.25em;width:100%;max-width:24em;-webkit-border-radius:.25em;border-radius:.25em;background:rgba(255,255,255,.12);overflow:hidden}',[cite: 7]
    '.mo-wait__fill{position:absolute;left:0;top:0;bottom:0;background:#7cc4ff;-webkit-transition:width .4s;transition:width .4s}',[cite: 7]
    '@media screen and (max-width:1300px){.mo-opt{width:33.333%}.mo-tile{width:33.333%}}',[cite: 7]
    '@media screen and (max-width:900px){.mo-opt{width:50%}.mo-tile{width:50%}.mo-head__title{font-size:1.4em}}',[cite: 7]
    '@media screen and (max-width:580px){.mo-opt{width:100%}.mo-seg{min-width:8em}}',[cite: 7]
    '</style>'[cite: 7]
  ].join('');[cite: 7]

  // ===== 6. ШАБЛОНЫ LAMPA =====
  function resetTemplates() {
    Lampa.Template.add('lampac_prestige_full', "<div class=\"online-prestige online-prestige--full selector\">\n            <div class=\"online-prestige__img\">\n                <img alt=\"\">\n                <div class=\"online-prestige__loader\"></div>\n            </div>\n            <div class=\"online-prestige__body\">\n                <div class=\"online-prestige__head\">\n                    <div class=\"online-prestige__title\">{title}</div>\n                    <div class=\"online-prestige__time\">{time}</div>\n                </div>\n\n                <div class=\"online-prestige__timeline\"></div>\n\n                <div class=\"online-prestige__footer\">\n                    <div class=\"online-prestige__info\">{info}</div>\n                    <div class=\"online-prestige__quality\">{quality}</div>\n                </div>\n            </div>\n        </div>");[cite: 7]
    Lampa.Template.add('lampac_content_loading', "<div class=\"online-empty\">\n            <div class=\"broadcast__scan\"><div></div></div>\n\t\t\t\n            <div class=\"online-empty__templates\">\n                <div class=\"online-empty-template selector\">\n                    <div class=\"online-empty-template__ico\"></div>\n                    <div class=\"online-empty-template__body\"></div>\n                </div>\n                <div class=\"online-empty-template\">\n                    <div class=\"online-empty-template__ico\"></div>\n                    <div class=\"online-empty-template__body\"></div>\n                </div>\n                <div class=\"online-empty-template\">\n                    <div class=\"online-empty-template__ico\"></div>\n                    <div class=\"online-empty-template__body\"></div>\n                </div>\n            </div>\n        </div>");[cite: 7]
    Lampa.Template.add('lampac_does_not_answer', "<div class=\"online-empty\">\n            <div class=\"online-empty__title\">\n                #{lampac_balanser_dont_work}\n            </div>\n            <div class=\"online-empty__time\">\n                #{lampac_balanser_timeout}\n            </div>\n            <div class=\"online-empty__buttons\">\n                <div class=\"online-empty__button selector cancel\">#{cancel}</div>\n                <div class=\"online-empty__button selector change\">#{lampac_change_balanser}</div>\n            </div>\n            <div class=\"online-empty__templates\">\n                <div class=\"online-empty-template\">\n                    <div class=\"online-empty-template__ico\"></div>\n                    <div class=\"online-empty-template__body\"></div>\n                </div>\n                <div class=\"online-empty-template\">\n                    <div class=\"online-empty-template__ico\"></div>\n                    <div class=\"online-empty-template__body\"></div>\n                </div>\n                <div class=\"online-empty-template\">\n                    <div class=\"online-empty-template__ico\"></div>\n                    <div class=\"online-empty-template__body\"></div>\n                </div>\n            </div>\n        </div>");[cite: 7]
    Lampa.Template.add('lampac_prestige_rate', "<div class=\"online-prestige-rate\">\n            <svg width=\"17\" height=\"16\" viewBox=\"0 0 17 16\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">\n                <path d=\"M8.39409 0.192139L10.99 5.30994L16.7882 6.20387L12.5475 10.4277L13.5819 15.9311L8.39409 13.2425L3.20626 15.9311L4.24065 10.4277L0 6.20387L5.79819 5.30994L8.39409 0.192139Z\" fill=\"#fff\"></path>\n            </svg>\n            <span>{rate}</span>\n        </div>");[cite: 7]
    Lampa.Template.add('lampac_prestige_folder', "<div class=\"online-prestige online-prestige--folder selector\">\n            <div class=\"online-prestige__folder\">\n                <svg viewBox=\"0 0 128 112\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">\n                    <rect y=\"20\" width=\"128\" height=\"92\" rx=\"13\" fill=\"white\"></rect>\n                    <path d=\"M29.9963 8H98.0037C96.0446 3.3021 91.4079 0 86 0H42C36.5921 0 31.9555 3.3021 29.9963 8Z\" fill=\"white\" fill-opacity=\"0.23\"></path>\n                    <rect x=\"11\" y=\"8\" width=\"106\" height=\"76\" rx=\"13\" fill=\"white\" fill-opacity=\"0.51\"></rect>\n                </svg>\n            </div>\n            <div class=\"online-prestige__body\">\n                <div class=\"online-prestige__head\">\n                    <div class=\"online-prestige__title\">{title}</div>\n                    <div class=\"online-prestige__time\">{time}</div>\n                </div>\n\n                <div class=\"online-prestige__footer\">\n                    <div class=\"online-prestige__info\">{info}</div>\n                </div>\n            </div>\n        </div>");[cite: 7]
    Lampa.Template.add('lampac_prestige_watched', "<div class=\"online-prestige online-prestige-watched selector\">\n            <div class=\"online-prestige-watched__icon\">\n                <svg width=\"21\" height=\"21\" viewBox=\"0 0 21 21\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">\n                    <circle cx=\"10.5\" cy=\"10.5\" r=\"9\" stroke=\"currentColor\" stroke-width=\"3\"/>\n                    <path d=\"M14.8477 10.5628L8.20312 14.399L8.20313 6.72656L14.8477 10.5628Z\" fill=\"currentColor\"/>\n                </svg>\n            </div>\n            <div class=\"online-prestige-watched__body\">\n                \n            </div>\n        </div>");[cite: 7]
  }

  // ===== 7. КОМПОНЕНТ ДВИЖКА (ИЗ РАБОЧЕГО Z2) =====
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
    var balanser_timer;[cite: 7]
    var images = [];[cite: 7]
    var number_of_requests = 0;[cite: 7]
    var number_of_requests_timer;[cite: 7]
    var life_wait_times = 0;[cite: 7]
    var life_wait_timer;[cite: 7]
    var filter_sources = {};[cite: 7]
    var filter_translate = {
      season: Lampa.Lang.translate('torrent_serial_season'),[cite: 7]
      voice: Lampa.Lang.translate('torrent_parser_voice'),[cite: 7]
      source: Lampa.Lang.translate('settings_rest_source')[cite: 7]
    };[cite: 7]
    var filter_find = { season: [], voice: [] };[cite: 7]

    if (balansers_with_search == undefined) {[cite: 7]
      network.timeout(10000);[cite: 7]
      network.silent(account('https://z01.online/lite/withsearch'), function(json) {[cite: 7]
        balansers_with_search = json;[cite: 7]
      }, function() { balansers_with_search = []; });[cite: 7]
    }

    function balanserName(j) {
      var bals = j.balanser;[cite: 7]
      var name = j.name.split(' ')[0];[cite: 7]
      return (bals || name).toLowerCase();[cite: 7]
    }

    function clarificationSearchAdd(value){
      var id = Lampa.Utils.hash(object.movie.number_of_seasons ? object.movie.original_name : object.movie.original_title);[cite: 7]
      var all = Lampa.Storage.get('clarification_search','{}');[cite: 7]
      all[id] = value;[cite: 7]
      Lampa.Storage.set('clarification_search',all);[cite: 7]
    }

    function clarificationSearchDelete(){
      var id = Lampa.Utils.hash(object.movie.number_of_seasons ? object.movie.original_name : object.movie.original_title);[cite: 7]
      var all = Lampa.Storage.get('clarification_search','{}');[cite: 7]
      delete all[id];[cite: 7]
      Lampa.Storage.set('clarification_search',all);[cite: 7]
    }

    var modern = Z01UI.enabled();[cite: 7]
    var ui = {};[cite: 7]
    var ui_items = [];[cite: 7]
    var ui_enter = null;[cite: 7]
    var ui_focus = '';[cite: 7]
    var ui_tried = {};[cite: 7]
    var ui_open = '';[cite: 7]
    var ui_nav = false;[cite: 7]
    var season_pinned = false;[cite: 7]
    var similar_list = null;[cite: 7]
    var similar_auto = false;[cite: 7]
    var similar_shown = false;[cite: 7]
    var last_origin = '';[cite: 7]
    var request_gen = 0;[cite: 7]
    var ui_watchdog;[cite: 7]
    var ui_load_timer;[cite: 7]
    var ui_load_started = 0;[cite: 7]
    var ui_load_found = 0;[cite: 7]
    var ui_load_percent = 0;[cite: 7]
    var ui_load_simple = false;[cite: 7]

    this.uiFrame = function() {
      if (!ui.root) {[cite: 7]
        ui.root = $('<div class="mo"></div>');[cite: 7]
        ui.status = $('<div class="mo__status"></div>');[cite: 7]
        ui.panel = $('<div class="mo__panel"></div>');[cite: 7]
        ui.list = $('<div class="mo-list"></div>');[cite: 7]
        ui.root.append(ui.status).append(ui.panel).append(ui.list);[cite: 7]
      }
      if (!ui.root.parent().length) {[cite: 7]
        scroll.clear();[cite: 7]
        scroll.append(ui.root);[cite: 7]
      }
      return ui.root;[cite: 7]
    };

    this.uiWaitBox = function(title) {
      var box = $('<div class="mo-wait"><div class="mo-wait__head"><div class="mo-wait__title"></div><div class="mo-wait__count"></div></div><div class="mo-wait__bar"><div class="mo-wait__fill"></div></div></div>');[cite: 7]
      box.find('.mo-wait__title').text(title);[cite: 7]
      return box;[cite: 7]
    };

    this.uiStatusPending = function() {
      if (!ui.status) return;[cite: 7]
      var box = ui.status.empty().removeClass('mo-head--hidden');[cite: 7]
      if (ui_nav || !object.movie.name) return box.addClass('mo-head--hidden');[cite: 7]
      var seasons = filter_find.season || [];[cite: 7]
      if (!seasons.length) return box.addClass('mo-head--hidden');[cite: 7]
      var choice = this.getChoice();[cite: 7]
      var title = (seasons[choice.season] || seasons[0]).title || '';[cite: 7]
      if (!title) return box.addClass('mo-head--hidden');[cite: 7]
      var head = $('<div class="mo-head"><div class="mo-head__text"><div class="mo-head__title"></div></div></div>');[cite: 7]
      head.find('.mo-head__title').text(title);[cite: 7]
      box.append(head);[cite: 7]
    };

    this.uiWaitStart = function(title, simple) {
      var _this = this;[cite: 7]
      this.uiStatusPending();[cite: 7]
      ui_load_started = Date.now();[cite: 7]
      ui_load_found = 0;[cite: 7]
      ui_load_percent = 0;[cite: 7]
      ui_load_simple = !!simple;[cite: 7]
      ui.load = this.uiWaitBox(title);[cite: 7]
      ui.list.empty().append(ui.load);[cite: 7]
      this.uiLoadingText();[cite: 7]
      clearInterval(ui_load_timer);[cite: 7]
      ui_load_timer = setInterval(function() { _this.uiLoadingText(); }, 1000);[cite: 7]
    };

    this.uiLoadingPanel = function() {
      this.uiFrame();[cite: 7]
      this.uiWatch(Z01UI.WATCHDOG_FIRST);[cite: 7]
      this.uiWaitStart(Lampa.Lang.translate('z01_loading_title'), false);[cite: 7]
    };

    this.uiLoadingText = function() {
      if (!ui.load || !ui.load.parent().length) return this.uiLoadingStop();[cite: 7]
      var seconds = Math.max(0, Math.round((Date.now() - ui_load_started) / 1000));[cite: 7]
      var text = (!ui_load_simple ? (ui_load_found ? Lampa.Lang.translate('z01_loading_found').replace('{n}', ui_load_found) : Lampa.Lang.translate('z01_loading_start')) + ' · ' : '') + seconds + Lampa.Lang.translate('z01_sec');[cite: 7]
      if (seconds >= 12 && ui_load_percent < 100) text += ' · ' + Lampa.Lang.translate('z01_loading_slow');[cite: 7]
      ui.load.find('.mo-wait__count').text(text);[cite: 7]
      var percent = Math.max(ui_load_percent, Math.min(90, seconds * 7));[cite: 7]
      ui.load.find('.mo-wait__fill').css('width', percent + '%');[cite: 7]
    };

    this.uiLoadingProgress = function(json, times) {
      if (!ui.load || !ui.load.parent().length) return;[cite: 7]
      var list = (json && json.online) || [];[cite: 7]
      var found = 0;[cite: 7]
      list.forEach(function(item) { if (item.show) found++; });[cite: 7]
      ui_load_found = found;[cite: 7]
      ui_load_percent = json && json.ready ? 100 : Math.min(95, Math.round((times / 15) * 100));[cite: 7]
      this.uiWatch(Z01UI.WATCHDOG_FIRST);[cite: 7]
      this.uiLoadingText();[cite: 7]
    };

    this.uiLoadingStop = function() {
      clearInterval(ui_load_timer);[cite: 7]
      ui_load_timer = null;[cite: 7]
      ui.load = null;[cite: 7]
    };

    this.uiWatch = function(seconds) {
      var _this = this;[cite: 7]
      clearTimeout(ui_watchdog);[cite: 7]
      if (!modern) return;[cite: 7]
      ui_watchdog = setTimeout(function() {
        if (Lampa.Activity.active().activity !== _this.activity) return;[cite: 7]
        network.clear();[cite: 7]
        _this.doesNotAnswer({ timeout: true });[cite: 7]
      }, (seconds || Z01UI.WATCHDOG) * 1000);[cite: 7]
    };

    this.uiWatchStop = function() {
      clearTimeout(ui_watchdog);[cite: 7]
      ui_watchdog = null;[cite: 7]
    };

    this.uiLoading = function() {
      this.uiFrame();[cite: 7]
      this.uiLoadingStop();[cite: 7]
      this.uiWatch();[cite: 7]
      request_gen++;[cite: 7]
      network.clear();[cite: 7]
      clearInterval(balanser_timer);[cite: 7]
      this.clearImages();[cite: 7]
      this.uiWaitStart(Lampa.Lang.translate('z01_loading_list'), true);[cite: 7]
      this.activity.loader(false);[cite: 7]
      this.activity.toggle();[cite: 7]
    };

    this.uiFocusTarget = function() { return last; };[cite: 7]
    this.uiFocusRestore = function(fallback) {
      var element = false;[cite: 7]
      if (ui_focus && ui.root) {[cite: 7]
        var found = ui.root.find('[data-mo-focus="' + ui_focus + '"]');[cite: 7]
        if (found.length) element = found[0];[cite: 7]
      }
      ui_focus = '';[cite: 7]
      if (!element && fallback) element = fallback;[cite: 7]
      if (element) last = element;[cite: 7]
    };

    this.uiPickResume = function(items) {
      if (!items || !items.length) return null;[cite: 7]
      var serial = object.movie.name ? true : false;[cite: 7]
      var viewed = Lampa.Storage.cache('online_view', 5000, []);[cite: 7]
      var i;[cite: 7]
      if (!serial) {
        var movie_choice = this.getChoice();[cite: 7]
        if (movie_choice.movie_view) {[cite: 7]
          for (i = 0; i < items.length; i++) {
            if (items[i].hash_behold == movie_choice.movie_view) return items[i];[cite: 7]
          }
        }
        var pref = Lampa.Storage.get('z01_voice_pref', '');[cite: 7]
        if (pref) {
          for (i = 0; i < items.length; i++) {
            if (Z01UI.voiceKind(items[i].title || items[i].text) == pref) return items[i];[cite: 7]
          }
        }
        return items[0];[cite: 7]
      }
      var choice = this.getChoice();[cite: 7]
      var season = items[0].season;[cite: 7]
      var reached = Z01UI.reached(object.movie, season);[cite: 7]
      if (!reached) {
        var mark = choice.episodes_view ? parseInt(choice.episodes_view[season], 10) : 0;[cite: 7]
        if (mark > reached) reached = mark;[cite: 7]
        var history = this.watched();[cite: 7]
        if (history && history.episode && (!history.season || history.season == season)) {[cite: 7]
          var last_seen = parseInt(history.episode, 10) || 0;[cite: 7]
          if (last_seen > reached) reached = last_seen;[cite: 7]
        }
        for (i = 0; i < items.length; i++) {
          if (Z01UI.isSeen(items[i], viewed)) {[cite: 7]
            var num = parseInt(items[i].episode, 10) || 0;[cite: 7]
            if (num > reached) reached = num;[cite: 7]
          }
        }
      }
      if (reached) {
        for (i = 0; i < items.length; i++) {
          if (items[i].episode == reached) {[cite: 7]
            var line = items[i].timeline;[cite: 7]
            if (line && line.percent > 0 && line.percent < 90) return items[i];[cite: 7]
            for (var j = i + 1; j < items.length; j++) {[cite: 7]
              if (!Z01UI.isSeen(items[j], viewed)) return items[j];[cite: 7]
            }
            return items[i + 1] || items[i];[cite: 7]
          }
        }
        var best = null;[cite: 7]
        for (i = 0; i < items.length; i++) {
          var value = parseInt(items[i].episode, 10) || 0;[cite: 7]
          if (value > reached && (!best || value < (parseInt(best.episode, 10) || 0))) best = items[i];[cite: 7]
        }
        if (best) return best;[cite: 7]
        return items[items.length - 1];[cite: 7]
      }
      for (i = 0; i < items.length; i++) {
        if (!Z01UI.isSeen(items[i], viewed)) return items[i];[cite: 7]
      }
      return items[0];[cite: 7]
    };

    this.uiStatus = function(items) {
      if (!ui.status) return;[cite: 7]
      var box = ui.status.empty().removeClass('mo-head--hidden');[cite: 7]
      var serial = object.movie.name ? true : false;[cite: 7]
      if (ui_nav || !items.length || !serial) return box.addClass('mo-head--hidden');[cite: 7]
      var viewed = Lampa.Storage.cache('online_view', 5000, []);[cite: 7]
      var seen = 0;[cite: 7]
      for (var i = 0; i < items.length; i++) {
        if (Z01UI.isSeen(items[i], viewed)) seen++;[cite: 7]
      }
      var title = '';[cite: 7]
      if (serial) {
        var seasons = filter_find.season || [];[cite: 7]
        var picked = seasons.length ? seasons[this.getChoice().season] || seasons[0] : null;[cite: 7]
        if (picked && picked.title) title = picked.title;[cite: 7]
        else {
          var season = items[0].season || this.seasonMemory() || 1;[cite: 7]
          title = Lampa.Lang.translate('torrent_serial_season') + ' ' + season;[cite: 7]
        }
      } else title = object.movie.title || object.movie.name || '';[cite: 7]
      var note = '';[cite: 7]
      if (serial && items.length > 1) {
        note = Lampa.Lang.translate('z01_season_progress').replace('{seen}', seen).replace('{total}', items.length);[cite: 7]
        if (seen < items.length) note += ' · ' + Lampa.Lang.translate('z01_season_left').replace('{left}', items.length - seen);[cite: 7]
      } else {
        var target = this.uiPickResume(items);[cite: 7]
        var line = target && target.timeline;[cite: 7]
        if (line && line.percent > 0 && line.duration > line.time) {[cite: 7]
          note = Lampa.Lang.translate('z01_left') + ' ' + Lampa.Utils.secondsToTime(line.duration - line.time, true);[cite: 7]
        }
      }
      var head = $('<div class="mo-head"><div class="mo-head__text"><div class="mo-head__title"></div><div class="mo-head__sub"></div></div><div class="mo-head__note"></div></div>');[cite: 7]
      head.find('.mo-head__title').text(title);[cite: 7]
      head.find('.mo-head__note').text(note);[cite: 7]
      if (!serial && object.movie.original_title && object.movie.original_title !== title) {[cite: 7]
        head.find('.mo-head__sub').text(object.movie.original_title);[cite: 7]
      }
      box.append(head);[cite: 7]
      if (serial && items.length > 1 && seen) {[cite: 7]
        var bar = $('<div class="mo-head__bar"><div class="mo-head__fill"></div></div>');[cite: 7]
        bar.find('.mo-head__fill').css('width', Math.round(seen / items.length * 100) + '%');[cite: 7]
        box.append(bar);[cite: 7]
      }
      return box;[cite: 7]
    };

    this.uiFallbackArt = function() {
      var movie = object.movie;[cite: 7]
      var path = function(value) { return (!value || value === 'undefined') ? '' : Lampa.TMDB.image('t/p/w300' + value); };[cite: 7]
      var art = path(movie.backdrop_path) || path(movie.poster_path);[cite: 7]
      if (!art && movie.img) {[cite: 7]
        art = movie.img;[cite: 7]
        if (art.indexOf('http') !== 0) art = '';[cite: 7]
      }
      return art || path(movie.img);[cite: 7]
    };

    this.uiSearch = function() {
      var native_search = filter.render().find('.filter--search');[cite: 7]
      if (native_search.length) return native_search.trigger('hover:enter');[cite: 7]
      if (Lampa.Input && Lampa.Input.edit) {[cite: 7]
        var enabled = Lampa.Controller.enabled().name;[cite: 7]
        Lampa.Input.edit({ value: object.search || '', free: true, nosave: true, title: Lampa.Lang.translate('search') }, function(value) {[cite: 7]
          Lampa.Controller.toggle(enabled);[cite: 7]
          if (value && filter.onSearch) filter.onSearch(value);[cite: 7]
        });
      }
    };

    this.uiRows = function() {
      var _this = this;[cite: 7]
      var panel = ui.panel.empty();[cite: 7]
      var bar = $('<div class="mo-panel"></div>');[cite: 7]

      var addSeg = function(key, name, value, mark) {
        var seg = $('<div class="mo-seg selector"><div class="mo-seg__name"></div><div class="mo-seg__value"></div><div class="mo-seg__arrow"></div></div>');[cite: 7]
        seg.attr('data-mo-focus', key);[cite: 7]
        seg.find('.mo-seg__name').text(name);[cite: 7]
        var box = seg.find('.mo-seg__value');[cite: 7]
        if (mark) box.append($('<span class="mo-seg__mark"></span>').text(mark));[cite: 7]
        box.append(document.createTextNode(value));[cite: 7]
        if (ui_open == key) seg.addClass('mo-seg--open');[cite: 7]
        seg.on('hover:enter', function() { _this.uiToggle(key); }).on('hover:focus', function(e) {[cite: 7]
          last = e.target;[cite: 7]
          scroll.update($(e.target), true);[cite: 7]
        });
        bar.append(seg);[cite: 7]
      };

      if (!object.balanser && sourceKeys().length && balanser) {[cite: 7]
        var info = sources[balanser] || {};[cite: 7]
        var parts = Z01UI.splitSourceName(info.name || balanser);[cite: 7]
        addSeg('source', Lampa.Lang.translate('lampac_balanser'), parts.name, Z01UI.sourceBadge(balanser, parts));[cite: 7]
      }

      var choice = this.getChoice();[cite: 7]
      var seasons = filter_find.season || [];[cite: 7]
      if (seasons.length > 1) {[cite: 7]
        addSeg('season', Lampa.Lang.translate('torrent_serial_season'), (seasons[choice.season] || seasons[0]).title, '');[cite: 7]
      }

      var voices = filter_find.voice || [];[cite: 7]
      if (voices.length > 1) {[cite: 7]
        addSeg('voice', Lampa.Lang.translate('torrent_parser_voice'), (voices[choice.voice] || voices[0]).title, '');[cite: 7]
      }

      if (similar_list && similar_list.length > 1 && !similar_shown) {[cite: 7]
        var back = $('<div class="mo-seg selector"><div class="mo-seg__name"></div><div class="mo-seg__value"></div></div>');[cite: 7]
        back.attr('data-mo-focus', 'variants');[cite: 7]
        back.find('.mo-seg__name').text(Lampa.Lang.translate('z01_similar_all'));[cite: 7]
        back.find('.mo-seg__value').text(similar_list.length);[cite: 7]
        back.on('hover:enter', function() {[cite: 7]
          var saved = similar_list;[cite: 7]
          similar_auto = true;[cite: 7]
          _this.uiSimilars(saved, true);[cite: 7]
        }).on('hover:focus', function(e) {[cite: 7]
          last = e.target;[cite: 7]
          scroll.update($(e.target), true);[cite: 7]
        });
        bar.append(back);[cite: 7]
      }

      if (bar.children().length) panel.append(bar);[cite: 7]

      if (ui_open == 'source' && !object.balanser) this.uiSourceRow();[cite: 7]
      else if (ui_open == 'season') this.uiOptionRow('season');[cite: 7]
      else if (ui_open == 'voice') this.uiOptionRow('voice');[cite: 7]
    };

    this.sourceOrder = function(names) {
      var rank = function(name) { return (name == balanser) ? -1 : ((sources[name] && sources[name].show) ? 0 : 1); };[cite: 7]
      var quality = function(name) {
        var info = sources[name] || {};[cite: 7]
        return Z01UI.qualityRank(Z01UI.sourceBadge(name, Z01UI.splitSourceName(info.name || name)));[cite: 7]
      };
      return names.map(function(name, index) { return { name: name, index: index }; }).sort(function(a, b) {[cite: 7]
        return (rank(a.name) - rank(b.name)) || (quality(b.name) - quality(a.name)) || (a.index - b.index);[cite: 7]
      }).map(function(entry) { return entry.name; });[cite: 7]
    };

    this.uiToggle = function(key) {
      var opening = ui_open != key;[cite: 7]
      ui_open = opening ? key : '';[cite: 7]
      ui_focus = key;[cite: 7]
      if (opening) {[cite: 7]
        var choice = this.getChoice();[cite: 7]
        if (key == 'source' && balanser) ui_focus = 'src:' + balanser;[cite: 7]
        else if (key == 'season') ui_focus = 'season:' + (choice.season || 0);[cite: 7]
        else if (key == 'voice') ui_focus = 'voice:' + (choice.voice || 0);[cite: 7]
      }
      this.uiRows();[cite: 7]
      this.uiFocusRestore(false);[cite: 7]
      Lampa.Controller.enable('content');[cite: 7]
    };

    this.uiPanelFocus = function() {
      if (!modern || !ui.panel) return false;[cite: 7]
      var seg = ui.panel.find('[data-mo-focus="source"]')[0] || ui.panel.find('.mo-seg')[0];[cite: 7]
      if (!seg) return false;[cite: 7]
      last = seg;[cite: 7]
      scroll.update($(seg), true);[cite: 7]
      Lampa.Controller.collectionFocus(seg, scroll.render());[cite: 7]
      return true;[cite: 7]
    };

    this.uiPanelFocused = function() { return (!modern || !ui.panel || !last) ? false : ui.panel.find(last).length > 0; };[cite: 7]
    this.uiUpFallback = function() { return (ui.root && last && ui.list && ui.list.find(last).length) ? this.uiPanelFocus() : false; };[cite: 7]

    this.uiOptionRow = function(type) {
      var _this = this;[cite: 7]
      var list = filter_find[type] || [];[cite: 7]
      var selected = this.getChoice()[type];[cite: 7]
      var grid = $('<div class="mo-grid"></div>');[cite: 7]
      var rows = [];[cite: 7]
      if (type == 'voice') {[cite: 7]
        Z01UI.voiceGroups(list).forEach(function(group) {[cite: 7]
          group.items.forEach(function(entry) {[cite: 7]
            rows.push({ index: entry.index, title: entry.title, note: group.title || '' });[cite: 7]
          });
        });
      } else {
        list.forEach(function(item, index) { rows.push({ index: index, title: item.title, note: '' }); });[cite: 7]
      }
      rows.forEach(function(entry) {
        var opt = $('<div class="mo-opt selector"><div class="mo-opt__in"><span class="mo-opt__label"></span><span class="mo-opt__note"></span></div></div>');[cite: 7]
        opt.attr('data-mo-focus', type + ':' + entry.index);[cite: 7]
        opt.find('.mo-opt__label').text(entry.title || '');[cite: 7]
        opt.find('.mo-opt__note').text(entry.note);[cite: 7]
        if (entry.index == selected) opt.addClass('mo-opt--active');[cite: 7]
        opt.on('hover:enter', function() { _this.uiSwitch(type, entry.index); }).on('hover:focus', function(e) {[cite: 7]
          last = e.target;[cite: 7]
          scroll.update($(e.target), true);[cite: 7]
        });
        grid.append(opt);[cite: 7]
      });
      ui.panel.append(grid);[cite: 7]
    };

    this.uiSwitch = function(type, index) {
      var choice = this.getChoice();[cite: 7]
      if (choice[type] == index && ui_open) {[cite: 7]
        ui_open = '';[cite: 7]
        ui_focus = type;[cite: 7]
        this.uiRows();[cite: 7]
        this.uiFocusRestore(false);[cite: 7]
        Lampa.Controller.enable('content');[cite: 7]
        return;[cite: 7]
      }
      choice[type] = index;[cite: 7]
      if (type == 'voice') {[cite: 7]
        var voice = filter_find.voice[index];[cite: 7]
        if (voice) {[cite: 7]
          choice.voice_name = voice.title;[cite: 7]
          Lampa.Storage.set('z01_voice_pref', Z01UI.voiceKind(voice.title));[cite: 7]
        }
      }
      if (type == 'season') {[cite: 7]
        var season = filter_find.season[index];[cite: 7]
        if (season) {[cite: 7]
          var number = Z01UI.seasonNumber(season.title);[cite: 7]
          if (number) this.seasonMemory(number);[cite: 7]
        }
        season_pinned = true;[cite: 7]
      }
      this.saveChoice(choice);[cite: 7]
      ui_open = '';[cite: 7]
      ui_focus = type;[cite: 7]
      this.uiLoading();[cite: 7]
      this.uiRows();[cite: 7]
      this.find();[cite: 7]
    };

    this.uiSourceMenu = function() { this.uiToggle('source'); };[cite: 7]

    this.uiSourceRow = function() {
      var _this = this;[cite: 7]
      var all = sourceKeys();[cite: 7]
      var visible = all.filter(function(name) {[cite: 7]
        var info = sources[name] || {};[cite: 7]
        return name == balanser || info.show || info.vip;[cite: 7]
      });
      var grid = $('<div class="mo-grid"></div>');[cite: 7]
      this.sourceOrder(visible).forEach(function(name) {[cite: 7]
        var info = sources[name] || {};[cite: 7]
        var parts = Z01UI.splitSourceName(info.name || name);[cite: 7]
        var opt = $('<div class="mo-opt selector"><div class="mo-opt__in"><span class="mo-opt__label"></span><span class="mo-opt__note"></span></div></div>');[cite: 7]
        opt.attr('data-mo-focus', 'src:' + name);[cite: 7]
        var label = opt.find('.mo-opt__label');[cite: 7]
        var tag = Z01UI.sourceBadge(name, parts);[cite: 7]
        if (info.vip) label.append('<span class="mo-opt__tag">VIP</span>');[cite: 7]
        else if (tag) label.append($('<span class="mo-opt__tag"></span>').text(tag));[cite: 7]
        label.append(document.createTextNode(parts.name));[cite: 7]
        if (name == balanser) opt.addClass('mo-opt--active');[cite: 7]
        opt.on('hover:enter', function() {[cite: 7]
          if (info.vip && !isZpremActive()) {
            _this.vipOffer({ title: info.name || name, source: name });
            return;
          }
          ui_open = '';[cite: 7]
          if (name == balanser) {[cite: 7]
            ui_focus = 'source';[cite: 7]
            _this.uiRows();[cite: 7]
            _this.uiFocusRestore(false);[cite: 7]
            Lampa.Controller.enable('content');[cite: 7]
            return;[cite: 7]
          }
          _this.switchSource(name);[cite: 7]
        }).on('hover:focus', function(e) {[cite: 7]
          last = e.target;[cite: 7]
          scroll.update($(e.target), true);[cite: 7]
        });
        grid.append(opt);[cite: 7]
      });
      ui.panel.append(grid);[cite: 7]
    };

    this.switchSource = function(name) {
      if (!sources[name]) return;[cite: 7]
      if (!modern) {[cite: 7]
        object.lampac_custom_select = name;[cite: 7]
        return this.changeBalanser(name);[cite: 7]
      }
      object.lampac_custom_select = name;[cite: 7]
      balanser = name;[cite: 7]
      source = sources[name].url;[cite: 7]
      Lampa.Storage.set('online_balanser', name);[cite: 7]
      Lampa.Storage.set('active_balanser', name);[cite: 7]
      this.updateBalanser(name);[cite: 7]
      filter_find = { season: [], voice: [] };[cite: 7]
      ui_tried[name] = true;[cite: 7]
      ui_open = '';[cite: 7]
      season_pinned = false;[cite: 7]
      similar_list = null;[cite: 7]
      similar_auto = false;[cite: 7]
      ui_focus = 'source';[cite: 7]
      this.uiLoading();[cite: 7]
      this.uiRows();[cite: 7]
      var seg = ui.panel.find('[data-mo-focus="source"]')[0];[cite: 7]
      if (seg) last = seg;[cite: 7]
      this.find();[cite: 7]
      Lampa.Controller.toggle('content');[cite: 7]
    };

    var sourceKeys = function() { return Object.prototype.toString.call(filter_sources) === '[object Array]' ? filter_sources : []; };[cite: 7]

    this.nextSource = function() {
      var keys = sourceKeys().filter(function(name) {[cite: 7]
        if (!sources[name] || sources[name].vip || name === balanser || ui_tried[name]) return false;[cite: 7]
        return sources[name].show;[cite: 7]
      });
      return !keys.length ? '' : this.sourceOrder(keys)[0];[cite: 7]
    };

    this.uiNote = function(params) {
      this.uiFrame();[cite: 7]
      this.uiLoadingStop();[cite: 7]
      this.uiWatchStop();[cite: 7]
      var note = $('<div class="mo-info"><div class="mo-info__title"></div><div class="mo-info__text"></div><div class="mo-info__acts"></div></div>');[cite: 7]
      note.find('.mo-info__title').text(params.title || '');[cite: 7]
      note.find('.mo-info__text').html(params.text || '');[cite: 7]
      var acts = note.find('.mo-info__acts');[cite: 7]
      (params.actions || []).forEach(function(action) {[cite: 7]
        var button = $('<div class="mo-act selector"></div>');[cite: 7]
        if (action.icon) button.append(action.icon);[cite: 7]
        button.append($('<span></span>').text(action.title));[cite: 7]
        button.on('hover:enter', function() { action.handler(); }).on('hover:focus', function(e) {[cite: 7]
          last = e.target;[cite: 7]
          scroll.update($(e.target), true);[cite: 7]
        });
        acts.append(button);[cite: 7]
      });
      ui.list.empty().append(note);[cite: 7]
      this.uiStatus([]);[cite: 7]
      this.uiRows();[cite: 7]
      this.loading(false);[cite: 7]
      last = acts.find('.mo-act')[0] || false;[cite: 7]
      Lampa.Controller.enable('content');[cite: 7]
      return note;[cite: 7]
    };

    this.markUpTo = function(element) {
      if (!element) return;[cite: 7]
      var upto = parseInt(element.episode, 10) || 0;[cite: 7]
      if (!upto) return;[cite: 7]
      var viewed = Lampa.Storage.cache('online_view', 5000, []);[cite: 7]
      var changed = false;[cite: 7]
      for (var i = 0; i < ui_items.length; i++) {[cite: 7]
        var item = ui_items[i];[cite: 7]
        var num = parseInt(item.episode, 10) || 0;[cite: 7]
        if (!num || !item.hash_behold) continue;[cite: 7]
        if (num <= upto) {[cite: 7]
          if (viewed.indexOf(item.hash_behold) === -1) {[cite: 7]
            viewed.push(item.hash_behold);[cite: 7]
            changed = true;[cite: 7]
          }
        } else {
          if (viewed.indexOf(item.hash_behold) !== -1) {[cite: 7]
            Lampa.Arrays.remove(viewed, item.hash_behold);[cite: 7]
            Lampa.Storage.remove('online_view', item.hash_behold);[cite: 7]
            changed = true;[cite: 7]
          }
          var line = item.timeline;[cite: 7]
          if (line && (line.percent || line.time)) {[cite: 7]
            line.percent = 0;[cite: 7]
            line.time = 0;[cite: 7]
            line.duration = 0;[cite: 7]
            Lampa.Timeline.update(line);[cite: 7]
          }
        }
      }
      if (changed) Lampa.Storage.set('online_view', viewed);[cite: 7]
      Z01UI.setReach(object.movie, element.season, upto);[cite: 7]
      var choice = this.getChoice();[cite: 7]
      if (element.season) choice.episodes_view[element.season] = upto;[cite: 7]
      this.saveChoice(choice);[cite: 7]
      this.uiRefreshMarks();[cite: 7]
    };

    this.uiDraw = function(items, params) {
      var _this = this;[cite: 7]
      params = params || {};[cite: 7]
      if (!items.length) return this.empty();[cite: 7]
      this.uiFrame();[cite: 7]
      this.uiLoadingStop();[cite: 7]
      this.uiWatchStop();[cite: 7]
      ui_items = items;[cite: 7]
      ui_enter = params.onEnter;[cite: 7]
      similar_shown = false;[cite: 7]
      if (!params.similars) Z01UI.rememberQuality(balanser, Z01UI.bestQuality(items));[cite: 7]
      var serial = object.movie.name ? true : false;[cite: 7]
      var title_count = {};[cite: 7]
      items.forEach(function(item) {[cite: 7]
        var text = item.text || item.title || '';[cite: 7]
        title_count[text] = (title_count[text] || 0) + 1;[cite: 7]
      });
      var looksEpisode = function(text) {
        return /сери|episode|эпізод|эпизод/i.test(String(text || '')) || /^\s*\d+\s*$/.test(String(text || ''));[cite: 7]
      };
      ui_nav = items.length > 1 && items.every(function(item) {[cite: 7]
        var text = item.text || item.title || '';[cite: 7]
        if (Z01UI.isSeasonLabel(text)) return true;[cite: 7]
        return serial && typeof item.episode === 'undefined' && !looksEpisode(text);[cite: 7]
      });
      var draw_gen = request_gen;[cite: 7]
      this.getEpisodes(items[0].season, function(episodes) {
        if (draw_gen !== request_gen) return;[cite: 7]
        var viewed = Lampa.Storage.cache('online_view', 5000, []);[cite: 7]
        var choice = _this.getChoice();[cite: 7]
        var fully = window.innerWidth > 580;[cite: 7]
        var list = ui.list.empty();[cite: 7]
        if (serial && !ui_nav) list.addClass('mo-tiles');[cite: 7]
        else list.removeClass('mo-tiles');[cite: 7]
        var focus_element = false;[cite: 7]
        var focus_mark = false;[cite: 7]
        var resume = _this.uiPickResume(items);[cite: 7]

        if (serial && items[0] && items[0].season) {[cite: 7]
          var shown_season = parseInt(items[0].season);[cite: 7]
          var wanted_season = _this.seasonMemory();[cite: 7]
          if (shown_season && (!wanted_season || shown_season == wanted_season || _this.seasonIndexByMemory() >= 0)) {[cite: 7]
            _this.seasonMemory(shown_season);[cite: 7]
          }
        }

        items.forEach(function(element, index) {
          var episode = serial && episodes.length && !params.similars ? arrFind(episodes, function(e) { return e.episode_number == element.episode; }) : false;[cite: 7]
          var episode_num = element.episode || index + 1;[cite: 7]
          var voice_name = (!serial && (element.voice_name || element.text)) || choice.voice_name || (filter_find.voice[0] ? filter_find.voice[0].title : false) || element.voice_name || (serial ? Lampa.Lang.translate('z01_unknown') : element.text) || Lampa.Lang.translate('z01_unknown');[cite: 7]
          if (element.quality) {[cite: 7]
            element.qualitys = element.quality;[cite: 7]
            element.quality = Lampa.Arrays.getKeys(element.quality)[0];[cite: 7]
          }
          element.voice_name = voice_name;[cite: 7]
          var runtime = episode ? episode.runtime : object.movie.runtime;[cite: 7]
          element.time = runtime ? Lampa.Utils.secondsToTime(runtime * 60, true) : '';[cite: 7]
          var hash_timeline = Lampa.Utils.hash(element.season ? [element.season, element.season > 10 ? ':' : '', element.episode, object.movie.original_title].join('') : object.movie.original_title);[cite: 7]
          var hash_behold = Lampa.Utils.hash(element.season ? [element.season, element.season > 10 ? ':' : '', element.episode, object.movie.original_title, element.voice_name].join('') : object.movie.original_title + element.voice_name);[cite: 7]
          element.hash_behold = hash_behold;[cite: 7]
          element.hash_timeline = hash_timeline;[cite: 7]
          element.timeline = Lampa.Timeline.view(hash_timeline);[cite: 7]
          if (element.season) {[cite: 7]
            element.translate_episode_end = _this.getLastEpisode(items);[cite: 7]
            element.translate_voice = element.voice_name;[cite: 7]
          }
          var data = { hash_timeline: hash_timeline, hash_behold: hash_behold };[cite: 7]
          var title = (episode ? episode.name : (element.text || element.title)) || object.movie.title || object.movie.name || '';[cite: 7]
          element.title = title;[cite: 7]
          var meta = [];[cite: 7]
          if (episode && episode.vote_average) meta.push('★ ' + parseFloat(episode.vote_average + '').toFixed(1));[cite: 7]
          if (episode && episode.air_date && fully) meta.push(Lampa.Utils.parseTime(episode.air_date).full);[cite: 7]
          else if (!episode && object.movie.release_date && fully && serial) meta.push(Lampa.Utils.parseTime(object.movie.release_date).full);[cite: 7]
          if (!serial && !ui_nav && voice_name && voice_name !== title && voice_name !== Lampa.Lang.translate('z01_unknown')) meta.push(voice_name);[cite: 7]
          element.__meta_base = meta.slice();[cite: 7]
          element.__own_line = !ui_nav && (serial || choice.movie_view === hash_behold);[cite: 7]
          var seen_line = element.timeline;[cite: 7]
          if (element.__own_line && seen_line && seen_line.percent > 0 && seen_line.duration > seen_line.time) {[cite: 7]
            meta.push(Lampa.Lang.translate('z01_left') + ' ' + Lampa.Utils.secondsToTime(seen_line.duration - seen_line.time, true));[cite: 7]
          }
          var tile = serial && !ui_nav;[cite: 7]
          var html;
          if (tile) {
            html = $('<div class="mo-tile selector"><div class="mo-tile__art"><img alt=""><div class="mo-tile__num">' + ('0' + (element.episode || index + 1)).slice(-2) + '</div></div><div class="mo-tile__title">' + Z01UI.esc(title) + '</div></div>');[cite: 7]
            var img = html.find('img')[0];[cite: 7]
            img.src = Lampa.TMDB.image('t/p/w300' + (object.movie.backdrop_path || object.movie.poster_path || ''));[cite: 7]
          } else {
            html = $('<div class="mo-line selector"><div style="font-size:1.15em;">' + Z01UI.esc(title) + '</div></div>');[cite: 7]
          }
          element.__html = html;[cite: 7]

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

        _this.uiStatus(items);[cite: 7]
        _this.uiRows();[cite: 7]
        var fallback = focus_element || focus_mark || false;[cite: 7]
        if (fallback && fallback.jquery) fallback = fallback[0];[cite: 7]
        if (!fallback) fallback = list.find('.mo-tile, .mo-line')[0];[cite: 7]
        _this.uiFocusRestore(fallback);[cite: 7]
        _this.loading(false);[cite: 7]
        Lampa.Controller.enable('content');[cite: 7]
      });
    };

    this.vipOffer = function(a) {
      var _this = this;
      requireLicense(function() {
        Lampa.Noty.show('Активация VIP-доступа...');
        zpremAutoEnsure(function(ok) {
          if (ok) _this.switchSource(a.source);
          else Lampa.Noty.show('Ошибка соединения с сервером');
        });
      });
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
      this.uiRefreshMarks();[cite: 7]
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

  function isRuUser() {
    try {
      var lang = Lampa.Storage.field('language');[cite: 7]
      if (lang) return lang === 'ru';[cite: 7]
    } catch(e) {}
    try {
      var nl = (navigator.language || navigator.userLanguage || '').toLowerCase();[cite: 7]
      return nl === 'ru' || nl.indexOf('ru-') === 0;[cite: 7]
    } catch(e) {}
    return false;[cite: 7]
  }

  // ===== 8. СТАРТ ПЛАГИНА И НАСТРОЙКИ =====
  function startPlugin() {
    window.lampac_z_plugin = true;[cite: 7]
    resetTemplates();

    var manifst = {
      type: 'video',[cite: 7]
      version: '2.1.0',
      name: 'FX1',
      description: 'Онлайн фильмы и сериалы',[cite: 7]
      component: 'lampac_z',[cite: 7]
      onContextMenu: function() { return { name: 'Смотреть онлайн', description: 'FX1' }; },
      onContextLauch: function(object) {
        requireLicense(function() {
          resetTemplates();[cite: 7]
          Lampa.Component.add('lampac_z', component);[cite: 7]
          var id = Lampa.Utils.hash(object.number_of_seasons ? object.original_name : object.original_title);[cite: 7]
          var all = Lampa.Storage.get('clarification_search','{}');[cite: 7]
          Lampa.Activity.push({
            url: '',[cite: 7]
            title: 'Онлайн',
            component: 'lampac_z',[cite: 7]
            movie: object,[cite: 7]
            page: 1,[cite: 7]
            clarification: all[id] ? true : false[cite: 7]
          });
        });
      }
    };
    Lampa.Manifest.plugins = manifst;[cite: 7]

    Lampa.Lang.add({
      lampac_watch: { ru: 'Смотреть онлайн', en: 'Watch online', uk: 'Дивитися онлайн', zh: '在线观看' },[cite: 7]
      lampac_balanser: { ru: 'Источник', uk: 'Джерело', en: 'Source', zh: '来源' },[cite: 7]
      torrent_serial_season: { ru: 'Сезон', uk: 'Сезон', en: 'Season', zh: '季' },
      torrent_parser_voice: { ru: 'Перевод', uk: 'Переклад', en: 'Voice', zh: '翻译' },
      settings_rest_source: { ru: 'Источник', uk: 'Джерело', en: 'Source', zh: '来源' },
      z01_loading_title: { ru: 'Ищем, где посмотреть', uk: 'Шукаємо, де подивитися', en: 'Looking for sources', zh: '正在查找播放源' },[cite: 7]
      z01_loading_list: { ru: 'Загружаем список', uk: 'Завантажуємо список', en: 'Loading the list', zh: '正在加载列表' },[cite: 7]
      z01_loading_start: { ru: 'Опрашиваем источники', uk: 'Опитуємо джерела', en: 'Polling sources', zh: '正在查询来源' },[cite: 7]
      z01_loading_found: { ru: 'Найдено источников: {n}', uk: 'Знайдено джерел: {n}', en: 'Sources found: {n}', zh: '已找到来源：{n}' },[cite: 7]
      z01_loading_slow: { ru: 'отвечают медленно', uk: 'відповідають повільно', en: 'responding slowly', zh: '响应缓慢' },[cite: 7]
      z01_sec: { ru: ' с', uk: ' с', en: 's', zh: ' 秒' },[cite: 7]
      z01_season_progress: { ru: 'Просмотрено {seen} из {total}', uk: 'Переглянуто {seen} з {total}', en: 'Watched {seen} of {total}', zh: '已观看 {seen} / {total}' },[cite: 7]
      z01_season_left: { ru: 'осталось {left}', uk: 'залишилось {left}', en: '{left} left', zh: '还剩 {left} 集' },[cite: 7]
      z01_left: { ru: 'осталось', uk: 'залишилось', en: 'left', zh: '剩余' },[cite: 7]
      z01_unknown: { ru: 'Неизвестно', uk: 'Невідомо', en: 'Unknown', zh: '未知' },[cite: 7]
      z01_voice_dub: { ru: 'Дубляж', uk: 'Дубляж', en: 'Dubbing', zh: '配音' },[cite: 7]
      z01_voice_mvo: { ru: 'Многоголосый', uk: 'Багатоголосий', en: 'Multi-voice', zh: '多人配音' },[cite: 7]
      z01_voice_dvo: { ru: 'Двухголосый', uk: 'Двоголосий', en: 'Two-voice', zh: '双人配音' },[cite: 7]
      z01_voice_avo: { ru: 'Авторский', uk: 'Авторський', en: 'Single-voice', zh: '单人配音' },[cite: 7]
      z01_voice_orig: { ru: 'Оригинал', uk: 'Оригінал', en: 'Original', zh: '原声' },[cite: 7]
      z01_voice_sub: { ru: 'Субтитры', uk: 'Субтитри', en: 'Subtitles', zh: '字幕' },[cite: 7]
      z01_voice_other: { ru: 'Прочие', uk: 'Інші', en: 'Other', zh: '其他' }[cite: 7]
    });

    var button = "<div class=\"full-start__button selector view--online lampac--button\"><svg width=\"128\" height=\"128\" viewBox=\"0 0 128 128\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\"><rect x=\"8\" y=\"8\" width=\"112\" height=\"112\" rx=\"32\" fill=\"white\" stroke=\"#2886fb\" stroke-width=\"12\"/><path d=\"M38 36h52L38 92h52\" stroke=\"#2886fb\" stroke-width=\"12\" stroke-linecap=\"round\" stroke-linejoin=\"round\" fill=\"none\"/></svg><span>Онлайн</span></div>";[cite: 7]

    function addButton(e) {
      if (e.render.find('.lampac--button').length) return;[cite: 7]
      var btn = $(button);
      btn.on('hover:enter click', function() {
        requireLicense(function() {
          resetTemplates();[cite: 7]
          Lampa.Component.add('lampac_z', component);[cite: 7]
          var id = Lampa.Utils.hash(e.movie.number_of_seasons ? e.movie.original_name : e.movie.original_title);[cite: 7]
          var all = Lampa.Storage.get('clarification_search','{}');[cite: 7]
          Lampa.Activity.push({
            url: '',[cite: 7]
            title: 'Онлайн',
            component: 'lampac_z',[cite: 7]
            movie: e.movie,[cite: 7]
            page: 1,[cite: 7]
            clarification: all[id] ? true : false[cite: 7]
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

    // ===== ЕДИНСТВЕННЫЙ РАЗДЕЛ НАСТРОЕК (FX1) =====
    Lampa.SettingsApi.addComponent({
      component: 'z01_license',
      icon: '<svg width="36" height="36" viewBox="0 0 128 128" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="8" y="8" width="112" height="112" rx="32" fill="none" stroke="white" stroke-width="12"/><path d="M38 36h52L38 92h52" stroke="white" stroke-width="12" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg>',
      name: 'FX1 Лицензия'
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_license',
      param: { name: 'fx1_devid_view', type: 'title', default: true },
      field: { name: '...' },
      onRender: function(item) {
        var devId = getMyDeviceId();
        item.find('.settings-param__name,.settings-param-title__text').text('ID вашего ТВ: ' + devId);
      }
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_license',
      param: { name: 'fx1_lic_status', type: 'title', default: true },
      field: { name: '...' },
      onRender: function(item) {
        var lic = verifyLicense();
        var txt = lic.active
          ? ('● Подписка активна (осталось ' + lic.days + ' дн., до ' + lic.date + ')')
          : ('○ Подписка не активна (Telegram: @Lopxh)');
        item.find('.settings-param__name,.settings-param-title__text').text(txt);
      }
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_license',
      param: { name: 'fx1_enter_key_btn', type: 'button', default: '' },
      field: {
        name: 'Ввести ключ активации',
        description: 'Нажмите для ввода ключа с экранной клавиатуры'
      },
      onRender: function(item) {
        var lic = verifyLicense();
        if (lic.active) {
          item.find('.settings-param__name').text('Продлить / Обновить ключ');
          item.find('.settings-param__descr,.settings-param__status').text('Активен до ' + lic.date + ' (осталось ' + lic.days + ' дн.)');
        } else {
          item.find('.settings-param__name').text('Ввести ключ активации');
          item.find('.settings-param__descr,.settings-param__status').text('Нажмите для открытия экранной клавиатуры');
        }
      },
      onChange: function() {
        Lampa.Input.edit({
          title: 'Ключ активации (12 символов)',
          value: Lampa.Storage.get('fx1_license_key', ''),
          free: true,
          nosave: true
        }, function(val) {
          if (val) {
            Lampa.Storage.set('fx1_license_key', val.trim().toUpperCase());
            var lic = verifyLicense();
            if (lic.active) {
              Lampa.Noty.show('Лицензия активирована до ' + lic.date + ' (осталось ' + lic.days + ' дн.)');
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
      param: { name: 'fx1_tg_info', type: 'title', default: true },
      field: { name: '...' },
      onRender: function(item) {
        item.find('.settings-param__name,.settings-param-title__text').text('Покупка и продление: Telegram @Lopxh');
      }
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_license',
      param: {
        name: 'z01_ui_mode',[cite: 7]
        type: 'select',[cite: 7]
        values: {
          modern: 'Новый (карточки)',
          classic: 'Классический (список)'
        },
        "default": 'modern'[cite: 7]
      },
      field: {
        name: 'Стиль интерфейса',
        description: 'Выбор отображения каталога серий'
      }
    });
  }

  // Фоновая пред-активация демо при наличии валидного ключа
  if (verifyLicense().active) {
    zpremAutoEnsure();
  }

  if (!window.lampac_z_plugin) startPlugin();[cite: 7]
})();
