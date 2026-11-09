(function() {
    'use strict';

    Lampa.Platform.tv();

    if (window.online_filmix_fx3) return;
    window.online_filmix_fx3 = true;

    var FX3_CONFIG = {
        login: 'hutgtghordi22',
        pass: 'rk3y0a371c4',
        site_url: 'https://filmix.gg',
        api_url: 'http://filmixapp.vip/api/v2/',
        default_proxy: 'http://fx.bylampa.online/proxy/',
        local_binder: 'http://127.0.0.1:8765/'
    };

    var uid = Lampa.Storage.get('fxapi_uid', '');
    if (!uid) {
        uid = Lampa.Utils.uid(16);
        Lampa.Storage.set('fxapi_uid', uid);
    }

    var proxy_url = Lampa.Storage.get('fxapi_proxy', FX3_CONFIG.default_proxy);
    if (proxy_url && proxy_url.charAt(proxy_url.length - 1) !== '/') proxy_url += '/';

    window.fxapi = {
        max_qualitie: 720,
        is_max_qualitie: false
    };

    var poll_timer = null;

    function getToken() {
        return Lampa.Storage.get('fxapi_token', '');
    }

    function buildDevParams(token) {
        var t = typeof token === 'string' ? token : getToken();
        return 'app_lang=ru_RU&user_dev_apk=2.2.13&user_dev_id=' + uid + '&user_dev_name=Lampa+FX3&user_dev_os=12&user_dev_token=' + t + '&user_dev_vendor=Lampa';
    }

    function getApiEndpoint(method) {
        return proxy_url + FX3_CONFIG.api_url + method;
    }

    // =========================================================================
    // АВТОМАТИЧЕСКОЕ УДЕРЖАНИЕ УСТРОЙСТВА И АВТО-УДАЛЕНИЕ 5/5 (AUTO-HEALER v3.0)
    // =========================================================================
    var AutoHealer = {
        is_healing: false,

        ensureDeviceBound: function(onReady, onError) {
            var self = this;
            var current_token = getToken();
            var net = new Lampa.Reguest();

            if (!current_token) {
                self.rebindDevice(onReady, onError);
                return;
            }

            net.timeout(6000);
            net.silent(Lampa.Utils.addUrlComponent(getApiEndpoint('user_profile'), buildDevParams(current_token)), function(json) {
                if (json && json.user_data && (json.user_data.login || json.user_data.is_pro || json.user_data.is_pro_plus)) {
                    updateQualityLimits(json.user_data);
                    Lampa.Storage.set('fxapi_status', json.user_data);
                    if (onReady) onReady();
                } else {
                    Lampa.Noty.show('FX3: Устройство не активно на Filmix! Привязываем...');
                    self.rebindDevice(onReady, onError);
                }
            }, function() {
                self.rebindDevice(onReady, onError);
            });
        },

        rebindDevice: function(onReady, onError) {
            var self = this;
            if (self.is_healing) return;
            self.is_healing = true;

            // Генерируем новый uid для чистого запроса кода без лимитов
            uid = Lampa.Utils.uid(16);
            Lampa.Storage.set('fxapi_uid', uid);

            var net = new Lampa.Reguest();
            net.timeout(10000);

            var req_url = Lampa.Utils.addUrlComponent(getApiEndpoint('token_request'), buildDevParams(''));
            net.quiet(req_url, function(data) {
                if (data && data.status === 'ok' && data.code && data.user_code) {
                    var new_token = data.code;
                    var user_code = data.user_code;
                    Lampa.Noty.show('FX3: Код [' + user_code + ']. Автоматическая привязка...');

                    self.tryAutoBindChannels(user_code, new_token, function(success) {
                        self.is_healing = false;
                        if (success) {
                            Lampa.Storage.set('fxapi_token', new_token);
                            Lampa.Noty.show('FX3: Устройство [' + user_code + '] успешно привязано (PRO+)!');
                            checkProfileAndUpdate(new_token, function() {
                                if (onReady) onReady();
                            });
                        } else {
                            self.openInteractiveCodeModal(user_code, new_token, onReady);
                        }
                    });
                } else {
                    self.is_healing = false;
                    var msg = (data && data.message) ? data.message : 'Не удалось получить код Filmix';
                    Lampa.Noty.show('FX3: ' + msg);
                    if (onError) onError(msg);
                }
            }, function() {
                self.is_healing = false;
                Lampa.Noty.show('FX3: Ошибка запроса к Filmix API');
                if (onError) onError('Ошибка запроса к Filmix API');
            });
        },

        tryAutoBindChannels: function(user_code, new_token, callback) {
            var self = this;
            var binder_url = Lampa.Storage.get('fxapi_binder', FX3_CONFIG.local_binder);
            if (binder_url && binder_url.charAt(binder_url.length - 1) !== '/') binder_url += '/';

            // Канал 1: Локальный помощник fx3_binder.py (127.0.0.1:8765/?code=XXXX)
            $.ajax({
                url: binder_url + '?code=' + encodeURIComponent(user_code),
                type: 'GET',
                dataType: 'json',
                timeout: 10000,
                success: function(res) {
                    if (res && res.status === 'ok') {
                        self.verifyTokenActive(new_token, callback);
                    } else {
                        self.tryDirectBrowserBind(user_code, new_token, callback);
                    }
                },
                error: function() {
                    self.tryDirectBrowserBind(user_code, new_token, callback);
                }
            });
        },

        tryDirectBrowserBind: function(user_code, new_token, callback) {
            var self = this;
            var base_url = FX3_CONFIG.site_url;

            // Шаг 1: GET /consoles (получение Cloudflare / session cookies)
            $.ajax({
                url: base_url + '/consoles',
                type: 'GET',
                timeout: 8000,
                xhrFields: { withCredentials: true },
                complete: function() {
                    // Шаг 2: Авторизация через user_auth.php
                    $.ajax({
                        url: base_url + '/engine/ajax/user_auth.php',
                        type: 'POST',
                        timeout: 8000,
                        xhrFields: { withCredentials: true },
                        data: {
                            login_name: FX3_CONFIG.login,
                            login_password: FX3_CONFIG.pass,
                            login_not_save: '1',
                            login: 'submit'
                        },
                        success: function(auth_text) {
                            // Шаг 3: Получение списка подключенных устройств
                            $.ajax({
                                url: base_url + '/adgvn/device/list',
                                type: 'GET',
                                dataType: 'json',
                                timeout: 8000,
                                xhrFields: { withCredentials: true },
                                success: function(dev_data) {
                                    var items = (dev_data && dev_data.items) ? dev_data.items : [];

                                    var doAdd = function() {
                                        // Шаг 5: Добавление нашего кода
                                        $.ajax({
                                            url: base_url + '/adgvn/device/add',
                                            type: 'POST',
                                            dataType: 'json',
                                            timeout: 8000,
                                            xhrFields: { withCredentials: true },
                                            data: { user_code: user_code },
                                            complete: function() {
                                                self.verifyTokenActive(new_token, callback);
                                            }
                                        });
                                    };

                                    // Шаг 4: Если 5/5 устройств занято - удаляем одно случайное
                                    if (items.length >= 5) {
                                        var rand_dev = items[Math.floor(Math.random() * items.length)];
                                        $.ajax({
                                            url: base_url + '/adgvn/device/remove',
                                            type: 'GET',
                                            dataType: 'json',
                                            timeout: 8000,
                                            xhrFields: { withCredentials: true },
                                            data: { id: rand_dev.id },
                                            complete: doAdd
                                        });
                                    } else {
                                        doAdd();
                                    }
                                },
                                error: function() {
                                    callback(false);
                                }
                            });
                        },
                        error: function() {
                            callback(false);
                        }
                    });
                }
            });
        },

        verifyTokenActive: function(token, callback) {
            var net = new Lampa.Reguest();
            net.timeout(6000);
            net.silent(Lampa.Utils.addUrlComponent(getApiEndpoint('user_profile'), buildDevParams(token)), function(res) {
                if (res && res.user_data && (res.user_data.login || res.user_data.is_pro || res.user_data.is_pro_plus)) {
                    callback(true);
                } else {
                    setTimeout(function() {
                        net.silent(Lampa.Utils.addUrlComponent(getApiEndpoint('user_profile'), buildDevParams(token)), function(res2) {
                            callback(!!(res2 && res2.user_data && (res2.user_data.login || res2.user_data.is_pro || res2.user_data.is_pro_plus)));
                        }, function() {
                            callback(false);
                        });
                    }, 1500);
                }
            }, function() {
                callback(false);
            });
        },

        openInteractiveCodeModal: function(user_code, new_token, onReady) {
            var net = new Lampa.Reguest();
            var controller_name = Lampa.Controller.enabled().name;

            Lampa.Utils.copyTextToClipboard(user_code, function() {
                Lampa.Noty.show('Код ' + user_code + ' скопирован в буфер!');
            }, function() {});

            var $html = $(
                '<div>' +
                    '<div class="broadcast__text" style="font-size: 1.1em; line-height: 1.4;">Код <b>' + user_code + '</b> скопирован в буфер обмена.<br>' +
                    'Для завершения вставьте его на <b>filmix.gg/consoles</b> (аккаунт: <b>' + FX3_CONFIG.login + '</b>):</div>' +
                    '<div class="broadcast__device selector" style="text-align: center; font-size: 2.5em; font-weight: bold; letter-spacing: 5px; margin: 15px 0; padding: 12px; background: rgba(255,255,255,0.12); border-radius: 8px; color: #fff;">' + user_code + '</div>' +
                    '<div class="broadcast__text" style="opacity: 0.8; font-size: 0.9em; text-align: center;">Ожидание привязки... Окно закроется автоматически сразу после привязки!</div>' +
                    '<br><div class="broadcast__scan"><div></div></div>' +
                '</div>'
            );

            Lampa.Modal.open({
                title: 'Привязка Filmix FX 3',
                html: $html,
                onBack: function() {
                    Lampa.Modal.close();
                    clearInterval(poll_timer);
                    Lampa.Controller.toggle(controller_name);
                },
                onSelect: function() {
                    Lampa.Utils.copyTextToClipboard(user_code, function() {
                        Lampa.Noty.show('Код ' + user_code + ' скопирован!');
                    });
                }
            });

            clearInterval(poll_timer);
            poll_timer = setInterval(function() {
                net.silent(Lampa.Utils.addUrlComponent(getApiEndpoint('user_profile'), buildDevParams(new_token)), function(res) {
                    if (res && res.user_data && (res.user_data.login || res.user_data.is_pro || res.user_data.is_pro_plus)) {
                        clearInterval(poll_timer);
                        Lampa.Modal.close();
                        Lampa.Storage.set('fxapi_token', new_token);
                        updateQualityLimits(res.user_data);
                        Lampa.Storage.set('fxapi_status', res.user_data);
                        Lampa.Noty.show('FX3: Устройство активировано! Приятного просмотра...');
                        Lampa.Controller.toggle(controller_name);
                        if (onReady) onReady();
                    }
                }, function() {});
            }, 1500);
        }
    };

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
    // ИСТОЧНИК ДАННЫХ FILMIX FX3
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
                    component.empty('Контент найден, но ссылки недоступны. Проверьте привязку устройства.');
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
                        Lampa.Noty.show(Lampa.Lang.translate('online_nolink'));
                    }
                },
                onContextMenu: function(item, _html, _data, call) {
                    call(getStreamFile(item, item.quality));
                }
            });
        }
    }

    // =========================================================================
    // ПОЛНЫЙ КОМПОНЕНТ ОТОБРАЖЕНИЯ В LAMPA
    // =========================================================================
    function OnlineFX3Component(object) {
        var network = new Lampa.Reguest();
        var scroll = new Lampa.Scroll({ mask: true, over: true });
        var explorer = new Lampa.Explorer(object);
        var filter = new Lampa.Filter(object);
        var source = null;
        var last_focused = false;
        var initialized = false;
        var active_id = 0;
        var loaded_images = [];

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

            this.activity.loader(true);
            AutoHealer.ensureDeviceBound(function() {
                self.search();
            }, function(err_msg) {
                Lampa.Noty.show(err_msg || 'FX3: Ошибка привязки');
                self.search();
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
            var item = ch[active_id || object.movie.id] || {};
            Lampa.Arrays.extend(item, { season: 0, voice: 0, voice_name: '', voice_id: 0, episodes_view: {}, movie_view: '' });
            return item;
        };

        this.saveChoice = function(ch) {
            var all = Lampa.Storage.cache('online_choice_fxapi', 3000, {});
            all[active_id || object.movie.id] = ch;
            Lampa.Storage.set('online_choice_fxapi', all);
        };

        this.similars = function(json) {
            var self = this;
            json.forEach(function(elem) {
                var info_arr = [];
                var year = ((elem.start_date || elem.year || '') + '').slice(0, 4);
                if (elem.rating && elem.rating !== 'null' && elem.filmId) {
                    info_arr.push(Lampa.Template.get('online_prestige_rate', { rate: elem.rating }, true));
                }
                if (year) info_arr.push(year);
                if (elem.categories && elem.categories.length) {
                    info_arr.push(elem.categories.slice(0, 4).join(', '));
                }
                var ru_t = elem.title || elem.ru_title || elem.en_title || elem.nameRu || elem.nameEn;
                var orig_t = elem.original_title || elem.nameEn || '';
                elem.title = ru_t + (orig_t && orig_t !== ru_t ? ' / ' + orig_t : '');
                elem.time = elem.filmLength || '';
                elem.info = info_arr.join('<span class="online-prestige-split">●</span>');

                var folder = Lampa.Template.get('online_prestige_folder', elem);
                folder.on('hover:enter', function() {
                    self.activity.loader(true);
                    self.reset();
                    object.search_date = year;
                    active_id = elem.id;
                    source.extendChoice(self.getChoice());
                    source.search(object, [elem]);
                }).on('hover:focus', function(e) {
                    last_focused = e.target;
                    scroll.update($(e.target), true);
                });
                scroll.append(folder);
            });
        };

        this.clearImages = function() {
            loaded_images.forEach(function(img) {
                img.onerror = function() {};
                img.onload = function() {};
                img.src = '';
            });
            loaded_images = [];
        };

        this.reset = function() {
            last_focused = false;
            network.clear();
            this.clearImages();
            scroll.render().find('.empty').remove();
            scroll.clear();
        };

        this.filter = function(f_items, ch) {
            var self = this;
            var list = [{ title: Lampa.Lang.translate('torrent_parser_reset'), reset: true }];
            this.saveChoice(ch);
            var addGroup = function(stype, title) {
                var saved = self.getChoice();
                var vals = f_items[stype];
                var sub = [];
                var sel_idx = saved[stype];
                vals.forEach(function(v, i) {
                    sub.push({ title: v, selected: sel_idx == i, index: i });
                });
                list.push({ title: title, subtitle: vals[sel_idx], items: sub, stype: stype });
            };
            if (f_items.voice && f_items.voice.length) addGroup('voice', Lampa.Lang.translate('torrent_parser_voice'));
            if (f_items.season && f_items.season.length) addGroup('season', Lampa.Lang.translate('torrent_serial_season'));
            filter.set('filter', list);

            var chosen = [];
            if (f_items.voice && f_items.voice.length) chosen.push(Lampa.Lang.translate('torrent_parser_voice') + ': ' + f_items.voice[ch.voice]);
            if (f_items.season && f_items.season.length) chosen.push(Lampa.Lang.translate('torrent_serial_season') + ': ' + f_items.season[ch.season]);
            filter.chosen('filter', chosen);
            filter.chosen('sort', ['fxapi']);
        };

        this.getEpisodes = function(season_num, call) {
            var episodes = [];
            if (typeof object.movie.id === 'number' && object.movie.name) {
                var tmdb_q = 'tv/' + object.movie.id + '/season/' + season_num + '?api_key=' + Lampa.TMDB.key() + '&language=' + Lampa.Storage.get('language', 'ru');
                var tmdb_url = Lampa.TMDB.api(tmdb_q);
                network.timeout(10000);
                network.silent(tmdb_url, function(data) {
                    episodes = data.episodes || [];
                    call(episodes);
                }, function() {
                    call(episodes);
                });
            } else {
                call(episodes);
            }
        };

        this.getLastEpisode = function(list) {
            var last = 0;
            list.forEach(function(e) {
                if (typeof e.episode !== 'undefined') last = Math.max(last, parseInt(e.episode, 10));
            });
            return last;
        };

        this.watched = function(set_data) {
            var file_hash = Lampa.Utils.hash(object.movie.number_of_seasons ? object.movie.original_name : object.movie.original_title);
            var watched_all = Lampa.Storage.cache('online_watched_last', 5000, {});
            if (set_data) {
                if (!watched_all[file_hash]) watched_all[file_hash] = {};
                Lampa.Arrays.extend(watched_all[file_hash], set_data, true);
                Lampa.Storage.set('online_watched_last', watched_all);
            } else {
                return watched_all[file_hash];
            }
        };

        this.draw = function(items, params) {
            var self = this;
            params = params || {};
            if (!items.length) return this.empty();

            this.getEpisodes(items[0].season, function(tmdb_eps) {
                var viewed = Lampa.Storage.cache('online_view', 5000, []);
                var is_serial = !!object.movie.name;
                var choice = self.getChoice();
                var wide = window.innerWidth > 480;
                var scroll_to_element = false;
                var scroll_to_mark = false;

                items.forEach(function(el, index) {
                    var tmdb_ep = is_serial && tmdb_eps.length && !params.similars ? tmdb_eps.find(function(e) {
                        return e.episode_number == el.episode;
                    }) : false;
                    var ep_num = el.episode || index + 1;
                    var last_ep_viewed = choice.episodes_view[el.season];

                    Lampa.Arrays.extend(el, {
                        info: '',
                        quality: '',
                        time: Lampa.Utils.secondsToTime((tmdb_ep ? tmdb_ep.runtime : object.movie.runtime) * 60, true)
                    });

                    var hash_tl = Lampa.Utils.hash(el.season ? [el.season, el.episode, object.movie.original_title].join('') : object.movie.original_title);
                    var hash_behold = Lampa.Utils.hash(el.season ? [el.season, el.episode, object.movie.original_title, el.voice_name].join('') : object.movie.original_title + el.voice_name);
                    var hashes = { hash_timeline: hash_tl, hash_behold: hash_behold };
                    var meta_tags = [];

                    if (el.season) {
                        el.translate_episode_end = self.getLastEpisode(items);
                        el.translate_voice = el.voice_name;
                    }
                    el.timeline = Lampa.Timeline.view(hash_tl);

                    if (tmdb_ep) {
                        el.title = tmdb_ep.name;
                        if (el.info.length < 30 && tmdb_ep.vote_average) {
                            meta_tags.push(Lampa.Template.get('online_prestige_rate', { rate: parseFloat(tmdb_ep.vote_average + '').toFixed(1) }, true));
                        }
                        if (tmdb_ep.air_date && wide) {
                            meta_tags.push(Lampa.Utils.parseTime(tmdb_ep.air_date).full);
                        }
                    } else if (object.movie.release_date && wide) {
                        meta_tags.push(Lampa.Utils.parseTime(object.movie.release_date).full);
                    }

                    if (!is_serial && object.movie.tagline && el.info.length < 30) {
                        meta_tags.push(object.movie.tagline);
                    }
                    if (el.info) meta_tags.push(el.info);
                    if (meta_tags.length) {
                        el.info = meta_tags.map(function(t) { return '<span>' + t + '</span>'; }).join('<span class="online-prestige-split">●</span>');
                    }

                    var card = Lampa.Template.get('online_prestige_full', el);
                    var loader = card.find('.online-prestige__loader');
                    var img_box = card.find('.online-prestige__img');

                    if (!is_serial) {
                        if (choice.movie_view == hash_behold) scroll_to_element = card;
                    } else if (typeof last_ep_viewed !== 'undefined' && last_ep_viewed == ep_num) {
                        scroll_to_element = card;
                    }

                    if (is_serial && !tmdb_ep) {
                        img_box.append('<div class="online-prestige__episode-number">' + ('0' + (el.episode || index + 1)).slice(-2) + '</div>');
                        loader.remove();
                    } else {
                        var img = card.find('img')[0];
                        img.onerror = function() { img.src = './img/img_broken.svg'; };
                        img.onload = function() {
                            img_box.addClass('online-prestige__img--loaded');
                            loader.remove();
                            if (is_serial) {
                                img_box.append('<div class="online-prestige__episode-number">' + ('0' + (el.episode || index + 1)).slice(-2) + '</div>');
                            }
                        };
                        img.src = Lampa.TMDB.image('t/p/w300' + (tmdb_ep ? tmdb_ep.still_path : object.movie.backdrop_path));
                        loaded_images.push(img);
                    }

                    card.find('.online-prestige__timeline').append(Lampa.Timeline.render(el.timeline));

                    if (viewed.indexOf(hash_behold) !== -1) {
                        scroll_to_mark = card;
                        img_box.append('<div class="online-prestige__viewed">' + Lampa.Template.get('icon_viewed', {}, true) + '</div>');
                    }

                    el.mark = function() {
                        viewed = Lampa.Storage.cache('online_view', 5000, []);
                        if (viewed.indexOf(hash_behold) === -1) {
                            viewed.push(hash_behold);
                            Lampa.Storage.set('online_view', viewed);
                            if (card.find('.online-prestige__viewed').length === 0) {
                                img_box.append('<div class="online-prestige__viewed">' + Lampa.Template.get('icon_viewed', {}, true) + '</div>');
                            }
                        }
                        choice = self.getChoice();
                        if (!is_serial) choice.movie_view = hash_behold;
                        else choice.episodes_view[el.season] = ep_num;
                        self.saveChoice(choice);
                        self.watched({
                            balanser: 'fxapi',
                            balanser_name: 'Filmix FX3',
                            voice_id: choice.voice_id,
                            voice_name: choice.voice_name || el.voice_name,
                            episode: el.episode,
                            season: el.season
                        });
                    };

                    el.unmark = function() {
                        viewed = Lampa.Storage.cache('online_view', 5000, []);
                        if (viewed.indexOf(hash_behold) !== -1) {
                            Lampa.Arrays.remove(viewed, hash_behold);
                            Lampa.Storage.set('online_view', viewed);
                            if (Lampa.Manifest.app_digital >= 177) Lampa.Storage.remove('online_view', hash_behold);
                            card.find('.online-prestige__viewed').remove();
                        }
                    };

                    el.timeclear = function() {
                        el.timeline.percent = 0;
                        el.timeline.time = 0;
                        el.timeline.duration = 0;
                        Lampa.Timeline.update(el.timeline);
                    };

                    card.on('hover:enter', function() {
                        if (object.movie.id) Lampa.Favorite.add('history', object.movie, 100);
                        if (params.onEnter) params.onEnter(el, card, hashes);
                    }).on('hover:focus', function(e) {
                        last_focused = e.target;
                        if (params.onFocus) params.onFocus(el, card, hashes);
                        scroll.update($(e.target), true);
                    });

                    if (params.onRender) params.onRender(el, card, hashes);

                    self.contextMenu({
                        html: card,
                        element: el,
                        onFile: function(call) {
                            if (params.onContextMenu) params.onContextMenu(el, card, hashes, call);
                        },
                        onClearAllMark: function() {
                            items.forEach(function(it) { it.unmark(); });
                        },
                        onClearAllTime: function() {
                            items.forEach(function(it) { it.timeclear(); });
                        }
                    });

                    scroll.append(card);
                });

                if (scroll_to_element) last_focused = scroll_to_element[0];
                else if (scroll_to_mark) last_focused = scroll_to_mark[0];

                Lampa.Controller.enable('content');
            });
        };

        this.contextMenu = function(data) {
            data.html.on('hover:long', function() {
                function showMenu(file_data) {
                    var enabled = Lampa.Controller.enabled().name;
                    var menu = [];
                    if (Lampa.Platform.is('webos')) {
                        menu.push({ title: Lampa.Lang.translate('player_lauch') + ' - WebOS', player: 'webos' });
                    }
                    if (Lampa.Platform.is('android')) {
                        menu.push({ title: Lampa.Lang.translate('player_lauch') + ' - Android', player: 'android' });
                    }
                    menu.push({ title: Lampa.Lang.translate('player_lauch') + ' - Lampa', player: 'lampa' });
                    menu.push({ title: Lampa.Lang.translate('online_video'), separator: true });
                    menu.push({ title: Lampa.Lang.translate('torrent_parser_label_title'), mark: true });
                    menu.push({ title: Lampa.Lang.translate('torrent_parser_label_cancel_title'), unmark: true });
                    menu.push({ title: Lampa.Lang.translate('time_reset'), timeclear: true });

                    if (file_data) {
                        menu.push({ title: Lampa.Lang.translate('copy_link'), copylink: true });
                    }
                    menu.push({ title: Lampa.Lang.translate('more'), separator: true });
                    menu.push({ title: 'Принудительно перепривязать устройство (FX3)', fx3_rebind: true });
                    menu.push({ title: Lampa.Lang.translate('online_clear_all_marks'), clearallmark: true });
                    menu.push({ title: Lampa.Lang.translate('online_clear_all_timecodes'), timeclearall: true });

                    Lampa.Select.show({
                        title: Lampa.Lang.translate('title_action'),
                        items: menu,
                        onBack: function() {
                            Lampa.Controller.toggle(enabled);
                        },
                        onSelect: function(a) {
                            if (a.mark) data.element.mark();
                            if (a.unmark) data.element.unmark();
                            if (a.timeclear) data.element.timeclear();
                            if (a.clearallmark) data.onClearAllMark();
                            if (a.timeclearall) data.onClearAllTime();
                            Lampa.Controller.toggle(enabled);

                            if (a.fx3_rebind) {
                                AutoHealer.rebindDevice(function() {
                                    Lampa.Noty.show('FX3: Перепривязка завершена!');
                                }, function(err) {
                                    Lampa.Noty.show(err);
                                });
                            }
                            if (a.player) {
                                Lampa.Player.runas(a.player);
                                data.html.trigger('hover:enter');
                            }
                            if (a.copylink) {
                                if (file_data.quality) {
                                    var quals = [];
                                    for (var q in file_data.quality) {
                                        quals.push({ title: q, file: file_data.quality[q] });
                                    }
                                    Lampa.Select.show({
                                        title: Lampa.Lang.translate('settings_server_links'),
                                        items: quals,
                                        onBack: function() { Lampa.Controller.toggle(enabled); },
                                        onSelect: function(b) {
                                            Lampa.Utils.copyTextToClipboard(b.file, function() {
                                                Lampa.Noty.show(Lampa.Lang.translate('copy_secuses'));
                                            }, function() {
                                                Lampa.Noty.show(Lampa.Lang.translate('copy_error'));
                                            });
                                        }
                                    });
                                } else {
                                    Lampa.Utils.copyTextToClipboard(file_data.file, function() {
                                        Lampa.Noty.show(Lampa.Lang.translate('copy_secuses'));
                                    }, function() {
                                        Lampa.Noty.show(Lampa.Lang.translate('copy_error'));
                                    });
                                }
                            }
                        }
                    });
                }
                data.onFile(showMenu);
            }).on('hover:focus', function() {
                if (Lampa.Helper) Lampa.Helper.show('online_file', Lampa.Lang.translate('helper_online_file'), data.html);
            });
        };

        this.empty = function(msg) {
            var tpl = Lampa.Template.get('online_does_not_answer', { balanser: 'fxapi' });
            tpl.find('.online-empty__buttons').remove();
            tpl.find('.online-empty__title').text(msg || Lampa.Lang.translate('empty_title_two'));
            scroll.append(tpl);
            this.loading(false);
        };

        this.doesNotAnswer = function() {
            this.reset();
            var tpl = Lampa.Template.get('online_does_not_answer', { balanser: 'fxapi' });
            scroll.append(tpl);
            this.loading(false);
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
            network.clear();
            this.clearImages();
            explorer.destroy();
            scroll.destroy();
            clearInterval(poll_timer);
            if (source && source.destroy) source.destroy();
        };
    }

    // =========================================================================
    // ШАБЛОНЫ, СТИЛИ, ПЕРЕВОДЫ И НАСТРОЙКИ РАСШИРЕНИЯ FILMIX FX 3
    // =========================================================================
    function renderSettingsProfile() {
        var $box = $('[data-name="fxapi_profile"]');
        if (!$box.length) return;
        var st = Lampa.Storage.get('fxapi_status', {});
        var cur_token = getToken();
        if (st && (st.login || st.is_pro || st.is_pro_plus)) {
            var badge = st.is_pro_plus ? 'PRO+' : (st.is_pro ? 'PRO' : 'FREE');
            $box.html(
                '<div class="fxapi-profile"><div class="fxapi-profile__wrap">' +
                '<div class="fxapi-profile__avatar"><div class="fxapi-profile__placeholder">' + (FX3_CONFIG.login.charAt(0).toUpperCase()) + '</div></div>' +
                '<div class="fxapi-profile__body">' +
                '<div class="fxapi-profile__title">' + (st.login || FX3_CONFIG.login) + ' (FX 3.1 Auto-Hold)</div>' +
                '<div class="fxapi-profile__meta">' +
                '<div class="fxapi-profile__badge">' + badge + '</div><br>' +
                'Макс. качество: <b>' + window.fxapi.max_qualitie + 'p</b><br>' +
                'Бот 5/5 Auto-Delete: <b>127.0.0.1:8765 (' + FX3_CONFIG.login + ')</b><br>' +
                'Токен: <b>' + (cur_token ? cur_token.slice(0, 10) + '...' : 'Авто') + '</b>' +
                '</div></div></div></div>'
            );
        } else {
            $box.html('<div class="fxapi-profile fxapi-profile--empty">Устройство не привязано. Нажмите «Онлайн» или кнопку автопривязки ниже (' + FX3_CONFIG.login + ')</div>');
        }
    }

    function registerTemplatesAndLocales() {
        Lampa.Lang.add({
            online_watch: { ru: 'Смотреть онлайн', en: 'Watch online', ua: 'Дивитися онлайн' },
            online_video: { ru: 'Видео', en: 'Video', ua: 'Відео' },
            online_nolink: { ru: 'Не удалось извлечь ссылку', uk: 'Неможливо отримати посилання', en: 'Failed to fetch link' },
            helper_online_file: { ru: 'Удерживайте клавишу "ОК" для вызова контекстного меню', uk: 'Утримуйте клавішу "ОК" для виклику контекстного меню', en: 'Hold the "OK" key to bring up the context menu' },
            title_online: { ru: 'Онлайн', uk: 'Онлайн', en: 'Online' },
            copy_secuses: { ru: 'Код скопирован в буфер обмена', uk: 'Код скопійовано в буфер обміну', en: 'Code copied to clipboard' },
            copy_fail: { ru: 'Ошибка при копировании', uk: 'Помилка при копіюванні', en: 'Copy error' },
            online_clear_all_marks: { ru: 'Очистить все метки', uk: 'Очистити всі мітки', en: 'Clear all labels' },
            online_clear_all_timecodes: { ru: 'Очистить все тайм-коды', uk: 'Очистити всі тайм-коди', en: 'Clear all timecodes' },
            online_balanser_dont_work: { ru: 'Поиск не дал результатов', uk: 'Пошук не дав результатів', en: 'The search did not return any results' }
        });

        Lampa.Template.add('fxapi_profile_css', '<style>.fxapi-profile{margin:1em 0;padding:1em;background:rgba(255,255,255,.08);border-radius:.6em;line-height:1.35}.fxapi-profile--empty{opacity:.75;padding:1.2em 1em}.fxapi-profile__wrap{display:flex;gap:1em;align-items:center}.fxapi-profile__avatar{width:4.5em;height:4.5em;border-radius:50%;overflow:hidden;background:rgba(0,0,0,.35);flex-shrink:0;display:flex;align-items:center;justify-content:center}.fxapi-profile__placeholder{font-size:1.8em;font-weight:600;text-transform:uppercase}.fxapi-profile__title{font-size:1.25em;font-weight:600}.fxapi-profile__meta{opacity:.85;font-size:.92em;margin-top:.45em}.fxapi-profile__badge{display:inline-block;margin-bottom:.35em;padding:.15em .55em;border-radius:.3em;background:rgba(117,199,27,.35);font-size:.88em;font-weight:600}</style>');
        $('body').append(Lampa.Template.get('fxapi_profile_css', {}, true));

        Lampa.Template.add('online_prestige_css', '<style>.online-prestige{position:relative;border-radius:.3em;background-color:rgba(0,0,0,0.3);display:flex;will-change:transform}.online-prestige__body{padding:1.2em;line-height:1.3;flex-grow:1;position:relative}@media screen and (max-width:480px){.online-prestige__body{padding:.8em 1.2em}}.online-prestige__img{position:relative;width:13em;flex-shrink:0;min-height:8.2em}.online-prestige__img>img{position:absolute;top:0;left:0;width:100%;height:100%;object-fit:cover;border-radius:.3em;opacity:0;transition:opacity .3s}.online-prestige__img--loaded>img{opacity:1}@media screen and (max-width:480px){.online-prestige__img{width:7em;min-height:6em}}.online-prestige__folder{padding:1em;flex-shrink:0}.online-prestige__folder>svg{width:4.4em !important;height:4.4em !important}.online-prestige__viewed{position:absolute;top:1em;left:1em;background:rgba(0,0,0,0.45);border-radius:100%;padding:.25em;font-size:.76em}.online-prestige__viewed>svg{width:1.5em !important;height:1.5em !important}.online-prestige__episode-number{position:absolute;top:0;left:0;right:0;bottom:0;display:flex;align-items:center;justify-content:center;font-size:2em}.online-prestige__loader{position:absolute;top:50%;left:50%;width:2em;height:2em;margin-left:-1em;margin-top:-1em;background:url(./img/loader.svg) no-repeat center center;background-size:contain}.online-prestige__head,.online-prestige__footer{display:flex;justify-content:space-between;align-items:center}.online-prestige__timeline{margin:.8em 0}.online-prestige__timeline>.time-line{display:block !important}.online-prestige__title{font-size:1.7em;overflow:hidden;text-overflow:ellipsis;display:-webkit-box;-webkit-line-clamp:1;line-clamp:1;-webkit-box-orient:vertical}@media screen and (max-width:480px){.online-prestige__title{font-size:1.4em}}.online-prestige__time{padding-left:2em}.online-prestige__info{display:flex;align-items:center}.online-prestige__info>*{overflow:hidden;text-overflow:ellipsis;display:-webkit-box;-webkit-line-clamp:1;line-clamp:1;-webkit-box-orient:vertical}.online-prestige__quality{padding-left:1em;white-space:nowrap}.online-prestige .online-prestige-split{font-size:.8em;margin:0 1em;flex-shrink:0}.online-prestige.focus::after{content:\'\';position:absolute;top:-0.6em;left:-0.6em;right:-0.6em;bottom:-0.6em;border-radius:.7em;border:solid .3em #fff;z-index:-1;pointer-events:none}.online-prestige+.online-prestige{margin-top:1.5em}.online-prestige--folder .online-prestige__footer{margin-top:.8em}.online-prestige-rate{display:inline-flex;align-items:center}.online-prestige-rate>svg{width:1.3em !important;height:1.3em !important}.online-prestige-rate>span{font-weight:600;font-size:1.1em;padding-left:.7em}.online-empty{line-height:1.4}.online-empty__title{font-size:2em;margin-bottom:.9em}.online-empty-template{background-color:rgba(255,255,255,0.3);padding:1em;display:flex;align-items:center;border-radius:.3em}.online-empty-template>*{background:rgba(0,0,0,0.3);border-radius:.3em}.online-empty-template__ico{width:4em;height:4em;margin-right:2.4em}.online-empty-template__body{height:1.7em;width:70%}.online-empty-template+.online-empty-template{margin-top:1em}</style>');
        $('body').append(Lampa.Template.get('online_prestige_css', {}, true));

        Lampa.Template.add('online_prestige_full', '<div class="online-prestige online-prestige--full selector"><div class="online-prestige__img"><img alt=""><div class="online-prestige__loader"></div></div><div class="online-prestige__body"><div class="online-prestige__head"><div class="online-prestige__title">{title}</div><div class="online-prestige__time">{time}</div></div><div class="online-prestige__timeline"></div><div class="online-prestige__footer"><div class="online-prestige__info">{info}</div><div class="online-prestige__quality">{quality}</div></div></div></div>');
        Lampa.Template.add('online_prestige_folder', '<div class="online-prestige online-prestige--folder selector"><div class="online-prestige__folder"><svg viewBox="0 0 128 112" fill="none" xmlns="http://www.w3.org/2000/svg"><rect y="20" width="128" height="92" rx="13" fill="white"></rect><path d="M29.9963 8H98.0037C96.0446 3.3021 91.4079 0 86 0H42C36.5921 0 31.9555 3.3021 29.9963 8Z" fill="white" fill-opacity="0.23"></path><rect x="11" y="8" width="106" height="76" rx="13" fill="white" fill-opacity="0.51"></rect></svg></div><div class="online-prestige__body"><div class="online-prestige__head"><div class="online-prestige__title">{title}</div><div class="online-prestige__time">{time}</div></div><div class="online-prestige__footer"><div class="online-prestige__info">{info}</div></div></div></div>');
        Lampa.Template.add('online_does_not_answer', '<div class="online-empty"><div class="online-empty__title" style="font-size: 2em; margin-bottom: .9em;">#{online_balanser_dont_work}</div><div class="online-empty__templates"><div class="online-empty-template"><div class="online-empty-template__ico"></div><div class="online-empty-template__body"></div></div><div class="online-empty-template"><div class="online-empty-template__ico"></div><div class="online-empty-template__body"></div></div><div class="online-empty-template"><div class="online-empty-template__ico"></div><div class="online-empty-template__body"></div></div></div></div>');
        Lampa.Template.add('online_prestige_rate', '<div class="online-prestige-rate"><svg width="17" height="16" viewBox="0 0 17 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M8.39409 0.192139L10.99 5.30994L16.7882 6.20387L12.5475 10.4277L13.5819 15.9311L8.39409 13.2425L3.20626 15.9311L4.24065 10.4277L0 6.20387L5.79819 5.30994L8.39409 0.192139Z" fill="#fff"></path></svg><span>{rate}</span></div>');
    }

    function startPlugin() {
        registerTemplatesAndLocales();

        var plugin_manifest = {
            type: 'video',
            version: '3.0.0',
            name: 'Онлайн - Filmix FX3',
            description: 'Автоматическое удержание устройства в filmix.gg/consoles',
            component: 'online_fxapi',
            onContextMenu: function() {
                return { name: Lampa.Lang.translate('online_watch') + ' (FX3)', description: '' };
            },
            onContextLauch: function(movie_card) {
                Lampa.Component.add('online_fxapi', OnlineFX3Component);
                Lampa.Activity.push({
                    url: '',
                    title: Lampa.Lang.translate('title_online') + ' - FX3',
                    component: 'online_fxapi',
                    search: movie_card.title,
                    search_one: movie_card.title,
                    search_two: movie_card.original_title,
                    movie: movie_card,
                    page: 1
                });
            }
        };

        Lampa.Manifest.plugins = plugin_manifest;
        Lampa.Component.add('online_fxapi', OnlineFX3Component);

        var btn_html = '<div class="full-start__button selector view--online" data-subtitle="Filmix FX v3.0 Auto">' +
            '<svg width="135" height="147" viewBox="0 0 135 147" fill="none" xmlns="http://www.w3.org/2000/svg">' +
            '<path d="M121.5 96.8823C139.5 86.49 139.5 60.5092 121.5 50.1169L41.25 3.78454C23.25 -6.60776 0.750004 6.38265 0.750001 27.1673L0.75 51.9742C4.70314 35.7475 23.6209 26.8138 39.0547 35.7701L94.8534 68.1505C110.252 77.0864 111.909 97.8693 99.8725 109.369L121.5 96.8823Z" fill="currentColor"/>' +
            '<path d="M63 84.9836C80.3333 94.991 80.3333 120.01 63 130.017L39.75 143.44C22.4167 153.448 0.749999 140.938 0.75 120.924L0.750001 94.0769C0.750002 74.0621 22.4167 61.5528 39.75 71.5602L63 84.9836Z" fill="currentColor"/>' +
            '</svg>' +
            '<span>#{title_online}</span>' +
            '</div>';

        Lampa.Listener.follow('full', function(e) {
            if (e.type === 'complite') {
                var $btn = $(Lampa.Lang.translate(btn_html));
                $btn.on('hover:enter', function() {
                    Lampa.Component.add('online_fxapi', OnlineFX3Component);
                    Lampa.Activity.push({
                        url: '',
                        title: Lampa.Lang.translate('title_online'),
                        component: 'online_fxapi',
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

        Lampa.Params.select('fxapi_token', '', '');
        Lampa.Params.select('fxapi_proxy', FX3_CONFIG.default_proxy, '');
        Lampa.Params.select('fxapi_binder', FX3_CONFIG.local_binder, '');

        Lampa.SettingsApi.addComponent({
            component: 'fxapi',
            name: 'Filmix FX 3',
            icon: '<svg height="57" viewBox="0 0 58 57" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M20 20.3735V45H26.8281V34.1262H36.724V26.9806H26.8281V24.3916C26.8281 21.5955 28.9062 19.835 31.1823 19.835H39V13H26.8281C23.6615 13 20 15.4854 20 20.3735Z" fill="white"/><rect x="2" y="2" width="54" height="53" rx="5" stroke="white" stroke-width="4"/></svg>'
        });

        Lampa.Template.add('settings_fxapi', '<div>' +
            '<div class="settings-param" data-name="fxapi_profile" data-static="true"></div>' +
            '<div class="settings-param selector" data-name="fxapi_add" data-static="true">' +
                '<div class="settings-param__name">Привязать устройство (Авто-бот 5/5 или по коду)</div>' +
                '<div class="settings-param__descr">Аккаунт: ' + FX3_CONFIG.login + '</div>' +
            '</div>' +
            '<div class="settings-param selector" data-name="fxapi_refresh" data-static="true">' +
                '<div class="settings-param__name">Проверить и обновить профиль Filmix</div>' +
            '</div>' +
            '<div class="settings-param selector" data-name="fxapi_binder" data-type="input" placeholder="http://127.0.0.1:8765/">' +
                '<div class="settings-param__name">Адрес локального бота автопривязки (fx3_server.py)</div>' +
                '<div class="settings-param__value"></div>' +
            '</div>' +
            '<div class="settings-param selector" data-name="fxapi_token" data-type="input" placeholder="Токен подставляется автоматически">' +
                '<div class="settings-param__name">Текущий ТОКЕН Filmix</div>' +
                '<div class="settings-param__value"></div>' +
            '</div>' +
        '</div>');

        Lampa.Storage.listener.follow('change', function(e) {
            if (e.name === 'fxapi_proxy') {
                proxy_url = e.value || FX3_CONFIG.default_proxy;
                if (proxy_url && proxy_url.charAt(proxy_url.length - 1) !== '/') proxy_url += '/';
            }
            if (e.name === 'fxapi_token') {
                window.fxapi.is_max_qualitie = false;
                if (e.value) checkProfileAndUpdate(e.value);
                else renderSettingsProfile();
            }
        });

        Lampa.Settings.listener.follow('open', function(e) {
            if (e.name !== 'fxapi') return;
            renderSettingsProfile();
            var t = getToken();
            if (t) checkProfileAndUpdate(t);

            e.body.find('[data-name="fxapi_refresh"]').unbind('hover:enter').on('hover:enter', function() {
                AutoHealer.ensureDeviceBound(function() {
                    renderSettingsProfile();
                    Lampa.Noty.show('FX3: Устройство активно!');
                }, function(err) {
                    Lampa.Noty.show(err);
                });
            });

            e.body.find('[data-name="fxapi_add"]').unbind('hover:enter').on('hover:enter', function() {
                AutoHealer.rebindDevice(function() {
                    var new_t = getToken();
                    e.body.find('[data-name="fxapi_token"] .settings-param__value').text(new_t);
                    renderSettingsProfile();
                }, function(err) {
                    Lampa.Noty.show(err);
                });
            });
        });

        var init_token = getToken();
        if (init_token) checkProfileAndUpdate(init_token);

        if (Lampa.Manifest.app_digital >= 177) {
            Lampa.Storage.sync('online_choice_fxapi', 'object_object');
        }
    }

    startPlugin();
})();