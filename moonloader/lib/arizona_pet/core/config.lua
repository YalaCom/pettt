return {
    schema = 1, tick_ms = 100, save_seconds = 30, history_limit = 60,
    offline_cap = 6 * 3600, no_restart_penalty = 2 * 3600,
    night_start = 21, night_end = 5, morning_start = 5, morning_end = 12,
    long_absence = 24 * 3600, notification_seconds = 900,
    items = {
        apple = {label='Яблоко', cost=8, hunger=18, health=2},
        cookie = {label='Печенье', cost=12, hunger=24, mood=4},
        fish = {label='Рыбка', cost=18, hunger=35, health=4},
        ball = {label='Мягкий мяч', cost=80, level=2},
        ribbon = {label='Лента дружбы', cost=120, level=3},
        interior = {label='Уютный интерьер', cost=180, level=4},
    },
    needs = {'hunger', 'energy', 'clean', 'mood', 'health', 'bond'},
    labels = {hunger='Сытость', energy='Энергия', clean='Чистота', mood='Настроение', health='Здоровье', bond='Привязанность'},
}
