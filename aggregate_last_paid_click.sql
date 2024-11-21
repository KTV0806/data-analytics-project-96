with tab as (
    select
        visitor_id,-- выбираем столбец с ID для дальнейшего соединения
        max(visit_date) as mx_visit-- определяем последний визит 
    from sessions--за основу берем таблицу sessions
    -- задаем условие на визит с платных сервисов (не = 'organic')
    where medium != 'organic'
    group by 1-- группируем по первому полю
),

lst_paid_click as (
    select
        t.visitor_id,--выбираем необходимые столбцы
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from tab as t--выбираем ранее созданные СТЕ
    inner join sessions as s-- присоединяем таблицу sessions
        on
            t.visitor_id = s.visitor_id-- по столбцу visitor_id
            -- по дате последнего платного визита из ранее созданного СТЕ
            and t.mx_visit = s.visit_date
    left join leads as l-- присоединяем таблицу leads
        on
            t.visitor_id = l.visitor_id-- по столбцу visitor_id
            and t.mx_visit <= l.created_at-- по условию, что лид после визита
    -- задаем условие на визит с платных сервисов (не = 'organic')
    where s.medium != 'organic'
),

tab2 as (
    select
        date(visit_date) as visit_date,--выбираем необходимые столбцы
        utm_source,
        utm_medium,
        utm_campaign,
        count(visitor_id) as visitors_count,-- считаем количество посетителей
        count(lead_id) as leads_count,-- считаем количество лидов
        -- считаем количество успешных сделок
        count(closing_reason) filter (where status_id = 142) as purchases_count,
        sum(amount) as revenue -- считаем доход от успешных сделок
    from lst_paid_click -- выбираем ранее созданный СТЕ
    group by 1, 2, 3, 4 -- группируем по первым 4 столбцам
),

ads as (
    select-- выбираем необходимые столбцы
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads
    group by 1, 2, 3, 4
    union
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by 1, 2, 3, 4
    order by 1
)

select
    t2.visit_date,
    t2.visitors_count,
    t2.utm_source,
    t2.utm_medium,
    t2.utm_campaign,
    a.total_cost,
    t2.leads_count,
    t2.purchases_count,
    t2.revenue
from tab2 as t2
left join ads as a
    on
        t2.utm_source = a.utm_source
        and t2.utm_medium = a.utm_medium
        and t2.utm_campaign = a.utm_campaign
        and t2.visit_date = a.campaign_date
order by
    revenue desc nulls last,
    t2.visit_date asc,
    t2.visitors_count desc,
    t2.utm_source asc,
    t2.utm_medium asc,
    t2.utm_campaign asc
limit 15;
