// =============================================================
// Lampac (Lampa) Plugin: online.js
// Версія БЕЗ авторизації (видалені account, uid, token, nws_id, RCH)
// Усі запити виконуються без додаткових параметрів
// =============================================================

(function(){

function startPlugin(){

    function resetTemplates(){
        // Ініціалізація стилів та HTML-шаблонів
    }

    function addButton(e){
        if(e.render.find('.lampac--button').length) return;

        var btn = $(Lampa.Lang.translate(button));

        btn.on('hover:enter', function(){
            resetTemplates();
            Lampa.Component.add('lampac2026', component);

            Lampa.Activity.push({
                url: '',
                title: Lampa.Lang.translate('title_online'),
                component: 'lampac2026',
                search: e.movie.title,
                search_one: e.movie.title,
                search_two: e.movie.original_title,
                movie: e.movie,
                page: 1,
                clarification: false
            });
        });

        e.render.after(btn);
    }

    Lampa.Listener.follow('full', function(e){
        if(e.type == 'complite'){
            addButton({
                render: e.object.activity.render().find('.view--torrent'),
                movie: e.data.movie
            });
        }
    });

    try{
        if(Lampa.Activity.active().component == 'full'){
            addButton({
                render: Lampa.Activity.active().activity.render().find('.view--torrent'),
                movie: Lampa.Activity.active().card
            });
        }
    }catch(e){}

    // ---------------------------------------------------------
    // СИНХРОНІЗАЦІЯ BALANSER-ІВ (джерел відео)
    // Повернуто. Не пов'язано з авторизацією.
    // ---------------------------------------------------------
    if (Lampa.Manifest.app_digital >= 177) {
        var balansers_sync = [
            "filmix", "filmixtv", "fxapi", "rezka", "rhsprem",
            "lumex", "videodb", "collaps", "collaps-dash",
            "hdvb", "zetflix", "kodik", "ashdi", "kinoukr",
            "kinotochka", "remux", "iframevideo", "cdnmovies",
            "anilibria", "animedia", "animego", "animevost",
            "animebesst", "redheadsound", "alloha", "animelib",
            "moonanime", "kinopub", "vibix", "vdbmovies",
            "fancdn", "cdnvideohub", "vokino",
            "rc/filmix", "rc/fxapi", "rc/rhs",
            "vcdn", "videocdn", "mirage", "hydraflix",
            "videasy", "vidsrc", "movpi", "vidlink",
            "twoembed", "autoembed", "smashystream",
            "rgshows", "pidtor", "videoseed",
            "iptvonline", "veoveo"
        ];

        balansers_sync.forEach(function(name) {
            Lampa.Storage.sync('online_choice_' + name, 'object_object');
        });

        Lampa.Storage.sync('online_watched_last', 'object_object');
    }
}

// -------------------------------------------------------------
// ЗАГЛУШКА account() — більше НЕ додає параметри
// -------------------------------------------------------------
// -------------------------------------------------------------
// AUTHORISATION REMOVED
// Функція account більше НЕ додає email, uid, token, nws_id
// Залишена лише як заглушка щоб не ламати існуючі виклики
// -------------------------------------------------------------
function account(url){
    return url;
}

// -------------------------------------------------------------
// ВИДАЛЕНО RCH / WebSocket авторизацію
// Немає NativeWsClient, Registry, connectionId
// -------------------------------------------------------------

// -------------------------------------------------------------
// Завантаження субтитрів (без account)
// -------------------------------------------------------------
this.loadSubtitles = function(link){
    network.silent(link, function(subs){
        Lampa.Player.subtitles(subs);
    });
};

// -------------------------------------------------------------
// Парсинг відповіді сервера
// -------------------------------------------------------------
this.parse = function(str){
    var json = Lampa.Arrays.decodeJson(str,{});

    try{
        var items = this.parseJsonDate(str,'.videos__item');
        var buttons = this.parseJsonDate(str,'.videos__button');
    }
    catch(e){
        console.log('Parse error', e);
    }
};

// -------------------------------------------------------------
// Відтворення
// -------------------------------------------------------------
// Lampa.Player.play(element);
// Lampa.Player.playlist(playlist);

if(!window.lampac2026_plugin) startPlugin();

})();

// =============================================================
// КІНЕЦЬ ВЕРСІЇ БЕЗ АВТОРИЗАЦІЇ
// =============================================================
