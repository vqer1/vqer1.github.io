(function () {
    'use strict';

    // База сопоставления раздач
    window._lampa_torrents_list = window._lampa_torrents_list || [];
    window._lampa_intercept_copy = false;

    function cleanStr(s) {
      if (!s) return '';
      return (s + '').toLowerCase().replace(/[^a-zа-я0-9]/gi, '');
    }

    function saveToCache(title, tracker, size, link, hash, rawObj) {
      var magnet = link || '';
      if ((!magnet || magnet.indexOf('magnet:') !== 0) && hash) {
        magnet = 'magnet:?xt=urn:btih:' + hash + (title ? '&dn=' + encodeURIComponent(title) : '');
      }
      if (!magnet) magnet = link;
      if (!magnet) return;

      var entry = {
        title: (title || '').trim(),
        titleClean: cleanStr(title),
        tracker: (tracker || '').toLowerCase().trim(),
        size: size,
        magnet: magnet,
        hash: hash,
        raw: rawObj
      };

      var exists = window._lampa_torrents_list.some(function (t) {
        return t.magnet === entry.magnet;
      });

      if (!exists) {
        window._lampa_torrents_list.push(entry);
      }
    }

    function extractFromObject(obj) {
      if (!obj) return;
      if (Array.isArray(obj)) {
        obj.forEach(extractFromObject);
        return;
      }
      if (typeof obj === 'object') {
        var link = obj.MagnetUri || obj.Link || obj.magnet || obj.link || '';
        var hash = obj.InfoHash || obj.info_hash || obj.Hash || obj.hash || '';
        var title = obj.Title || obj.title || '';

        if (link || hash) {
          saveToCache(title, obj.Tracker || obj.tracker, obj.Size || obj.size, link, hash, obj);
        }

        for (var k in obj) {
          if (Array.isArray(obj[k])) {
            obj[k].forEach(extractFromObject);
          }
        }
      }
    }

    // --- 1. Глобальный перехват сетевых ответов JacRed / Jackett (XHR + Fetch) ---
    (function interceptNetwork() {
      if (window._lampa_net_intercepted) return;
      window._lampa_net_intercepted = true;

      var origXHRSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.send = function () {
        this.addEventListener('load', function () {
          try {
            var txt = this.responseText;
            if (txt && (txt.indexOf('magnet:') !== -1 || txt.indexOf('MagnetUri') !== -1 || txt.indexOf('InfoHash') !== -1 || txt.indexOf('btih') !== -1)) {
              var json = JSON.parse(txt);
              extractFromObject(json);
            }
          } catch (e) {}
        });
        return origXHRSend.apply(this, arguments);
      };

      if (window.fetch) {
        var origFetch = window.fetch;
        window.fetch = function () {
          return origFetch.apply(this, arguments).then(function (res) {
            try {
              var clone = res.clone();
              clone.text().then(function (txt) {
                if (txt && (txt.indexOf('magnet:') !== -1 || txt.indexOf('MagnetUri') !== -1 || txt.indexOf('InfoHash') !== -1 || txt.indexOf('btih') !== -1)) {
                  extractFromObject(JSON.parse(txt));
                }
              }).catch(function () {});
            } catch (e) {}
            return res;
          });
        };
      }
    })();

    // --- 2. Поиск magnet по элементу раздачи ---
    function findMagnetForElement(elem) {
      var $el = $(elem);
      if ($el.data('magnet_url')) return $el.data('magnet_url');

      var text = $el.text();
      var cleanElemText = cleanStr(text);
      var list = window._lampa_torrents_list;

      // Поиск по полному совпадению очищенного названия
      for (var i = 0; i < list.length; i++) {
        if (list[i].titleClean && cleanElemText.indexOf(list[i].titleClean) !== -1) {
          $el.data('magnet_url', list[i].magnet);
          return list[i].magnet;
        }
      }

      // Поиск по первым 15 символам названия
      for (var j = 0; j < list.length; j++) {
        if (list[j].titleClean && list[j].titleClean.length >= 10) {
          var prefix = list[j].titleClean.slice(0, 15);
          if (cleanElemText.indexOf(prefix) !== -1) {
            $el.data('magnet_url', list[j].magnet);
            return list[j].magnet;
          }
        }
      }

      // Сопоставление по порядковому номеру на экране
      var allRows = $('.torrent-item');
      var idx = allRows.index($el);
      if (idx !== -1 && list[idx] && list[idx].magnet) {
        return list[idx].magnet;
      }

      return null;
    }

    // --- 3. Буфер обмена ---
    function copyToClipboard(text) {
      if (!text) {
        Lampa.Noty.show('Ссылка не найдена');
        return;
      }

      function onOk() {
        Lampa.Noty.show('🧲 Magnet скопирован в буфер!');
      }

      function onFail(val) {
        if (Lampa.Modal) {
          Lampa.Modal.open({
            title: 'Magnet-ссылка',
            html: $('<div style="padding: 1.2em;"><p style="font-size: 13px; margin-bottom: 8px;">Выделите и скопируйте (Ctrl+C):</p><input type="text" id="lampa_copy_field" style="width: 100%; padding: 8px; background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.3); color: #fff; border-radius: 4px;" value="' + val.replace(/"/g, '&quot;') + '" /></div>'),
            size: 'medium',
            onBack: function () { Lampa.Modal.close(); }
          });
          setTimeout(function () {
            var inp = document.getElementById('lampa_copy_field');
            if (inp) { inp.focus(); inp.select(); }
          }, 100);
        } else {
          window.prompt('Скопируйте magnet-ссылку:', val);
        }
      }

      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(onOk).catch(function () {
          fallbackCopy(text, onOk, onFail);
        });
      } else {
        fallbackCopy(text, onOk, onFail);
      }
    }

    function fallbackCopy(text, onOk, onFail) {
      try {
        var ta = document.createElement('textarea');
        ta.value = text;
        ta.style.position = 'fixed';
        ta.style.left = '-9999px';
        document.body.appendChild(ta);
        ta.focus();
        ta.select();
        var ok = document.execCommand('copy');
        document.body.removeChild(ta);
        if (ok) onOk();
        else onFail(text);
      } catch (e) {
        onFail(text);
      }
    }

    // --- 4. Перехватчик TorrServer (гарантированное извлечение ссылки) ---
    function hookTorrServer() {
      if (!window.Lampa || !Lampa.Torrserver || Lampa.Torrserver._magnet_hooked) return;
      Lampa.Torrserver._magnet_hooked = true;

      for (var key in Lampa.Torrserver) {
        if (typeof Lampa.Torrserver[key] === 'function') {
          (function (methodName, origFn) {
            Lampa.Torrserver[methodName] = function () {
              var foundTorrent = null;

              for (var i = 0; i < arguments.length; i++) {
                var a = arguments[i];
                if (a && typeof a === 'object') {
                  if (a.MagnetUri || a.Link || a.magnet || a.link || a.hash || a.InfoHash) {
                    foundTorrent = a;
                    extractFromObject(a);
                  }
                }
              }

              if (window._lampa_intercept_copy) {
                window._lampa_intercept_copy = false;

                if (foundTorrent) {
                  var magnetLink = foundTorrent.MagnetUri || foundTorrent.magnet || foundTorrent.Link || foundTorrent.link || '';
                  var h = foundTorrent.hash || foundTorrent.Hash || foundTorrent.InfoHash || '';
                  if (!magnetLink && h) {
                    magnetLink = 'magnet:?xt=urn:btih:' + h + (foundTorrent.Title ? '&dn=' + encodeURIComponent(foundTorrent.Title) : '');
                  }

                  if (magnetLink) {
                    copyToClipboard(magnetLink);
                    return; // Блокируем показ ошибки подключения TorrServer
                  }
                }
              }

              return origFn.apply(this, arguments);
            };
          })(key, Lampa.Torrserver[key]);
        }
      }
    }

    function triggerCopy(row) {
      var $row = $(row);
      var magnet = findMagnetForElement($row);

      if (magnet) {
        copyToClipboard(magnet);
        return;
      }

      // Если в сетевом кеше не нашлось — опрашиваем строку через клик
      hookTorrServer();
      window._lampa_intercept_copy = true;
      $row.trigger('hover:enter');

      setTimeout(function () {
        if (window._lampa_intercept_copy) {
          window._lampa_intercept_copy = false;
          copyToClipboard(findMagnetForElement($row));
        }
      }, 400);
    }

    // --- 5. Встраивание пункта в меню «Действие» (ПКМ) ---
    if (window.Lampa && Lampa.Select && !Lampa.Select._action_magnet_hooked) {
      Lampa.Select._action_magnet_hooked = true;
      var origSelectShow = Lampa.Select.show;

      Lampa.Select.show = function (params) {
        if (params && Array.isArray(params.items)) {
          var isTorrentAction = params.items.some(function (it) {
            var str = (it.title || '') + ' ' + (it.subtitle || '');
            return str.indexOf('торрент') !== -1 || str.indexOf('раздач') !== -1;
          });

          if (isTorrentAction) {
            var activeRow = window._lampa_last_context_row || $('.torrent-item.focus, .torrent-item:hover').first();

            params.items.unshift({
              title: '🧲 Скопировать Magnet-ссылку',
              subtitle: 'Скопировать раздачу в буфер обмена',
              magnet_copy_action: true,
              row: activeRow
            });

            var origOnSelect = params.onSelect;
            params.onSelect = function (selected) {
              if (selected.magnet_copy_action) {
                triggerCopy(selected.row);
                if (Lampa.Controller) Lampa.Controller.toggle('content');
                return;
              }
              if (origOnSelect) origOnSelect.apply(this, arguments);
            };
          }
        }
        return origSelectShow.apply(this, arguments);
      };
    }

    document.addEventListener('contextmenu', function (e) {
      var row = e.target.closest('.torrent-item');
      if (row) window._lampa_last_context_row = row;
    }, true);

    // --- 6. Наблюдатель за появлением карточек раздач на экране ---
    var domObserver = new MutationObserver(function () {
      hookTorrServer();

      $('.torrent-item').each(function () {
        var row = $(this);
        if (row.find('.torrent-item__magnet-btn').length) return;

        var details = row.find('.torrent-item__details');
        if (!details.length) return;

        var btn = $(
          '<span class="torrent-item__detail torrent-item__magnet-btn" style="' +
            'cursor: pointer; color: #fff; background: rgba(255, 255, 255, 0.22); ' +
            'padding: 2px 8px; border-radius: 4px; font-weight: bold; margin-left: 8px;' +
          '" title="Скопировать magnet">🧲 Magnet</span>'
        );

        btn.on('mouseenter', function () { $(this).css('background', 'rgba(255, 255, 255, 0.45)'); });
        btn.on('mouseleave', function () { $(this).css('background', 'rgba(255, 255, 255, 0.22)'); });

        btn.on('click', function (e) {
          e.preventDefault();
          e.stopPropagation();
          triggerCopy(row);
        });

        details.append(btn);
      });
    });

    domObserver.observe(document.body, { childList: true, subtree: true });

    // --- 7. Оригинальная логика Jackett / JacRed ByLampa ---
    function startPlugin() {
      function add() {
        function button_click(data) {
          var year = ((data.movie.first_air_date || data.movie.release_date || '0000') + '').slice(0, 4);
          var combinations = {
            'df': data.movie.original_title,
            'df_year': data.movie.original_title + ' ' + year,
            'df_lg': data.movie.original_title + ' ' + data.movie.title,
            'df_lg_year': data.movie.original_title + ' ' + data.movie.title + ' ' + year,
            'lg': data.movie.title,
            'lg_year': data.movie.title + ' ' + year,
            'lg_df': data.movie.title + ' ' + data.movie.original_title,
            'lg_df_year': data.movie.title + ' ' + data.movie.original_title + ' ' + year
          };
          Lampa.Activity.push({
            url: '',
            title: Lampa.Lang.translate('title_torrents') + ' ...',
            component: 'torrents',
            search: combinations[Lampa.Storage.field('parse_lang')],
            search_one: data.movie.title,
            search_two: data.movie.original_title,
            movie: data.movie,
            page: 1
          });
        }

        Lampa.Listener.follow('full', function (e) {
          if (e.type == 'complite') {
            var button = '<div class="full-start__button view---torrent">' +
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="50px" height="50px">' +
              '<path d="M25,2C12.317,2,2,12.317,2,25s10.317,23,23,23s23-10.317,23-23S37.683,2,25,2z M40.5,30.963c-3.1,0-4.9-2.4-4.9-2.4 S34.1,35,27,35c-1.4,0-3.6-0.837-3.6-0.837l4.17,9.643C26.727,43.92,25.874,44,25,44c-2.157,0-4.222-0.377-6.155-1.039L9.237,16.851 c0,0-0.7-1.2,0.4-1.5c1.1-0.3,5.4-1.2,5.4-1.2s1.475-0.494,1.8,0.5c0.5,1.3,4.063,11.112,4.063,11.112S22.6,29,27.4,29 c4.7,0,5.9-3.437,5.7-3.937c-1.2-3-4.993-11.862-4.993-11.862s-0.6-1.1,0.8-1.4c1.4-0.3,3.8-0.7,3.8-0.7s1.105-0.163,1.6,0.8 c0.738,1.437,5.193,11.262,5.193,11.262s1.1,2.9,3.3,2.9c0.464,0,0.834-0.046,1.152-0.104c-0.082,1.635-0.348,3.221-0.817,4.722 C42.541,30.867,41.756,30.963,40.5,30.963z" fill="currentColor"/>' +
              '</svg>' +
              '<span>#{full_torrents} ...</span></div>';

            var btn = $(Lampa.Lang.translate(button));
            btn.on('hover:enter', function () {
              var jackett_default = {
                'ru.jac.black': '1',
                'jac.black': '1',
                'jac.red': '1',
                'jac-red.ru': '1',
                'ru.jacred.stream': 'pp',
                'jacred.stream': 'pp',
                'jr.maxvol.pro': '1',
                'jacred.freebie.tom.ru': '1'
              };
              var jackett = {
                jackett_url: Lampa.Storage.field('jackett_url'),
                jackett_key: Lampa.Storage.field('jackett_key'),
                jackett_interview: Lampa.Storage.field('jackett_interview'),
                jackett_url_pva: Lampa.Storage.get('jackett_url_pva', Lampa.Arrays.getKeys(jackett_default).join(';')),
                jackett_key_pva: Lampa.Storage.get('jackett_key_pva', Lampa.Arrays.getValues(jackett_default).join(';')),
                items: []
              };

              function cleanTitle(title) {
                return title.replace(/https?:\/\//, '').replace(/^#/, '').replace(/:\d+$/, '').replace(/^api\./, '').replace(/jacred.viewbox.dev/, 'viewbox.dev').replace(/jacred.freebie.tom.ru/, 'freebie.tom.ru');
              }

              jackett.jackett_url_pva.split(';').forEach(function (item) {
                jackett.items.push({
                  title: cleanTitle(item),
                  jackett_url: item.toLowerCase().indexOf('#') == 0 ? item.slice(1) : item,
                  jackett_key: '',
                  interview: item.toLowerCase().indexOf('#') == 0 ? 'all' : 'healthy',
                  selected: false
                });
              });

              var i = 0;
              jackett.jackett_key_pva.split(';').forEach(function (item) {
                if (jackett.items[i]) jackett.items[i++].jackett_key = item;
              });

              Lampa.Select.show({
                title: Lampa.Lang.translate('settings_parser_use'),
                items: jackett.items,
                onSelect: function (b) {
                  try {
                    Lampa.Storage.set('jackett_url', b.jackett_url);
                    Lampa.Storage.set('jackett_key', b.jackett_key);
                    Lampa.Storage.set('jackett_interview', b.interview);
                    button_click(e.data);
                  } finally {
                    Lampa.Storage.set('jackett_url', jackett.jackett_url);
                    Lampa.Storage.set('jackett_key', jackett.jackett_key);
                  }
                },
                onBack: function () {
                  Lampa.Controller.toggle('content');
                }
              });
            });

            if (e.data && e.object) {
              e.object.activity.render().find('.view--torrent').last().after(btn);
            }
          }
        });

        Lampa.SettingsApi.addParam({
          component: 'parser',
          param: {
            name: 'jackett_url_pva',
            type: 'input',
            value: '',
            default: ''
          },
          field: {
            name: Lampa.Lang.translate('settings_parser_jackett_link') + ' ...',
            description: Lampa.Lang.translate('settings_parser_jackett_link_descr') + ' ...<br>jacred.xyz;jacred.ru;#jackett:9117<br># - поиск по всем трекерам'
          }
        });

        Lampa.SettingsApi.addParam({
          component: 'parser',
          param: {
            name: 'jackett_key_pva',
            type: 'input',
            value: '',
            default: ''
          },
          field: {
            name: Lampa.Lang.translate('settings_parser_jackett_key') + ' ...',
            description: Lampa.Lang.translate('settings_parser_jackett_key_descr') + ' ...<br>;;jackettkey'
          }
        });

        Lampa.Params.select('jackett_url_pva', '', '');
        Lampa.Params.select('jackett_key_pva', '', '');
        Lampa.Settings.main().update();
      }

      if (window.appready) add();
      else {
        Lampa.Listener.follow('app', function (e) {
          if (e.type == 'ready') add();
        });
      }
    }

    startPlugin();
})();
