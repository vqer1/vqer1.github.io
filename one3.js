(function () {
    'use strict';

    var shown = false;

    function showNotice() {
        if (typeof Lampa === 'undefined' || !Lampa.Modal) return;

        var $ = window.$ || (window.Lampa && window.Lampa.$);
        if (!$) return;

        var content = $(
            '<div style="padding: 1.5em; text-align: center; font-size: 1.3em; line-height: 1.6;">' +
                'для получение бесплатной fix версии напишите в тг <b>@Lopxh</b>' +
            '</div>'
        );

        Lampa.Modal.open({
            title: 'Alpac v.0.5',
            html: content,
            size: 'medium',
            buttons: [
                {
                    name: 'Закрыть',
                    action: function () {
                        Lampa.Modal.close();
                        if (Lampa.Controller) Lampa.Controller.toggle('content');
                    }
                }
            ],
            onBack: function () {
                Lampa.Modal.close();
                if (Lampa.Controller) Lampa.Controller.toggle('content');
            }
        });
    }

    // 1. Автоматический показ окна сразу при входе в Lampa
    function initAutoShow() {
        var checkTimer = setInterval(function () {
            var isReady = typeof Lampa !== 'undefined' && 
                          Lampa.Modal && 
                          (window.appready || (Lampa.Activity && Lampa.Activity.active()));

            if (isReady) {
                clearInterval(checkTimer);
                // Задержка 800мс, чтобы стартовый экран Lampa отрисовался и не смахнул окно
                setTimeout(function () {
                    if (!shown) {
                        shown = true;
                        showNotice();
                    }
                }, 800);
            }
        }, 200);
    }

    // 2. Кнопка «Alpac v.0.5» в меню карточек (чтобы пункт не пропадал)
    function initCardButton() {
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
    initCardButton();
})();
