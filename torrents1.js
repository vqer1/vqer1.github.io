(function () {
    'use strict';

    // Глобальное хранилище найденных раздач
    window._lampa_captured_torrents = window._lampa_captured_torrents || [];
    window._lampa_last_torrent = null;

    function saveTorrentData(obj) {
      if (!obj) return;
      if (Array.isArray(obj)) {
        obj.forEach(saveTorrentData);
        return;
      }
      if (obj.MagnetUri || obj.Link || obj.hash || obj.InfoHash || obj.magnet) {
        // Проверка на дубликат по хэшу или ссылке
        var exists = window._lampa_captured_torrents.some(function (t) {
          return (t.hash && t.hash === obj.hash) || (t.Title && t.Title === obj.Title);
        });
        if (!exists) {
          window._lampa_captured_torrents.push(obj);
        }
      }
    }

    function extractMagnet(data) {
      if (!data) return '';
      if (typeof data === 'string' && data.indexOf('magnet:') === 0) return data;
      if (data.MagnetUri && data.MagnetUri.indexOf('magnet:') === 0) return data.MagnetUri;
      if (data.magnet && data.magnet.indexOf('magnet:') === 0) return data.magnet;
      if (data.Link && data.Link.indexOf('magnet:') === 0) return data.Link;
      if (data.link && data.link.indexOf('magnet:') === 0) return data.link;

      var hash = data.hash || data.Hash || data.info_hash || data.InfoHash;
      if (hash) {
        var title = data.title || data.Title || '';
        return 'magnet:?xt=urn:btih:' + hash + (title ? '&dn=' + encodeURIComponent(title) : '');
      }
      return data.MagnetUri || data.Link || '';
    }

    function copyToClipboard(text) {
      if (!text) {
        Lampa.Noty.show('Ссылка не найдена');
        return;
      }

      function onDone() {
        Lampa.Noty.show('🧲 Magnet скопирован в буфер!');
      }

      function onFallback() {
        if (Lampa.Modal) {
          Lampa.Modal.open({
            title: 'Magnet-ссылка',
            html: $('<div style="padding: 1.2em;"><p style="font-size: 13px; margin-bottom: 8px;">Выделите и скопируйте вручную (Ctrl+C):</p><input type="text" id="lampa_copy_val" readonly style="width: 100%; padding: 8px; background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.3); color: #fff; border-radius: 4px;" value="' + text.replace(/"/g, '&quot;') + '" /></div>'),
            size: 'medium',
            onBack: function () { Lampa.Modal.close(); }
          });
          setTimeout(function () {
            var input = document.getElementById('lampa_copy_val');
            if (input) { input.focus(); input.select(); }
          }, 100);
        } else {
          window.prompt('Скопируйте magnet-ссылку:', text);
        }
      }

      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(onDone).catch(onFallback);
      } else {
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
          if (ok) onDone();
          else onFallback();
        } catch (e) {
          onFallback();
        }
      }
    }

    function findTorrentByNode(node) {
      if (!node) return window._lampa_last_torrent;
      var text = $(node).text().toLowerCase();

      for (var i = 0; i < window._lampa_captured_torrents.length; i++) {
        var item = window._lampa_captured_torrents[i];
        var title = (item.Title || item.title || '').toLowerCase().trim();
        if (title && (text.indexOf(title.slice(0, 18)) !== -1 || title.indexOf(text.slice(0, 18)) !== -1)) {
          return item;
        }
      }
      return window._lampa_last_torrent;
    }

    // 1. Перехват отправки в TorrServer (Скриншот 2)
    if (window.Lampa && Lampa.Torrserver) {
      ['stream', 'connect', 'play'].forEach(function (method) {
        if (typeof Lampa.Torrserver[method] === 'function') {
          var orig_method = Lampa.Torrserver[method];
          Lampa.Torrserver[method] = function (torrent) {
            if (torrent) {
              window._lampa_last_torrent = torrent;
              saveTorrentData(torrent);
            }
            return orig_method.apply(this, arguments);
          };
        }
      });
    }

    // 2. Перехват выдачи парсеров Lampa
    if (window.Lampa && Lampa.Parser && !Lampa.Parser._magnet_hooked) {
      Lampa.Parser._magnet_hooked = true;
      var orig_parser_get = Lampa.Parser.get;
      Lampa.Parser.get = function (params, complite, error) {
        return orig_parser_get.call(this, params, function (results) {
          if (Array.isArray(results)) {
            saveTorrentData(results);
          }
          complite(results);
        }, error);
      };
    }

    // 3. Добавление пункта в меню «Действие» (Скриншот 1)
    if (window.Lampa && Lampa.Select && !Lampa.Select._magnet_hooked) {
      Lampa.Select._magnet_hooked = true;
      var orig_select_show = Lampa.Select.show;

      Lampa.Select.show = function (params) {
        if (params && Array.isArray(params.items)) {
          var isTorrentAction = params.items.some(function (it) {
            var t = (it.title || '') + (it.subtitle || '');
            return t.indexOf('торрент') !== -1 || t.indexOf('раздач') !== -1;
          });

          if (isTorrentAction) {
            var focused = Lampa.Navigator ? Lampa.Navigator.focused() : null;
            var targetTorrent = findTorrentByNode(focused) || window._lampa_last_torrent;
            var magnetLink = extractMagnet(targetTorrent);

            if (magnetLink) {
              params.items.unshift({
                title: '🧲 Скопировать Magnet-ссылку',
                subtitle: 'Скопировать раздачу в буфер обмена',
                magnet_action: true
              });

              var orig_onSelect = params.onSelect;
              params.onSelect = function (selected) {
                if (selected.magnet_action) {
                  copyToClipboard(magnetLink);
                  if (Lampa.Controller) Lampa.Controller.toggle('content');
                  return;
                }
                if (orig_onSelect) orig_onSelect.apply(this, arguments);
              };
            }
          }
        }
        return orig_select_show.apply(this, arguments);
      };
    }

    // 4. Встраивание кнопки копирования в окно ошибки TorrServer (Скриншот 2)
    if (window.Lampa && Lampa.Modal && !Lampa.Modal._magnet_hooked) {
      Lampa.Modal._magnet_hooked = true;
      var orig_modal_open = Lampa.Modal.open;

      Lampa.Modal.open = function (data) {
        if (data && data.title && data.title.indexOf('подключения') !== -1) {
          var magnet = extractMagnet(window._lampa_last_torrent);
          if (magnet && data.html) {
            var btnHtml = $(
              '<div class="simple-button selector" style="' +
                'margin: 15px 0 5px; background: #e50914; color: #fff; font-weight: bold; ' +
                'text-align: center; padding: 12px; border-radius: 6px; cursor: pointer;' +
              '">🧲 Скопировать Magnet этой раздачи</div>'
            );

            btnHtml.on('click', function () {
              copyToClipboard(magnet);
            });

            data.html.find('.modal__content, div').first().prepend(btnHtml);
          }
        }
        return orig_modal_open.apply(this, arguments);
      };
    }

    // 5. Постоянный наблюдатель DOM для отрисовки кнопки [🧲 Magnet] в списке
    var domObserver = new MutationObserver(function () {
      $('.torrent-item').each(function () {
        var row = $(this);
        if (row.data('has_magnet_btn')) return;
        row.data('has_magnet_btn', true);

        var details = row.find('.torrent-item__details');
        if (!details.length) return;

        var magnetBtn = $(
          '<span class="torrent-item__detail" style="' +
            'cursor: pointer; color: #fff; background: rgba(255,255,255,0.18); ' +
            'padding: 2px 7px; border-radius: 4px; font-weight: bold; margin-left: 8px;' +
          '" title="Скопировать magnet">🧲 Magnet</span>'
        );

        magnetBtn.on('mouseenter', function () { $(this).css('background', 'rgba(255,255,255,0.35)'); });
        magnetBtn.on('mouseleave', function () { $(this).css('background', 'rgba(255,255,255,0.18)'); });

        magnetBtn.on('click', function (e) {
          e.preventDefault();
          e.stopPropagation();
          var t = findTorrentByNode(row);
          copyToClipboard(extractMagnet(t));
        });

        details.append(magnetBtn);
      });
    });

    domObserver.observe(document.body, { childList: true, subtree: true });

    // Фиксация активного элемента по ПКМ
    document.addEventListener('contextmenu', function (e) {
      var el = e.target.closest('.torrent-item');
      if (el) window._lampa_last_torrent = findTorrentByNode(el);
    }, true);

    // --- Оригинальная логика Jackett ByLampa ---
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
