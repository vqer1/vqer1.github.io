(function () {
    'use strict';

    function showNotice() {
        if (typeof Lampa === 'undefined' || !Lampa.Modal) return;

        var html = $(
            '<div style="padding: 1.5em; text-align: center; font-size: 1.3em; line-height: 1.6;">' +
                'для получение бесплатной fix версии напишите в тг <b>@Lopxh</b>' +
            '</div>'
        );

        Lampa.Modal.open({
            title: 'Alpac v.0.5',
            html: html,
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

    function init() {
        // Добавление пункта в раздел настроек вместо меню Alpac
        if (typeof Lampa !== 'undefined' && Lampa.SettingsApi) {
            Lampa.SettingsApi.addComponent({
                component: 'alpac_notice_item',
                name: 'Alpac v.0.5',
                icon: '<svg height="24" viewBox="0 0 24 24" width="24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>'
            });

            Lampa.SettingsApi.addParam({
                component: 'alpac_notice_item',
                param: {
                    name: 'alpac_info_trigger',
                    type: 'static',
                    default: ''
                },
                field: {
                    name: 'Информация',
                    description: 'Открыть окно поддержки'
                },
                onChange: function () {
                    showNotice();
                }
            });
        }

        // Автоматический показ окна при загрузке приложения
        showNotice();
    }

    if (window.appready) {
        init();
    } else if (typeof Lampa !== 'undefined' && Lampa.Listener) {
        Lampa.Listener.follow('app', function (e) {
            if (e.type === 'ready') init();
        });
    }
})();
