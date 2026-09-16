(function () {
    'use strict';

    function initPatch() {
        if (typeof Lampa === 'undefined' || !Lampa.Storage) {
            return setTimeout(initPatch, 250);
        }

        // 1. Подстановка токенов и учетной записи в LocalStorage Lampa
        Lampa.Storage.set('account_email', 'vip_user@akter.black');
        Lampa.Storage.set('token', 'muWXy7P5rKOJrLuFKt9RceAn');
        Lampa.Storage.set('ab_account', {
            id: 1337,
            token: 'muWXy7P5rKOJrLuFKt9RceAn',
            email: 'vip_user@akter.black',
            premium: true,
            vip: true,
            quality: '4k'
        });

        // 2. Выставляем 4K (2160p) как качество по умолчанию
        Lampa.Storage.set('video_quality_default', '2160');

        // 3. Открываем разрешения аккаунта
        if (Lampa.Account) {
            Lampa.Account.Permit = Lampa.Account.Permit || {};
            Lampa.Account.Permit.access = true;
            Lampa.Account.Permit.account = true;
        }

        // 4. Глобальный обход заглушки VIP для плагина sisi
        window.isVIP = function() { return false; };

        // Уведомление на экране о том, что скрипт сработал
        if (Lampa.Noty) {
            Lampa.Noty.show('Патч авторизации успешно загружен');
        }
    }

    initPatch();
})();
