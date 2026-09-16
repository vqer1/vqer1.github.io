(function () {
    'use strict';

    function startPlugin() {
      // --- Буфер для хранения исходных объектов раздач от парсера ---
      var last_parsed_results = [];

      // 1. Перехват выдачи парсера (JacRed / Jackett) для сохранения MagnetUri
      if (window.Lampa && Lampa.Parser) {
        if (!Lampa.Parser._orig_magnet_get) {
          Lampa.Parser._orig_magnet_get = Lampa.Parser.get;
        }
        Lampa.Parser.get = function (params, complite, error) {
          return Lampa.Parser._orig_magnet_get.call(this, params, function (results) {
            if (Array.isArray(results)) {
              last_parsed_results = results.map(function (item) {
                item._ui_matched = false;
                return item;
              });
            }
            complite(results);
          }, error);
        };
      }

      // --- Вспомогательные функции извлечения и копирования ---
      function findTorrentData(vars) {
        if (!vars) return null;
        if (vars.MagnetUri || vars.Link || vars.hash || vars.InfoHash) return vars;

        var targetTitle = (vars.title || vars.Title || '').trim();
        var targetTracker = (vars.tracker || vars.Tracker || '').toLowerCase();

        // Поиск первого свободного совпадения по названию и трекеру
        for (var i = 0; i < last_parsed_results.length; i++) {
          var el = last_parsed_results[i];
          if (el._ui_matched) continue;
          var elTitle = (el.Title || el.title || '').trim();
          var elTracker = (el.Tracker || el.tracker || '').toLowerCase();

          if (elTitle === targetTitle && (!targetTracker || elTracker === targetTracker)) {
            el._ui_matched = true;
            return el;
          }
        }

        // Запасной поиск без учета флага
        for (var j = 0; j < last_parsed_results.length; j++) {
          var item = last_parsed_results[j];
          var tTitle = (item.Title || item.title || '').trim();
          if (tTitle === targetTitle) return item;
        }

        return null;
      }

      function extractMagnet(source, vars) {
        var data = source || vars || {};

        if (typeof data.MagnetUri === 'string' && data.MagnetUri.indexOf('magnet:') === 0) return data.MagnetUri;
        if (typeof data.magnet === 'string' && data.magnet.indexOf('magnet:') === 0) return data.magnet;
        if (typeof data.Link === 'string' && data.Link.indexOf('magnet:') === 0) return data.Link;
        if (typeof data.link === 'string' && data.link.indexOf('magnet:') === 0) return data.link;

        var hash = data.InfoHash || data.info_hash || data.Hash || data.hash;
        if (hash) {
          var title = data.Title || data.title || (vars && (vars.Title || vars.title)) || '';
          return 'magnet:?xt=urn:btih:' + hash + (title ? '&dn=' + encodeURIComponent(title) : '');
        }

        return data.Link || data.link || '';
      }

      function copyText(text) {
        if (!text) {
          Lampa.Noty.show('Ссылка не найдена');
          return;
        }

        function showOk() {
          Lampa.Noty.show('🧲 Magnet скопирован в буфер');
        }

        function fallbackPrompt(val) {
          if (Lampa.Modal) {
            Lampa.Modal.open({
              title: 'Magnet-ссылка',
              html: $('<div style="padding: 1.5em;"><p style="margin-bottom: 10px; font-size: 14px;">Выделите и скопируйте (Ctrl+C):</p><input type="text" id="lampa_magnet_out" style="width: 100%; padding: 10px; background: rgba(255,255,255,0.1); color: #fff; border: 1px solid rgba(255,255,255,0.3); border-radius: 4px;" value="' + val + '" /></div>'),
              size: 'medium',
              onBack: function () { Lampa.Modal.close(); }
            });
            setTimeout(function () {
              var inp = document.getElementById('lampa_magnet_out');
              if (inp) { inp.focus(); inp.select(); }
            }, 100);
          } else {
            window.prompt('Скопируйте magnet-ссылку:', val);
          }
        }

        if (navigator.clipboard && window.isSecureContext) {
          navigator.clipboard.writeText(text).then(showOk).catch(function () {
            tryLegacyCopy(text, showOk, fallbackPrompt);
          });
        } else {
          tryLegacyCopy(text, showOk, fallbackPrompt);
        }
      }

      function tryLegacyCopy(text, onSuccess, onFail) {
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
          if (ok) onSuccess();
          else onFail(text);
        } catch (e) {
          onFail(text);
        }
      }

      // --- Привязка кнопки и меню к элементу раздачи ---
      function attachMagnetButton(item, vars) {
        if (!item || !item.find || item.data('magnet_ready')) return;
        item.data('magnet_ready', true);

        var btn = $(
          '<div class="torrent-item__detail torrent-item__magnet-btn" style="' +
            'display: inline-flex; align-items: center; padding: 2px 7px; margin-left: 10px; ' +
            'border-radius: 4px; background: rgba(255, 255, 255, 0.15); color: #fff; ' +
            'font-size: 11px; font-weight: bold; cursor: pointer; user-select: none; ' +
            'transition: background 0.15s ease;' +
          '">🧲 Magnet</div>'
        );

        btn.on('mouseenter', function () { $(this).css('background', 'rgba(255, 255, 255, 0.3)'); });
        btn.on('mouseleave', function () { $(this).css('background', 'rgba(255, 255, 255, 0.15)'); });

        function handleCopy(e) {
          if (e) {
            e.preventDefault();
            e.stopPropagation();
          }
          var rawData = findTorrentData(vars);
          var link = extractMagnet(rawData, vars);
          copyText(link);
        }

        btn.on('click', handleCopy);

        var details = item.find('.torrent-item__details');
        if (details.length) {
          details.append(btn);
        } else {
          item.append(btn);
        }

        // Контекстное меню по ПКМ
        item.on('contextmenu', function (e) {
          handleCopy(e);
          return false;
        });

        // Долгое удержание ОК (для ТВ пульта)
        item.on('hover:long', function (e) {
          handleCopy(e);
        });
      }

      // 2. Перехват создания карточки раздачи в интерфейсе
      if (window.Lampa && Lampa.Template) {
        if (!Lampa.Template._orig_magnet_get) {
          Lampa.Template._orig_magnet_get = Lampa.Template.get;
        }
        Lampa.Template.get = function (name, vars, bool) {
          var item = Lampa.Template._orig_magnet_get.apply(this, arguments);
          if (name === 'torrent_item' && vars && item && item.find) {
            attachMagnetButton(item, vars);
          }
          return item;
        };
      }

      // --- Оригинальная логика плагина Jackett ByLampa ---
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
