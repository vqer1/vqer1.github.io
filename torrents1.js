(function () {
    'use strict';

    function startPlugin() {
      window.plugin_torrents_ready = true;

      // --- Вспомогательные функции для копирования Magnet ---
      function extractMagnet(data) {
        if (!data) return '';
        if (typeof data.MagnetUri === 'string' && data.MagnetUri.indexOf('magnet:') === 0) return data.MagnetUri;
        if (typeof data.magnet === 'string' && data.magnet.indexOf('magnet:') === 0) return data.magnet;
        if (typeof data.Link === 'string' && data.Link.indexOf('magnet:') === 0) return data.Link;
        var hash = data.hash || data.Hash || data.info_hash;
        if (hash) {
          var title = data.Title || data.title || '';
          return 'magnet:?xt=urn:btih:' + hash + (title ? '&dn=' + encodeURIComponent(title) : '');
        }
        return data.Link || '';
      }

      function copyToClipboard(text, message) {
        if (!text) {
          Lampa.Noty.show('Magnet-ссылка не найдена');
          return;
        }

        var successMsg = message || 'Magnet-ссылка скопирована';

        function showSuccess() {
          Lampa.Noty.show(successMsg);
        }

        function fallback() {
          try {
            if (Lampa.Utils && typeof Lampa.Utils.copyTextToClipboard === 'function') {
              Lampa.Utils.copyTextToClipboard(text, function(result) {
                if (result !== false) showSuccess();
                else Lampa.Noty.show('Не удалось скопировать');
              });
            } else {
              var ta = document.createElement('textarea');
              ta.value = text;
              ta.style.position = 'fixed';
              ta.style.left = '-9999px';
              ta.style.top = '0';
              document.body.appendChild(ta);
              ta.focus();
              ta.select();
              var ok = document.execCommand('copy');
              document.body.removeChild(ta);
              if (ok) showSuccess();
              else Lampa.Noty.show('Не удалось скопировать');
            }
          } catch (e) {
            Lampa.Noty.show('Ошибка буфера обмена');
          }
        }

        if (navigator.clipboard && window.isSecureContext) {
          navigator.clipboard.writeText(text).then(showSuccess).catch(fallback);
        } else {
          fallback();
        }
      }

      function attachTorrentHandlers(item, data) {
        var magnet = extractMagnet(data);
        if (!magnet) return;

        function showActionMenu() {
          var items = [
            {
              title: 'Копировать Magnet-ссылку',
              action: 'copy_magnet'
            }
          ];

          var hash = data.hash || data.Hash || data.info_hash;
          if (!hash && magnet.indexOf('btih:') !== -1) {
            var m = magnet.match(/btih:([a-zA-Z0-9]+)/i);
            if (m) hash = m[1];
          }

          if (hash) {
            items.push({
              title: 'Копировать Hash (' + hash.slice(0, 8) + '...)',
              action: 'copy_hash'
            });
          }

          items.push({
            title: 'Запустить (по умолчанию)',
            action: 'play'
          });

          Lampa.Select.show({
            title: data.Title || data.title || 'Действие с торрентом',
            items: items,
            onSelect: function (a) {
              if (a.action === 'copy_magnet') {
                copyToClipboard(magnet, 'Magnet-ссылка скопирована');
              } else if (a.action === 'copy_hash') {
                copyToClipboard(hash, 'Hash скопирован');
              } else if (a.action === 'play') {
                item.trigger('hover:enter');
              }
            },
            onBack: function () {
              Lampa.Controller.toggle('content');
            }
          });
        }

        // Вызов меню по долгому нажатию (пульт ТВ / клавиатура)
        item.on('hover:long', function () {
          showActionMenu();
        });

        // ПКМ для браузера/ПК
        item.on('contextmenu', function (e) {
          e.preventDefault();
          e.stopPropagation();
          showActionMenu();
          return false;
        });

        // Кнопка быстрого копирования в строке параметров торрента
        var details = item.find('.torrent-item__details');
        var copyBtn = $('<div class="torrent-item__detail torrent-item__copy" style="cursor: pointer; opacity: 0.85; margin-left: 8px; text-decoration: underline;" title="Копировать magnet">🧲 Magnet</div>');

        copyBtn.on('click', function (e) {
          e.preventDefault();
          e.stopPropagation();
          copyToClipboard(magnet, 'Magnet-ссылка скопирована');
        });

        if (details.length) {
          details.append(copyBtn);
        } else {
          item.append(copyBtn);
        }
      }

      // Перехват генерации карточек раздач
      if (!window.plugin_copy_magnet_hooked) {
        window.plugin_copy_magnet_hooked = true;
        var original_template_get = Lampa.Template.get;
        Lampa.Template.get = function (name, vars, bool) {
          var item = original_template_get.apply(this, arguments);
          if (name === 'torrent_item' && vars && item && item.on) {
            attachTorrentHandlers(item, vars);
          }
          return item;
        };
      }

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
            title: Lampa.Lang.translate('title_torrents')+' ...',
            component: 'torrents',
            search: combinations[Lampa.Storage.field('parse_lang')],
            search_one: data.movie.title,
            search_two: data.movie.original_title,
            movie: data.movie,
            page: 1
          });
        };

        Lampa.Listener.follow('full', function (e) {
          if (e.type == 'complite') {
            var button = "<div class=\"full-start__button view---torrent\">\n                    <svg xmlns=\"http://www.w3.org/2000/svg\"  viewBox=\"0 0 50 50\" width=\"50px\" height=\"50px\">\n                        <path d=\"M25,2C12.317,2,2,12.317,2,25s10.317,23,23,23s23-10.317,23-23S37.683,2,25,2z M40.5,30.963c-3.1,0-4.9-2.4-4.9-2.4 S34.1,35,27,35c-1.4,0-3.6-0.837-3.6-0.837l4.17,9.643C26.727,43.92,25.874,44,25,44c-2.157,0-4.222-0.377-6.155-1.039L9.237,16.851 c0,0-0.7-1.2,0.4-1.5c1.1-0.3,5.4-1.2,5.4-1.2s1.475-0.494,1.8,0.5c0.5,1.3,4.063,11.112,4.063,11.112S22.6,29,27.4,29 c4.7,0,5.9-3.437,5.7-3.937c-1.2-3-4.993-11.862-4.993-11.862s-0.6-1.1,0.8-1.4c1.4-0.3,3.8-0.7,3.8-0.7s1.105-0.163,1.6,0.8 c0.738,1.437,5.193,11.262,5.193,11.262s1.1,2.9,3.3,2.9c0.464,0,0.834-0.046,1.152-0.104c-0.082,1.635-0.348,3.221-0.817,4.722 C42.541,30.867,41.756,30.963,40.5,30.963z\" fill=\"currentColor\"/>\n                    </svg>\n\n    <span>#{full_torrents} ...</span>\n    </div>";
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
                'jacred.freebie.tom.ru': '1',
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
              jackett.jackett_url_pva.split(';').forEach( function(item) {                
                jackett.items.push({ 
                  title: cleanTitle(item),
                  jackett_url: item.toLowerCase().indexOf('#') == 0 ? item.slice(1) : item, 
                  jackett_key: '', 
                  interview: item.toLowerCase().indexOf('#') == 0 ? 'all' : 'healthy', selected: false 
                });
              });
              var i = 0;
              jackett.jackett_key_pva.split(';').forEach( function(item) {
                if (jackett.items[i]) jackett.items[i++].jackett_key = item;
              });
              Lampa.Select.show({
                title: Lampa.Lang.translate('settings_parser_use'),
                items: jackett.items,
                onSelect: function onSelect(b) {
                  try { 
                    Lampa.Storage.set('jackett_url', b.jackett_url);
                    Lampa.Storage.set('jackett_key', b.jackett_key);
                    Lampa.Storage.set('jackett_interview', b.interview);
                    button_click(e.data); 
                  } 
                  finally { 
                    Lampa.Storage.set('jackett_url', jackett.jackett_url);
                    Lampa.Storage.set('jackett_key', jackett.jackett_key);
                  }
                },
                onBack: function onBack() {
                  Lampa.Controller.toggle('content');
                }                  
              });
            });
            if (e.data && e.object)
              e.object.activity.render().find('.view--torrent').last().after(btn);
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
            name: Lampa.Lang.translate('settings_parser_jackett_link')+' ...',
            description: Lampa.Lang.translate('settings_parser_jackett_link_descr')+' ...' + '<br>jacred.xyz;jacred.ru;#jackett:9117<br># - поиск по всем трекерам'
          },
          onChange: function (value) {
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
            name: Lampa.Lang.translate('settings_parser_jackett_key')+' ...',
            description: Lampa.Lang.translate('settings_parser_jackett_key_descr')+' ...' + '<br>;;jackettkey'
          },
          onChange: function (value) {
          }
        });
        Lampa.Params.select('jackett_url_pva', '', '');
        Lampa.Params.select('jackett_key_pva', '', '');
        Lampa.Settings.main().update();

      }

      if (window.appready) add(); else {
        Lampa.Listener.follow('app', function (e) {
          if (e.type == 'ready') { add(); }
        });
      }
    }

    if (!window.plugin_torrents_ready) startPlugin();

})();
