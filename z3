(function() {
  'use strict';

  // ===== СИСТЕМА ОФЛАЙН ЛИЦЕНЗИРОВАНИЯ =====
  var SECRET_SALT = "Z01_OFFLINE_SECRET_SALT_2026";

  function simpleHash(str) {
    var hash = 5381;
    for (var i = 0; i < str.length; i++) {
      hash = ((hash << 5) + hash) + str.charCodeAt(i);
      hash = hash & hash;
    }
    return Math.abs(hash).toString(16).toUpperCase();
  }

  function getClientDeviceId() {
    var dev = Lampa.Storage.get('z01_client_device_id', '');
    if (!dev) {
      dev = 'Z01-' + Lampa.Utils.uid(8).toUpperCase();
      Lampa.Storage.set('z01_client_device_id', dev);
    }
    return dev;
  }

  function verifyLicense() {
    var key = (Lampa.Storage.get('z01_license_key', '') || '').trim();
    if (!key) return { active: false, msg: 'Ключ активации не введен' };

    try {
      var decoded = atob(key);
      var parts = decoded.split('|');
      if (parts.length !== 3) return { active: false, msg: 'Неверный формат ключа' };

      var keyDevId = parts[0];
      var expTime = parseInt(parts[1], 10);
      var sign = parts[2];

      var myDevId = getClientDeviceId();
      if (keyDevId !== myDevId) {
        return { active: false, msg: 'Ключ выписан для другого устройства' };
      }

      var expectedSign = simpleHash(keyDevId + "|" + expTime + "|" + SECRET_SALT);
      if (sign !== expectedSign) {
        return { active: false, msg: 'Недействительная цифровая подпись' };
      }

      if (Date.now() > expTime) {
        return { active: false, msg: 'Срок действия ключа истек' };
      }

      var daysLeft = Math.ceil((expTime - Date.now()) / 86400000);
      var expDateStr = new Date(expTime).toISOString().slice(0, 10);
      return { active: true, days: daysLeft, date: expDateStr };
    } catch(e) {
      return { active: false, msg: 'Ошибка расшифровки ключа' };
    }
  }

  function requireLicense(callback) {
    var lic = verifyLicense();
    if (lic.active) {
      if (callback) callback();
    } else {
      var devId = getClientDeviceId();
      var modalHtml = $('<div style="padding:1.5em;text-align:center;">' +
        '<div style="font-size:1.4em;margin-bottom:0.5em;color:#e74c3c;">🔒 Требуется активация плагина</div>' +
        '<div style="font-size:1em;opacity:0.8;margin-bottom:1em;">' + lic.msg + '</div>' +
        '<div style="font-size:0.9em;opacity:0.6;margin-bottom:0.4em;">Ваш уникальный ID устройства:</div>' +
        '<div style="font-size:1.3em;font-weight:bold;color:#7cc4ff;background:rgba(255,255,255,0.08);padding:8px;border-radius:6px;margin-bottom:1.2em;user-select:all;">' + devId + '</div>' +
        '<div style="font-size:0.85em;opacity:0.7;">Отправьте этот ID администратору для получения ключа подписки, затем введите ключ в Настройки &rarr; Z01 Premium.</div>' +
      '</div>');
      Lampa.Modal.open({
        title: 'Активация',
        html: modalHtml,
        onBack: function() {
          Lampa.Modal.close();
          Lampa.Controller.toggle('content');
        }
      });
    }
  }
  // ==========================================

  // ===== ES5 polyfills for old devices =====
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
    Array.prototype.includes = function(val) { return this.indexOf(val) !== -1; };
  }
  if (!String.prototype.includes) {
    String.prototype.includes = function(val) { return this.indexOf(val) !== -1; };
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
    window.Promise.prototype['catch'] = function(onRejected) { return this.then(null, onRejected); };
    window.Promise.resolve = function(val) { return new Promise(function(r) { r(val); }); };
    window.Promise.reject = function(val) { return new Promise(function(_, r) { r(val); }); };
  }
  // ===== /ES5 polyfills =====

  var Z01_SERVERS = ['http://s1.z01.online/', 'http://s2.z01.online/', 'http://s3.z01.online/'];
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
      xhr.onload = function() { finish(xhr.status >= 200 && xhr.status < 400); };
      xhr.onerror = function() { finish(false); };
      xhr.ontimeout = function() { finish(false); };
      xhr.send();
    } catch (e) { finish(false); }
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
        if (ok) callback(candidates[index]);
        else tryNext(index + 1);
      });
    }
    tryNext(0);
  }

  var Defined = {
    api: 'lampac',
    localhost: 'http://z01.online/',
    apn: ''
  };

  var Z01_FREE = Z01_FALLBACK;
  z01PickServer(function(server) {
    Z01_FREE = server;
    if (Defined.localhost === Z01_FALLBACK) Defined.localhost = server;
  });

  var ZPREM_SERVER = (Lampa.Utils && Lampa.Utils.protocol ? Lampa.Utils.protocol() : 'http://') + 'prem.z01.online/';
  var ZPREM_CHECK_URL = (Lampa.Utils && Lampa.Utils.protocol ? Lampa.Utils.protocol() : 'http://') + 'oplata.z01.online/check.php';
  var ZPREM_TRIAL_URL = (Lampa.Utils && Lampa.Utils.protocol ? Lampa.Utils.protocol() : 'http://') + 'oplata.z01.online/trial.php';

  var zprem_dropped = false;
  function zpremDrop(er) {
    if (zprem_dropped || !er || !er.accsdb || Defined.localhost !== ZPREM_SERVER) return false;
    zprem_dropped = true;
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

  // ===== UID & TRIAL AUTO-RESET =====
  var unic_id = Lampa.Storage.get('lampac_unic_id', '');
  if (!unic_id) {
    unic_id = Lampa.Utils.uid(8).toLowerCase();
    Lampa.Storage.set('lampac_unic_id', unic_id);
  }

  function resetZ01Uid() {
    unic_id = Lampa.Utils.uid(8).toLowerCase();
    Lampa.Storage.set('lampac_unic_id', unic_id);
    return unic_id;
  }

  function getZ01Email() {
    var trialEmail = Lampa.Storage.get('z01_trial_email', '');
    if (trialEmail) return trialEmail;
    var email = Lampa.Storage.get('account_email', '');
    if (!email) {
      email = 'z01_' + (Lampa.Storage.get('lampac_unic_id', '') || Lampa.Utils.uid(8).toLowerCase()) + '@gmail.com';
      Lampa.Storage.set('z01_trial_email', email);
    }
    return email;
  }

  function rotateZ01TrialEmail() {
    var base = Lampa.Storage.get('account_email', '');
    var newEmail = '';
    if (base && base.indexOf('@') !== -1) {
      var parts = base.split('@');
      var name = parts[0].split('+')[0];
      newEmail = name + '+z' + Lampa.Utils.uid(5).toLowerCase() + '@' + parts[1];
    } else {
      newEmail = 'z01_' + Lampa.Utils.uid(8).toLowerCase() + '@gmail.com';
    }
    Lampa.Storage.set('z01_trial_email', newEmail);
    return newEmail;
  }

  function zpremResetTrial() {
    Lampa.Storage.set('zpremkey', '');
    Lampa.Storage.set('zprem_expires', '');
    Lampa.Storage.set('zprem_trial_used', '');
    resetZ01Uid();
    rotateZ01TrialEmail();
  }

  function isZpremActive() {
    var key = Lampa.Storage.get('zpremkey', '');
    var exp = Lampa.Storage.get('zprem_expires', '');
    return !!(key && exp && (new Date(exp).getTime() - Date.now() > 0));
  }

  function zpremTrial(callback) {
    if (!isZpremActive()) zpremResetTrial();
    var email = getZ01Email();
    var uid = Lampa.Storage.get('lampac_unic_id', '');
    if (!email || !uid) { if (callback) callback(false, 'no_data'); return; }

    var net = new Lampa.Reguest();
    net.timeout(10000);

    function sendTrialRequest(e, u, attempts) {
      attempts = attempts || 0;
      net.silent(ZPREM_TRIAL_URL + '?email=' + encodeURIComponent(e) + '&uid=' + encodeURIComponent(u), function(resp) {
        try {
          if (typeof resp === 'string') resp = JSON.parse(resp);
          if (resp.status === 'activated' && resp.zpremkey) {
            Lampa.Storage.set('zpremkey', resp.zpremkey);
            Lampa.Storage.set('zprem_expires', resp.expires_at);
            if (resp.prem_url) Lampa.Storage.set('online_url', resp.prem_url);
            Lampa.Storage.set('zprem_trial_used', '1');
            Defined.localhost = ZPREM_SERVER;
            if (callback) callback(true, 'activated');
          } else if (resp.status === 'already_used' && attempts < 3) {
            var nextEmail = rotateZ01TrialEmail();
            var nextUid = resetZ01Uid();
            sendTrialRequest(nextEmail, nextUid, attempts + 1);
          } else {
            if (callback) callback(false, resp.status || 'error');
          }
        } catch(err) { if (callback) callback(false, 'parse_error'); }
      }, function() {
        if (callback) callback(false, 'network_error');
      });
    }

    sendTrialRequest(email, uid, 0);
  }

  function zpremAutoEnsure(callback) {
    // Демо сбрасывается и выдается, только если ваш офлайн-ключ подлинный
    if (!verifyLicense().active) {
      if (callback) callback(false);
      return;
    }
    if (isZpremActive()) {
      Defined.localhost = ZPREM_SERVER;
      if (callback) callback(true);
      return;
    }
    zpremTrial(function(ok) {
      if (ok) Defined.localhost = ZPREM_SERVER;
      if (callback) callback(ok);
    });
  }

  function zpremActivate() {
    if (verifyLicense().active) {
      if (isZpremActive()) Defined.localhost = ZPREM_SERVER;
      else zpremAutoEnsure();
    }
  }
  // ==========================================

  function getAndroidVersion() {
    if (Lampa.Platform.is('android')) {
      try {
        var current = AndroidJS.appVersion().split('-');
        return parseInt(current.pop());
      } catch (e) { return 0; }
    }
    return 0;
  }

  var hostkey = 'https://z01.online'.replace('http://', '').replace('https://', '');

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
        net.silent('https://z01.online'.indexOf(location.host) >= 0 ? 'https://github.com/' : host + '/cors/check', function() {
          check(true);
        }, function() {
          check(false);
        }, false, { dataType: 'text' });
      }
    } else call();
  };

  window.rch_nws[hostkey].Registry = function RchRegistry(client, startConnection) {
    window.rch_nws[hostkey].typeInvoke('https://z01.online', function() {
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
        var rchOrigin = (client && client.url) ? client.url.replace(/^ws(s?):\/\/([^\/?#]+).*/, 'http$1://$2') : 'https://z01.online';

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
            error: function() { client.invoke("RchResult", rchId, ''); }
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
            new Response(compressedStream).arrayBuffer().then(function(compressedBuffer) {
              var compressedArray = new Uint8Array(compressedBuffer);
              if (compressedArray.length > html.length) {
                sendResult('result', html);
              } else {
                sendResult('gzresult', new Blob([compressedArray], { type: 'application/octet-stream' }));
              }
            })['catch'](function() { sendResult('result', html); });
          } else {
            sendResult('result', html);
          }
        }

        if (url == 'eval') result(eval(data));
        else if (url == 'evalrun') eval(data);
        else if (url == 'ping') result('pong');
        else {
          network["native"](url, result, function(e) { result(''); }, data, {
            dataType: 'text',
            timeout: 1000 * 8,
            headers: headers,
            returnHeaders: returnHeaders
          });
        }
      });

      client.on('Connected', function(connectionId) { window.rch_nws[hostkey].connectionId = connectionId; });
      client.on('Closed', function() {});
      client.on('Error', function(err) {});
    });
  };
  window.rch_nws[hostkey].typeInvoke('https://z01.online', function() {});

  function rchInvoke(json, call) {
    if (window.nwsClient && window.nwsClient[hostkey] && window.nwsClient[hostkey]._shouldReconnect){
      call();
      return;
    }
    if (!window.nwsClient) window.nwsClient = {};
    if (window.nwsClient[hostkey] && window.nwsClient[hostkey].socket) window.nwsClient[hostkey].socket.close();
    window.nwsClient[hostkey] = new NativeWsClient(json.nws, { autoReconnect: false });
    window.nwsClient[hostkey].on('Connected', function(connectionId) {
      window.rch_nws[hostkey].Registry(window.nwsClient[hostkey], function() { call(); });
    });
    window.nwsClient[hostkey].connect();
  }

  function rchRun(json, call) {
    if (typeof NativeWsClient == 'undefined') {
      Lampa.Utils.putScript(["https://z01.online/js/nws-client-es5.js?v03022026"], function() {}, false, function() {
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

  var Network = Lampa.Reguest;

  function component(object) {
    var network = new Network();
    var scroll = new Lampa.Scroll({ mask: true, over: true });
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
    var filter_sources = {};
    var filter_find = { season: [], voice: [] };

    if (balansers_with_search == undefined) {
      network.timeout(10000);
      network.silent(account('https://z01.online/lite/withsearch'), function(json) {
        balansers_with_search = json;
      }, function() { balansers_with_search = []; });
    }

    function balanserName(j) {
      var bals = j.balanser;
      var name = j.name.split(' ')[0];
      return (bals || name).toLowerCase();
    }

    this.initialize = function() {
      var _this = this;
      this.loading(true);
      filter.onSearch = function(value) {
        Lampa.Activity.replace({ search: value, clarification: true, similar: true });
      };
      filter.onBack = function() { _this.start(); };
      filter.render().find('.selector').on('hover:enter', function() { clearInterval(balanser_timer); });
      filter.render().find('.filter--search').appendTo(filter.render().find('.torrent-filter'));
      filter.onSelect = function(type, a, b) {
        if (type == 'sort' && sources[a.source] && sources[a.source].vip && !isZpremActive()) {
          Lampa.Select.close();
          zpremAutoEnsure(function(ok) {
            if (ok) _this.switchSource(a.source);
            else requireLicense();
          });
          return;
        }
        if (type == 'filter') {
          if (a.reset) {
            _this.replaceChoice({ season: 0, voice: 0, voice_url: '', voice_name: '' });
            setTimeout(function() {
              Lampa.Select.close();
              Lampa.Activity.replace({ clarification: 0, similar: 0 });
            }, 10);
          } else {
            var url = filter_find[a.stype][b.index].url;
            var choice = _this.getChoice();
            if (a.stype == 'voice') {
              choice.voice_name = filter_find.voice[b.index].title;
              choice.voice_url = url;
            }
            choice[a.stype] = b.index;
            _this.saveChoice(choice);
            _this.reset();
            _this.request(url);
            setTimeout(Lampa.Select.close, 10);
          }
        } else if (type == 'sort') {
          Lampa.Select.close();
          _this.switchSource(a.source);
        }
      };
      if (filter.addButtonBack) filter.addButtonBack();
      filter.render().find('.filter--sort span').text(Lampa.Lang.translate('lampac_balanser'));
      scroll.body().addClass('torrent-list');
      files.appendFiles(scroll.render());
      files.appendHead(filter.render());
      scroll.minus(files.render().find('.explorer__files-head'));
      scroll.body().append(Lampa.Template.get('lampac_content_loading'));
      Lampa.Controller.enable('content');
      this.loading(false);
      
      var askServer = function() {
        return _this.createSource().then(function(json) {
          _this.search();
        })["catch"](function(e) {
          if (zpremDrop(e)) return askServer();
          _this.noConnectToServer(e);
        });
      };
      this.externalids().then(askServer);
    };

    this.rch = function(json, noreset) {
      var _this2 = this;
      rchRun(json, function() {
        if (!noreset) _this2.find();
        else noreset();
      });
    };

    this.externalids = function() {
      return new Promise(function(resolve) {
        if (!object.movie.imdb_id || !object.movie.kinopoisk_id) {
          var query = ['id=' + encodeURIComponent(object.movie.id), 'serial=' + (object.movie.name ? 1 : 0)];
          if (object.movie.imdb_id) query.push('imdb_id=' + object.movie.imdb_id);
          if (object.movie.kinopoisk_id) query.push('kinopoisk_id=' + object.movie.kinopoisk_id);
          var url = Defined.localhost + 'externalids?' + query.join('&');
          network.timeout(10000);
          network.silent(account(url), function(json) {
            for (var name in json) object.movie[name] = json[name];
            resolve();
          }, function() { resolve(); }, false, {
            headers: {'X-Kit-AesGcm': Lampa.Storage.get('aesgcmkey', ''), 'X-Zprem-Key': Lampa.Storage.get('zpremkey', '')}
          });
        } else resolve();
      });
    };

    this.switchSource = function(name) {
      if (!sources[name]) return;
      balanser = name;
      source = sources[name].url;
      Lampa.Storage.set('online_balanser', name);
      this.reset();
      this.find();
    };

    this.requestParams = function(url) {
      var query = ['id=' + encodeURIComponent(object.movie.id)];
      if (object.movie.imdb_id) query.push('imdb_id=' + object.movie.imdb_id);
      if (object.movie.kinopoisk_id) query.push('kinopoisk_id=' + object.movie.kinopoisk_id);
      query.push('title=' + encodeURIComponent(object.movie.title || object.movie.name));
      query.push('serial=' + (object.movie.name ? 1 : 0));
      var emailParam = getZ01Email();
      if (emailParam) query.push('cub_id=' + Lampa.Utils.hash(emailParam));
      return url + (url.indexOf('?') >= 0 ? '&' : '?') + query.join('&');
    };

    this.startSource = function(json) {
      var _this = this;
      return new Promise(function(resolve, reject) {
        json.forEach(function(j) {
          var name = balanserName(j);
          sources[name] = { url: j.url, name: j.name, show: typeof j.show == 'undefined' ? true : j.show };
        });
        filter_sources = Lampa.Arrays.getKeys(sources);
        ['Filmix 4K VIP','HDRezka 4K VIP','KinoPub 4K VIP','Alloha 4K VIP'].forEach(function(n){ 
          var k = 'vip_' + n.toLowerCase().replace(/\s/g,'_'); 
          if(!sources[k]) { sources[k] = { name: n, url: '', show: false, vip: true }; filter_sources.push(k); } 
        });
        if (filter_sources.length) {
          balanser = filter_sources[0];
          source = sources[balanser].url;
          resolve(json);
        } else reject();
      });
    };

    this.createSource = function() {
      var _this = this;
      return new Promise(function(resolve, reject) {
        var url = _this.requestParams(Defined.localhost + 'lite/events?life=true');
        network.timeout(15000);
        network.silent(account(url), function(json) {
          _this.startSource(json).then(resolve)["catch"](reject);
        }, reject, false, {
          headers: {'X-Kit-AesGcm': Lampa.Storage.get('aesgcmkey', ''), 'X-Zprem-Key': Lampa.Storage.get('zpremkey', '')}
        });
      });
    };

    this.create = function() { return this.render(); };
    this.search = function() {
      this.filter({ source: filter_sources }, this.getChoice());
      this.find();
    };
    this.find = function() { this.request(this.requestParams(source)); };
    this.request = function(url) {
      var _this = this;
      number_of_requests++;
      if (number_of_requests < 10) {
        network.timeout(20000);
        network["native"](account(url), function(str) { _this.parse(str); }, function(er) { _this.doesNotAnswer(er); }, false, {
          dataType: 'text',
          headers: {'X-Kit-AesGcm': Lampa.Storage.get('aesgcmkey', ''), 'X-Zprem-Key': Lampa.Storage.get('zpremkey', '')}
        });
        clearTimeout(number_of_requests_timer);
        number_of_requests_timer = setTimeout(function() { number_of_requests = 0; }, 4000);
      } else this.empty();
    };

    this.parseJsonDate = function(str, name) {
      try {
        var html = $('<div>' + str + '</div>');
        var elems = [];
        html.find(name).each(function() {
          var item = $(this);
          var data = JSON.parse(item.attr('data-json'));
          if (item.attr('s')) data.season = parseInt(item.attr('s'));
          if (item.attr('e')) data.episode = parseInt(item.attr('e'));
          data.text = item.text();
          data.active = item.hasClass('active');
          elems.push(data);
        });
        return elems;
      } catch(e) { return []; }
    };

    this.getFileUrl = function(file, call) {
      var _this = this;
      Lampa.Loading.start(function() {
        Lampa.Loading.stop();
        Lampa.Controller.toggle('content');
        network.clear();
      });
      network["native"](account(file.url), function(json) {
        Lampa.Loading.stop();
        if (json.rch) {
          _this.rch(json, function() { _this.getFileUrl(file, call); });
        } else {
          call(json, json);
        }
      }, function() {
        Lampa.Loading.stop();
        call(false, {});
      }, false, {
        headers: {'X-Kit-AesGcm': Lampa.Storage.get('aesgcmkey', ''), 'X-Zprem-Key': Lampa.Storage.get('zpremkey', '')}
      });
    };

    this.display = function(videos) {
      var _this = this;
      this.draw(videos, {
        onEnter: function(item) {
          _this.getFileUrl(item, function(json, json_call) {
            if (json && json.url) {
              var element = {
                title: item.title || item.text,
                url: json.url,
                headers: json_call.headers || json.headers,
                isonline: true
              };
              Lampa.Player.play(element);
            } else {
              Lampa.Noty.show('Не удалось извлечь ссылку');
            }
          });
        }
      });
    };

    this.parse = function(str) {
      var json = Lampa.Arrays.decodeJson(str, {});
      if (json.rch) return this.rch(json);
      try {
        var items = this.parseJsonDate(str, '.videos__item');
        var buttons = this.parseJsonDate(str, '.videos__button');
        var videos = items.filter(function(v) { return v.method == 'play' || v.method == 'call'; });
        if (videos.length) {
          this.display(videos);
        } else if (items.length && items[0].url) {
          this.request(items[0].url);
        } else {
          this.empty();
        }
      } catch(e) { this.doesNotAnswer(e); }
    };

    this.getChoice = function() { return { season: 0, voice: 0 }; };
    this.saveChoice = function() {};
    this.replaceChoice = function() {};
    this.reset = function() {
      scroll.clear();
      scroll.body().append(Lampa.Template.get('lampac_content_loading'));
    };
    this.loading = function(status) {
      if (status) this.activity.loader(true);
      else {
        this.activity.loader(false);
        this.activity.toggle();
      }
    };
    this.filter = function(filter_items) {
      filter.set('sort', filter_sources.map(function(e) {
        return { title: sources[e].name, source: e, selected: e == balanser };
      }));
    };
    this.draw = function(items, params) {
      var _this = this;
      scroll.clear();
      items.forEach(function(element) {
        var html = $('<div class="online-prestige online-prestige--full selector" style="padding:1em;margin-bottom:0.5em;background:rgba(255,255,255,0.05);border-radius:6px;cursor:pointer;">' +
          '<div style="font-size:1.2em;">' + (element.text || element.title) + '</div>' +
        '</div>');
        html.on('hover:enter click', function() {
          if (params.onEnter) params.onEnter(element);
        }).on('hover:focus', function(e) {
          last = e.target;
          scroll.update($(e.target), true);
        });
        scroll.append(html);
      });
      Lampa.Controller.enable('content');
    };
    this.empty = function() {
      scroll.clear();
      scroll.append('<div style="padding:2em;text-align:center;font-size:1.3em;opacity:0.6;">Ничего не найдено</div>');
      this.loading(false);
    };
    this.noConnectToServer = function() { this.empty(); };
    this.doesNotAnswer = function() { this.empty(); };
    this.start = function() {
      if (!initialized) { initialized = true; this.initialize(); }
      Lampa.Controller.add('content', {
        toggle: function() {
          Lampa.Controller.collectionSet(scroll.render(), files.render());
          Lampa.Controller.collectionFocus(last || false, scroll.render());
        },
        up: function() { Navigator.move('up'); },
        down: function() { Navigator.move('down'); },
        right: function() { Navigator.move('right'); },
        left: function() { Navigator.move('left'); },
        back: this.back.bind(this)
      });
      Lampa.Controller.toggle('content');
    };
    this.render = function() { return files.render(); };
    this.back = function() { Lampa.Activity.backward(); };
    this.pause = function() {};
    this.stop = function() {};
    this.destroy = function() { network.clear(); scroll.destroy(); };
  }

  function startPlugin() {
    window.lampac_z_plugin = true;
    var manifst = {
      type: 'video',
      version: '1.2.0',
      name: 'Z01 Private',
      description: 'Онлайн кинотеатр с VIP-доступом',
      component: 'lampac_z',
      onContextMenu: function() { return { name: 'Смотреть онлайн', description: 'VIP источники' }; },
      onContextLauch: function(object) {
        requireLicense(function() {
          Lampa.Component.add('lampac_z', component);
          Lampa.Activity.push({
            url: '',
            title: 'Онлайн',
            component: 'lampac_z',
            movie: object,
            page: 1
          });
        });
      }
    };
    Lampa.Manifest.plugins = manifst;

    var button = "<div class=\"full-start__button selector view--online lampac--button\"><svg width=\"128\" height=\"128\" viewBox=\"0 0 128 128\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\"><rect x=\"8\" y=\"8\" width=\"112\" height=\"112\" rx=\"32\" fill=\"white\" stroke=\"#2886fb\" stroke-width=\"12\"/><path d=\"M38 36h52L38 92h52\" stroke=\"#2886fb\" stroke-width=\"12\" stroke-linecap=\"round\" stroke-linejoin=\"round\" fill=\"none\"/></svg><span>Онлайн</span></div>";

    function addButton(e) {
      if (e.render.find('.lampac--button').length) return;
      var btn = $(button);
      btn.on('hover:enter click', function() {
        requireLicense(function() {
          Lampa.Component.add('lampac_z', component);
          Lampa.Activity.push({
            url: '',
            title: 'Онлайн',
            component: 'lampac_z',
            movie: e.movie,
            page: 1
          });
        });
      });
      e.render.after(btn);
    }

    Lampa.Listener.follow('full', function(e) {
      if (e.type == 'complite') {
        addButton({ render: e.object.activity.render().find('.view--torrent'), movie: e.data.movie });
      }
    });

    // ===== НАСТРОЙКИ ЛИЦЕНЗИИ В МЕНЮ LAMPA =====
    Lampa.SettingsApi.addComponent({
      component: 'z01_premium',
      icon: '<svg width="36" height="36" viewBox="0 0 128 128" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="8" y="8" width="112" height="112" rx="32" fill="none" stroke="white" stroke-width="12"/><path d="M38 36h52L38 92h52" stroke="white" stroke-width="12" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg>',
      name: 'Z01 Лицензия'
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_premium',
      param: { name: 'z01_devid_view', type: 'title', default: true },
      field: { name: '...' },
      onRender: function(item) {
        var devId = getClientDeviceId();
        item.find('.settings-param__name,.settings-param-title__text').text('Ваш ID устройства: ' + devId);
      }
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_premium',
      param: { name: 'z01_lic_status', type: 'title', default: true },
      field: { name: '...' },
      onRender: function(item) {
        var lic = verifyLicense();
        var txt = lic.active ? ('● Подписка активна (осталось ' + lic.days + ' дн., до ' + lic.date + ')') : ('○ Статус: ' + lic.msg);
        item.find('.settings-param__name,.settings-param-title__text').text(txt);
      }
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_premium',
      param: { name: 'z01_license_input', type: 'input', default: '' },
      field: {
        name: 'Ключ активации',
        description: 'Вставьте полученный лицензионный код'
      },
      onRender: function(item) {
        var key = Lampa.Storage.get('z01_license_key', '');
        if (key) item.find('.settings-param__descr').text('Ключ сохранен в памяти');
      },
      onChange: function(val) {
        Lampa.Storage.set('z01_license_key', (val || '').trim());
        var lic = verifyLicense();
        if (lic.active) {
          Lampa.Noty.show('Лицензия активирована до ' + lic.date + '!');
          zpremAutoEnsure();
        } else {
          Lampa.Noty.show('Ошибка ключа: ' + lic.msg);
        }
        try { Lampa.Settings.update(); } catch(e) {}
      }
    });
  }

  // Фоновая пред-активация демо при наличии валидного ключа
  zpremActivate();

  if (!window.lampac_z_plugin) startPlugin();
})();
