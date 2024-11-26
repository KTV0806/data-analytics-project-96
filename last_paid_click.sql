-- Проект "Онлайн-школа" (шаг 2)
--создаем CTE для определения последнего платного визита
with tab as (
    select
        visitor_id, -- выбираем столбец с ID для дальнейшего соединения
        max(visit_date) as mx_visit -- определяем последний визит 
    from sessions --за основу берем таблицу sessions
    -- задаем условие на визит с платных сервисов (не = 'organic')
    where medium != 'organic'
    group by 1 -- группируем по первому полю
)

select
    t.visitor_id, --выбираем необходимые столбцы
    s.visit_date,
    s.source as utm_source,
    s.medium as utm_medium,
    s.campaign as utm_campaign,
    l.lead_id,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id
from tab as t --выбираем ранее созданные СТЕ
inner join sessions as s -- присоединяем таблицу sessions
    on
        t.visitor_id = s.visitor_id -- по столбцу visitor_id
        -- по дате последнего платного визита из ранее созданного СТЕ
        and t.mx_visit = s.visit_date
left join leads as l -- присоединяем таблицу leads
    on
        t.visitor_id = l.visitor_id -- по столбцу visitor_id
        and t.mx_visit <= l.created_at -- по условию, что лид после визита
-- задаем условие на визит с платных сервисов (не = 'organic')
where s.medium != 'organic'
order by
    l.amount desc nulls last, --сортируем данные
    s.visit_date asc,
    s.utm_source asc,
    s.utm_medium asc,
    s.utm_campaign asc
limit 10; -- ограничиваем выборку 10 первыми записями

--Проект "Онлайн-школа" (шаг 3)
--создаем СТЕ для объединения таблиц 
--с затратами на рекламы по источникам vk и yandex
with ads as (
    select -- выбираем необходимые столбцы
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads -- выбираем таблицу vk
    group by 1, 2, 3, 4 -- группируем по выбранным столбцам
    union -- объединяем запросы
    select -- выбираем необходимые столбцы
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads -- выбираем таблицу yandex
    group by 1, 2, 3, 4 -- группируем по выбранным столбцам
    order by 1 -- сортируем итоговую таблицу по дате
),

-- создаем СТЕ для определения посленего платного визита
tab as (
    select
        visitor_id,
        max(visit_date) as lst_visit
    from sessions -- выбираем таблицу
    where medium != 'organic' -- задаем условие, что визит платный
    group by 1 -- группируем таблицу по столбцу с id 
),

-- создаем СТЕ для создания сводной таблицы
lst_click as (
    select --выбираем необходимые столбцы
        t.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from tab as t --выбираем ранее созданный СТЕ
    inner join sessions as s -- присоединяем таблицу sessions
        on
            t.visitor_id = s.visitor_id -- по столбцу visitor_id
            and t.lst_visit = s.visit_date
    left join leads as l -- присоединяем таблицу leads
        on
            t.visitor_id = l.visitor_id -- по столбцу visitor_id
            and t.lst_visit <= l.created_at -- по условию, что лид после визита
    where s.medium != 'organic'
    order by
        l.amount desc nulls last, --сортируем данные
        s.visit_date asc,
        s.utm_source asc,
        s.utm_medium asc,
        s.utm_campaign asc
),

--создаем СТЕ для подсчета количества лидов, 
--посетителей и успешно реализованных сделок
tab2 as (
    select -- выбираем необходимие столбцы
        date(lc.visit_date) as visit_date,
        lc.utm_source,
        lc.utm_medium,
        lc.utm_campaign,
        count(distinct lc.visitor_id) as visitors_count,
        count(lc.lead_id) as leads_count, -- считаем количество лидов
        count(lc.closing_reason) filter (
            where lc.status_id = 142
        ) as purchases_count,
        sum(lc.amount) as revenue -- считаем доход
    from lst_click as lc -- выбираем ранее созданный СТЕ
    group by 1, 2, 3, 4
    order by 1 -- сортируем по дате
)

--считаем необходимые метрики
select --выбираем необходимые столбцы
    t2.visit_date,
    t2.utm_source,
    t2.utm_medium,
    t2.utm_campaign,
    t2.visitors_count,
    a.total_cost,
    t2.leads_count,
    t2.purchases_count,
    t2.revenue
from tab2 as t2 --выбираем ранее созданный СТЕ
left join ads as a
    on
        t2.utm_source = a.utm_source -- по источнику перехода
        and t2.utm_medium = a.utm_medium -- по типу рекламной кампании
        and t2.utm_campaign = a.utm_campaign -- по названию рекламной кампании
        and t2.visit_date = a.campaign_date -- по последнему платному визиту
order by
    t2.revenue desc nulls last, t2.visit_date asc,
    t2.visitors_count desc, t2.utm_source asc, t2.utm_medium asc,
    t2.utm_campaign asc
limit 15; -- ограничиваем поках строк до 15
