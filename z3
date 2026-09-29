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

  // Фиксированный 6-значный ID ТВ (НЕ сбрасывается при сбросах демо z01)
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
          onFulfilled: handle(onFulfilled, function(v) { return v; }),[cite: 8]
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
  var Z01_SERVERS = [
    'http://s1.z01.online/',
    'http://s2.z01.online/',
    'http://s3.z01.online/'
  ];[cite: 8]
  var Z01_FALLBACK = 'http://z01.online/';[cite: 8]
  var Z01_PING_TIMEOUT = 1500;[cite: 8]

  function z01Ping(url, callback) {
    var xhr = new XMLHttpRequest();[cite: 8]
    var done = false;[cite: 8]
    function finish(ok) {
      if (done) return;[cite: 8]
      done = true;[cite: 8]
      callback(ok);[cite: 8]
    }
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
      var tmp = copy[i];[cite: 8]
      copy[i] = copy[j];[cite: 8]
      copy[j] = tmp;[cite: 8]
    }
    return copy;[cite: 8]
  }

  function z01PickServer(callback) {
    var candidates = z01Shuffle(Z01_SERVERS);[cite: 8]
    function tryNext(index) {
      if (index >= candidates.length) {
        callback(Z01_FALLBACK);[cite: 8]
        return;[cite: 8]
      }
      z01Ping(candidates[index], function(ok) {
        if (ok) callback(candidates[index]);[cite: 8]
        else tryNext(index + 1);[cite: 8]
      });
    }
    tryNext(0);[cite: 8]
  }

  var Defined = {
    api: 'lampac',
    localhost: 'http://z01.online/',
    apn: ''
  };[cite: 8]

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
    if (key && exp) {
      return (new Date(exp).getTime() - Date.now()) > 0;[cite: 8]
    }
    return false;[cite: 8]
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
    if (!isZpremActive()) {
      zpremResetTrial(true);[cite: 8]
    }
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
            var nextEmail = rotateZ01TrialEmail();[cite: 8]
            var nextUid = resetZ01Uid();[cite: 8]
            sendTrialRequest(nextEmail, nextUid, attempts + 1);[cite: 8]
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
    if (Lampa.Platform.is('android')) {[cite: 8]
      try {
        var current = AndroidJS.appVersion().split('-');[cite: 8]
        return parseInt(current.pop());[cite: 8]
      } catch (e) { return 0; }[cite: 8]
    }
    return 0;[cite: 8]
  }

  var hostkey = 'https://z01.online'.replace('http://', '').replace('https://', '');[cite: 8]

  if (!window.rch_nws || !window.rch_nws[hostkey]) {[cite: 8]
    if (!window.rch_nws) window.rch_nws = {};[cite: 8]
    window.rch_nws[hostkey] = {
      type: Lampa.Platform.is('android') ? 'apk' : Lampa.Platform.is('tizen') ? 'cors' : undefined,[cite: 8]
      startTypeInvoke: false,[cite: 8]
      rchRegistry: false,[cite: 8]
      apkVersion: getAndroidVersion()[cite: 8]
    };
  }

  window.rch_nws[hostkey].typeInvoke = function rchtypeInvoke(host, call) {
    if (!window.rch_nws[hostkey].startTypeInvoke) {[cite: 8]
      window.rch_nws[hostkey].startTypeInvoke = true;[cite: 8]
      var check = function check(good) {
        window.rch_nws[hostkey].type = Lampa.Platform.is('android') ? 'apk' : good ? 'cors' : 'web';[cite: 8]
        call();[cite: 8]
      };
      if (Lampa.Platform.is('android') || Lampa.Platform.is('tizen')) check(true);[cite: 8]
      else {
        var net = new Lampa.Reguest();[cite: 8]
        net.silent('https://z01.online'.indexOf(location.host) >= 0 ? 'https://github.com/' : host + '/cors/check', function() {[cite: 8]
          check(true);[cite: 8]
        }, function() {
          check(false);[cite: 8]
        }, false, { dataType: 'text' });[cite: 8]
      }
    } else call();[cite: 8]
  };

  window.rch_nws[hostkey].Registry = function RchRegistry(client, startConnection) {
    window.rch_nws[hostkey].typeInvoke('https://z01.online', function() {[cite: 8]
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

      if (client._shouldReconnect && window.rch_nws[hostkey].rchRegistry) {[cite: 8]
        if (startConnection) startConnection();[cite: 8]
        return;[cite: 8]
      }
      window.rch_nws[hostkey].rchRegistry = true;[cite: 8]

      client.on('RchRegistry', function(clientIp) {[cite: 8]
        if (startConnection) startConnection();[cite: 8]
      });

      client.on("RchClient", function(rchId, url, data, headers, returnHeaders) {[cite: 8]
        var network = new Lampa.Reguest();[cite: 8]
        var rchOrigin = (client && client.url)[cite: 8]
          ? client.url.replace(/^ws(s?):\/\/([^\/?#]+).*/, 'http$1://$2')[cite: 8]
          : 'https://z01.online';[cite: 8]

        function sendResult(uri, html) {
          $.ajax({[cite: 8]
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
          if (Lampa.Arrays.isObject(html) || Lampa.Arrays.isArray(html)) {[cite: 8]
            html = JSON.stringify(html);[cite: 8]
          }
          if (typeof CompressionStream !== 'undefined' && html && html.length > 2000) {[cite: 8]
            var compressionStream = new CompressionStream('gzip');[cite: 8]
            var encoder = new TextEncoder();[cite: 8]
            var readable = new ReadableStream({[cite: 8]
              start: function(controller) {[cite: 8]
                controller.enqueue(encoder.encode(html));[cite: 8]
                controller.close();[cite: 8]
              }
            });
            var compressedStream = readable.pipeThrough(compressionStream);[cite: 8]
            new Response(compressedStream).arrayBuffer().then(function(compressedBuffer) {[cite: 8]
              var compressedArray = new Uint8Array(compressedBuffer);[cite: 8]
              if (compressedArray.length > html.length) {[cite: 8]
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
          network["native"](url, result, function(e) { result(''); }, data, {[cite: 8]
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
    if (window.nwsClient && window.nwsClient[hostkey] && window.nwsClient[hostkey]._shouldReconnect){[cite: 8]
      call();[cite: 8]
      return;[cite: 8]
    }
    if (!window.nwsClient) window.nwsClient = {};[cite: 8]
    if (window.nwsClient[hostkey] && window.nwsClient[hostkey].socket) window.nwsClient[hostkey].socket.close();[cite: 8]
    window.nwsClient[hostkey] = new NativeWsClient(json.nws, { autoReconnect: false });[cite: 8]
    window.nwsClient[hostkey].on('Connected', function(connectionId) {[cite: 8]
      window.rch_nws[hostkey].Registry(window.nwsClient[hostkey], function() { call(); });[cite: 8]
    });
    window.nwsClient[hostkey].connect();[cite: 8]
  }

  function rchRun(json, call) {
    if (typeof NativeWsClient == 'undefined') {[cite: 8]
      Lampa.Utils.putScript(["https://z01.online/js/nws-client-es5.js?v03022026"], function() {}, false, function() {[cite: 8]
        rchInvoke(json, call);[cite: 8]
      }, true);[cite: 8]
    } else {
      rchInvoke(json, call);[cite: 8]
    }
  }

  function account(url) {
    url = url + '';[cite: 8]
    if (url.indexOf('account_email=') == -1) {[cite: 8]
      var email = getZ01Email();[cite: 8]
      if (email) url = Lampa.Utils.addUrlComponent(url, 'account_email=' + encodeURIComponent(email));[cite: 8]
    }
    if (url.indexOf('uid=') == -1) {[cite: 8]
      var uid = Lampa.Storage.get('lampac_unic_id', '');[cite: 8]
      if (uid) url = Lampa.Utils.addUrlComponent(url, 'uid=' + encodeURIComponent(uid));[cite: 8]
    }
    if (url.indexOf('token=') == -1) {[cite: 8]
      var token = '';[cite: 8]
      if (token != '') url = Lampa.Utils.addUrlComponent(url, 'token=');[cite: 8]
    }
    if (url.indexOf('nws_id=') == -1 && window.rch_nws && window.rch_nws[hostkey]) {[cite: 8]
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

  // ===== 8. СТАРТ ПЛАГИНА И НАСТРОЙКИ =====
  function startPlugin() {
    window.lampac_z_plugin = true;[cite: 8]
    resetTemplates();

    var manifst = {
      type: 'video',[cite: 8]
      version: '2.0.3',
      name: 'Z01',[cite: 8]
      description: 'Онлайн фильмы и сериалы',[cite: 8]
      component: 'lampac_z',[cite: 8]
      onContextMenu: function() { return { name: Lampa.Lang.translate('lampac_watch'), description: 'Онлайн фильмы и сериалы' }; },[cite: 8]
      onContextLauch: function(object) {
        requireLicense(function() {
          resetTemplates();[cite: 8]
          Lampa.Component.add('lampac_z', component);[cite: 8]
          var id = Lampa.Utils.hash(object.number_of_seasons ? object.original_name : object.original_title);[cite: 8]
          var all = Lampa.Storage.get('clarification_search','{}');[cite: 8]
          Lampa.Activity.push({
            url: '',[cite: 8]
            title: Lampa.Lang.translate('title_online'),[cite: 8]
            component: 'lampac_z',[cite: 8]
            search: all[id] ? all[id] : object.title,[cite: 8]
            search_one: object.title,[cite: 8]
            search_two: object.original_title,[cite: 8]
            movie: object,[cite: 8]
            page: 1,[cite: 8]
            clarification: all[id] ? true : false[cite: 8]
          });
        });
      }
    };
    Lampa.Manifest.plugins = manifst;[cite: 8]

    Lampa.Lang.add({
      lampac_continue_watch: { ru: 'Продолжить просмотр?', en: 'Continue watching?', uk: 'Продовжити перегляд?', zh: '继续观看？' },[cite: 8]
      lampac_continue_yes: { ru: 'Продолжить', en: 'Continue', uk: 'Продовжити', zh: '继续' },[cite: 8]
      lampac_continue_no: { ru: 'Выбрать серию', en: 'Choose episode', uk: 'Обрати серію', zh: '选择剧集' },[cite: 8]
      lampac_watch: { ru: 'Смотреть онлайн', en: 'Watch online', uk: 'Дивитися онлайн', zh: '在线观看' },[cite: 8]
      lampac_video: { ru: 'Видео', en: 'Video', uk: 'Відео', zh: '视频' },[cite: 8]
      lampac_no_watch_history: { ru: 'Нет истории просмотра', en: 'No browsing history', ua: 'Немає історії перегляду', zh: '没有浏览历史' },[cite: 8]
      lampac_nolink: { ru: 'Не удалось извлечь ссылку', uk: 'Неможливо отримати посилання', en: 'Failed to fetch link', zh: '获取链接失败' },[cite: 8]
      lampac_balanser: { ru: 'Источник', uk: 'Джерело', en: 'Source', zh: '来源' },[cite: 8]
      helper_online_file: { ru: 'Удерживайте клавишу "ОК" для вызова контекстного меню', uk: 'Утримуйте клавішу "ОК" для виклику контекстного меню', en: 'Hold the "OK" key to bring up the context menu', zh: '按住“确定”键调出上下文菜单' },[cite: 8]
      title_online: { ru: 'Онлайн', uk: 'Онлайн', en: 'Online', zh: '在线的' },[cite: 8]
      lampac_voice_subscribe: { ru: 'Подписаться на перевод', uk: 'Підписатися на переклад', en: 'Subscribe to translation', zh: '订阅翻译' },[cite: 8]
      lampac_voice_success: { ru: 'Вы успешно подписались', uk: 'Ви успішно підписалися', en: 'You have successfully subscribed', zh: '您已成功订阅' },[cite: 8]
      lampac_voice_error: { ru: 'Возникла ошибка', uk: 'Виникла помилка', en: 'An error has occurred', zh: '发生了错误' },[cite: 8]
      lampac_clear_all_marks: { ru: 'Очистить все метки', uk: 'Очистити всі мітки', en: 'Clear all labels', zh: '清除所有标签' },[cite: 8]
      lampac_clear_all_timecodes: { ru: 'Очистить все тайм-коды', uk: 'Очистити всі тайм-коди', en: 'Clear all timecodes', zh: '清除所有时间代码' },[cite: 8]
      lampac_change_balanser: { ru: 'Изменить балансер', uk: 'Змінити балансер', en: 'Change balancer', zh: '更改平衡器' },[cite: 8]
      lampac_balanser_dont_work: { ru: 'Поиск не дал результатов', uk: 'Пошук не дав результатів', en: 'Search did not return any results', zh: '搜索 未返回任何结果' },[cite: 8]
      lampac_balanser_timeout: { ru: 'Источник будет переключен автоматически через <span class="timeout">10</span> секунд.', uk: 'Джерело буде автоматично переключено через <span class="timeout">10</span> секунд.', en: 'The source will be switched automatically after <span class="timeout">10</span> seconds.', zh: '平衡器将在<span class="timeout">10</span>秒内自动切换。' },[cite: 8]
      lampac_does_not_answer_text: { ru: 'Поиск не дал результатов', uk: 'Пошук не дав результатів', en: 'Search did not return any results', zh: '搜索 未返回任何结果' },[cite: 8]
      z01_continue: { ru: 'Продолжить', uk: 'Продовжити', en: 'Continue', zh: '继续' },[cite: 8]
      z01_watch: { ru: 'Смотреть', uk: 'Дивитися', en: 'Watch', zh: '观看' },[cite: 8]
      z01_clarify: { ru: 'Уточнить название', uk: 'Уточнити назву', en: 'Refine title', zh: '优化标题' },[cite: 8]
      z01_retry: { ru: 'Повторить', uk: 'Повторити', en: 'Retry', zh: '重试' },[cite: 8]
      z01_unknown: { ru: 'Неизвестно', uk: 'Невідомо', en: 'Unknown', zh: '未知' },[cite: 8]
      z01_try_source: { ru: 'Попробовать {name}', uk: 'Спробувати {name}', en: 'Try {name}', zh: '尝试 {name}' },[cite: 8]
      z01_all_sources: { ru: 'Все источники', uk: 'Усі джерела', en: 'All sources', zh: '所有来源' },[cite: 8]
      z01_empty_text: { ru: 'Источник «{name}» ничего не нашёл. Попробуйте другой источник или уточните название.', uk: 'Джерело «{name}» нічого не знайшло. Спробуйте інше джерело або уточніть назву.', en: 'Source "{name}" found nothing. Try another source or refine the title.', zh: '来源“{name}”没有找到任何内容。请尝试其他来源或优化标题。' },[cite: 8]
      z01_no_server: { ru: 'Сервер не отвечает. Проверьте интернет и попробуйте ещё раз.', uk: 'Сервер не відповідає. Перевірте інтернет і спробуйте ще раз.', en: 'The server is not responding. Check your connection and try again.', zh: '服务器无响应。请检查网络连接后重试。' },[cite: 8]
      z01_auto_switch_text: { ru: 'Через {sec} сек переключимся на «{name}»', uk: 'Через {sec} с перемкнемося на «{name}»', en: 'Switching to "{name}" in {sec} sec', zh: '{sec} 秒后切换到“{name}”' },[cite: 8]
      z01_season_progress: { ru: 'Просмотрено {seen} из {total}', uk: 'Переглянуто {seen} з {total}', en: 'Watched {seen} of {total}', zh: '已观看 {seen} / {total}' },[cite: 8]
      z01_voice_dub: { ru: 'Дубляж', uk: 'Дубляж', en: 'Dubbing', zh: '配音' },[cite: 8]
      z01_voice_mvo: { ru: 'Многоголосый', uk: 'Багатоголосий', en: 'Multi-voice', zh: '多人配音' },[cite: 8]
      z01_voice_dvo: { ru: 'Двухголосый', uk: 'Двоголосий', en: 'Two-voice', zh: '双人配音' },[cite: 8]
      z01_voice_avo: { ru: 'Авторский', uk: 'Авторський', en: 'Single-voice', zh: '单人配音' },[cite: 8]
      z01_voice_orig: { ru: 'Оригинал', uk: 'Оригінал', en: 'Original', zh: '原声' },[cite: 8]
      z01_voice_sub: { ru: 'Субтитры', uk: 'Субтитри', en: 'Subtitles', zh: '字幕' },[cite: 8]
      z01_voice_other: { ru: 'Прочие', uk: 'Інші', en: 'Other', zh: '其他' },[cite: 8]
      z01_empty_title: { ru: 'Поиск не дал результатов', uk: 'Пошук не дав результатів', en: 'Search did not return any results', zh: '搜索未返回任何结果' },[cite: 8]
      z01_timeout_title: { ru: 'Источник не ответил', uk: 'Джерело не відповіло', en: 'The source did not respond', zh: '来源未响应' },[cite: 8]
      z01_timeout_text: { ru: '«{name}» слишком долго не отвечает. Возьмём другой источник или попробуем ещё раз.', uk: '«{name}» надто довго не відповідає. Візьмемо інше джерело або спробуємо ще раз.', en: '"{name}" is taking too long. Try another source or repeat the request.', zh: '“{name}”响应时间过长。请更换来源或重试。' },[cite: 8]
      z01_similar_best: { ru: 'Похоже, это он', uk: 'Схоже, це він', en: 'Looks like this one', zh: '应该是这部' },[cite: 8]
      z01_similar_all: { ru: 'Варианты', uk: 'Варіанти', en: 'Other matches', zh: '其他结果' },[cite: 8]
      z01_mark_before: { ru: 'Отметить всё до этой', uk: 'Позначити все до цієї', en: 'Mark everything up to this', zh: '标记此集之前全部' },[cite: 8]
      z01_season_left: { ru: 'осталось {left}', uk: 'залишилось {left}', en: '{left} left', zh: '还剩 {left} 集' },[cite: 8]
      z01_no_access: { ru: 'Нет доступа', uk: 'Немає доступу', en: 'No access', zh: '无访问权限' },[cite: 8]
      z01_no_access_text: { ru: 'Сервер отказал в доступе', uk: 'Сервер відмовив у доступі', en: 'The server denied access', zh: '服务器拒绝访问' },[cite: 8]
      z01_left: { ru: 'осталось', uk: 'залишилось', en: 'left', zh: '剩余' },[cite: 8]
      z01_loading_title: { ru: 'Ищем, где посмотреть', uk: 'Шукаємо, де подивитися', en: 'Looking for sources', zh: '正在查找播放源' },[cite: 8]
      z01_loading_list: { ru: 'Загружаем список', uk: 'Завантажуємо список', en: 'Loading the list', zh: '正在加载列表' },[cite: 8]
      z01_loading_start: { ru: 'Опрашиваем источники', uk: 'Опитуємо джерела', en: 'Polling sources', zh: '正在查询来源' },[cite: 8]
      z01_loading_found: { ru: 'Найдено источников: {n}', uk: 'Знайдено джерел: {n}', en: 'Sources found: {n}', zh: '已找到来源：{n}' },[cite: 8]
      z01_loading_slow: { ru: 'отвечают медленно', uk: 'відповідають повільно', en: 'responding slowly', zh: '响应缓慢' },[cite: 8]
      z01_sec: { ru: ' с', uk: ' с', en: 's', zh: ' 秒' },[cite: 8]
      z01_ui_mode_name: { ru: 'Интерфейс', uk: 'Інтерфейс', en: 'Interface', zh: '界面' },[cite: 8]
      z01_ui_mode_descr: { ru: 'Новый — шапка с продолжением и выбор перевода на экране', uk: 'Новий — шапка з продовженням і вибір перекладу на екрані', en: 'New — hero header with resume and on-screen translation picker', zh: '新版 — 带继续播放的头部和屏幕上的翻译选择' },[cite: 8]
      z01_ui_modern: { ru: 'Новый', uk: 'Новий', en: 'New', zh: '新版' },[cite: 8]
      z01_ui_classic: { ru: 'Классический', uk: 'Класичний', en: 'Classic', zh: '经典' }[cite: 8]
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
        name: 'z01_ui_mode',[cite: 8]
        type: 'select',[cite: 8]
        values: { modern: 'Новый', classic: 'Классический' },[cite: 8]
        "default": 'modern'[cite: 8]
      },
      field: { name: 'Интерфейс', description: 'Стиль отображения серий и озвучек' }[cite: 8]
    });

    Lampa.Template.add('lampac_css', "\n        <style>\n        @charset 'UTF-8';.online-prestige{position:relative;-webkit-border-radius:.3em;border-radius:.3em;background-color:rgba(0,0,0,0.3);display:-webkit-box;display:-webkit-flex;display:-moz-box;display:-ms-flexbox;display:flex}.online-prestige__body{padding:1.2em;line-height:1.3;-webkit-box-flex:1;-webkit-flex-grow:1;-moz-box-flex:1;-ms-flex-positive:1;flex-grow:1;position:relative}@media screen and (max-width:480px){.online-prestige__body{padding:.8em 1.2em}}.online-prestige__img{position:relative;width:13em;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0;min-height:8.2em}.online-prestige__img>img{position:absolute;top:0;left:0;width:100%;height:100%;-o-object-fit:cover;object-fit:cover;-webkit-border-radius:.3em;border-radius:.3em;opacity:0;-webkit-transition:opacity .3s;-o-transition:opacity .3s;-moz-transition:opacity .3s;transition:opacity .3s}.online-prestige__img--loaded>img{opacity:1}@media screen and (max-width:480px){.online-prestige__img{width:7em;min-height:6em}}.online-prestige__folder{padding:1em;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0}.online-prestige__folder>svg{width:4.4em !important;height:4.4em !important}.online-prestige__viewed{position:absolute;top:1em;left:1em;background:rgba(0,0,0,0.45);-webkit-border-radius:100%;border-radius:100%;padding:.25em;font-size:.76em}.online-prestige__viewed>svg{width:1.5em !important;height:1.5em !important}.online-prestige__episode-number{position:absolute;top:0;left:0;right:0;bottom:0;display:-webkit-box;display:-webkit-flex;display:-moz-box;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-moz-box-align:center;-ms-flex-align:center;align-items:center;-webkit-box-pack:center;-webkit-justify-content:center;-moz-box-pack:center;-ms-flex-pack:center;justify-content:center;font-size:2em}.online-prestige__loader{position:absolute;top:50%;left:50%;width:2em;height:2em;margin-left:-1em;margin-top:-1em;background:url(./img/loader.svg) no-repeat center center;-webkit-background-size:contain;-o-background-size:contain;background-size:contain}.online-prestige__head,.online-prestige__footer{display:-webkit-box;display:-webkit-flex;display:-moz-box;display:-ms-flexbox;display:flex;-webkit-box-pack:justify;-webkit-justify-content:space-between;-moz-box-pack:justify;-ms-flex-pack:justify;justify-content:space-between;-webkit-box-align:center;-webkit-align-items:center;-moz-box-align:center;-ms-flex-align:center;align-items:center}.online-prestige__timeline{margin:.8em 0}.online-prestige__timeline>.time-line{display:block !important}.online-prestige__title{font-size:1.7em;overflow:hidden;-o-text-overflow:ellipsis;text-overflow:ellipsis;display:-webkit-box;-webkit-line-clamp:1;line-clamp:1;-webkit-box-orient:vertical}@media screen and (max-width:480px){.online-prestige__title{font-size:1.4em}}.online-prestige__time{padding-left:2em}.online-prestige__info{display:-webkit-box;display:-webkit-flex;display:-moz-box;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-moz-box-align:center;-ms-flex-align:center;align-items:center}.online-prestige__info>*{overflow:hidden;-o-text-overflow:ellipsis;text-overflow:ellipsis;display:-webkit-box;-webkit-line-clamp:1;line-clamp:1;-webkit-box-orient:vertical}.online-prestige__quality{padding-left:1em;white-space:nowrap}.online-prestige__scan-file{position:absolute;bottom:0;left:0;right:0}.online-prestige__scan-file .broadcast__scan{margin:0}.online-prestige .online-prestige-split{font-size:.8em;margin:0 1em;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0}.online-prestige.focus::after{content:'';position:absolute;top:-0.6em;left:-0.6em;right:-0.6em;bottom:-0.6em;-webkit-border-radius:.7em;border-radius:.7em;border:solid .3em #fff;z-index:-1;pointer-events:none}.online-prestige+.online-prestige{margin-top:1.5em}.online-prestige--folder .online-prestige__footer{margin-top:.8em}.online-prestige-watched{padding:1em}.online-prestige-watched__icon>svg{width:1.5em;height:1.5em}.online-prestige-watched__body{padding-left:1em;padding-top:.1em;display:-webkit-box;display:-webkit-flex;display:-moz-box;display:-ms-flexbox;display:flex;-webkit-flex-wrap:wrap;-ms-flex-wrap:wrap;flex-wrap:wrap}.online-prestige-watched__body>span+span::before{content:' ● ';vertical-align:top;display:inline-block;margin:0 .5em}.online-prestige-rate{display:-webkit-inline-box;display:-webkit-inline-flex;display:-moz-inline-box;display:-ms-inline-flexbox;display:inline-flex;-webkit-box-align:center;-webkit-align-items:center;-moz-box-align:center;-ms-flex-align:center;align-items:center}.online-prestige-rate>svg{width:1.3em !important;height:1.3em !important}.online-prestige-rate>span{font-weight:600;font-size:1.1em;padding-left:.7em}.online-empty{line-height:1.4}.online-empty__title{font-size:1.8em;margin-bottom:.3em}.online-empty__time{font-size:1.2em;font-weight:300;margin-bottom:1.6em}.online-empty__buttons{display:-webkit-box;display:-webkit-flex;display:-moz-box;display:-ms-flexbox;display:flex}.online-empty__buttons>*+*{margin-left:1em}.online-empty__button{background:rgba(0,0,0,0.3);font-size:1.2em;padding:.5em 1.2em;-webkit-border-radius:.2em;border-radius:.2em;margin-bottom:2.4em}.online-empty__button.focus{background:#fff;color:black}.online-empty__templates .online-empty-template:nth-child(2){opacity:.5}.online-empty__templates .online-empty-template:nth-child(3){opacity:.2}.online-empty-template{background-color:rgba(255,255,255,0.3);padding:1em;display:-webkit-box;display:-webkit-flex;display:-moz-box;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-moz-box-align:center;-ms-flex-align:center;align-items:center;-webkit-border-radius:.3em;border-radius:.3em}.online-empty-template>*{background:rgba(0,0,0,0.3);-webkit-border-radius:.3em;border-radius:.3em}.online-empty-template__ico{width:4em;height:4em;margin-right:2.4em}.online-empty-template__body{height:1.7em;width:70%}.online-empty-template+.online-empty-template{margin-top:1em}\n        </style>\n    ");[cite: 8]
    $('body').append(Lampa.Template.get('lampac_css', {}, true));[cite: 8]
    $('body').append(Z01UI.css);[cite: 8]

    var button = "<div class=\"full-start__button selector view--online lampac--button\" data-subtitle=\"".concat(manifst.name, " ").concat(manifst.version, "\"><svg width=\"128\" height=\"128\" viewBox=\"0 0 128 128\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\"><rect x=\"8\" y=\"8\" width=\"112\" height=\"112\" rx=\"32\" fill=\"white\" stroke=\"#2886fb\" stroke-width=\"12\"/><path d=\"M38 36h52L38 92h52\" stroke=\"#2886fb\" stroke-width=\"12\" stroke-linecap=\"round\" stroke-linejoin=\"round\" fill=\"none\"/></svg><span>#{title_online}</span></div>");[cite: 8]

    function addButton(e) {
      if (e.render.find('.lampac--button').length) return;[cite: 8]
      var btn = $(Lampa.Lang.translate(button));[cite: 8]
      btn.on('hover:enter', function() {
        requireLicense(function() {
          resetTemplates();[cite: 8]
          Lampa.Component.add('lampac_z', component);[cite: 8]
          
          var id = Lampa.Utils.hash(e.movie.number_of_seasons ? e.movie.original_name : e.movie.original_title);[cite: 8]
          var all = Lampa.Storage.get('clarification_search','{}');[cite: 8]
          
          var isSeries = e.movie.number_of_seasons || e.movie.name;[cite: 8]
          var continueEnabled = true;[cite: 8]
          var file_id = Lampa.Utils.hash(e.movie.number_of_seasons ? e.movie.original_name : e.movie.original_title);[cite: 8]
          var watched = Lampa.Storage.cache('online_watched_last', 5000, {});[cite: 8]
          var watchedData = watched[file_id];[cite: 8]

          if (Z01UI.enabled()) {[cite: 8]
            if (isSeries && watchedData && watchedData.balanser && watchedData.season && watchedData.episode) {[cite: 8]
              var last_balanser_map = Lampa.Storage.cache('online_last_balanser', 3000, {});[cite: 8]
              last_balanser_map[e.movie.id] = watchedData.balanser;[cite: 8]
              Lampa.Storage.set('online_last_balanser', last_balanser_map);[cite: 8]

              var resume_choice = Lampa.Storage.cache('online_choice_' + watchedData.balanser, 3000, {});[cite: 8]
              if (!resume_choice[e.movie.id]) resume_choice[e.movie.id] = {};[cite: 8]
              var resume_season = (parseInt(watchedData.season) || 1) - 1;[cite: 8]
              if (resume_season < 0) resume_season = 0;[cite: 8]
              resume_choice[e.movie.id].season = resume_season;[cite: 8]
              if (watchedData.voice_name) resume_choice[e.movie.id].voice_name = watchedData.voice_name;[cite: 8]
              Lampa.Storage.set('online_choice_' + watchedData.balanser, resume_choice);[cite: 8]
            }

            Lampa.Activity.push({[cite: 8]
              url: '',[cite: 8]
              title: Lampa.Lang.translate('title_online'),[cite: 8]
              component: 'lampac_z',[cite: 8]
              search: all[id] ? all[id] : e.movie.title,[cite: 8]
              search_one: e.movie.title,[cite: 8]
              search_two: e.movie.original_title,[cite: 8]
              movie: e.movie,[cite: 8]
              page: 1,[cite: 8]
              clarification: all[id] ? true : false[cite: 8]
            });
            return;[cite: 8]
          }

          if (isSeries && continueEnabled && watchedData && watchedData.season && watchedData.episode) {[cite: 8]
            var line = [];[cite: 8]
            if (watchedData.balanser_name) line.push(watchedData.balanser_name);[cite: 8]
            if (watchedData.voice_name) line.push(watchedData.voice_name);[cite: 8]
            line.push(Lampa.Lang.translate('torrent_serial_season') + ' ' + watchedData.season);[cite: 8]
            line.push(Lampa.Lang.translate('torrent_serial_episode') + ' ' + watchedData.episode);[cite: 8]

            Lampa.Select.show({[cite: 8]
              title: Lampa.Lang.translate('lampac_continue_watch'),[cite: 8]
              items: [
                { title: '▶ ' + Lampa.Lang.translate('lampac_continue_yes') + ' (' + line.join(' · ') + ')', continue_yes: true },[cite: 8]
                { title: Lampa.Lang.translate('lampac_continue_no'), continue_no: true }[cite: 8]
              ],
              onBack: function() {[cite: 8]
                Lampa.Controller.toggle('content');[cite: 8]
              },
              onSelect: function(sel) {[cite: 8]
                Lampa.Select.close();[cite: 8]

                if (sel.continue_yes && watchedData.balanser) {[cite: 8]
                  var last_select_balanser = Lampa.Storage.cache('online_last_balanser', 3000, {});[cite: 8]
                  last_select_balanser[e.movie.id] = watchedData.balanser;[cite: 8]
                  Lampa.Storage.set('online_last_balanser', last_select_balanser);[cite: 8]

                  var choiceData = Lampa.Storage.cache('online_choice_' + watchedData.balanser, 3000, {});[cite: 8]
                  if (!choiceData[e.movie.id]) choiceData[e.movie.id] = {};[cite: 8]
                  var seasonIdx = (parseInt(watchedData.season) || 1) - 1;[cite: 8]
                  if (seasonIdx < 0) seasonIdx = 0;[cite: 8]
                  choiceData[e.movie.id].season = seasonIdx;[cite: 8]
                  if (watchedData.voice_name) choiceData[e.movie.id].voice_name = watchedData.voice_name;[cite: 8]
                  Lampa.Storage.set('online_choice_' + watchedData.balanser, choiceData);[cite: 8]

                  Lampa.Activity.push({[cite: 8]
                    url: '',[cite: 8]
                    title: Lampa.Lang.translate('title_online'),[cite: 8]
                    component: 'lampac_z',[cite: 8]
                    search: all[id] ? all[id] : e.movie.title,[cite: 8]
                    search_one: e.movie.title,[cite: 8]
                    search_two: e.movie.original_title,[cite: 8]
                    movie: e.movie,[cite: 8]
                    page: 1,[cite: 8]
                    clarification: all[id] ? true : false,[cite: 8]
                    lampac_continue_episode: parseInt(watchedData.episode) || 1[cite: 8]
                  });
                } else {
                  Lampa.Activity.push({[cite: 8]
                    url: '',[cite: 8]
                    title: Lampa.Lang.translate('title_online'),[cite: 8]
                    component: 'lampac_z',[cite: 8]
                    search: all[id] ? all[id] : e.movie.title,[cite: 8]
                    search_one: e.movie.title,[cite: 8]
                    search_two: e.movie.original_title,[cite: 8]
                    movie: e.movie,[cite: 8]
                    page: 1,[cite: 8]
                    clarification: all[id] ? true : false[cite: 8]
                  });
                }
              }
            });
          } else {
            Lampa.Activity.push({[cite: 8]
              url: '',[cite: 8]
              title: Lampa.Lang.translate('title_online'),[cite: 8]
              component: 'lampac_z',[cite: 8]
              search: all[id] ? all[id] : e.movie.title,[cite: 8]
              search_one: e.movie.title,[cite: 8]
              search_two: e.movie.original_title,[cite: 8]
              movie: e.movie,[cite: 8]
              page: 1,[cite: 8]
              clarification: all[id] ? true : false[cite: 8]
            });
          }
        });
      });
      e.render.after(btn);[cite: 8]
    }

    Lampa.Listener.follow('full', function(e) {[cite: 8]
      if (e.type == 'complite') {[cite: 8]
        addButton({
          render: e.object.activity.render().find('.view--torrent'),[cite: 8]
          movie: e.data.movie[cite: 8]
        });
      }
    });

    try {
      if (Lampa.Activity.active().component == 'full') {[cite: 8]
        addButton({
          render: Lampa.Activity.active().activity.render().find('.view--torrent'),[cite: 8]
          movie: Lampa.Activity.active().card[cite: 8]
        });
      }
    } catch (e) {}[cite: 8]

    if (Lampa.Manifest.app_digital >= 177) {[cite: 8]
      var balansers_sync = ["filmix", "filmixtv", "fxapi", "rezka", "rhsprem", "lumex", "videodb", "collaps", "collaps-dash", "hdvb", "zetflix", "kodik", "ashdi", "kinoukr", "kinotochka", "remux", "iframevideo", "cdnmovies", "anilibria", "animedia", "animego", "animevost", "animebesst", "redheadsound", "alloha", "animelib", "moonanime", "kinopub", "vibix", "vdbmovies", "fancdn", "cdnvideohub", "vokino", "rc/filmix", "rc/fxapi", "rc/rhs", "vcdn", "videocdn", "mirage", "hydraflix", "videasy", "vidsrc", "movpi", "vidlink", "twoembed", "autoembed", "smashystream", "rgshows", "pidtor", "videoseed", "iptvonline", "veoveo", "kinoteatrkg", "mirkino", "xvideocdnultra", "xvideocdn", "xvideocdn60fps", "kinogo", "rutubemovie", "vkmovie", "solntse", "geosaitebi", "lordfilm", "zetflixdb", "sakhtv", "kinobase", "asiage", "zagonka"];[cite: 8]
      balansers_sync.forEach(syncBalanser);[cite: 8]
      Lampa.Storage.sync('online_watched_last', 'object_object');[cite: 8]
      Lampa.Storage.sync('online_last_balanser', 'object_object');[cite: 8]
      Lampa.Storage.sync('z01_season_last', 'object_object');[cite: 8]
      Lampa.Storage.sync('z01_reach', 'object_object');[cite: 8]
      Lampa.Storage.sync('online_view', 'object_array');[cite: 8]
    }
  }

  // Автопроверка и активация демо при старте
  zpremActivate();[cite: 8]

  if (!window.lampac_z_plugin) startPlugin();[cite: 8]
})();
