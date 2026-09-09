(function () {
    'use strict';

    var isNoticeOpen = false;
    var canCloseNotice = false;
    var origModalClose = null;

    // Защита окна от принудительного закрытия внутренними процессами Lampa
    function hookModalClose() {
        if (typeof Lampa !== 'undefined' && Lampa.Modal && !origModalClose) {
            origModalClose = Lampa.Modal.close;
            Lampa.Modal.close = function () {
                if (isNoticeOpen && !canCloseNotice) {
                    return; // Блокируем фоновые события роутера Lampa
                }
                return origModalClose.apply(this, arguments);
            };
        }
    }

    function showNotice() {
        if (typeof Lampa === 'undefined' || !Lampa.Modal) return;
        hookModalClose();

        var $ = window.$ || (window.Lampa && window.Lampa.$);
        if (!$) return;

        isNoticeOpen = true;
        canCloseNotice = false;

        var content = $(
            '<div style="padding: 1.5em; text-align: center; font-size: 1.3em; line-height: 1.6;">' +
                'для получение бесплатной fix версии напишите в тг <b>@Lopxh</b>' +
            '</div>'
        );

        function closeModal() {
            canCloseNotice = true;
            isNoticeOpen = false;
            if (origModalClose) {
                origModalClose.call(Lampa.Modal);
            } else {
                Lampa.Modal.close();
            }
            if (Lampa.Controller) Lampa.Controller.toggle('content');
        }

        Lampa.Modal.open({
            title: 'Alpac v.0.5',
            html: content,
            size: 'medium',
            select: true,
            no_cancel: true,
            buttons: [
                {
                    name: 'Закрыть',
                    action: function () {
                        closeModal();
                    }
                }
            ],
            onBack: function () {
                closeModal();
            }
        });

        if (Lampa.Controller) {
            setTimeout(function () {
                Lampa.Controller.toggle('modal');
            }, 100);
        }
    }

    // 1. Показ окна при старте Lampa после завершения инициализации интерфейса
    function initAutoShow() {
        var shown = false;
        var attempts = 0;
        var checkTimer = setInterval(function () {
            attempts++;
            var isReady = typeof Lampa !== 'undefined' &&
                          Lampa.Modal &&
                          (window.appready || (Lampa.Activity && Lampa.Activity.active()));

            if (isReady) {
                clearInterval(checkTimer);
                setTimeout(function () {
                    if (!shown) {
                        shown = true;
                        showNotice();
                    }
                }, 1500);
            }
            if (attempts > 60) clearInterval(checkTimer);
        }, 200);
    }

    // 2. Внедрение кнопки Alpac v.0.5 в меню выбора источников (балансеров)
    function hookSourcesSelect() {
        var timer = setInterval(function () {
            if (typeof Lampa !== 'undefined' && Lampa.Select && Lampa.Select.show) {
                clearInterval(timer);
                var origSelectShow = Lampa.Select.show;

                Lampa.Select.show = function (params) {
                    if (params && params.items && Array.isArray(params.items)) {
                        var isSourceMenu = false;
                        var title = (params.title || '').toLowerCase();

                        if (title.indexOf('источник') !== -1 || title.indexOf('балансер') !== -1 || title.indexOf('source') !== -1) {
                            isSourceMenu = true;
                        } else {
                            for (var i = 0; i < params.items.length; i++) {
                                var itm = (params.items[i].title || params.items[i].name || '').toLowerCase();
                                if (/rezka|filmix|alloha|collaps|videocdn|zetflix|ashdi|kinogo|voidboost/i.test(itm)) {
                                    isSourceMenu = true;
                                    break;
                                }
                            }
                        }

                        if (isSourceMenu) {
                            var exists = false;
                            for (var j = 0; j < params.items.length; j++) {
                                var name = (params.items[j].title || params.items[j].name || '');
                                if (name.indexOf('Alpac') !== -1) {
                                    exists = true;
                                    break;
                                }
                            }

                            if (!exists) {
                                params.items.unshift({
                                    title: 'Alpac v.0.5',
                                    name: 'Alpac v.0.5',
                                    subtitle: 'Fix версия',
                                    alpac_trigger: true
                                });
                            }

                            var origOnSelect = params.onSelect;
                            params.onSelect = function (item) {
                                if (item.alpac_trigger || (item.title && item.title.indexOf('Alpac') !== -1)) {
                                    if (Lampa.Select.close) Lampa.Select.close();
                                    showNotice();
                                    return;
                                }
                                if (origOnSelect) origOnSelect(item);
                            };
                        }
                    }
                    return origSelectShow.call(this, params);
                };
            }
        }, 150);
    }

    // 3. Добавление кнопки Alpac v.0.5 в карточку фильма
    function hookCardButtons() {
        if (typeof Lampa !== 'undefined' && Lampa.Listener) {
            Lampa.Listener.follow('full', function (e) {
                if (e.type === 'complite') {
                    var $ = window.$ || (window.Lampa && window.Lampa.$);
                    if (!$) return;

                    var btn = $(
                        '<div class="full-start__button selector">' +
                            '<svg height="24" viewBox="0 0 24 24" width="24" fill="currentColor" style="margin-right: 8px;">' +
                                '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/>' +
                            '</svg>' +
                            '<span>Alpac v.0.5</span>' +
                        '</div>'
                    );

                    btn.on('hover:enter', function () {
                        showNotice();
                    });

                    var container = e.object.activity.render().find('.full-start-new__buttons, .full-start__buttons');
                    if (container.length) {
                        container.append(btn);
                    }
                }
            });
        }
    }

    initAutoShow();
    hookSourcesSelect();
    hookCardButtons();
})();
