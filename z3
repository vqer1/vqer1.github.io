(function() {
  'use strict';

  // ===== СИСТЕМА ЛИЦЕНЗИРОВАНИЯ (ОФЛАЙН) =====
  var LIC_SALT = "Z01_SALT_2026_SHORT";

  function licHash(s) {
    var h = 5381;
    for (var i = 0; i < s.length; i++) {
      h = ((h << 5) + h) + s.charCodeAt(i);
      h = h & h;
    }
    return Math.abs(h).toString(16).toUpperCase();
  }

  // Неизменный 6-значный ID устройства клиента
  function getMyDeviceId() {
    var id = Lampa.Storage.get('z01_my_dev_id', '');
    if (!id) {
      id = Lampa.Utils.uid(6).toUpperCase();
      Lampa.Storage.set('z01_my_dev_id', id);
    }
    return id;
  }

  // Проверка короткого ключа: ГГММДД-ХХХХ
  function verifyLicense() {
    var key = (Lampa.Storage.get('z01_license_key', '') || '').trim().toUpperCase();
    if (!key) return { active: false, msg: 'Ключ не введен' };

    var match = key.match(/^(\d{2})(\d{2})(\d{2})-([A-F0-9]{4})$/);
    if (!match) return { active: false, msg: 'Неверный формат ключа' };

    var datePart = match[1] + match[2] + match[3];
    var signPart = match[4];
    var myDev = getMyDeviceId();

    var expectedSign = ('0000' + licHash(myDev + datePart + LIC_SALT)).slice(-4);
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
        '<div style="font-size:1.6em;font-weight:bold;color:#7cc4ff;background:rgba(255,255,255,0.08);padding:10px;border-radius:8px;margin-bottom:1.2em;letter-spacing:2px;user-select:all;">' + devId + '</div>' +
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
  // ==========================================

  // ===== ES5 Polyfills =====
  if (!Array.prototype.find) {
    Array.prototype.find = function(callback, thisArg) {
      for (var i = 0; i < this.length; i++) {
        if (callback.call(thisArg, this[i], i, this)) return this[i];
      }
      return undefined;
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
  // ===== /ES5 Polyfills =====

  var Z01_SERVERS = ['http://s1.z01.online/', 'http://s2.z01.online/', 'http://s3.z01.online/'];
  var Z01_FALLBACK = 'http://z01.online/';

  var Defined = {
    api: 'lampac',
    localhost: 'http://z01.online/',
    apn: ''
  };

  var ZPREM_SERVER = (Lampa.Utils && Lampa.Utils.protocol ? Lampa.Utils.protocol() : 'http://') + 'prem.z01.online/';
  var ZPREM_TRIAL_URL = (Lampa.Utils && Lampa.Utils.protocol ? Lampa.Utils.protocol() : 'http://') + 'oplata.z01.online/trial.php';

  // Внутренний сброс демо z01 (НИКАК не трогает z01_my_dev_id и z01_license_key)
  function resetZ01Uid() {
    var u = Lampa.Utils.uid(8).toLowerCase();
    Lampa.Storage.set('lampac_unic_id', u);
    return u;
  }

  function getZ01Email() {
    var trialEmail = Lampa.Storage.get('z01_trial_email', '');
    if (trialEmail) return trialEmail;
    var u = Lampa.Storage.get('lampac_unic_id', '') || resetZ01Uid();
    var email = 'z01_' + u + '@gmail.com';
    Lampa.Storage.set('z01_trial_email', email);
    return email;
  }

  function rotateZ01TrialEmail() {
    var newEmail = 'z01_' + Lampa.Utils.uid(8).toLowerCase() + '@gmail.com';
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
    if (!email || !uid) { if (callback) callback(false); return; }

    var net = new Lampa.Reguest();
    net.timeout(10000);

    function sendReq(e, u, attempts) {
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
            if (callback) callback(true);
          } else if (resp.status === 'already_used' && attempts < 3) {
            sendReq(rotateZ01TrialEmail(), resetZ01Uid(), attempts + 1);
          } else {
            if (callback) callback(false);
          }
        } catch(err) { if (callback) callback(false); }
      }, function() { if (callback) callback(false); });
    }

    sendReq(email, uid, 0);
  }

  function zpremAutoEnsure(callback) {
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

  var hostkey = 'https://z01.online'.replace('http://', '').replace('https://', '');

  if (!window.rch_nws || !window.rch_nws[hostkey]) {
    if (!window.rch_nws) window.rch_nws = {};
    window.rch_nws[hostkey] = {
      type: Lampa.Platform.is('android') ? 'apk' : Lampa.Platform.is('tizen') ? 'cors' : undefined,
      startTypeInvoke: false,
      rchRegistry: false,
      apkVersion: 0
    };
  }

  window.rch_nws[hostkey].typeInvoke = function(host, call) { call(); };
  window.rch_nws[hostkey].Registry = function(client, startConnection) {
    if (startConnection) startConnection();
  };

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
    var filter_sources = [];
    var filter_find = { season: [], voice: [] };

    this.initialize = function() {
      var _this = this;
      this.loading(true);
      filter.onBack = function() { _this.start(); };
      filter.onSelect = function(type, a, b) {
        if (type == 'sort') {
          Lampa.Select.close();
          _this.switchSource(a.source);
        }
        if (type == 'filter') {
          var url = filter_find[a.stype][b.index].url;
          _this.reset();
          _this.request(url);
          setTimeout(Lampa.Select.close, 10);
        }
      };

      scroll.body().addClass('torrent-list');
      files.appendFiles(scroll.render());
      files.appendHead(filter.render());
      scroll.minus(files.render().find('.explorer__files-head'));
      Lampa.Controller.enable('content');
      this.loading(false);

      this.createSource().then(function() {
        _this.search();
      })['catch'](function() {
        _this.empty();
      });
    };

    this.switchSource = function(name) {
      if (!sources[name]) return;
      balanser = name;
      source = sources[name].url;
      this.reset();
      this.find();
    };

    this.requestParams = function(url) {
      var query = ['id=' + encodeURIComponent(object.movie.id)];
      if (object.movie.imdb_id) query.push('imdb_id=' + object.movie.imdb_id);
      if (object.movie.kinopoisk_id) query.push('kinopoisk_id=' + object.movie.kinopoisk_id);
      query.push('title=' + encodeURIComponent(object.movie.title || object.movie.name));
      query.push('serial=' + (object.movie.name ? 1 : 0));
      query.push('cub_id=' + Lampa.Utils.hash(getZ01Email()));
      return url + (url.indexOf('?') >= 0 ? '&' : '?') + query.join('&');
    };

    this.createSource = function() {
      var _this = this;
      return new Promise(function(resolve, reject) {
        var url = _this.requestParams(Defined.localhost + 'lite/events?life=true');
        network.timeout(15000);
        network.silent(account(url), function(json) {
          json.forEach(function(j) {
            var n = (j.balanser || j.name.split(' ')[0]).toLowerCase();
            sources[n] = { url: j.url, name: j.name, show: j.show };
          });
          filter_sources = Lampa.Arrays.getKeys(sources);
          ['Filmix 4K VIP', 'HDRezka 4K VIP', 'KinoPub 4K VIP', 'Alloha 4K VIP'].forEach(function(n) {
            var k = 'vip_' + n.toLowerCase().replace(/\s/g, '_');
            if (!sources[k]) {
              sources[k] = { name: n + ' [VIP]', url: '', show: true, vip: true };
              filter_sources.push(k);
            }
          });
          if (filter_sources.length) {
            balanser = filter_sources[0];
            source = sources[balanser].url;
            resolve();
          } else reject();
        }, reject, false, {
          headers: {'X-Kit-AesGcm': Lampa.Storage.get('aesgcmkey', ''), 'X-Zprem-Key': Lampa.Storage.get('zpremkey', '')}
        });
      });
    };

    this.create = function() { return this.render(); };
    this.search = function() {
      filter.set('sort', filter_sources.map(function(e) {
        return { title: sources[e].name, source: e, selected: e == balanser };
      }));
      this.find();
    };
    this.find = function() { this.request(this.requestParams(source)); };
    this.request = function(url) {
      var _this = this;
      network.timeout(20000);
      network['native'](account(url), function(str) { _this.parse(str); }, function() { _this.empty(); }, false, {
        dataType: 'text',
        headers: {'X-Kit-AesGcm': Lampa.Storage.get('aesgcmkey', ''), 'X-Zprem-Key': Lampa.Storage.get('zpremkey', '')}
      });
    };

    this.parse = function(str) {
      var _this = this;
      try {
        var html = $('<div>' + str + '</div>');
        var items = [];
        html.find('.videos__item').each(function() {
          var data = JSON.parse($(this).attr('data-json') || '{}');
          data.text = $(this).text();
          items.push(data);
        });

        var buttons = [];
        html.find('.videos__button').each(function() {
          var item = $(this);
          buttons.push({ text: item.text(), url: item.attr('href') || item.attr('data-url') });
        });

        if (buttons.length) {
          filter_find.voice = buttons.map(function(b) { return { title: b.text, url: b.url }; });
          filter.set('filter', [{ title: 'Перевод', stype: 'voice', items: filter_find.voice }]);
        }

        var videos = items.filter(function(v) { return v.method == 'play' || v.method == 'call'; });
        if (videos.length) {
          this.draw(videos);
        } else if (items.length && items[0].url) {
          this.request(items[0].url);
        } else {
          this.empty();
        }
      } catch(e) { this.empty(); }
    };

    this.draw = function(items) {
      var _this = this;
      scroll.clear();
      items.forEach(function(el) {
        var row = $('<div class="online-prestige online-prestige--full selector" style="padding:1.1em;margin-bottom:0.4em;background:rgba(255,255,255,0.06);border-radius:6px;cursor:pointer;">' +
          '<div style="font-size:1.2em;">' + (el.text || el.title || 'Видео') + '</div>' +
        '</div>');
        row.on('hover:enter click', function() {
          requireLicense(function() {
            Lampa.Loading.start(function() { Lampa.Loading.stop(); });
            network['native'](account(el.url), function(json) {
              Lampa.Loading.stop();
              if (json && json.url) {
                Lampa.Player.play({ title: el.title || el.text, url: json.url, isonline: true });
              } else {
                Lampa.Noty.show('Ссылка недоступна');
              }
            }, function() {
              Lampa.Loading.stop();
              Lampa.Noty.show('Ошибка соединения');
            });
          });
        }).on('hover:focus', function(e) {
          last = e.target;
          scroll.update($(e.target), true);
        });
        scroll.append(row);
      });
      Lampa.Controller.enable('content');
    };

    this.empty = function() {
      scroll.clear();
      scroll.append('<div style="padding:3em;text-align:center;font-size:1.2em;opacity:0.6;">Ничего не найдено</div>');
      this.loading(false);
    };
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
      version: '2.0.0',
      name: 'Z01',
      description: 'Онлайн просмотр',
      component: 'lampac_z',
      onContextMenu: function() { return { name: 'Смотреть онлайн', description: 'Z01' }; },
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

    // ===== НАСТРОЙКИ (БЕЗ TYPE: INPUT, ПОЛНОСТЬЮ БЕЗОПАСНО) =====
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
        var devId = getMyDeviceId();
        item.find('.settings-param__name,.settings-param-title__text').text('ID вашего ТВ: ' + devId);
      }
    });

    Lampa.SettingsApi.addParam({
      component: 'z01_premium',
      param: { name: 'z01_lic_status', type: 'title', default: true },
      field: { name: '...' },
      onRender: function(item) {
        var lic = verifyLicense();
        var txt = lic.active ? ('● Подписка активна (до ' + lic.date + ', ' + lic.days + ' дн.)') : ('○ Статус: ' + lic.msg);
        item.find('.settings-param__name,.settings-param-title__text').text(txt);
      }
    });

    // Корректный ввод ключа через нативную экранную клавиатуру Lampa
    Lampa.SettingsApi.addParam({
      component: 'z01_premium',
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
          title: 'Код активации (11 символов)',
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
  }

  // Автопроверка при старте
  if (verifyLicense().active) {
    zpremAutoEnsure();
  }

  if (!window.lampac_z_plugin) startPlugin();
})();
