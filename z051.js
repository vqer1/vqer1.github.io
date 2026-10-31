(function() {
  'use strict';
  if (!Array.prototype.find) {
    Array.prototype.find = function(callback, thisArg) {
      for (var i = 0; i < this.length; i++) {
        if (callback.call(thisArg, this[i], i, this)) return this[i];
      }
      return undefined;
    };
  }
  if (!Array.prototype.findIndex) {
    Array.prototype.findIndex = function(callback, thisArg) {
      for (var i = 0; i < this.length; i++) {
        if (callback.call(thisArg, this[i], i, this)) return i;
      }
      return -1;
    };
  }
  if (!Array.prototype.includes) {
    Array.prototype.includes = function(val) {
      return this.indexOf(val) !== -1;
    };
  }
  if (!String.prototype.includes) {
    String.prototype.includes = function(val) {
      return this.indexOf(val) !== -1;
    };
  }
  if (!String.prototype.startsWith) {
    String.prototype.startsWith = function(s, pos) {
      pos = pos || 0;
      return this.indexOf(s, pos) === pos;
    };
  }
  if (!String.prototype.endsWith) {
    String.prototype.endsWith = function(s, len) {
      if (len === undefined || len > this.length) len = this.length;
      return this.substring(len - s.length, len) === s;
    };
  }
  if (typeof Promise === 'undefined') {
    window.Promise = function(executor) {
      var self = this;
      self._state = 0;
      self._value = undefined;
      self._handlers = [];
      function resolve(val) {
        if (self._state !== 0) return;
        self._state = 1;
        self._value = val;
        self._handlers.forEach(function(h) { h.onFulfilled(val); });
      }
      function reject(val) {
        if (self._state !== 0) return;
        self._state = 2;
        self._value = val;
        self._handlers.forEach(function(h) { h.onRejected(val); });
      }
      try { executor(resolve, reject); } catch(e) { reject(e); }
    };
    window.Promise.prototype.then = function(onFulfilled, onRejected) {
      var self = this;
      return new Promise(function(resolve, reject) {
        function handle(onFn, fallback) {
          return function(val) {
            try {
              var result = (typeof onFn === 'function') ? onFn(val) : fallback(val);
              if (result && typeof result.then === 'function') result.then(resolve, reject);
              else resolve(result);
            } catch(e) { reject(e); }
          };
        }
        var handler = {
          onFulfilled: handle(onFulfilled, function(v) { return v; }),
          onRejected: handle(onRejected, function(e) { throw e; })
        };
        if (self._state === 1) setTimeout(function() { handler.onFulfilled(self._value); }, 0);
        else if (self._state === 2) setTimeout(function() { handler.onRejected(self._value); }, 0);
        else self._handlers.push(handler);
      });
    };
    window.Promise.prototype['catch'] = function(onRejected) {
      return this.then(null, onRejected);
    };
    window.Promise.resolve = function(val) { return new Promise(function(r) { r(val); }); };
    window.Promise.reject = function(val) { return new Promise(function(_, r) { r(val); }); };
  }

  var Z01_SERVERS = [
    'http://s1.z01.online/',
    'http://s2.z01.online/',
    'http://s3.z01.online/'
  ];
  var Z01_FALLBACK = 'http://z01.online/';
  var Z01_PING_TIMEOUT = 1500;

  function z01Ping(url, callback) {
    var xhr = new XMLHttpRequest();
    var done = false;
    function finish(ok) {
      if (done) return;
      done = true;
      callback(ok);
    }
    try {
      xhr.open('GET', url, true);
      xhr.timeout = Z01_PING_TIMEOUT;
      xhr.onload = function() {
        finish(xhr.status >= 200 && xhr.status < 400);
      };
      xhr.onerror = function() { finish(false); };
      xhr.ontimeout = function() { finish(false); };
      xhr.send();
    } catch (e) {
      finish(false);
    }
  }

  function z01Shuffle(arr) {
    var copy = arr.slice();
    for (var i = copy.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var tmp = copy[i];
      copy[i] = copy[j];
      copy[j] = tmp;
    }
    return copy;
  }

  function z01PickServer(callback) {
    var candidates = z01Shuffle(Z01_SERVERS);
    function tryNext(index) {
      if (index >= candidates.length) {
        callback(Z01_FALLBACK);
        return;
      }
      z01Ping(candidates[index], function(ok) {
        if (ok) {
          callback(candidates[index]);
        } else {
          tryNext(index + 1);
        }
      });
    }
    tryNext(0);
  }

  var online_results_cache = {};
  var ONLINE_CACHE_TTL = 5 * 60 * 1000;

  var Network = Lampa.Reguest;
  function zpremProto() {
    return Lampa.Utils && Lampa.Utils.protocol ? Lampa.Utils.protocol() : 'https://';
  }

  var Defined = {
    api: 'lampac',
    localhost: zpremProto() + 'prem.z01.online/',
    apn: ''
  };

  var Z01_FREE = Z01_FALLBACK;
  z01PickServer(function(server) {
    Z01_FREE = server;
  });

  var ZPREM_SERVER = Defined.localhost;
  var ZPREM_HOSTS = [
    { host: 'prem.z01.online', k: 1, add: 0 },
    { host: 'rf.z01.online', k: 1, add: 0 },
    { host: 'prem2.z01.online', k: 1, add: 0 },
    { host: 'cf.z01.online', k: 1.2, add: 100 }
  ];
  var ZPREM_PING_TIMEOUT = 3000;
  var zprem_resolving = false;

  function zpremUse(host) {
    var server = zpremProto() + host + '/';
    if (server === ZPREM_SERVER) return;
    if (Defined.localhost === ZPREM_SERVER) Defined.localhost = server;
    ZPREM_SERVER = server;
  }

  function zpremMeasure(host, callback) {
    var url = zpremProto() + host + '/lite/withsearch';
    function once(call) {
      var xhr = new XMLHttpRequest();
      var done = false;
      var t0 = Date.now();
      function finish(ok) {
        if (done) return;
        done = true;
        call(ok ? Date.now() - t0 : -1);
      }
      try {
        xhr.open('GET', url + '?_=' + t0, true);
        xhr.timeout = ZPREM_PING_TIMEOUT;
        xhr.onload = function() { finish(xhr.status >= 200 && xhr.status < 400); };
        xhr.onerror = function() { finish(false); };
        xhr.ontimeout = function() { finish(false); };
        xhr.send();
      } catch (e) {
        finish(false);
      }
    }
    once(function(first) {
      if (first < 0) return callback(-1);
      once(function(second) {
        callback(second < 0 ? first : Math.min(first, second));
      });
    });
  }

  function zpremResolve() {
    if (zprem_resolving) return;
    zprem_resolving = true;
    var left = ZPREM_HOSTS.length;
    var best = null;
    ZPREM_HOSTS.forEach(function(h) {
      zpremMeasure(h.host, function(ms) {
        if (ms >= 0) {
          var score = ms * h.k + h.add;
          if (!best || score < best.score) best = { host: h.host, score: score };
        }
        if (--left) return;
        zprem_resolving = false;
        if (!best) return;
        Lampa.Storage.set('zprem_host', best.host);
        zpremUse(best.host);
      });
    });
  }

  (function() {
    var saved = Lampa.Storage.get('zprem_host', '');
    for (var i = 0; i < ZPREM_HOSTS.length; i++) {
      if (ZPREM_HOSTS[i].host === saved) return zpremUse(saved);
    }
  })();
  zpremResolve();

  var ZPREM_CHECK_URL = zpremProto() + 'oplata.z01.online/check.php';
  var ZPREM_PAY_URL = 'https://oplata.z01.online/pay.php';
  var ZPREM_TRIAL_URL = zpremProto() + 'oplata.z01.online/trial.php';

  // ===== UID, CLEAN EMAIL & SUBNET BYPASS LOGIC (MODIFED2) =====
  var zprem_dropped = false;
  function zpremDrop(er) {
    // Как в 1online.js / 2online.js удерживаем премиум-сервер,
    // но если вернулась жесткая ошибка accsdb — пробуем авто-перевыпуск триала перед откатом
    if (!er || !er.accsdb) return false;
    if (!zprem_dropped) {
      zprem_dropped = true;
      zpremResetTrial(true);
      return true;
    }
    Defined.localhost = Z01_FREE;
    return true;
  }

  function arrFind(list, test) {
    if (!list) return undefined;
    for (var i = 0; i < list.length; i++) {
      if (test(list[i], i, list)) return list[i];
    }
    return undefined;
  }

  var balansers_with_search;

  // Генерация случайного IP из российских диапазонов разных подсетей (/16 и /24)
  var RU_SUBNET_PREFIXES = [
    [5, 18], [5, 141], [31, 173], [37, 140], [46, 39], [77, 88],
    [78, 107], [79, 137], [81, 211], [83, 220], [85, 26], [87, 250],
    [89, 178], [91, 210], [93, 158], [95, 24], [109, 252], [128, 69],
    [176, 59], [178, 140], [185, 32], [188, 170], [195, 208], [213, 87]
  ];

  function generateRandomRuIp() {
    var pair = RU_SUBNET_PREFIXES[Math.floor(Math.random() * RU_SUBNET_PREFIXES.length)];
    var oct3 = Math.floor(Math.random() * 254) + 1;
    var oct4 = Math.floor(Math.random() * 253) + 2;
    return pair[0] + '.' + pair[1] + '.' + oct3 + '.' + oct4;
  }

  function getSpoofedIp() {
    var ip = Lampa.Storage.get('z01_spoof_ip', '');
    if (!ip) {
      ip = generateRandomRuIp();
      Lampa.Storage.set('z01_spoof_ip', ip);
    }
    return ip;
  }

  function rotateSpoofedIp() {
    var ip = generateRandomRuIp();
    Lampa.Storage.set('z01_spoof_ip', ip);
    return ip;
  }

  function getBypassHeaders(extraHeaders) {
    var ip = getSpoofedIp();
    var h = {
      'X-Forwarded-For': ip,
      'CF-Connecting-IP': ip,
      'X-Real-IP': ip,
      'True-Client-IP': ip,
      'Client-IP': ip
    };
    if (extraHeaders) {
      for (var k in extraHeaders) {
        h[k] = extraHeaders[k];
      }
    }
    return h;
  }

  // Генерация правдоподобного UID (совпадающего с форматом Lampa 8 hex/alphanumeric символов)
  function generateCleanUid() {
    var chars = '0123456789abcdef';
    var res = '';
    for (var i = 0; i < 8; i++) {
      res += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return res;
  }

  var unic_id = Lampa.Storage.get('lampac_unic_id', '');
  if (!unic_id) {
    unic_id = generateCleanUid();
    Lampa.Storage.set('lampac_unic_id', unic_id);
  }

  function resetZ01Uid() {
    unic_id = generateCleanUid();
    Lampa.Storage.set('lampac_unic_id', unic_id);
    // Сбрасываем и profile_id / nws_id, чтобы сервер не связывал сессии
    Lampa.Storage.set('lampac_nws_id', '');
    return unic_id;
  }

  // Генератор чистых реалистичных email без '+' и без префикса 'z01_'
  var EMAIL_NAMES = [
    'alexey', 'dmitry', 'sergey', 'andrey', 'maxim', 'ivan', 'artem', 'nikita',
    'mikhail', 'roman', 'egor', 'pavel', 'vladimir', 'denis', 'konstantin',
    'oleg', 'viktor', 'anton', 'igor', 'timur', 'ruslan', 'vadim', 'kirill'
  ];
  var EMAIL_SURNAMES = [
    'smirnov', 'ivanov', 'kuznetsov', 'popov', 'sokolov', 'lebedev', 'kozlov',
    'novikov', 'morozov', 'petrov', 'volkov', 'solovyov', 'vasilyev', 'zaytsev',
    'pavlov', 'semyonov', 'golubev', 'vinogradov', 'bogdanov', 'vorobyov', 'belov'
  ];
  var EMAIL_DOMAINS = [
    'gmail.com', 'yandex.ru', 'mail.ru', 'bk.ru', 'inbox.ru', 'list.ru'
  ];

  function generateRealisticEmail() {
    var n = EMAIL_NAMES[Math.floor(Math.random() * EMAIL_NAMES.length)];
    var s = EMAIL_SURNAMES[Math.floor(Math.random() * EMAIL_SURNAMES.length)];
    var d = EMAIL_DOMAINS[Math.floor(Math.random() * EMAIL_DOMAINS.length)];
    var sep = Math.random() > 0.5 ? '.' : (Math.random() > 0.5 ? '_' : '');
    var num = Math.floor(Math.random() * 9899) + 100;
    var tail = Lampa.Utils.uid(2).toLowerCase();
    return n + sep + s + num + tail + '@' + d;
  }

  function getZ01Email() {
    var trialEmail = Lampa.Storage.get('z01_trial_email', '');
    // Если остался старый спаленный формат с +z или z01_, сразу меняем
    if (trialEmail && trialEmail.indexOf('+') === -1 && trialEmail.indexOf('z01_') !== 0) {
      return trialEmail;
    }
    var newEmail = generateRealisticEmail();
    Lampa.Storage.set('z01_trial_email', newEmail);
    if (!Lampa.Storage.get('account_email', '')) {
      Lampa.Storage.set('account_email', newEmail);
    }
    return newEmail;
  }

  function rotateZ01TrialEmail() {
    var newEmail = generateRealisticEmail();
    Lampa.Storage.set('z01_trial_email', newEmail);
    // Синхронизируем с account_email, так как оригинальный Z01 берет email напрямую из account_email
    Lampa.Storage.set('account_email', newEmail);
    return newEmail;
  }

  function zpremResetTrial(quiet) {
    Lampa.Storage.set('zpremkey', '');
    Lampa.Storage.set('zprem_expires', '');
    Lampa.Storage.set('zprem_trial_used', '');
    resetZ01Uid();
    rotateZ01TrialEmail();
    rotateSpoofedIp();
    if (!quiet && typeof Lampa !== 'undefined' && Lampa.Noty) {
      Lampa.Noty.show('Демо-профиль, UID и подсеть обновлены!');
    }
  }
  window.zpremResetTrial = zpremResetTrial;

  function zpremDaysText(days) {
    if (days <= 0) return 'истекла';
    var n = Math.abs(days) % 100;
    var n1 = n % 10;
    if (n > 10 && n < 20) return days + ' дней';
    if (n1 > 1 && n1 < 5) return days + ' дня';
    if (n1 == 1) return days + ' день';
    return days + ' дней';
  }

  function isZpremActive() {
    var key = Lampa.Storage.get('zpremkey', '');
    var exp = Lampa.Storage.get('zprem_expires', '');
    if (key && exp) {
      return (new Date(exp).getTime() - Date.now()) > 0;
    }
    return false;
  }

  function zpremCheck(callback) {
    var email = getZ01Email();
    if (!email) { if (callback) callback(false); return; }
    var net = new Lampa.Reguest();
    net.timeout(10000);
    var url = ZPREM_CHECK_URL + '?email=' + encodeURIComponent(email);
    net["native"](url, function(resp) {
      try {
        if (typeof resp === 'string') resp = JSON.parse(resp);
        if (resp && resp.status === 'active' && resp.zpremkey) {
          Lampa.Storage.set('zpremkey', resp.zpremkey);
          Lampa.Storage.set('zprem_expires', resp.expires_at);
          Defined.localhost = ZPREM_SERVER;
          zpremResolve();
          if (callback) callback(true);
        } else {
          Lampa.Storage.set('zpremkey', '');
          Lampa.Storage.set('zprem_expires', '');
          if (callback) callback(false);
        }
      } catch(e) { if (callback) callback(false); }
    }, function() {
      if (callback) callback(false);
    }, false, {
      dataType: 'text',
      headers: getBypassHeaders()
    });
  }

  function zpremTrial(callback) {
    if (!isZpremActive()) {
      zpremResetTrial(true);
    }
    var email = getZ01Email();
    var uid = Lampa.Storage.get('lampac_unic_id', '');
    if (!email || !uid) { if (callback) callback(false, 'no_data'); return; }

    var net = new Lampa.Reguest();
    net.timeout(10000);

    var trialEndpoints = [
      ZPREM_TRIAL_URL,
      'https://oplata.z01.online/trial.php',
      'http://oplata.z01.online/trial.php'
    ];

    function sendTrialRequest(e, u, attempts) {
      attempts = attempts || 0;
      var baseUrl = trialEndpoints[attempts % trialEndpoints.length];
      var reqUrl = baseUrl + '?email=' + encodeURIComponent(e) + '&uid=' + encodeURIComponent(u) + '&_=' + Date.now();

      var handleResp = function(resp) {
        try {
          if (typeof resp === 'string') resp = JSON.parse(resp);
          if (resp && resp.status === 'activated' && resp.zpremkey) {
            Lampa.Storage.set('zpremkey', resp.zpremkey);
            Lampa.Storage.set('zprem_expires', resp.expires_at);
            if (resp.prem_url) Lampa.Storage.set('online_url', resp.prem_url);
            Lampa.Storage.set('zprem_trial_used', '');
            Defined.localhost = ZPREM_SERVER;
            zpremResolve();
            if (callback) callback(true, 'activated');
          } else if (attempts < 4) {
            var nextEmail = rotateZ01TrialEmail();
            var nextUid = resetZ01Uid();
            rotateSpoofedIp();
            sendTrialRequest(nextEmail, nextUid, attempts + 1);
          } else {
            // Если сервер жестко режет по реальному IP/24, включаем прямое подключение к prem.z01.online / rf.z01.online
            Defined.localhost = ZPREM_SERVER;
            zpremResolve();
            if (callback) callback(false, (resp && (resp.status || resp.reason || resp.msg)) || 'subnet_limit');
          }
        } catch(err) {
          if (attempts < 4) {
            sendTrialRequest(rotateZ01TrialEmail(), resetZ01Uid(), attempts + 1);
          } else {
            if (callback) callback(false, 'parse_error');
          }
        }
      };

      // Сначала пробуем через native с кастомными заголовками IP/подсети, при ошибке — fallback на silent
      net["native"](reqUrl, handleResp, function() {
        net.silent(reqUrl, handleResp, function() {
          if (attempts < 3) {
            sendTrialRequest(rotateZ01TrialEmail(), resetZ01Uid(), attempts + 1);
          } else {
            if (callback) callback(false, 'network_error');
          }
        });
      }, false, {
        dataType: 'text',
        headers: getBypassHeaders()
      });
    }

    sendTrialRequest(email, uid, 0);
  }

  function zpremAutoEnsure(callback) {
    if (isZpremActive()) {
      Defined.localhost = ZPREM_SERVER;
      zpremResolve();
      if (callback) callback(true);
      return;
    }
    zpremTrial(function(ok, reason) {
      Defined.localhost = ZPREM_SERVER;
      zpremResolve();
      if (callback) callback(ok, reason);
    });
  }

  function zpremActivate() {
    // Гарантируем, что в account_email лежит валидный сгенерированный email
    getZ01Email();
    if (isZpremActive()) {
      Defined.localhost = ZPREM_SERVER;
      zpremResolve();
    } else {
      zpremAutoEnsure();
    }
  }

  window.zpremCheck = zpremCheck;
  window.zpremDaysText = zpremDaysText;
  window.zpremTrial = zpremTrial;
  window.zpremAutoEnsure = zpremAutoEnsure;
  // ===== /UID, CLEAN EMAIL & SUBNET BYPASS LOGIC =====

  function getAndroidVersion() {
    if (Lampa.Platform.is('android')) {
      try {
        var current = AndroidJS.appVersion().split('-');
        return parseInt(current.pop());
      } catch (e) {
        return 0;
      }
    } else {
      return 0;
    }
  }

  var hostkey = 'https://prem.z01.online'.replace('http://', '').replace('https://', '');
  if (!window.rch_nws || !window.rch_nws[hostkey]) {
    if (!window.rch_nws) window.rch_nws = {};
    window.rch_nws[hostkey] = {
      type: Lampa.Platform.is('android') ? 'apk' : Lampa.Platform.is('tizen') ? 'cors' : undefined,
      startTypeInvoke: false,
      rchRegistry: false,
      apkVersion: getAndroidVersion()
    };
  }

  window.rch_nws[hostkey].typeInvoke = function rchtypeInvoke(host, call) {
    if (!window.rch_nws[hostkey].startTypeInvoke) {
      window.rch_nws[hostkey].startTypeInvoke = true;
      var check = function check(good) {
        window.rch_nws[hostkey].type = Lampa.Platform.is('android') ? 'apk' : good ? 'cors' : 'web';
        call();
      };
      if (Lampa.Platform.is('android') || Lampa.Platform.is('tizen')) check(true);
      else {
        var net = new Lampa.Reguest();
        net.silent('https://prem.z01.online'.indexOf(location.host) >= 0 ? 'https://github.com/' : host + '/cors/check', function() {
          check(true);
        }, function() {
          check(false);
        }, false, {
          dataType: 'text'
        });
      }
    } else call();
  };

  window.rch_nws[hostkey].Registry = function RchRegistry(client, startConnection) {
    window.rch_nws[hostkey].typeInvoke('https://prem.z01.online', function() {
      client.invoke("RchRegistry", {
        version: 154,
        host: location.host,
        rchtype: Lampa.Platform.is('android') ? 'apk' : Lampa.Platform.is('tizen') ? 'cors' : (window.rch_nws[hostkey].type || 'web'),
        apkVersion: window.rch_nws[hostkey].apkVersion,
        player: Lampa.Storage.field('player'),
        account_email: getZ01Email(),
        unic_id: Lampa.Storage.get('lampac_unic_id', ''),
        profile_id: Lampa.Storage.get('lampac_profile_id', ''),
        token: ''
      });
      if (client._shouldReconnect && window.rch_nws[hostkey].rchRegistry) {
        if (startConnection) startConnection();
        return;
      }
      window.rch_nws[hostkey].rchRegistry = true;
      client.on('RchRegistry', function(clientIp) {
        if (startConnection) startConnection();
      });
      client.on("RchClient", function(rchId, url, data, headers, returnHeaders) {
        var network = new Lampa.Reguest();
        var rchOrigin = (client && client.url)
          ? client.url.replace(/^ws(s?):\/\/([^\/?#]+).*/, 'http$1://$2')
          : 'https://prem.z01.online';
        function sendResult(uri, html) {
          $.ajax({
            url: rchOrigin + '/rch/' + uri + '?id=' + rchId,
            type: 'POST',
            data: html,
            async: true,
            cache: false,
            contentType: false,
            processData: false,
            success: function(j) {},
            error: function() {
              client.invoke("RchResult", rchId, '');
            }
          });
        }
        function result(html) {
          if (Lampa.Arrays.isObject(html) || Lampa.Arrays.isArray(html)) {
            html = JSON.stringify(html);
          }
          if (typeof CompressionStream !== 'undefined' && html && html.length > 2000) {
            var compressionStream = new CompressionStream('gzip');
            var encoder = new TextEncoder();
            var readable = new ReadableStream({
              start: function(controller) {
                controller.enqueue(encoder.encode(html));
                controller.close();
              }
            });
            var compressedStream = readable.pipeThrough(compressionStream);
            new Response(compressedStream).arrayBuffer()
              .then(function(compressedBuffer) {
                var compressedArray = new Uint8Array(compressedBuffer);
                if (compressedArray.length > html.length) {
                  sendResult('result', html);
                } else {
                  sendResult('gzresult', new Blob([compressedArray], { type: 'application/octet-stream' }));
                }
              })
              ['catch'](function() {
                sendResult('result', html);
              });
          } else {
            sendResult('result', html);
          }
        }
        if (url == 'eval') {
          result(eval(data));
        } else if (url == 'evalrun') {
          eval(data);
        } else if (url == 'ping') {
          result('pong');
        } else {
          network["native"](url, result, function(e) {
            result('');
          }, data, {
            dataType: 'text',
            timeout: 1000 * 8,
            headers: headers,
            returnHeaders: returnHeaders
          });
        }
      });
      client.on('Connected', function(connectionId) {
        window.rch_nws[hostkey].connectionId = connectionId;
      });
      client.on('Closed', function() {});
      client.on('Error', function(err) {});
    });
  };
  window.rch_nws[hostkey].typeInvoke('https://prem.z01.online', function() {});

  function rchInvoke(json, call) {
    if (window.nwsClient && window.nwsClient[hostkey] && window.nwsClient[hostkey]._shouldReconnect){
      call();
      return;
    }
    if (!window.nwsClient) window.nwsClient = {};
    if (window.nwsClient[hostkey] && window.nwsClient[hostkey].socket)
      window.nwsClient[hostkey].socket.close();
    window.nwsClient[hostkey] = new NativeWsClient(json.nws, {
      autoReconnect: false
    });
    window.nwsClient[hostkey].on('Connected', function(connectionId) {
      window.rch_nws[hostkey].Registry(window.nwsClient[hostkey], function() {
        call();
      });
    });
    window.nwsClient[hostkey].connect();
  }

  function rchRun(json, call) {
    if (typeof NativeWsClient == 'undefined') {
      Lampa.Utils.putScript(["https://prem.z01.online/js/nws-client-es5.js?v03022026"], function() {}, false, function() {
        rchInvoke(json, call);
      }, true);
    } else {
      rchInvoke(json, call);
    }
  }

  function account(url) {
    url = url + '';
    if (url.indexOf('account_email=') == -1) {
      var email = getZ01Email();
      if (email) url = Lampa.Utils.addUrlComponent(url, 'account_email=' + encodeURIComponent(email));
    }
    if (url.indexOf('uid=') == -1) {
      var uid = Lampa.Storage.get('lampac_unic_id', '');
      if (uid) url = Lampa.Utils.addUrlComponent(url, 'uid=' + encodeURIComponent(uid));
    }
    if (url.indexOf('token=') == -1) {
      var token = '';
      if (token != '') url = Lampa.Utils.addUrlComponent(url, 'token=');
    }
    if (url.indexOf('nws_id=') == -1 && window.rch_nws && window.rch_nws[hostkey]) {
      var nws_id = window.rch_nws[hostkey].connectionId || Lampa.Storage.get('lampac_nws_id', '');
      if (nws_id) url = Lampa.Utils.addUrlComponent(url, 'nws_id=' + encodeURIComponent(nws_id));
    }
    return url;
  }

  var synced_balansers = {};
  function syncBalanser(name) {
    if (!name || synced_balansers[name]) return;
    if (!Lampa.Manifest || Lampa.Manifest.app_digital < 177) return;
    if (!Lampa.Storage.sync) return;
    synced_balansers[name] = true;
    Lampa.Storage.sync('online_choice_' + name, 'object_object');
  }

  var Z01UI = {};
  Z01UI.enabled = function() {
    return Lampa.Storage.get('z01_ui_mode', 'modern') !== 'classic';
  };
  Z01UI.REQUEST_TIMEOUT = 20000;
  Z01UI.WATCHDOG = 24;
  Z01UI.WATCHDOG_FIRST = 40;
  Z01UI.esc = function(str) {
    return (str === undefined || str === null ? '' : String(str))
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  };
  Z01UI.shortQuality = function(text) {
    if (!text) return '';
    text = String(text);
    var match = text.match(/(2160|1440|1080|720|576|480|360)\s*p?/i);
    if (match) {
      var value = parseInt(match[1]);
      if (value >= 2160) return '4K';
      if (value >= 1080) return 'FHD';
      if (value >= 720) return 'HD';
      return 'SD';
    }
    if (/4k|uhd/i.test(text)) return '4K';
    if (/fhd/i.test(text)) return 'FHD';
    if (/\bhd\b/i.test(text)) return 'HD';
    return '';
  };
  Z01UI.VOICE_KINDS = [{
    key: 'dub',
    title: 'z01_voice_dub',
    re: /дубляж|дублирован|\bdub\b|\bdubbing\b/i
  }, {
    key: 'mvo',
    title: 'z01_voice_mvo',
    re: /многоголос|\bmvo\b|\bpmvo\b/i
  }, {
    key: 'dvo',
    title: 'z01_voice_dvo',
    re: /двухголос|\bdvo\b/i
  }, {
    key: 'avo',
    title: 'z01_voice_avo',
    re: /авторск|одноголос|\bavo\b|\bvo\b/i
  }, {
    key: 'orig',
    title: 'z01_voice_orig',
    re: /оригинал|original|\beng\b|\bua\b|\bukr\b/i
  }, {
    key: 'sub',
    title: 'z01_voice_sub',
    re: /субтитр|sub(title)?s?\b/i
  }];
  Z01UI.VOICE_STUDIOS = [{
    key: 'mvo',
    re: /lostfilm|лостфильм|tvshows|dniprofilm|невафильм|newstudio|newcomers|baibako|байбако|alexfilm|jaskier|coldfilm|колдфильм|hdrezka|rezkastudio|red head sound|sunshine|amedia|zakadry|закадры|linefilm|le-production|1win|kerob|profix|selena|октопус/i
  }, {
    key: 'dvo',
    re: /кубик в кубе|kubik|viruseproject|вирус|green ?tea|paradox/i
  }, {
    key: 'avo',
    re: /яроцк|гаврилов|володарск|сербин|горчаков|михал[её]в|живов|пучков|гоблин|кураж|дольск|есарев|карповск|визгунов/i
  }];
  Z01UI.voiceKind = function(title) {
    var text = String(title || '');
    var i;
    for (i = 0; i < Z01UI.VOICE_KINDS.length; i++) {
      if (Z01UI.VOICE_KINDS[i].re.test(text)) return Z01UI.VOICE_KINDS[i].key;
    }
    for (i = 0; i < Z01UI.VOICE_STUDIOS.length; i++) {
      if (Z01UI.VOICE_STUDIOS[i].re.test(text)) return Z01UI.VOICE_STUDIOS[i].key;
    }
    return 'other';
  };
  Z01UI.voiceLabel = function(title) {
    var s = String(title == null ? '' : title);
    var out = s.replace(/\s*,\s*(?:4k|uhd|2160p?)(?=\s*(?:[\],)]|$))/gi, '')
      .replace(/(\[|\()\s*(?:4k|uhd|2160p?)\s*,\s*/gi, '$1')
      .replace(/\s*[\[(]\s*(?:4k|uhd|2160p?)\s*[\])]/gi, '')
      .replace(/\s+(?:4k|uhd)\s*$/i, '')
      .replace(/^\s+|\s+$/g, '')
      .replace(/\[/g, '(').replace(/\]/g, ')');
    return out || s;
  };
  Z01UI.voiceKindTitle = function(key) {
    for (var i = 0; i < Z01UI.VOICE_KINDS.length; i++) {
      if (Z01UI.VOICE_KINDS[i].key == key) return Lampa.Lang.translate(Z01UI.VOICE_KINDS[i].title);
    }
    return Lampa.Lang.translate('z01_voice_other');
  };
  Z01UI.voiceGroups = function(list) {
    var order = [];
    var map = {};
    (list || []).forEach(function(entry, index) {
      var key = Z01UI.voiceKind(entry.title);
      if (!map[key]) {
        map[key] = {
          key: key,
          title: Z01UI.voiceKindTitle(key),
          items: []
        };
        order.push(key);
      }
      map[key].items.push({
        index: index,
        title: entry.title,
        url: entry.url
      });
    });
    var rank = function(key) {
      for (var i = 0; i < Z01UI.VOICE_KINDS.length; i++) {
        if (Z01UI.VOICE_KINDS[i].key == key) return i;
      }
      return 90;
    };
    order.sort(function(a, b) {
      return rank(a) - rank(b);
    });
    return order.map(function(key) {
      return map[key];
    });
  };
  Z01UI.splitSourceName = function(name) {
    name = String(name || '');
    var badge = '';
    var match = name.match(/\s*[-~–]\s*(2160p?|1440p?|1080p?|720p?|480p?|4k|uhd|fhd|hd)\b[^,]*$/i);
    if (match) {
      badge = Z01UI.shortQuality(match[1]);
      if (badge) name = name.slice(0, match.index);
    }
    return {
      name: name.replace(/\s+$/, ''),
      badge: badge
    };
  };
  Z01UI.isSeasonLabel = function(text) {
    text = String(text || '').trim();
    return /^\d+\s*(-?[йя])?\s*(сезон|season)$/i.test(text) || /^(сезон|season)\s*\d+$/i.test(text);
  };
  Z01UI.MOVIE_ONLY = ['xvideocdnultra', 'xvideocdn60fps'];
  Z01UI.isMovieOnlySource = function(key, title) {
    if (Z01UI.MOVIE_ONLY.indexOf(String(key || '').toLowerCase()) !== -1) return true;
    return /^xvideocdn/i.test(key || '') && /ultra|60\s*\/?\s*120|60fps/i.test(title || '');
  };
  Z01UI.payLink = function(answer) {
    if (!answer) return '';
    var fields = ['url', 'link', 'pay', 'pay_url', 'payurl', 'buy', 'account'];
    for (var i = 0; i < fields.length; i++) {
      var value = answer[fields[i]];
      if (typeof value === 'string' && /^https?:\/\//i.test(value)) return value;
    }
    var text = String(answer.msg || answer.message || answer.text || '');
    var match = text.match(/https?:\/\/[^\s"'<>)]+/i);
    return match ? match[0] : '';
  };
  Z01UI.serverDenial = function(answer) {
    if (!answer || typeof answer !== 'object') return null;
    var denied = !!(answer.accsdb || answer.blocked || answer.error ||
      (typeof answer.code === 'number' && answer.code >= 300));
    if (!denied) return null;
    var text = String(answer.msg || answer.message || answer.text || '');
    var own_image = /<img|qr-code|qrcode/i.test(text);
    return {
      msg: text || Lampa.Lang.translate('z01_no_access_text'),
      link: own_image ? '' : Z01UI.payLink(answer)
    };
  };
  window.z01PayDirect = function() {
    try {
      var P = Lampa.Platform;
      if (P.screen && P.screen('mobile')) return true;
      if (P.screen && P.screen('tv')) return false;
      if (P.is('tizen') || P.is('webos') || P.is('orsay') || P.is('netcast') || P.is('android')) return false;
    } catch (e) {}
    var ua = navigator.userAgent.toLowerCase();
    if (/tizen|webos|web0s|smart-?tv|android|\batv\b|tv browser|crkey|aft[a-z]|bravia|hbbtv|netcast/.test(ua) || window.tizen || window.webOS) return false;
    return /windows|macintosh|x11|cros|iphone|ipad/.test(ua);
  };
  Z01UI.qrImage = function(link, size) {
    size = size || 300;
    return 'https://api.qrserver.com/v1/create-qr-code/?size=' + size + 'x' + size +
      '&margin=10&data=' + encodeURIComponent(link);
  };
  Z01UI.providerName = function(url) {
    var path = String(url || '').split('?')[0].split('#')[0];
    var parts = path.split('/');
    var last = '';
    while (parts.length && !last) last = parts.pop();
    return last;
  };
  Z01UI.seasonNumber = function(title) {
    var match = String(title || '').match(/\d+/);
    return match ? parseInt(match[0]) : 0;
  };
  Z01UI.normName = function(text) {
    text = String(text === undefined || text === null ? '' : text).toLowerCase();
    text = text.replace(/\u0451/g, '\u0435').replace(/[^0-9a-z\u0430-\u044f]+/g, ' ');
    return text.replace(/^\s+/, '').replace(/\s+$/, '');
  };
  Z01UI.nameParts = function(text) {
    var raw = String(text || '').split(/\s*[\/|]\s*/);
    var out = [];
    for (var i = 0; i < raw.length; i++) {
      var norm = Z01UI.normName(raw[i]);
      if (norm) out.push(norm);
    }
    return out;
  };
  Z01UI.yearOf = function(value) {
    var match = String(value === undefined || value === null ? '' : value).match(/\d{4}/);
    var year = match ? parseInt(match[0], 10) : 0;
    return year > 1900 && year < 2200 ? year : 0;
  };
  Z01UI.movieNames = function(movie) {
    var fields = ['title', 'name', 'original_title', 'original_name'];
    var out = [];
    for (var i = 0; i < fields.length; i++) {
      var parts = Z01UI.nameParts(movie && movie[fields[i]]);
      for (var j = 0; j < parts.length; j++) {
        if (out.indexOf(parts[j]) === -1) out.push(parts[j]);
      }
    }
    return out;
  };
  Z01UI.matchScore = function(elem, movie) {
    if (!elem || !movie) return 0;
    var mine = Z01UI.movieNames(movie);
    var theirs = Z01UI.nameParts(elem.title || elem.text || '');
    var score = 0;
    for (var i = 0; i < theirs.length; i++) {
      for (var j = 0; j < mine.length; j++) {
        var a = theirs[i];
        var b = mine[j];
        var hit = 0;
        if (a === b) hit = 60;
        else if (a.length > 3 && b.length > 3 && (a.indexOf(b) === 0 || b.indexOf(a) === 0)) hit = 34;
        else if (a.length > 5 && b.length > 5 && (a.indexOf(b) !== -1 || b.indexOf(a) !== -1)) hit = 22;
        if (hit > score) score = hit;
      }
    }
    var my_year = Z01UI.yearOf(movie.release_date || movie.first_air_date || movie.year);
    var their_year = Z01UI.yearOf(elem.year || elem.start_date);
    if (my_year && their_year) {
      var diff = Math.abs(my_year - their_year);
      if (diff === 0) score += 34;
      else if (diff === 1) score += 16;
      else score -= 30;
    }
    return score;
  };
  Z01UI.rankSimilars = function(list, movie) {
    var ranked = [];
    for (var i = 0; i < (list || []).length; i++) {
      ranked.push({
        elem: list[i],
        index: i,
        score: Z01UI.matchScore(list[i], movie)
      });
    }
    ranked.sort(function(a, b) {
      return b.score - a.score || a.index - b.index;
    });
    var best = ranked[0];
    var second = ranked[1];
    var gap = best ? best.score - (second ? second.score : -100) : 0;
    return {
      list: ranked,
      best: best || null,
      likely: !!(best && best.score >= 45 && gap >= 10),
      sure: !!(best && best.score >= 70 && gap >= 25)
    };
  };
  Z01UI.SEEN_PERCENT = 90;
  Z01UI.isSeen = function(element, viewed) {
    if (!element) return false;
    if (element.hash_behold && viewed && viewed.indexOf(element.hash_behold) !== -1) return true;
    var line = element.timeline;
    return !!(line && line.percent >= Z01UI.SEEN_PERCENT);
  };
  Z01UI.QUALITY_RANK = {
    '4K': 4,
    'FHD': 3,
    'HD': 2,
    'SD': 1
  };
  Z01UI.qualityRank = function(label) {
    return Z01UI.QUALITY_RANK[label] || 0;
  };
  Z01UI.reachKey = function(movie) {
    if (!movie) return '';
    return Lampa.Utils.hash(movie.original_name || movie.original_title || movie.name || movie.title || '');
  };
  Z01UI.bestQuality = function(items) {
    var best = '';
    for (var i = 0; i < (items || []).length; i++) {
      var item = items[i] || {};
      var label = '';
      var quality = item.quality || item.qualitys;
      if (quality && typeof quality === 'object') label = Lampa.Arrays.getKeys(quality).join(' ');
      else if (quality) label = String(quality);
      var found = Z01UI.qualityFromText(label) || Z01UI.qualityFromText(item.title || item.text || '');
      if (Z01UI.qualityRank(found) > Z01UI.qualityRank(best)) best = found;
    }
    return best;
  };
  Z01UI.qualityFromText = function(text) {
    text = String(text === undefined || text === null ? '' : text);
    var best = '';
    var re = /(?:^|[^\d])(2160|1440|1080|720|576|480)\s*p?(?![\d])/gi;
    var found;
    while ((found = re.exec(text))) {
      var label = Z01UI.shortQuality(found[1] + 'p');
      if (Z01UI.qualityRank(label) > Z01UI.qualityRank(best)) best = label;
    }
    if (/4k|uhd/i.test(text) && Z01UI.qualityRank('4K') > Z01UI.qualityRank(best)) best = '4K';
    if (!best && /fhd/i.test(text)) best = 'FHD';
    return best;
  };
  Z01UI.knownQuality = function(name) {
    return Lampa.Storage.cache('z01_source_quality', 500, {})[name] || '';
  };
  Z01UI.rememberQuality = function(name, label) {
    if (!name || !label) return;
    var all = Lampa.Storage.cache('z01_source_quality', 500, {});
    if (Z01UI.qualityRank(label) <= Z01UI.qualityRank(all[name])) return;
    all[name] = label;
    Lampa.Storage.set('z01_source_quality', all);
  };
  Z01UI.sourceBadge = function(name, parts) {
    return Z01UI.knownQuality(name) || (parts ? parts.badge : '');
  };
  Z01UI.reachEntry = function(movie, season) {
    var all = Lampa.Storage.cache('z01_reach', 2000, {});
    var mine = all[Z01UI.reachKey(movie)] || {};
    var value = mine[season || 1];
    if (typeof value === 'number') return {
      e: value,
      l: value,
      r: 2
    };
    if (value && typeof value === 'object') return {
      e: parseInt(value.e, 10) || 0,
      l: parseInt(value.l, 10) || 0,
      r: parseInt(value.r, 10) || 0
    };
    return {
      e: 0,
      l: 0,
      r: 0
    };
  };
  Z01UI.reached = function(movie, season) {
    return Z01UI.reachEntry(movie, season).e;
  };
  Z01UI.setReach = function(movie, season, episode) {
    episode = parseInt(episode, 10) || 0;
    var key = Z01UI.reachKey(movie);
    if (!key) return;
    var all = Lampa.Storage.cache('z01_reach', 2000, {});
    var mine = all[key] || {};
    mine[season || 1] = {
      e: episode,
      l: episode,
      r: episode ? 2 : 0
    };
    all[key] = mine;
    Lampa.Storage.set('z01_reach', all);
  };
  Z01UI.rememberReach = function(movie, season, episode) {
    episode = parseInt(episode, 10) || 0;
    var key = Z01UI.reachKey(movie);
    if (!episode || !key) return;
    var entry = Z01UI.reachEntry(movie, season);
    if (episode === entry.l || episode === entry.l + 1) entry.r = (entry.r || 0) + 1;
    else entry.r = 1;
    entry.l = episode;
    if (!entry.e || entry.r >= 2 || episode === entry.e + 1) entry.e = episode;
    var all = Lampa.Storage.cache('z01_reach', 2000, {});
    var mine = all[key] || {};
    mine[season || 1] = {
      e: entry.e,
      l: entry.l,
      r: entry.r
    };
    all[key] = mine;
    Lampa.Storage.set('z01_reach', all);
  };
  Z01UI.episodeNumber = function(value) {
    var num = parseInt(value, 10);
    if (!num && num !== 0) return String(value === undefined || value === null ? '' : value);
    return num < 10 ? '0' + num : String(num);
  };
  Z01UI.JUMP_FROM = 20;
  Z01UI.pageSize = function(total) {
    return total > 200 ? 50 : total > 80 ? 20 : 10;
  };
  Z01UI.pages = function(total) {
    var size = Z01UI.pageSize(total);
    var out = [];
    for (var start = 0; start < total; start += size) {
      out.push({
        start: start,
        end: Math.min(start + size, total) - 1
      });
    }
    if (out.length > 1) {
      var tail = out[out.length - 1];
      if (tail.end - tail.start + 1 <= size / 2) {
        out[out.length - 2].end = tail.end;
        out.pop();
      }
    }
    return out;
  };
  Z01UI.pageAt = function(pages, index) {
    for (var i = 0; i < pages.length; i++) {
      if (index >= pages[i].start && index <= pages[i].end) return pages[i];
    }
    return pages[0] || {
      start: 0,
      end: -1
    };
  };
  Z01UI.icon = {
    play: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"></path></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M4 12l5 5L20 6" stroke-linecap="round" stroke-linejoin="round"></path></svg>',
    chevron: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6"><path d="M6 9l6 6 6-6" stroke-linecap="round" stroke-linejoin="round"></path></svg>',
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="11" cy="11" r="7"></circle><path d="M20 20l-4-4" stroke-linecap="round"></path></svg>',
    refresh: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M20 11a8 8 0 10-2.3 5.7" stroke-linecap="round"></path><path d="M20 4v7h-7" stroke-linecap="round" stroke-linejoin="round"></path></svg>',
    warn: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M12 4l9 16H3z" stroke-linejoin="round"></path><path d="M12 10v4" stroke-linecap="round"></path><circle cx="12" cy="17" r="0.6" fill="currentColor"></circle></svg>'
  };
  Z01UI.css = [
    '<style>',
    '.mo{padding:0 0 3em 0}',
    '.mo *{-webkit-box-sizing:border-box;box-sizing:border-box}',
    '.mo-head{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-ms-flex-align:center;align-items:center;padding:0 .2em .7em .2em}',
    '.mo-head__art{position:relative;width:4.6em;height:6.6em;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0;margin-right:1.1em;background:rgba(255,255,255,.07);-webkit-border-radius:.35em;border-radius:.35em;overflow:hidden}',
    '.mo-head__art img{position:absolute;top:0;left:0;width:100%;height:100%;-o-object-fit:cover;object-fit:cover;opacity:0;-webkit-transition:opacity .3s;transition:opacity .3s}',
    '.mo-head__art--loaded img{opacity:1}',
    '.mo-head__text{-webkit-box-flex:1;-webkit-flex:1 1 auto;-ms-flex:1 1 auto;flex:1 1 auto;min-width:0;padding-right:1em}',
    '.mo-head__sub{font-size:1em;opacity:.45;line-height:1.3;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',
    '.mo-head__title{font-size:1.7em;font-weight:600;line-height:1.2;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',
    '.mo-head__note{font-size:1.05em;opacity:.7;white-space:nowrap;padding-bottom:.15em}',
    '.mo-head__bar{position:relative;height:.25em;-webkit-border-radius:.25em;border-radius:.25em;background:rgba(255,255,255,.12);margin:0 .2em 1.4em .2em;overflow:hidden}',
    '.mo-head__fill{position:absolute;left:0;top:0;bottom:0;background:#7cc4ff}',
    '.mo-head--hidden{display:none}',
    '.mo-panel{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-flex-wrap:wrap;-ms-flex-wrap:wrap;flex-wrap:wrap;margin:0 0 1.3em 0}',
    '.mo-seg{position:relative;min-width:11em;max-width:24em;padding:.6em 2.2em .6em 1em;margin:0 .8em .6em 0;background:rgba(255,255,255,.08);-webkit-border-radius:.35em;border-radius:.35em;line-height:1.25}',
    '.mo-seg__name{font-size:.75em;letter-spacing:.06em;text-transform:uppercase;opacity:.5}',
    '.mo-seg__value{font-size:1.15em;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',
    '.mo-seg__mark{font-size:.68em;font-weight:600;padding:.1em .4em;margin-right:.5em;background:rgba(255,255,255,.2);-webkit-border-radius:.25em;border-radius:.25em;vertical-align:.15em}',
    '.mo-seg__arrow{position:absolute;right:.9em;top:50%;margin-top:-.2em;width:0;height:0;border-left:.4em solid transparent;border-right:.4em solid transparent;border-top:.45em solid rgba(255,255,255,.55)}',
    '.mo-seg.focus{background:#fff;color:#000}',
    '.mo-seg.focus .mo-seg__name{opacity:.6}',
    '.mo-seg.focus .mo-seg__mark{background:rgba(0,0,0,.15)}',
    '.mo-seg.focus .mo-seg__arrow{border-top-color:rgba(0,0,0,.6)}',
    '.mo-seg--open{background:rgba(124,196,255,.22)}',
    '.mo-grid{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-flex-wrap:wrap;-ms-flex-wrap:wrap;flex-wrap:wrap;margin:0 -.3em 1.4em -.3em}',
    '.mo-opt{width:25%;padding:0 .3em .6em .3em}',
    '.mo-opt__in{position:relative;padding:.65em .8em;min-height:3.1em;background:rgba(255,255,255,.07);-webkit-border-radius:.35em;border-radius:.35em;line-height:1.3;overflow:hidden}',
    '.mo-opt__label{display:block;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',
    '.mo-opt__note{display:block;font-size:.8em;opacity:.5;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',
    '.mo-opt.focus .mo-opt__in{background:#fff;color:#000}',
    '.mo-opt.focus .mo-opt__note{opacity:.6}',
    '.mo-opt--active .mo-opt__in{-webkit-box-shadow:inset 0 0 0 .12em #7cc4ff;box-shadow:inset 0 0 0 .12em #7cc4ff}',
    '.mo-opt__tag{display:inline-block;min-width:2.4em;text-align:center;font-size:.7em;font-weight:600;background:rgba(255,255,255,.18);-webkit-border-radius:.25em;border-radius:.25em;padding:.1em .3em;margin-right:.5em;vertical-align:.15em}',
    '.mo-opt.focus .mo-opt__tag{background:rgba(0,0,0,.14)}',
    '.mo-tiles{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-flex-wrap:wrap;-ms-flex-wrap:wrap;flex-wrap:wrap;margin:0 -.45em}',
    '.mo-tile{width:25%;padding:0 .45em 1.1em .45em}',
    '.mo-tile__art{position:relative;padding-top:56%;background:rgba(255,255,255,.08);-webkit-border-radius:.4em;border-radius:.4em;overflow:hidden}',
    '.mo-tile__art img{position:absolute;top:0;left:0;width:100%;height:100%;-o-object-fit:cover;object-fit:cover;opacity:0;-webkit-transition:opacity .3s;transition:opacity .3s}',
    '.mo-tile__art--loaded img{opacity:1}',
    '.mo-tile__num{position:absolute;left:.5em;top:.45em;font-size:1.1em;font-weight:700;padding:.05em .45em;background:rgba(0,0,0,.55);-webkit-border-radius:.25em;border-radius:.25em}',
    '.mo-tile__tag{position:absolute;right:.5em;top:.45em;font-size:.72em;font-weight:600;padding:.15em .4em;background:rgba(0,0,0,.55);-webkit-border-radius:.25em;border-radius:.25em}',
    '.mo-tile__time{position:absolute;right:.5em;bottom:.5em;font-size:.8em;padding:.1em .4em;background:rgba(0,0,0,.55);-webkit-border-radius:.25em;border-radius:.25em}',
    '.mo-tile__check{position:absolute;left:.5em;bottom:.5em;width:1.5em;height:1.5em;padding:.25em;color:#0b0c12;background:#7bd88f;-webkit-border-radius:100%;border-radius:100%}',
    '.mo-tile__check svg{width:100%;height:100%}',
    '.mo-tile__line{position:absolute;left:0;right:0;bottom:0;height:.25em}',
    '.mo-tile__line .time-line{display:block !important;height:100%;margin:0;background:rgba(0,0,0,.5)}',
    '.mo-tile__line .time-line>div{background:#7cc4ff}',
    '.mo-tile__body{padding:.5em .15em 0 .15em}',
    '.mo-tile__title{font-size:1.05em;line-height:1.35;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',
    '.mo-tile__meta{font-size:.85em;opacity:.5;line-height:1.4;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',
    '.mo-tile__meta span+span:before{content:" · "}',
    '.mo-tile--seen .mo-tile__art img{opacity:.45}',
    '.mo-tile--seen .mo-tile__title{opacity:.6}',
    '.mo-tile.focus .mo-tile__art{-webkit-box-shadow:0 0 0 .2em #fff;box-shadow:0 0 0 .2em #fff}',
    '.mo-tile--current .mo-tile__art{-webkit-box-shadow:0 0 0 .16em #7cc4ff;box-shadow:0 0 0 .16em #7cc4ff}',
    '.mo-tile.focus.mo-tile--current .mo-tile__art{-webkit-box-shadow:0 0 0 .2em #fff;box-shadow:0 0 0 .2em #fff}',
    '.mo-tile--soon{opacity:.45}',
    '.mo-line{position:relative;display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-ms-flex-align:center;align-items:center;padding:.6em 1em .65em .6em;margin-bottom:.45em;background:rgba(255,255,255,.06);-webkit-border-radius:.4em;border-radius:.4em}',
    '.mo-line__art{position:relative;width:4.4em;height:4.4em;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0;margin-right:1em;background:rgba(255,255,255,.08);-webkit-border-radius:.3em;border-radius:.3em;overflow:hidden}',
    '.mo-line__art img{position:absolute;top:0;left:0;width:100%;height:100%;-o-object-fit:cover;object-fit:cover;opacity:0;-webkit-transition:opacity .3s;transition:opacity .3s}',
    '.mo-line__art--loaded img{opacity:1}',
    '.mo-line__time{font-size:.9em;opacity:.6;margin-left:.7em}',
    '.mo-line__line{position:absolute;left:6.2em;right:1em;bottom:.35em;height:.16em}',
    '.mo-line__line .time-line{display:block !important;height:100%;margin:0;background:rgba(255,255,255,.14);-webkit-border-radius:.16em;border-radius:.16em;overflow:hidden}',
    '.mo-line__line .time-line>div{background:#7cc4ff}',
    '.mo-line.focus .mo-line__line .time-line{background:rgba(0,0,0,.15)}',
    '.mo-line.focus{background:#fff;color:#000}',
    '.mo-line--current{-webkit-box-shadow:inset .18em 0 0 #7cc4ff;box-shadow:inset .18em 0 0 #7cc4ff}',
    '.mo-line__tag{font-size:.72em;font-weight:600;background:rgba(255,255,255,.18);-webkit-border-radius:.25em;border-radius:.25em;padding:.15em .45em;margin-left:.7em}',
    '.mo-line.focus .mo-line__tag{background:rgba(0,0,0,.14)}',
    '.mo-line__body{-webkit-box-flex:1;-webkit-flex:1 1 auto;-ms-flex:1 1 auto;flex:1 1 auto;min-width:0}',
    '.mo-line__title{font-size:1.15em;line-height:1.35;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',
    '.mo-line__note{font-size:.85em;opacity:.55;line-height:1.4;overflow:hidden;white-space:nowrap;-o-text-overflow:ellipsis;text-overflow:ellipsis}',
    '.mo-line__side{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-box-align:center;-webkit-align-items:center;-ms-flex-align:center;align-items:center;-webkit-flex-shrink:0;-ms-flex-negative:0;flex-shrink:0;padding-left:1em}',
    '.mo-line--nav .mo-line__side:after{content:"›";font-size:1.5em;opacity:.6}',
    '.mo-info{padding:1.4em .2em}',
    '.mo-info__title{font-size:1.5em;font-weight:600;margin-bottom:.4em}',
    '.mo-info__text{font-size:1.05em;line-height:1.5;opacity:.7;margin-bottom:1.1em;max-width:44em}',
    '.mo-info__text img{max-width:12em;margin-top:.8em;display:block}',
    '.mo-info__link{font-size:.95em;opacity:.5;word-break:break-all;margin-bottom:1em}',
    '.mo-info__qr{margin-bottom:1.1em}',
    '.mo-info__qr img{display:block;width:11em;height:11em;background:#fff;padding:.4em;-webkit-border-radius:.4em;border-radius:.4em}',
    '.mo-info__acts{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-flex-wrap:wrap;-ms-flex-wrap:wrap;flex-wrap:wrap}',
    '.mo-act{padding:.6em 1.4em;margin:0 .8em .6em 0;background:rgba(255,255,255,.12);-webkit-border-radius:.35em;border-radius:.35em;font-size:1.05em;white-space:nowrap}',
    '.mo-act.focus{background:#fff;color:#000}',
    '.mo-act>svg{width:1.1em;height:1.1em;margin-right:.5em;vertical-align:-.15em}',
    '.mo-wait{width:100%;padding:.2em .2em 1.2em .2em}',
    '.mo-wait__head{display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;-webkit-box-align:baseline;-webkit-align-items:baseline;-ms-flex-align:baseline;align-items:baseline;margin-bottom:.5em}',
    '.mo-wait__title{font-size:1.25em;padding-right:.8em;-webkit-box-flex:1;-webkit-flex:1 1 auto;-ms-flex:1 1 auto;flex:1 1 auto}',
    '.mo-wait__count{font-size:.95em;opacity:.55}',
    '.mo-wait__bar{position:relative;height:.25em;width:100%;max-width:24em;-webkit-border-radius:.25em;border-radius:.25em;background:rgba(255,255,255,.12);overflow:hidden}',
    '.mo-wait__fill{position:absolute;left:0;top:0;bottom:0;background:#7cc4ff;-webkit-transition:width .4s;transition:width .4s}',
    '@media screen and (max-width:1300px){',
    '.mo-opt{width:33.333%}',
    '.mo-tile{width:33.333%}',
    '}',
    '@media screen and (max-width:900px){',
    '.mo-opt{width:50%}',
    '.mo-tile{width:50%}',
    '.mo-head__title{font-size:1.4em}',
    '}',
    '@media screen and (max-width:580px){',
    '.mo-opt{width:100%}',
    '.mo-seg{min-width:8em}',
    '}',
    '</style>'
  ].join('');

  function component(object) {
    var network = new Network();
    var scroll = new Lampa.Scroll({
      mask: true,
      over: true
    });
    var files = new Lampa.Explorer(object);
    var filter = new Lampa.Filter(object);
    var sources = {};
    var last;
    var source;
    var balanser;
    var initialized;
    var balanser_timer;
    var images = [];
    var number_of_requests = 0;
    var number_of_requests_timer;
    var life_wait_times = 0;
    var life_wait_timer;
    var probe_self = this;
    var probe_busy = false;
    var probe_started = false;
    var probe_nets = [];
    var fileurl_cache = {};
    var fileurl_prefetching = {};
    var prefetch_timer = null;
    var prefetch_network = null;
    var FILEURL_TTL = 90 * 1000;
    var filter_sources = {};
    var filter_translate = {
      season: Lampa.Lang.translate('torrent_serial_season'),
      voice: Lampa.Lang.translate('torrent_parser_voice'),
      source: Lampa.Lang.translate('settings_rest_source')
    };
    var filter_find = {
      season: [],
      voice: []
    };
    if (balansers_with_search == undefined) {
      network.timeout(10000);
      network.silent(account(Defined.localhost + 'lite/withsearch'), function(json) {
        balansers_with_search = json;
      }, function() {
        balansers_with_search = [];
      });
    }
    function balanserName(j) {
      var bals = j.balanser;
      var name = j.name.split(' ')[0];
      return (bals || name).toLowerCase();
    }
    function clarificationSearchAdd(value){
      var id = Lampa.Utils.hash(object.movie.number_of_seasons ? object.movie.original_name : object.movie.original_title);
      var all = Lampa.Storage.get('clarification_search','{}');
      all[id] = value;
      Lampa.Storage.set('clarification_search',all);
    }
    function clarificationSearchDelete(){
      var id = Lampa.Utils.hash(object.movie.number_of_seasons ? object.movie.original_name : object.movie.original_title);
      var all = Lampa.Storage.get('clarification_search','{}');
      delete all[id];
      Lampa.Storage.set('clarification_search',all);
    }
    function clarificationSearchGet(){
      var id = Lampa.Utils.hash(object.movie.number_of_seasons ? object.movie.original_name : object.movie.original_title);
      var all = Lampa.Storage.get('clarification_search','{}');
      return all[id];
    }
    var modern = Z01UI.enabled();
    var ui = {};
    var ui_items = [];
    var ui_enter = null;
    var ui_focus = '';
    var ui_tried = {};
    var ui_open = '';
    var ui_nav = false;
    var ui_page = -1;
    var ui_page_focus = -1;
    var ui_page_key = '';
    var ui_draw_params = {};
    var ui_paged = false;
    var season_pinned = false;
    var similar_list = null;
    var similar_auto = false;
    var similar_shown = false;
    var last_origin = '';
    var request_gen = 0;
    var ui_watchdog;
    var ui_load_timer;
    var ui_load_started = 0;
    var ui_load_found = 0;
    var ui_load_percent = 0;
    var ui_load_simple = false;
    this.uiFrame = function() {
      if (!ui.root) {
        ui.root = $('<div class="mo"></div>');
        ui.status = $('<div class="mo__status"></div>');
        ui.panel = $('<div class="mo__panel"></div>');
        ui.list = $('<div class="mo-list"></div>');
        ui.root.append(ui.status).append(ui.panel).append(ui.list);
      }
      if (!ui.root.parent().length) {
        scroll.clear();
        scroll.append(ui.root);
      }
      return ui.root;
    };
    this.uiWaitBox = function(title) {
      var box = $('<div class="mo-wait">' +
        '<div class="mo-wait__head"><div class="mo-wait__title"></div><div class="mo-wait__count"></div></div>' +
        '<div class="mo-wait__bar"><div class="mo-wait__fill"></div></div>' +
        '</div>');
      box.find('.mo-wait__title').text(title);
      return box;
    };
    this.uiStatusPending = function() {
      if (!ui.status) return;
      var box = ui.status.empty().removeClass('mo-head--hidden');
      if (ui_nav || !object.movie.name) return box.addClass('mo-head--hidden');
      var seasons = filter_find.season || [];
      if (!seasons.length) return box.addClass('mo-head--hidden');
      var choice = this.getChoice();
      var title = (seasons[choice.season] || seasons[0]).title || '';
      if (!title) return box.addClass('mo-head--hidden');
      var head = $('<div class="mo-head"><div class="mo-head__text"><div class="mo-head__title"></div></div></div>');
      head.find('.mo-head__title').text(title);
      box.append(head);
    };
    this.uiWaitStart = function(title, simple) {
      var _this = this;
      this.uiStatusPending();
      ui_load_started = Date.now();
      ui_load_found = 0;
      ui_load_percent = 0;
      ui_load_simple = !!simple;
      ui.load = this.uiWaitBox(title);
      ui.list.empty().append(ui.load);
      this.uiLoadingText();
      clearInterval(ui_load_timer);
      ui_load_timer = setInterval(function() {
        _this.uiLoadingText();
      }, 1000);
    };
    this.uiLoadingPanel = function() {
      this.uiFrame();
      this.uiWatch(Z01UI.WATCHDOG_FIRST);
      this.uiWaitStart(Lampa.Lang.translate('z01_loading_title'), false);
    };
    this.uiLoadingText = function() {
      if (!ui.load || !ui.load.parent().length) return this.uiLoadingStop();
      var seconds = Math.max(0, Math.round((Date.now() - ui_load_started) / 1000));
      var text = '';
      if (!ui_load_simple) {
        text = ui_load_found ?
          Lampa.Lang.translate('z01_loading_found').replace('{n}', ui_load_found) :
          Lampa.Lang.translate('z01_loading_start');
        text += ' · ';
      }
      text += seconds + Lampa.Lang.translate('z01_sec');
      if (seconds >= 12 && ui_load_percent < 100) text += ' · ' + Lampa.Lang.translate('z01_loading_slow');
      ui.load.find('.mo-wait__count').text(text);
      var percent = Math.max(ui_load_percent, Math.min(90, seconds * 7));
      ui.load.find('.mo-wait__fill').css('width', percent + '%');
    };
    this.uiLoadingProgress = function(json, times) {
      if (!ui.load || !ui.load.parent().length) return;
      var list = (json && json.online) || [];
      var found = 0;
      list.forEach(function(item) {
        if (item.show) found++;
      });
      ui_load_found = found;
      ui_load_percent = json && json.ready ? 100 : Math.min(95, Math.round((times / 15) * 100));
      this.uiWatch(Z01UI.WATCHDOG_FIRST);
      this.uiLoadingText();
    };
    this.uiLoadingStop = function() {
      clearInterval(ui_load_timer);
      ui_load_timer = null;
      ui.load = null;
    };
    this.uiWatch = function(seconds) {
      var _this = this;
      clearTimeout(ui_watchdog);
      if (!modern) return;
      ui_watchdog = setTimeout(function() {
        if (Lampa.Activity.active().activity !== _this.activity) return;
        network.clear();
        _this.doesNotAnswer({
          timeout: true
        });
      }, (seconds || Z01UI.WATCHDOG) * 1000);
    };
    this.uiWatchStop = function() {
      clearTimeout(ui_watchdog);
      ui_watchdog = null;
    };
    this.uiLoading = function() {
      this.uiFrame();
      this.uiLoadingStop();
      this.uiWatch();
      request_gen++;
      network.clear();
      clearInterval(balanser_timer);
      this.clearImages();
      this.uiWaitStart(Lampa.Lang.translate('z01_loading_list'), true);
      this.activity.loader(false);
      this.activity.toggle();
    };
    this.uiFocusTarget = function() {
      return last;
    };
    this.uiFocusRestore = function(fallback) {
      var element = false;
      if (ui_focus && ui.root) {
        var found = ui.root.find('[data-mo-focus="' + ui_focus + '"]');
        if (found.length) element = found[0];
      }
      ui_focus = '';
      if (!element && fallback) element = fallback;
      if (element) last = element;
    };
    this.uiPickResume = function(items) {
      if (!items || !items.length) return null;
      var serial = object.movie.name ? true : false;
      var viewed = Lampa.Storage.cache('online_view', 5000, []);
      var i;
      if (!serial) {
        var movie_choice = this.getChoice();
        if (movie_choice.movie_view) {
          for (i = 0; i < items.length; i++) {
            if (items[i].hash_behold == movie_choice.movie_view) return items[i];
          }
        }
        var pref = Lampa.Storage.get('z01_voice_pref', '');
        if (pref) {
          for (i = 0; i < items.length; i++) {
            if (Z01UI.voiceKind(items[i].title || items[i].text) == pref) return items[i];
          }
        }
        return items[0];
      }
      var choice = this.getChoice();
      var season = items[0].season;
      var reached = Z01UI.reached(object.movie, season);
      if (!reached) {
        var mark = choice.episodes_view ? parseInt(choice.episodes_view[season], 10) : 0;
        if (mark > reached) reached = mark;
        var history = this.watched();
        if (history && history.episode && (!history.season || history.season == season)) {
          var last_seen = parseInt(history.episode, 10) || 0;
          if (last_seen > reached) reached = last_seen;
        }
        for (i = 0; i < items.length; i++) {
          if (Z01UI.isSeen(items[i], viewed)) {
            var num = parseInt(items[i].episode, 10) || 0;
            if (num > reached) reached = num;
          }
        }
      }
      if (reached) {
        for (i = 0; i < items.length; i++) {
          if (items[i].episode == reached) {
            var line = items[i].timeline;
            if (line && line.percent > 0 && line.percent < 90) return items[i];
            for (var j = i + 1; j < items.length; j++) {
              if (!Z01UI.isSeen(items[j], viewed)) return items[j];
            }
            return items[i + 1] || items[i];
          }
        }
        var best = null;
        for (i = 0; i < items.length; i++) {
          var value = parseInt(items[i].episode, 10) || 0;
          if (value > reached && (!best || value < (parseInt(best.episode, 10) || 0))) best = items[i];
        }
        if (best) return best;
        return items[items.length - 1];
      }
      for (i = 0; i < items.length; i++) {
        if (!Z01UI.isSeen(items[i], viewed)) return items[i];
      }
      return items[0];
    };
    this.uiStatus = function(items) {
      if (!ui.status) return;
      var box = ui.status.empty().removeClass('mo-head--hidden');
      var serial = object.movie.name ? true : false;
      if (ui_nav || !items.length || !serial) return box.addClass('mo-head--hidden');
      var viewed = Lampa.Storage.cache('online_view', 5000, []);
      var seen = 0;
      var i;
      for (i = 0; i < items.length; i++) {
        if (Z01UI.isSeen(items[i], viewed)) seen++;
      }
      var title = '';
      if (serial) {
        var seasons = filter_find.season || [];
        var picked = seasons.length ? seasons[this.getChoice().season] || seasons[0] : null;
        if (picked && picked.title) title = picked.title;
        else {
          var season = items[0].season || this.seasonMemory() || 1;
          title = Lampa.Lang.translate('torrent_serial_season') + ' ' + season;
        }
      } else title = object.movie.title || object.movie.name || '';
      var note = '';
      if (serial && items.length > 1) {
        note = Lampa.Lang.translate('z01_season_progress').replace('{seen}', seen).replace('{total}', items.length);
        if (seen < items.length) note += ' · ' + Lampa.Lang.translate('z01_season_left').replace('{left}', items.length - seen);
      } else {
        var target = this.uiPickResume(items);
        var line = target && target.timeline;
        if (line && line.percent > 0 && line.duration > line.time) {
          note = Lampa.Lang.translate('z01_left') + ' ' + Lampa.Utils.secondsToTime(line.duration - line.time, true);
        }
      }
      var head = $('<div class="mo-head"><div class="mo-head__art"><img alt=""></div>' +
        '<div class="mo-head__text"><div class="mo-head__title"></div><div class="mo-head__sub"></div></div>' +
        '<div class="mo-head__note"></div></div>');
      head.find('.mo-head__title').text(title);
      head.find('.mo-head__note').text(note);
      head.find('.mo-head__art').remove();
      if (!serial && object.movie.original_title && object.movie.original_title !== title) {
        head.find('.mo-head__sub').text(object.movie.original_title);
      }
      box.append(head);
      if (serial && items.length > 1 && seen) {
        var bar = $('<div class="mo-head__bar"><div class="mo-head__fill"></div></div>');
        bar.find('.mo-head__fill').css('width', Math.round(seen / items.length * 100) + '%');
        box.append(bar);
      }
      return box;
    };
    this.uiFallbackArt = function() {
      var movie = object.movie;
      var path = function(value) {
        if (!value || value === 'undefined') return '';
        return Lampa.TMDB.image('t/p/w300' + value);
      };
      var art = path(movie.backdrop_path);
      if (!art) art = path(movie.poster_path);
      if (!art && movie.img) {
        art = movie.img;
        if (art.indexOf('http') !== 0) art = '';
      }
      if (!art) art = path(movie.img);
      return art;
    };
    this.uiSearch = function() {
      var native_search = filter.render().find('.filter--search');
      if (native_search.length) return native_search.trigger('hover:enter');
      if (Lampa.Input && Lampa.Input.edit) {
        var enabled = Lampa.Controller.enabled().name;
        Lampa.Input.edit({
          value: object.search || '',
          free: true,
          nosave: true,
          title: Lampa.Lang.translate('search')
        }, function(value) {
          Lampa.Controller.toggle(enabled);
          if (value && filter.onSearch) filter.onSearch(value);
        });
      }
    };
    this.uiRows = function() {
      var _this = this;
      var panel = ui.panel.empty();
      var bar = $('<div class="mo-panel"></div>');
      var addSeg = function(key, name, value, mark) {
        var seg = $('<div class="mo-seg selector"><div class="mo-seg__name"></div><div class="mo-seg__value"></div><div class="mo-seg__arrow"></div></div>');
        seg.attr('data-mo-focus', key);
        seg.find('.mo-seg__name').text(name);
        var box = seg.find('.mo-seg__value');
        if (mark) box.append($('<span class="mo-seg__mark"></span>').text(mark));
        box.append(document.createTextNode(value));
        if (ui_open == key) seg.addClass('mo-seg--open');
        seg.on('hover:enter', function() {
          _this.uiToggle(key);
        }).on('hover:focus', function(e) {
          last = e.target;
          scroll.update($(e.target), true);
        });
        bar.append(seg);
      };
      if (!object.balanser && sourceKeys().length && balanser) {
        var info = sources[balanser] || {};
        var parts = Z01UI.splitSourceName(info.name || balanser);
        addSeg('source', Lampa.Lang.translate('lampac_balanser'), parts.name, Z01UI.sourceBadge(balanser, parts));
      }
      var choice = this.getChoice();
      var seasons = filter_find.season || [];
      if (seasons.length > 1) {
        addSeg('season', Lampa.Lang.translate('torrent_serial_season'), (seasons[choice.season] || seasons[0]).title, '');
      }
      var voices = filter_find.voice || [];
      if (voices.length > 1) {
        addSeg('voice', Lampa.Lang.translate('torrent_parser_voice'), Z01UI.voiceLabel((voices[choice.voice] || voices[0]).title), '');
      }
      if (ui_paged) {
        var page_now = Z01UI.pageAt(Z01UI.pages(ui_items.length), ui_page > 0 ? ui_page : 0);
        addSeg('jump', Lampa.Lang.translate('z01_jump'), this.pageTitle(page_now), '');
      }
      if (similar_list && similar_list.length > 1 && !similar_shown) {
        var back = $('<div class="mo-seg selector"><div class="mo-seg__name"></div><div class="mo-seg__value"></div></div>');
        back.attr('data-mo-focus', 'variants');
        back.find('.mo-seg__name').text(Lampa.Lang.translate('z01_similar_all'));
        back.find('.mo-seg__value').text(similar_list.length);
        back.on('hover:enter', function() {
          var saved = similar_list;
          similar_auto = true;
          _this.uiSimilars(saved, true);
        }).on('hover:focus', function(e) {
          last = e.target;
          scroll.update($(e.target), true);
        });
        bar.append(back);
      }
      if (bar.children().length) panel.append(bar);
      if (ui_open == 'source' && !object.balanser) this.uiSourceRow();
      else if (ui_open == 'season') this.uiOptionRow('season');
      else if (ui_open == 'voice') this.uiOptionRow('voice');
      else if (ui_open == 'jump') this.uiJumpRow();
    };
    this.uiJumpRow = function() {
      var _this = this;
      var grid = $('<div class="mo-grid"></div>');
      Z01UI.pages(ui_items.length).forEach(function(page) {
        var opt = $('<div class="mo-opt selector"><div class="mo-opt__in"><span class="mo-opt__label"></span></div></div>');
        opt.attr('data-mo-focus', 'jump:' + page.start);
        opt.find('.mo-opt__label').text(_this.pageTitle(page));
        if (page.start === ui_page) opt.addClass('mo-opt--active');
        opt.on('hover:enter', function() {
          _this.uiShowPage(page.start, page.start);
        }).on('hover:focus', function(e) {
          last = e.target;
          scroll.update($(e.target), true);
        });
        grid.append(opt);
      });
      ui.panel.append(grid);
    };
    this.pageTitle = function(page) {
      var first = parseInt(ui_items[page.start] && ui_items[page.start].episode, 10) || page.start + 1;
      var last_num = parseInt(ui_items[page.end] && ui_items[page.end].episode, 10) || page.end + 1;
      return first == last_num ? String(first) : first + '–' + last_num;
    };
    this.uiShowPage = function(start, focus_index) {
      if (!ui_items.length) return;
      ui_open = '';
      ui_focus = '';
      ui_page = start;
      ui_page_focus = typeof focus_index === 'number' ? focus_index : start;
      this.uiDraw(ui_items, ui_draw_params);
    };
    this.sourceOrder = function(names) {
      var rank = function(name) {
        if (name == balanser) return -1;
        return (sources[name] && sources[name].show) ? 0 : 1;
      };
      var quality = function(name) {
        var info = sources[name] || {};
        return Z01UI.qualityRank(Z01UI.sourceBadge(name, Z01UI.splitSourceName(info.name || name)));
      };
      return names.map(function(name, index) {
        return {
          name: name,
          index: index
        };
      }).sort(function(a, b) {
        return (rank(a.name) - rank(b.name)) ||
          (quality(b.name) - quality(a.name)) ||
          (a.index - b.index);
      }).map(function(entry) {
        return entry.name;
      });
    };
    this.uiToggle = function(key) {
      var opening = ui_open != key;
      ui_open = opening ? key : '';
      ui_focus = key;
      if (opening) {
        var choice = this.getChoice();
        if (key == 'source' && balanser) ui_focus = 'src:' + balanser;
        else if (key == 'season') ui_focus = 'season:' + (choice.season || 0);
        else if (key == 'voice') ui_focus = 'voice:' + (choice.voice || 0);
        else if (key == 'jump') ui_focus = 'jump:' + (ui_page > 0 ? ui_page : 0);
      }
      this.uiRows();
      this.uiFocusRestore(false);
      Lampa.Controller.enable('content');
    };
    this.uiPanelFocus = function() {
      if (!modern || !ui.panel) return false;
      var seg = ui.panel.find('[data-mo-focus="source"]')[0] || ui.panel.find('.mo-seg')[0];
      if (!seg) return false;
      last = seg;
      scroll.update($(seg), true);
      Lampa.Controller.collectionFocus(seg, scroll.render());
      return true;
    };
    this.uiPanelFocused = function() {
      if (!modern || !ui.panel || !last) return false;
      return ui.panel.find(last).length > 0;
    };
    this.uiUpFallback = function() {
      if (!ui.root || !last) return false;
      if (ui.list && ui.list.find(last).length) return this.uiPanelFocus();
      return false;
    };
    this.uiOptionRow = function(type) {
      var _this = this;
      var list = filter_find[type] || [];
      var selected = this.getChoice()[type];
      var grid = $('<div class="mo-grid"></div>');
      var rows = [];
      if (type == 'voice') {
        Z01UI.voiceGroups(list).forEach(function(group) {
          group.items.forEach(function(entry) {
            rows.push({
              index: entry.index,
              title: Z01UI.voiceLabel(entry.title),
              note: group.title || ''
            });
          });
        });
      } else {
        list.forEach(function(item, index) {
          rows.push({
            index: index,
            title: item.title,
            note: ''
          });
        });
      }
      rows.forEach(function(entry) {
        var opt = $('<div class="mo-opt selector"><div class="mo-opt__in"><span class="mo-opt__label"></span><span class="mo-opt__note"></span></div></div>');
        opt.attr('data-mo-focus', type + ':' + entry.index);
        opt.find('.mo-opt__label').text(entry.title || '');
        opt.find('.mo-opt__note').text(entry.note);
        if (entry.index == selected) opt.addClass('mo-opt--active');
        opt.on('hover:enter', function() {
          _this.uiSwitch(type, entry.index);
        }).on('hover:focus', function(e) {
          last = e.target;
          scroll.update($(e.target), true);
        });
        grid.append(opt);
      });
      ui.panel.append(grid);
    };
    this.uiSwitch = function(type, index) {
      var choice = this.getChoice();
      if (choice[type] == index && ui_open) {
        ui_open = '';
        ui_focus = type;
        this.uiRows();
        this.uiFocusRestore(false);
        Lampa.Controller.enable('content');
        return;
      }
      choice[type] = index;
      if (type == 'voice') {
        var voice = filter_find.voice[index];
        if (voice) {
          choice.voice_name = voice.title;
          Lampa.Storage.set('z01_voice_pref', Z01UI.voiceKind(voice.title));
        }
      }
      if (type == 'season') {
        var season = filter_find.season[index];
        if (season) {
          var number = Z01UI.seasonNumber(season.title);
          if (number) this.seasonMemory(number);
        }
        season_pinned = true;
      }
      this.saveChoice(choice);
      ui_open = '';
      ui_focus = type;
      this.uiLoading();
      this.uiRows();
      this.find();
    };
    this.uiSourceMenu = function() {
      this.uiToggle('source');
    };
    this.uiSourceRow = function() {
      var _this = this;
      var all = sourceKeys();
      var visible = all.filter(function(name) {
        var info = sources[name] || {};
        return name == balanser || info.show || info.vip;
      });
      var grid = $('<div class="mo-grid"></div>');
      this.sourceOrder(visible).forEach(function(name) {
        var info = sources[name] || {};
        var parts = Z01UI.splitSourceName(info.name || name);
        var opt = $('<div class="mo-opt selector"><div class="mo-opt__in"><span class="mo-opt__label"></span><span class="mo-opt__note"></span></div></div>');
        opt.attr('data-mo-focus', 'src:' + name);
        var label = opt.find('.mo-opt__label');
        var tag = Z01UI.sourceBadge(name, parts);
        if (info.vip) label.append('<span class="mo-opt__tag">VIP</span>');
        else if (tag) label.append($('<span class="mo-opt__tag"></span>').text(tag));
        label.append(document.createTextNode(parts.name));
        if (name == balanser) opt.addClass('mo-opt--active');
        opt.on('hover:enter', function() {
          if (info.vip && !isZpremActive()) {
            Lampa.Noty.show('Активация тестового VIP-доступа...');
            zpremAutoEnsure(function(ok) {
              if (ok) {
                Lampa.Noty.show('VIP 48ч активирован! Перезагрузка...');
                setTimeout(function() { location.reload(); }, 1500);
              } else {
                _this.vipOffer({
                  title: info.name || name,
                  source: name
                });
              }
            });
            return;
          }
          ui_open = '';
          if (name == balanser) {
            ui_focus = 'source';
            _this.uiRows();
            _this.uiFocusRestore(false);
            Lampa.Controller.enable('content');
            return;
          }
          _this.switchSource(name);
        }).on('hover:focus', function(e) {
          last = e.target;
          scroll.update($(e.target), true);
        });
        grid.append(opt);
      });
      ui.panel.append(grid);
    };
    this.switchSource = function(name) {
      if (!sources[name]) return;
      if (!modern) {
        object.lampac_custom_select = name;
        return this.changeBalanser(name);
      }
      object.lampac_custom_select = name;
      balanser = name;
      source = sources[name].url;
      Lampa.Storage.set('online_balanser', name);
      Lampa.Storage.set('active_balanser', name);
      this.updateBalanser(name);
      filter_find = {
        season: [],
        voice: []
      };
      ui_tried[name] = true;
      ui_open = '';
      season_pinned = false;
      similar_list = null;
      similar_auto = false;
      ui_focus = 'source';
      this.uiLoading();
      this.uiRows();
      var seg = ui.panel.find('[data-mo-focus="source"]')[0];
      if (seg) last = seg;
      this.find();
      Lampa.Controller.toggle('content');
    };
    var sourceKeys = function() {
      return Object.prototype.toString.call(filter_sources) === '[object Array]' ? filter_sources : [];
    };
    var PROBE_TTL_OK = 6 * 3600 * 1000;
    var PROBE_TTL_EMPTY = 30 * 60 * 1000;
    var PROBE_PARALLEL = 2;
    var PROBE_LIMIT = 26;
    var PROBE_TIMEOUT = 7000;
    var PROBE_BUDGET = 45000;
    var probeCache = function() {
      var all = Lampa.Storage.get('z01_probe', '{}') || {};
      if (typeof all !== 'object') all = {};
      var mine = all[object.movie.id] || {};
      var now = Date.now();
      for (var key in mine) {
        var e = mine[key] || {};
        if (now - (e.t || 0) > (e.s == 'ok' ? PROBE_TTL_OK : PROBE_TTL_EMPTY)) delete mine[key];
      }
      return mine;
    };
    var probeSave = function(name, state) {
      var all = Lampa.Storage.get('z01_probe', '{}') || {};
      if (typeof all !== 'object') all = {};
      var mine = probeCache();
      mine[name] = { s: state, t: Date.now() };
      all[object.movie.id] = mine;
      var ids = Object.keys(all);
      if (ids.length > 200) ids.slice(0, ids.length - 200).forEach(function(id) { delete all[id]; });
      Lampa.Storage.set('z01_probe', all);
    };
    var probeApply = function() {
      var mine = probeCache();
      for (var name in mine) {
        if (mine[name].s == 'ok' && sources[name] && !sources[name].vip) sources[name].show = true;
      }
    };
    var probeSkip = function(name) {
      var info = sources[name];
      if (!info || info.show || info.vip || !info.url) return true;
      if (name == balanser) return true;
      return name.indexOf('alloha') === 0;
    };
    this.probeStop = function() {
      probe_busy = false;
      probe_nets.forEach(function(net) { try { net.clear(); } catch (e) {} });
      probe_nets = [];
    };
    this.probeGrey = function() {
      if (probe_started) return;
      probe_started = true;
      var cached = probeCache();
      var queue = sourceKeys().filter(function(name) {
        return !probeSkip(name) && !cached[name];
      }).slice(0, PROBE_LIMIT);
      if (!queue.length) return;
      probe_busy = true;
      var deadline = Date.now() + PROBE_BUDGET;
      var found = 0;
      var running = 0;
      var index = 0;
      var finish = function() {
        if (running || (index < queue.length && probe_busy)) return;
        probe_busy = false;
        if (found && ui_open == 'source' && ui.panel) {
          probe_self.uiRows();
          probe_self.uiFocusRestore(false);
        }
      };
      var next = function() {
        if (!probe_busy || index >= queue.length || Date.now() > deadline) {
          index = queue.length;
          return finish();
        }
        var name = queue[index++];
        if (probeSkip(name)) return next();
        var url = probe_self.requestParams(sources[name].url);
        var net = new Network();
        probe_nets.push(net);
        running++;
        var done = function(str) {
          running--;
          if (!probe_busy && !running) return finish();
          var text = typeof str === 'string' ? str : '';
          if (text.indexOf('"rch"') !== -1 || text.indexOf('"accsdb"') !== -1) {
          } else if (text.indexOf('videos__') !== -1) {
            found++;
            probeSave(name, 'ok');
            online_results_cache[url] = { time: Date.now(), text: text };
            if (sources[name]) sources[name].show = true;
          } else {
            probeSave(name, 'empty');
          }
          next();
        };
        net.timeout(PROBE_TIMEOUT);
        net["native"](account(url), done, function() { done(''); }, false, {
          dataType: 'text',
          headers: getBypassHeaders({'X-Kit-AesGcm': Lampa.Storage.get('aesgcmkey', ''), 'X-Zprem-Key': Lampa.Storage.get('zpremkey', '')})
        });
      };
      for (var w = 0; w < PROBE_PARALLEL; w++) next();
    };
    this.nextSource = function() {
      var keys = sourceKeys().filter(function(name) {
        if (!sources[name] || sources[name].vip || name === balanser || ui_tried[name]) return false;
        return sources[name].show;
      });
      if (!keys.length) return '';
      return this.sourceOrder(keys)[0];
    };
    this.uiNote = function(params) {
      this.uiFrame();
      this.uiLoadingStop();
      this.uiWatchStop();
      var note = $('<div class="mo-info"><div class="mo-info__title"></div><div class="mo-info__text"></div><div class="mo-info__acts"></div></div>');
      var noBal = function(t) { return String(t || '').replace(/\s+(?:на|on)\s+\(?\{balanser\}\)?|\s*\(?\{balanser\}\)?/g, ''); };
      note.find('.mo-info__title').text(noBal(params.title));
      note.find('.mo-info__text').html(noBal(params.text));
      var acts = note.find('.mo-info__acts');
      (params.actions || []).forEach(function(action) {
        var button = $('<div class="mo-act selector"></div>');
        if (action.icon) button.append(action.icon);
        button.append($('<span></span>').text(action.title));
        button.on('hover:enter', function() {
          action.handler();
        }).on('hover:focus', function(e) {
          last = e.target;
          scroll.update($(e.target), true);
        });
        acts.append(button);
      });
      var link = params.qr || params.link || '';
      if (link) {
        var qr = $('<div class="mo-info__qr"><img alt=""></div>');
        qr.find('img').attr('src', Z01UI.qrImage(link));
        note.find('.mo-info__text').after($('<div class="mo-info__link"></div>').text(link)).after(qr);
      }
      ui.list.empty().append(note);
      this.uiStatus([]);
      this.uiRows();
      this.loading(false);
      last = acts.find('.mo-act')[0] || false;
      Lampa.Controller.enable('content');
      return note;
    };
    this.markUpTo = function(element) {
      if (!element) return;
      var upto = parseInt(element.episode, 10) || 0;
      if (!upto) return;
      var viewed = Lampa.Storage.cache('online_view', 5000, []);
      var changed = false;
      for (var i = 0; i < ui_items.length; i++) {
        var item = ui_items[i];
        var num = parseInt(item.episode, 10) || 0;
        if (!num || !item.hash_behold) continue;
        if (num <= upto) {
          if (viewed.indexOf(item.hash_behold) === -1) {
            viewed.push(item.hash_behold);
            changed = true;
          }
        } else {
          if (viewed.indexOf(item.hash_behold) !== -1) {
            Lampa.Arrays.remove(viewed, item.hash_behold);
            Lampa.Storage.remove('online_view', item.hash_behold);
            changed = true;
          }
          var line = item.timeline;
          if (line && (line.percent || line.time)) {
            line.percent = 0;
            line.time = 0;
            line.duration = 0;
            Lampa.Timeline.update(line);
          }
        }
      }
      if (changed) Lampa.Storage.set('online_view', viewed);
      Z01UI.setReach(object.movie, element.season, upto);
      var choice = this.getChoice();
      if (element.season) choice.episodes_view[element.season] = upto;
      this.saveChoice(choice);
      this.uiRefreshMarks();
    };
    this.uiDraw = function(items, params) {
      var _this = this;
      params = params || {};
      if (!items.length) return this.empty();
      this.uiFrame();
      this.uiLoadingStop();
      this.uiWatchStop();
      ui_items = items;
      ui_draw_params = params;
      ui_enter = params.onEnter;
      similar_shown = false;
      if (!params.similars) Z01UI.rememberQuality(balanser, Z01UI.bestQuality(items));
      var serial = object.movie.name ? true : false;
      var title_count = {};
      items.forEach(function(item) {
        var text = item.text || item.title || '';
        title_count[text] = (title_count[text] || 0) + 1;
      });
      var looksEpisode = function(text) {
        return /сери|episode|эпізод|эпизод/i.test(String(text || '')) || /^\s*\d+\s*$/.test(String(text || ''));
      };
      ui_nav = items.length > 1 && items.every(function(item) {
        var text = item.text || item.title || '';
        if (Z01UI.isSeasonLabel(text)) return true;
        return serial && typeof item.episode === 'undefined' && !looksEpisode(text);
      });
      var draw_gen = request_gen;
      this.getEpisodes(items[0].season, function(episodes) {
        if (draw_gen !== request_gen) return;
        var viewed = Lampa.Storage.cache('online_view', 5000, []);
        var choice = _this.getChoice();
        var fully = window.innerWidth > 580;
        var list = ui.list.empty();
        if (serial && !ui_nav) list.addClass('mo-tiles');
        else list.removeClass('mo-tiles');
        var focus_element = false;
        var focus_mark = false;
        var resume = _this.uiPickResume(items);
        if (resume && !ui_nav) _this.prefetchFileUrl(resume);
        if (serial && items[0] && items[0].season) {
          var shown_season = parseInt(items[0].season);
          var wanted_season = _this.seasonMemory();
          if (shown_season && (!wanted_season || shown_season == wanted_season || _this.seasonIndexByMemory() >= 0)) {
            _this.seasonMemory(shown_season);
          }
        }
        ui_paged = serial && !ui_nav && !params.similars && items.length > Z01UI.JUMP_FROM;
        var page_start = 0;
        var page_end = items.length - 1;
        var page_key = balanser + ':' + (items[0].season || '');
        if (page_key !== ui_page_key) {
          ui_page_key = page_key;
          ui_page = -1;
        }
        if (ui_paged) {
          var pages = Z01UI.pages(items.length);
          var page;
          if (ui_page < 0 || ui_page >= items.length) {
            var want = resume;
            if (object.lampac_continue_episode) {
              want = arrFind(items, function(el) {
                return el.episode == object.lampac_continue_episode;
              }) || want;
            }
            var want_at = Math.max(0, items.indexOf(want));
            page = Z01UI.pageAt(pages, want_at);
          } else page = Z01UI.pageAt(pages, ui_page);
          ui_page = page.start;
          page_start = page.start;
          page_end = page.end;
        } else ui_page = 0;
        items.forEach(function(element, index) {
          var on_page = !ui_paged || (index >= page_start && index <= page_end);
          var episode = serial && episodes.length && !params.similars ? arrFind(episodes, function(e) {
            return e.episode_number == element.episode;
          }) : false;
          var episode_num = element.episode || index + 1;
          var voice_name = (!serial && (element.voice_name || element.text)) ||
            choice.voice_name || (filter_find.voice[0] ? filter_find.voice[0].title : false) ||
            element.voice_name || (serial ? Lampa.Lang.translate('z01_unknown') : element.text) ||
            Lampa.Lang.translate('z01_unknown');
          if (element.quality) {
            element.qualitys = element.quality;
            element.quality = Lampa.Arrays.getKeys(element.quality)[0];
          }
          element.voice_name = voice_name;
          var runtime = episode ? episode.runtime : object.movie.runtime;
          element.time = runtime ? Lampa.Utils.secondsToTime(runtime * 60, true) : '';
          var hash_timeline = Lampa.Utils.hash(element.season ? [element.season, element.season > 10 ? ':' : '', element.episode, object.movie.original_title].join('') : object.movie.original_title);
          var hash_behold = Lampa.Utils.hash(element.season ? [element.season, element.season > 10 ? ':' : '', element.episode, object.movie.original_title, element.voice_name].join('') : object.movie.original_title + element.voice_name);
          element.hash_behold = hash_behold;
          element.hash_timeline = hash_timeline;
          element.timeline = Lampa.Timeline.view(hash_timeline, Lampa.Timeline.link ? Lampa.Timeline.link(object.movie, element.season, element.episode) : null);
          if (element.season) {
            element.translate_episode_end = _this.getLastEpisode(items);
            element.translate_voice = element.voice_name;
          }
          var data = {
            hash_timeline: hash_timeline,
            hash_behold: hash_behold
          };
          var title = (episode ? episode.name : (element.text || element.title)) || object.movie.title || object.movie.name || '';
          element.title = title;
          var meta = [];
          if (episode && episode.vote_average) meta.push('★ ' + parseFloat(episode.vote_average + '').toFixed(1));
          if (episode && episode.air_date && fully) meta.push(Lampa.Utils.parseTime(episode.air_date).full);
          else if (!episode && object.movie.release_date && fully && serial) meta.push(Lampa.Utils.parseTime(object.movie.release_date).full);
          if (!serial && !ui_nav && voice_name && voice_name !== title && voice_name !== Lampa.Lang.translate('z01_unknown')) meta.push(Z01UI.voiceLabel(voice_name));
          element.__meta_base = meta.slice();
          element.__own_line = !ui_nav && (serial || choice.movie_view === hash_behold);
          var seen_line = element.timeline;
          if (element.__own_line && seen_line && seen_line.percent > 0 && seen_line.duration > seen_line.time) {
            meta.push(Lampa.Lang.translate('z01_left') + ' ' + Lampa.Utils.secondsToTime(seen_line.duration - seen_line.time, true));
          }
          var tile = serial && !ui_nav;
          var html;
          if (tile) {
            html = $('<div class="mo-tile selector">' +
              '<div class="mo-tile__art"><img alt=""><div class="mo-tile__num"></div><div class="mo-tile__line"></div></div>' +
              '<div class="mo-tile__body"><div class="mo-tile__title"></div><div class="mo-tile__meta"></div></div>' +
              '</div>');
            html.find('.mo-tile__title').text(title);
            html.find('.mo-tile__meta').html(meta.map(function(part) {
              return '<span>' + Z01UI.esc(part) + '</span>';
            }).join(''));
            html.find('.mo-tile__num').text(Z01UI.episodeNumber(episode_num));
            var art_box = html.find('.mo-tile__art');
            var badge = Z01UI.shortQuality(element.quality);
            if (badge) art_box.append($('<div class="mo-tile__tag"></div>').text(badge));
            if (element.time)