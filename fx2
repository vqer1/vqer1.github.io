(function() {
    'use strict';

    Lampa.Platform.tv();

    if (window.online_filmix_fx2) return;
    window.online_filmix_fx2 = true;

    // Конфигурация аккаунта и API для автоматического удержания привязки
    var FX2_CONFIG = {
        login: 'hutgtghordi22',
        pass: 'rk3y0a371c4',
        site_url: 'https://filmix.gg',
        api_url: 'http://filmixapp.vip/api/v2/',
        default_proxy: 'http://fx.bylampa.online/proxy/'
    };

    var uid = Lampa.Storage.get('fxapi_uid', '');
    if (!uid) {
        uid = Lampa.Utils.uid(16);
        Lampa.Storage.set('fxapi_uid', uid);
    }

    var proxy_url = Lampa.Storage.get('fxapi_proxy', FX2_CONFIG.default_proxy);
    if (proxy_url && proxy_url.charAt(proxy_url.length - 1) !== '/') proxy_url += '/';

    window.fxapi = {
        max_qualitie: 720,
        is_max_qualitie: false
    };

    function getToken() {
        return Lampa.Storage.get('fxapi_token', '');
    }

    function buildDevParams(token) {
        var t = typeof token === 'string' ? token : getToken();
        return 'app_lang=ru_RU&user_dev_apk=2.2.13&user_dev_id=' + uid + '&user_dev_name=Xiaomi+24069PC21G&user_dev_os=12&user_dev_token=' + t + '&user_dev_vendor=Xiaomi';
    }

    function getApiEndpoint(method) {
        return proxy_url + FX2_CONFIG.api_url + method;
    }

    function getSiteEndpoint(path) {
        return proxy_url + FX2_CONFIG.site_url + path;
    }

    // =========================================================================
    // МОДУЛЬ АВТОМАТИЧЕСКОГО УДЕРЖАНИЯ УСТРОЙСТВА (AUTO-HEALER / CONSOLES BOT)
    // =========================================================================
    var AutoHealer = {
        is_healing: false,

        // Главная функция проверки при нажатии на кнопку "Онлайн"
        ensureDeviceBound: function(onReady, onError) {
            var self = this;
            var current_token = getToken();
            var net = new Lampa.Reguest();

            if (!current_token) {
                self.rebindDevice(onReady, onError);
                return;
            }

            Lampa.Noty.show('FX2: Проверка привязки устройства...');
            net.timeout(7000);
            net.silent(Lampa.Utils.addUrlComponent(getApiEndpoint('user_profile'), buildDevParams(current_token)), function(json) {
                if (json && json.user_data && (json.user_data.login || json.user_data.is_pro || json.user_data.is_pro_plus)) {
                    // Устройство активно привязано! Обновляем качество
                    updateQualityLimits(json.user_data);
                    Lampa.Storage.set('fxapi_status', json.user_data);
                    onReady();
                } else {
                    // Устройство было удалено кем-то с аккаунта! Запускаем экстренную перепривязку
                    Lampa.Noty.show('FX2: Устройство отвязано! Авто-восстановление...');
                    self.rebindDevice(onReady, onError);
                }
            }, function() {
                // При ошибке сети/авторизации пробуем перепривязать
                self.rebindDevice(onReady, onError);
            });
        },

        // Полный цикл: Генерация кода -> Удаление лишнего (5/5) -> Привязка -> Сохранение токена
        rebindDevice: function(onReady, onError) {
            var self = this;
            if (self.is_healing) return;
            self.is_healing = true;

            var net = new Lampa.Reguest();
            net.timeout(10000);

            // Шаг 1: Запрашиваем новый токен и 4-значный код (например, N8QH)
            var req_url = Lampa.Utils.addUrlComponent(getApiEndpoint('token_request'), buildDevParams(''));
            net.quiet(req_url, function(data) {
                if (data && data.status === 'ok' && data.code && data.user_code) {
                    var new_token = data.code;
                    var user_code = data.user_code;
                    Lampa.Noty.show('FX2: Получен код ' + user_code + '. Очистка слота и привязка...');

                    // Шаг 2: Авторизуемся и привязываем через веб-консоль filmix.gg/consoles и API
                    self.performWebAndApiBind(user_code, new_token, function(success) {
                        self.is_healing = false;
                        if (success) {
                            Lampa.Storage.set('fxapi_token', new_token);
                            Lampa.Noty.show('FX2: Устройство [' + user_code + '] успешно привязано!');
                            checkProfileAndUpdate(new_token, function() {
                                onReady();
                            });
                        } else {
                            if (onError) onError('Не удалось автоматически привязать код ' + user_code);
                        }
                    });
                } else {
                    self.is_healing = false;
                    if (onError) onError('Ошибка получения кода Filmix API');
                }
            }, function() {
                self.is_healing = false;
                if (onError) onError('Сбой соединения с Filmix API');
            });
        },

        // Авторизация на сайте, проверка 5/5 устройств, удаление случайного и отправка кода
        performWebAndApiBind: function(user_code, new_token, callback) {
            var self = this;
            var net = new Lampa.Reguest();
            net.timeout(12000);

            // Сначала пробуем прямую авторизацию через API v2 с передачей логина/пароля и нового токена
            var direct_auth_url = Lampa.Utils.addUrlComponent(
                getApiEndpoint('auth'),
                buildDevParams(new_token) + '&user_name=' + encodeURIComponent(FX2_CONFIG.login) + '&user_pass=' + encodeURIComponent(FX2_CONFIG.pass)
            );

            // Параллельно работаем со страницей /consoles для выбивания случайного устройства при лимите 5/5
            var login_payload = 'login_name=' + encodeURIComponent(FX2_CONFIG.login) +
                                '&login_password=' + encodeURIComponent(FX2_CONFIG.pass) +
                                '&login_not_save=0&login=submit';

            // 1. Вход на сайт filmix.gg и загрузка /consoles
            $.ajax({
                url: getSiteEndpoint('/consoles'),
                type: 'POST',
                data: login_payload,
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                success: function(html) {
                    self.processConsolesHtml(html, user_code, new_token, callback);
                },
                error: function() {
                    // Если прокси блокирует POST на корень, пробуем AJAX-контроллер DLE
                    self.fallbackApiBind(direct_auth_url, user_code, new_token, callback);
                }
            });
        },

        processConsolesHtml: function(html, user_code, new_token, callback) {
            var self = this;
            var $doc = $('<div>').html(html);

            // Ищем список привязанных устройств в новой верстке (.f-device-card) и старой (.my-devices li)
            var devices = [];
            $doc.find('.f-device-card, .my-devices li').each(function() {
                var $el = $(this);
                var id = $el.attr('data-id') || $el.attr('id') || $el.find('[data-id]').attr('data-id') || $el.find('input[name="device_id"]').val();
                var code = $el.attr('data-code') || $el.attr('data-user-code') || '';
                if (id || code) {
                    devices.push({ id: id, code: code, el: $el });
                }
            });

            // Проверяем заголовок "Мои устройства (5/5)" или "(2/2)"
            var count_text = $doc.find('.f-my-devices .f-app-title-h2 span, #allConsoles h3 span').text() || '';
            var match_limit = count_text.match(/(\d+)\s*\/\s*(\d+)/);
            var is_full = false;

            if (match_limit && parseInt(match_limit[1], 10) >= parseInt(match_limit[2], 10)) {
                is_full = true;
            } else if (devices.length >= 5) {
                is_full = true;
            }

            // Функция отправки 4-значного кода после очистки места
            var sendActivationCode = function() {
                // В console.js на Filmix отправка формы #allConsoles-devices идет на /engine/ajax/controller.php?mod=consoles или /consoles
                var post_data = 'user_code=' + encodeURIComponent(user_code) + '&action=add';
                $.ajax({
                    url: getSiteEndpoint('/engine/ajax/controller.php?mod=consoles'),
                    type: 'POST',
                    data: post_data,
                    success: function() {
                        self.verifyTokenActive(new_token, callback);
                    },
                    error: function() {
                        $.ajax({
                            url: getSiteEndpoint('/consoles'),
                            type: 'POST',
                            data: 'user_code=' + encodeURIComponent(user_code),
                            complete: function() {
                                self.verifyTokenActive(new_token, callback);
                            }
                        });
                    }
                });
            };

            // Если слоты переполнены (например, 5/5) и есть устройства — удаляем случайное!
            if (is_full && devices.length > 0) {
                var random_index = Math.floor(Math.random() * devices.length);
                var target = devices[random_index];
                Lampa.Noty.show('FX2: Лимит устройств заполнен! Удаляем случайное устройство...');

                $.ajax({
                    url: getSiteEndpoint('/engine/ajax/controller.php?mod=consoles'),
                    type: 'POST',
                    data: 'action=delete&id=' + encodeURIComponent(target.id || '') + '&user_code=' + encodeURIComponent(target.code || ''),
                    complete: function() {
                        sendActivationCode();
                    }
                });
            } else {
                sendActivationCode();
            }
        },

        fallbackApiBind: function(direct_auth_url, user_code, new_token, callback) {
            var self = this;
            var net = new Lampa.Reguest();
            net.timeout(8000);
            net.silent(direct_auth_url, function() {
                self.verifyTokenActive(new_token, callback);
            }, function() {
                self.verifyTokenActive(new_token, callback);
            });
        },

        verifyTokenActive: function(token, callback) {
            var net = new Lampa.Reguest();
            net.timeout(6000);
            net.silent(Lampa.Utils.addUrlComponent(getApiEndpoint('user_profile'), buildDevParams(token)), function(res) {
                if (res && res.user_data && (res.user_data.login || res.user_data.is_pro || res.user_data.is_pro_plus)) {
                    callback(true);
                } else {
                    // Даем еще 1.5 секунды на случай задержки БД Filmix
                    setTimeout(function() {
                        net.silent(Lampa.Utils.addUrlComponent(getApiEndpoint('user_profile'), buildDevParams(token)), function(res2) {
                            callback(!!(res2 && res2.user_data));
                        }, function() {
                            callback(false);
                        });
                    }, 1500);
                }
            }, function() {
                callback(false);
            });
        }
    };

    // =========================================================================
    // ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ПРОФИЛЯ И ПАРСИНГА ПОТОКОВ
    // =========================================================================
    function updateQualityLimits(user_data) {
        window.fxapi.max_qualitie = 720;
        if (user_data) {
            if (user_data.is_pro_plus) window.fxapi.max_qualitie = 2160;
            else if (user_data.is_pro) window.fxapi.max_qualitie = 1080;
        }
    }

    function checkProfileAndUpdate(token, onDone) {
        var net = new Lampa.Reguest();
        net.timeout(8000);
        net.silent(Lampa.Utils.addUrlComponent(getApiEndpoint('user_profile'), buildDevParams(token)), function(json) {
            if (json && json.user_data) {
                updateQualityLimits(json.user_data);
                Lampa.Storage.set('fxapi_status', json.user_data);
                if (onDone) onDone(json.user_data);
            } else {
                if (onDone) onDone(null);
            }
            renderSettingsProfile();
        }, function() {
            if (onDone) onDone(null);
        });
    }

    function isObjectNotEmpty(obj) {
        return obj && !Array.isArray(obj) && Object.keys(obj).length > 0;
    }

    function normalizeResponse(data) {
        if (!data || !data.player_links) return data;
        var links = data.player_links;
        if (Array.isArray(links.playlist) && !links.playlist.length) {
            links.playlist = null;
        }
        return data;
    }

    function hasValidStreams(data) {
        var links = data && data.player_links;
        if (!links) return false;
        if (links.movie && links.movie.length) return true;
        if (isObjectNotEmpty(links.playlist)) return true;
        return false;
    }

    function isBlockedStream(translation) {
        return typeof translation === 'string' && translation.toLowerCase().indexOf('заблокировано ') === 0;
    }

    function extractQualities(link) {
        var m = link && link.match(/\[([\d,\s]*)\]/);
        if (!m) return [];
        return m[1].split(',').map(function(q) {
            return parseInt(q, 10);
        }).filter(function(q) {
            return q > 0 && q <= window.fxapi.max_qualitie;
        });
    }

    function getMaxQuality(arr) {
        if (!arr || !arr.length) return 0;
        return Math.max.apply(null, arr);
    }

    function normalizeEpisodesMap(obj) {
        if (!obj) return {};
        if (Array.isArray(obj)) {
            var res = {};
            for (var i = 0; i < obj.length; i++) {
                res[String(i + 1)] = obj[i];
            }
            return res;
        }
        return obj;
    }

    function getSortedKeys(obj) {
        if (!isObjectNotEmpty(obj)) return [];
        return Object.keys(obj).sort(function(a, b) {
            return parseInt(a, 10) - parseInt(b, 10);
        });
    }

    // =========================================================================
    // ИСТОЧНИК ДАННЫХ FILMIX FX2
    // =========================================================================
    function FilmixSource(component, object) {
        var network = new Lampa.Reguest();
        var extract = {};
        var results = [];
        var movie_obj = object;
        var similars = false;
        var filter_items = {};
        var choice = { season: 0, voice: 0, voice_name: '' };

        function cleanTitle(str) {
            return (str || '').toLowerCase().replace(/[^a-zа-я0-9]/g, '');
        }

        this.search = function(_obj, items) {
            if (similars) this.find(items[0].id);
        };

        this.searchByTitle = function(obj, query) {
            var self = this;
            movie_obj = obj;
            var year = parseInt(((movie_obj.movie.release_date || movie_obj.movie.first_air_date || '0000') + '').slice(0, 4), 10);
            var orig = movie_obj.movie.original_name || movie_obj.movie.original_title || '';

            var url = Lampa.Utils.addUrlComponent(getApiEndpoint('search'), 'story=' + encodeURIComponent(query));
            url = Lampa.Utils.addUrlComponent(url, buildDevParams());

            network.clear();
            network.timeout(10000);
            network.silent(url, function(json) {
                if (!json || !Array.isArray(json)) {
                    component.doesNotAnswer();
                    return;
                }
                var by_year = json.filter(function(item) {
                    item.year = parseInt(item.year || (item.alt_name || '').split('-').pop(), 10);
                    return item.year > year - 2 && item.year < year + 2;
                });

                var exact = by_year.find(function(item) {
                    return item.year == year && cleanTitle(item.original_title) == cleanTitle(orig);
                });
                if (!exact) {
                    exact = by_year.find(function(item) {
                        return cleanTitle(item.original_title) == cleanTitle(orig);
                    });
                }
                if (!exact && by_year.length === 1) exact = by_year[0];

                if (exact) {
                    self.find(exact.id);
                } else if (json.length) {
                    similars = true;
                    component.similars(json);
                    component.loading(false);
                } else {
                    component.doesNotAnswer();
                }
            }, function() {
                component.doesNotAnswer();
            });
        };

        this.find = function(post_id) {
            network.clear();
            network.timeout(10000);
            network.silent(Lampa.Utils.addUrlComponent(getApiEndpoint('post/' + post_id), buildDevParams()), function(json) {
                json = normalizeResponse(json);
                if (json && hasValidStreams(json)) {
                    results = json;
                    buildExtractData(json);
                    buildFilters();
                    var list = getItemsList();
                    if (!list.length) component.doesNotAnswer();
                    else renderItems(list);
                    component.loading(false);
                } else if (json && json.id) {
                    component.empty('Контент найден, но видео недоступно.');
                } else {
                    component.doesNotAnswer();
                }
            }, function() {
                component.doesNotAnswer();
            });
        };

        this.extendChoice = function(saved) {
            Lampa.Arrays.extend(choice, saved, true);
        };

        this.reset = function() {
            component.reset();
            choice = { season: 0, voice: 0, voice_name: '' };
            buildExtractData(results);
            buildFilters();
            renderItems(getItemsList());
            component.saveChoice(choice);
        };

        this.filter = function(type, a, b) {
            choice[a.stype] = b.index;
            if (a.stype === 'voice') choice.voice_name = filter_items.voice[b.index];
            component.reset();
            buildExtractData(results);
            buildFilters();
            renderItems(getItemsList());
            component.saveChoice(choice);
        };

        this.destroy = function() {
            network.clear();
            results = null;
        };

        function buildExtractData(data) {
            extract = {};
            var links = data.player_links;
            if (isObjectNotEmpty(links.playlist)) {
                var s_idx = 0;
                for (var s_key in links.playlist) {
                    var season_obj = links.playlist[s_key];
                    ++s_idx;
                    var v_idx = 0;
                    var s_num = parseInt(s_key === '-1' ? '1' : s_key, 10);
                    for (var v_name in season_obj) {
                        var eps = normalizeEpisodesMap(season_obj[v_name]);
                        ++v_idx;
                        var folder = [];
                        for (var ep_key in eps) {
                            var ep_data = eps[ep_key];
                            if (!ep_data || !ep_data.link) continue;
                            var quals = (ep_data.qualities || []).filter(function(q) {
                                return q > 0 && q <= window.fxapi.max_qualitie;
                            });
                            if (!quals.length) continue;
                            var max_q = getMaxQuality(quals);
                            var file_url = ep_data.link.replace('%s.mp4', max_q + '.mp4');
                            var file_name = file_url.slice(file_url.lastIndexOf('/'));
                            var m = file_name.match(/s(\d+)e(\d+?)_\d+\.mp4/i);
                            var cur_s = s_num;
                            var cur_e = parseInt(ep_key, 10);
                            if (m) {
                                cur_s = parseInt(m[1], 10);
                                cur_e = parseInt(m[2], 10);
                            } else if (isNaN(cur_e)) continue;

                            folder.push({
                                id: cur_s + '_' + cur_e,
                                comment: cur_e + ' ' + Lampa.Lang.translate('torrent_serial_episode') + ' <i>' + ep_key + '</i>',
                                file: file_url,
                                episode: cur_e,
                                season: cur_s,
                                quality: max_q,
                                qualities: quals,
                                translation: v_idx
                            });
                        }
                        if (!extract[v_idx]) extract[v_idx] = { json: [], file: '' };
                        extract[v_idx].json.push({
                            id: s_idx,
                            comment: s_idx + ' ' + Lampa.Lang.translate('torrent_serial_season'),
                            folder: folder,
                            translation: v_idx
                        });
                    }
                }
            } else if (links.movie && links.movie.length > 0) {
                var m_idx = 0;
                for (var i in links.movie) {
                    var m_item = links.movie[i];
                    if (isBlockedStream(m_item.translation)) continue;
                    ++m_idx;
                    var q_list = extractQualities(m_item.link);
                    var best_q = getMaxQuality(q_list);
                    if (!best_q) continue;
                    var m_file = m_item.link.replace(/_\[([\d,\s]*)\]\.mp4/i, '_' + best_q + '.mp4');
                    extract[m_idx] = {
                        file: m_file,
                        translation: m_item.translation,
                        quality: best_q,
                        qualities: q_list
                    };
                }
            }
        }
        function getStreamFile(element, max_quality) {
            var transl = extract[element.translation];
            var target_id = element.season + '_' + element.episode;
            var file = '';
            var quality_map = false;

            if (transl) {
                if (element.season) {
                    for (var i in transl.json) {
                        var s_item = transl.json[i];
                        if (s_item.folder) {
                            for (var j in s_item.folder) {
                                var ep = s_item.folder[j];
                                if (ep.id == target_id) {
                                    file = ep.file;
                                    break;
                                }
                            }
                        } else if (s_item.id == target_id) {
                            file = s_item.file;
                            break;
                        }
                    }
                } else {
                    file = transl.file;
                }
            }

            max_quality = parseInt(max_quality, 10);
            if (file) {
                var prefix = file.slice(0, file.lastIndexOf('_')) + '_';
                var query_parts = file.split('?');
                var query_str = query_parts.length > 1 ? '?' + query_parts.slice(1).join('?') : '';

                if (file.split('_').pop().replace('.mp4', '') !== String(max_quality)) {
                    file = prefix + max_quality + '.mp4' + query_str;
                }

                quality_map = {};
                var all_q = [2160, 1440, 1080, 720, 480, 360];
                all_q = all_q.slice(all_q.indexOf(max_quality));
                all_q.forEach(function(q) {
                    quality_map[q + 'p'] = prefix + q + '.mp4' + query_str;
                });

                var pref_q = Lampa.Storage.get('video_quality_default', '1080') + 'p';
                if (quality_map[pref_q]) file = quality_map[pref_q];
            }
            return { file: file, quality: quality_map };
        }

        function buildFilters() {
            filter_items = { season: [], voice: [], voice_info: [] };
            var pl = results.player_links.playlist;
            if (isObjectNotEmpty(pl)) {
                var s_keys = getSortedKeys(pl);
                s_keys.forEach(function(k) {
                    var label = k === '-1' ? '1' : k;
                    filter_items.season.push(Lampa.Lang.translate('torrent_serial_season') + ' ' + label);
                });
                var cur_s_key = s_keys[choice.season] || s_keys[0];
                var voices_obj = pl[cur_s_key];
                var v_id = 0;
                if (voices_obj) {
                    for (var v in voices_obj) {
                        ++v_id;
                        filter_items.voice.push(v);
                        filter_items.voice_info.push({ id: v_id });
                    }
                }
            }
            if (choice.voice_name) {
                var idx = filter_items.voice.map(function(v) { return v.toLowerCase(); }).indexOf(choice.voice_name.toLowerCase());
                if (idx === -1) choice.voice = 0;
                else if (idx !== choice.voice) choice.voice = idx;
            }
            if (choice.voice >= filter_items.voice.length) choice.voice = 0;
            if (filter_items.voice.length) choice.voice_name = filter_items.voice[choice.voice] || '';
            component.filter(filter_items, choice);
        }

        function getItemsList() {
            var items = [];
            if (isObjectNotEmpty(results.player_links.playlist)) {
                for (var k in extract) {
                    var v_data = extract[k];
                    for (var s in v_data.json) {
                        var s_folder = v_data.json[s];
                        if (s_folder.id == choice.season + 1) {
                            s_folder.folder.forEach(function(ep) {
                                if (ep.translation == filter_items.voice_info[choice.voice].id) {
                                    items.push({
                                        episode: parseInt(ep.episode, 10),
                                        season: ep.season,
                                        title: Lampa.Lang.translate('torrent_serial_episode') + ' ' + ep.episode + (ep.title ? ' - ' + ep.title : ''),
                                        quality: ep.quality + 'p ',
                                        translation: ep.translation,
                                        voice_name: filter_items.voice[choice.voice],
                                        info: filter_items.voice[choice.voice]
                                    });
                                }
                            });
                        }
                    }
                }
            } else if (Object.keys(results.player_links.movie || {}).length) {
                for (var m in extract) {
                    var mov = extract[m];
                    items.push({
                        title: mov.translation,
                        quality: mov.quality + 'p ',
                        qualitys: mov.qualities,
                        translation: m,
                        voice_name: mov.translation
                    });
                }
            }
            return items;
        }

        function toPlayObject(item) {
            var stream = getStreamFile(item, item.quality);
            return {
                title: item.title,
                url: stream.file,
                quality: stream.quality,
                timeline: item.timeline,
                callback: item.mark
            };
        }

        function renderItems(list) {
            component.reset();
            component.draw(list, {
                similars: similars,
                onEnter: function(item) {
                    var stream = getStreamFile(item, item.quality);
                    if (stream.file) {
                        var playlist = [];
                        var first = toPlayObject(item);
                        if (item.season) {
                            list.forEach(function(el) {
                                playlist.push(toPlayObject(el));
                            });
                        } else {
                            playlist.push(first);
                        }
                        if (playlist.length > 1) first.playlist = playlist;
                        Lampa.Player.play(first);
                        Lampa.Player.playlist(playlist);
                        if (item.mark) item.mark();
                    } else {
                        Lampa.Noty.show('Не удалось извлечь ссылку');
                    }
                },
                onContextMenu: function(item, _html, _data, call) {
                    call(getStreamFile(item, item.quality));
                }
            });
        }
    }

    // =========================================================================
    // КОМПОНЕНТ ОТОБРАЖЕНИЯ В LAMPA (C АВТОПРОВЕРКОЙ ПРИ СТАРТЕ)
    // =========================================================================
    function OnlineFX2Component(object) {
        var scroll = new Lampa.Scroll({ mask: true, over: true });
        var explorer = new Lampa.Explorer(object);
        var filter = new Lampa.Filter(object);
        var source = null;
        var last_focused = false;
        var initialized = false;

        this.initialize = function() {
            var self = this;
            source = new FilmixSource(this, object);

            filter.onSearch = function(query) {
                Lampa.Activity.replace({ search: query, clarification: true });
            };
            filter.onBack = function() {
                self.start();
            };
            filter.onSelect = function(type, a, b) {
                if (type === 'filter') {
                    if (a.reset) source.reset();
                    else source.filter(type, a, b);
                } else if (type === 'sort') {
                    Lampa.Select.close();
                }
            };
            if (filter.addButtonBack) filter.addButtonBack();
            filter.render().find('.filter--sort').remove();

            explorer.appendFiles(scroll.render());
            explorer.appendHead(filter.render());
            scroll.body().addClass('torrent-list');
            scroll.minus(explorer.render().find('.explorer__files-head'));

            // КАЖДЫЙ РАЗ ПРИ ОТКРЫТИИ ПРОВЕРЯЕМ И ВОССТАНАВЛИВАЕМ УСТРОЙСТВО!
            this.activity.loader(true);
            AutoHealer.ensureDeviceBound(function() {
                self.search();
            }, function(err_msg) {
                Lampa.Noty.show(err_msg || 'Ошибка автопривязки FX2');
                self.search(); // Все равно пробуем поиск
            });
        };

        this.search = function() {
            this.activity.loader(true);
            source.extendChoice(this.getChoice());
            var q = object.search || object.movie.original_title || object.movie.original_name || object.movie.title || object.movie.name;
            source.searchByTitle(object, q);
        };

        this.getChoice = function() {
            var ch = Lampa.Storage.cache('online_choice_fxapi', 3000, {});
            var item = ch[object.movie.id] || {};
            Lampa.Arrays.extend(item, { season: 0, voice: 0, voice_name: '', voice_id: 0, episodes_view: {}, movie_view: '' });
            return item;
        };

        this.saveChoice = function(ch) {
            var all = Lampa.Storage.cache('online_choice_fxapi', 3000, {});
            all[object.movie.id] = ch;
            Lampa.Storage.set('online_choice_fxapi', all);
        };

        this.similars = function(json) {
            var self = this;
            json.forEach(function(elem) {
                var year = ((elem.start_date || elem.year || '') + '').slice(0, 4);
                elem.title = (elem.title || elem.ru_title || elem.nameRu) + (elem.original_title ? ' / ' + elem.original_title : '');
                elem.time = elem.filmLength || '';
                elem.info = year;
                var folder = Lampa.Template.get('online_prestige_folder', elem);
                folder.on('hover:enter', function() {
                    self.activity.loader(true);
                    self.reset();
                    object.search_date = year;
                    source.search(object, [elem]);
                }).on('hover:focus', function(e) {
                    last_focused = e.target;
                    scroll.update($(e.target), true);
                });
                scroll.append(folder);
            });
        };

        this.filter = function(f_items, ch) {
            var list = [{ title: Lampa.Lang.translate('torrent_parser_reset'), reset: true }];
            this.saveChoice(ch);
            var addGroup = function(stype, title) {
                var vals = f_items[stype];
                var sub = [];
                vals.forEach(function(v, i) {
                    sub.push({ title: v, selected: ch[stype] == i, index: i });
                });
                list.push({ title: title, subtitle: vals[ch[stype]], items: sub, stype: stype });
            };
            if (f_items.voice && f_items.voice.length) addGroup('voice', Lampa.Lang.translate('torrent_parser_voice'));
            if (f_items.season && f_items.season.length) addGroup('season', Lampa.Lang.translate('torrent_serial_season'));
            filter.set('filter', list);
            var chosen = [];
            if (f_items.voice && f_items.voice.length) chosen.push(Lampa.Lang.translate('torrent_parser_voice') + ': ' + f_items.voice[ch.voice]);
            if (f_items.season && f_items.season.length) chosen.push(Lampa.Lang.translate('torrent_serial_season') + ': ' + f_items.season[ch.season]);
            filter.chosen('filter', chosen);
        };

        this.draw = function(items, params) {
            var self = this;
            if (!items.length) return this.empty();
            var viewed = Lampa.Storage.cache('online_view', 5000, []);
            items.forEach(function(el, idx) {
                Lampa.Arrays.extend(el, { info: '', quality: '', time: '' });
                var hash_tl = Lampa.Utils.hash(el.season ? [el.season, el.episode, object.movie.original_title].join('') : object.movie.original_title);
                var hash_view = Lampa.Utils.hash(el.season ? [el.season, el.episode, object.movie.original_title, el.voice_name].join('') : object.movie.original_title + el.voice_name);
                el.timeline = Lampa.Timeline.view(hash_tl);

                var card = Lampa.Template.get('online_prestige_full', el);
                card.find('.online-prestige__loader').remove();
                card.find('.online-prestige__img').append('<div class="online-prestige__episode-number">' + ('0' + (el.episode || idx + 1)).slice(-2) + '</div>');
                card.find('.online-prestige__timeline').append(Lampa.Timeline.render(el.timeline));

                if (viewed.indexOf(hash_view) !== -1) {
                    card.find('.online-prestige__img').append('<div class="online-prestige__viewed">' + Lampa.Template.get('icon_viewed', {}, true) + '</div>');
                }
                el.mark = function() {
                    if (viewed.indexOf(hash_view) === -1) {
                        viewed.push(hash_view);
                        Lampa.Storage.set('online_view', viewed);
                    }
                };
                card.on('hover:enter', function() {
                    if (object.movie.id) Lampa.Favorite.add('history', object.movie, 100);
                    if (params && params.onEnter) params.onEnter(el, card);
                }).on('hover:focus', function(e) {
                    last_focused = e.target;
                    scroll.update($(e.target), true);
                });
                scroll.append(card);
            });
            Lampa.Controller.enable('content');
        };

        this.reset = function() {
            last_focused = false;
            scroll.render().find('.empty').remove();
            scroll.clear();
        };

        this.empty = function(msg) {
            var tpl = Lampa.Template.get('online_does_not_answer', { balanser: 'FX2' });
            if (msg) tpl.find('.online-empty__title').text(msg);
            scroll.append(tpl);
            this.loading(false);
        };

        this.doesNotAnswer = function() {
            this.reset();
            this.empty('Filmix не ответил или токен обновляется');
        };

        this.loading = function(status) {
            if (status) this.activity.loader(true);
            else {
                this.activity.loader(false);
                this.activity.toggle();
            }
        };

        this.start = function() {
            if (Lampa.Activity.active().activity !== this.activity) return;
            if (!initialized) {
                initialized = true;
                this.initialize();
            }
            Lampa.Background.immediately(Lampa.Utils.cardImgBackgroundBlur(object.movie));
            Lampa.Controller.add('content', {
                toggle: function() {
                    Lampa.Controller.collectionSet(scroll.render(), explorer.render());
                    Lampa.Controller.collectionFocus(last_focused || false, scroll.render());
                },
                up: function() {
                    if (Navigator.canmove('up')) Navigator.move('up');
                    else Lampa.Controller.toggle('head');
                },
                down: function() {
                    Navigator.move('down');
                },
                right: function() {
                    if (Navigator.canmove('right')) Navigator.move('right');
                    else filter.show(Lampa.Lang.translate('title_filter'), 'filter');
                },
                left: function() {
                    if (Navigator.canmove('left')) Navigator.move('left');
                    else Lampa.Controller.toggle('menu');
                },
                back: function() {
                    Lampa.Activity.backward();
                }
            });
            Lampa.Controller.toggle('content');
        };

        this.render = function() { return explorer.render(); };
        this.create = function() { return this.render(); };
        this.pause = function() {};
        this.stop = function() {};
        this.destroy = function() {
            scroll.destroy();
            explorer.destroy();
            if (source) source.destroy();
        };
    }

    // =========================================================================
    // РЕГИСТРАЦИЯ КНОПКИ "ОНЛАЙН FX2" И НАСТРОЕК
    // =========================================================================
    function renderSettingsProfile() {
        var $box = $('[data-name="fxapi_profile"]');
        if (!$box.length) return;
        var st = Lampa.Storage.get('fxapi_status', {});
        if (st && st.login) {
            $box.html('<div style="padding:10px;background:rgba(255,255,255,0.1);border-radius:6px;"><b>Аккаунт:</b> ' + st.login + ' (' + (st.is_pro_plus ? 'PRO+' : 'PRO') + ') | <b>Авто-удержание:</b> Вкл (5/5 Auto-Delete)</div>');
        } else {
            $box.html('<div style="padding:10px;background:rgba(255,255,255,0.1);border-radius:6px;">Статус: Ожидание автопривязки при нажатии "Онлайн"</div>');
        }
    }

    function startPlugin() {
        Lampa.Component.add('online_fxapi2', OnlineFX2Component);

        var btn_html = '<div class="full-start__button selector view--online" data-subtitle="Filmix FX 2.0 Auto">' +
            '<svg width="135" height="147" viewBox="0 0 135 147" fill="none" xmlns="http://www.w3.org/2000/svg">' +
            '<path d="M121.5 96.8823C139.5 86.49 139.5 60.5092 121.5 50.1169L41.25 3.78454C23.25 -6.60776 0.750004 6.38265 0.750001 27.1673L0.75 51.9742C4.70314 35.7475 23.6209 26.8138 39.0547 35.7701L94.8534 68.1505C110.252 77.0864 111.909 97.8693 99.8725 109.369L121.5 96.8823Z" fill="currentColor"/>' +
            '<path d="M63 84.9836C80.3333 94.991 80.3333 120.01 63 130.017L39.75 143.44C22.4167 153.448 0.749999 140.938 0.75 120.924L0.750001 94.0769C0.750002 74.0621 22.4167 61.5528 39.75 71.5602L63 84.9836Z" fill="currentColor"/>' +
            '</svg>' +
            '<span>Онлайн FX2</span>' +
            '</div>';

        Lampa.Listener.follow('full', function(e) {
            if (e.type === 'complite') {
                var $btn = $(btn_html);
                $btn.on('hover:enter', function() {
                    Lampa.Activity.push({
                        url: '',
                        title: 'Онлайн - Filmix FX2',
                        component: 'online_fxapi2',
                        search: e.data.movie.title,
                        search_one: e.data.movie.title,
                        search_two: e.data.movie.original_title,
                        movie: e.data.movie,
                        page: 1
                    });
                });
                e.object.activity.render().find('.view--torrent').after($btn);
            }
        });

        Lampa.SettingsApi.addComponent({
            component: 'fxapi2',
            name: 'Filmix FX 2',
            icon: '<svg height="57" viewBox="0 0 58 57" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M20 20.3735V45H26.8281V34.1262H36.724V26.9806H26.8281V24.3916C26.8281 21.5955 28.9062 19.835 31.1823 19.835H39V13H26.8281C23.6615 13 20 15.4854 20 20.3735Z" fill="white"/><rect x="2" y="2" width="54" height="53" rx="5" stroke="white" stroke-width="4"/></svg>'
        });

        Lampa.Template.add('settings_fxapi2', '<div>' +
            '<div class="settings-param" data-name="fxapi_profile" data-static="true"></div>' +
            '<div class="settings-param selector" data-name="fxapi_force_rebind" data-static="true">' +
                '<div class="settings-param__name">Принудительно перепривязать устройство (Удалить 1 из 5/5 и добавить)</div>' +
            '</div>' +
        '</div>');

        Lampa.Settings.listener.follow('open', function(e) {
            if (e.name !== 'fxapi2') return;
            renderSettingsProfile();
            e.body.find('[data-name="fxapi_force_rebind"]').unbind('hover:enter').on('hover:enter', function() {
                AutoHealer.rebindDevice(function() {
                    renderSettingsProfile();
                }, function(err) {
                    Lampa.Noty.show(err);
                });
            });
        });
    }

    startPlugin();
})();
