-- Проект "Онлайн-школа" (шаг 2, витрина Last_Paid_Click)
--создаем CTE для определения последнего платного визита
with tab as (
    select
        s.visitor_id, -- выбираем столбец с ID для дальнейшего соединения
        max(visit_date) as mx_visit -- определяем последний визит 
    from sessions as s --за основу берем таблицу sessions
    left join leads as l -- присоединяем таблицу leads
        on s.visitor_id = l.visitor_id --по полю visitor_id
    -- задаем условие на визит с платных сервисов (не = 'organic')
    where s.medium <> 'organic'
    group by 1 -- группируем по первому полю
)

select
    t.visitor_id, --выбираем необходимые столбцы
    s.visit_date,
    s.source as utm_source,
    s.medium as utm_medium,
    s.campaign as utm_campaign,
    lead_id,
    created_at,
    amount,
    closing_reason,
    status_id
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
where medium <> 'organic'
order by
    amount desc nulls last, --сортируем данные
    visit_date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc
limit 10; -- ограничиваем выборку 10 первыми записями

-- Проект "Онлайн-школа" (шаг 3, витрина Aggregate_Last_Paid_Click)
with tab as (
    select
        s.visitor_id, -- выбираем столбец с ID для дальнейшего соединения
        max(visit_date) as mx_visit -- определяем последний визит 
    from sessions as s --за основу берем таблицу sessions
    left join leads as l -- присоединяем таблицу leads
        on s.visitor_id = l.visitor_id --по полю visitor_id
    -- задаем условие на визит с платных сервисов (не = 'organic')
    where s.medium <> 'organic'
    group by 1 -- группируем по первому полю
),

lst_paid_click as (
select
    t.visitor_id, --выбираем необходимые столбцы
    s.visit_date,
    s.source as utm_source,
    s.medium as utm_medium,
    s.campaign as utm_campaign,
    lead_id,
    created_at,
    amount,
    closing_reason,
    status_id
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
where medium <> 'organic'
),

tab2 as ( 
select visit_date, --выбираем необходимые столбцы
	utm_source,
    utm_medium,
    utm_campaign,
	count(visitor_id) as visitors_count, -- считаем количество посетителей
	count(lead_id) as leads_count, -- считаем количество лидов
	count(closing_reason) filter (where status_id = 142) as purchases_count, -- считаем количество успешных сделок
	sum(amount) as revenue -- считаем доход от успешных сделок
from lst_paid_click -- выбираем ранее созданный СТЕ
group by 1,2,3,4 -- группируем по первым 4 столбцам
),
ads as ( 
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
)
select 
	t2.visit_date, -- выбираем необходимые столбцы
	t2.utm_source,
	t2.utm_medium,
	t2.utm_campaign,
	t2.visitors_count,
	a.total_cost,
	t2.leads_count,
	t2.purchases_count,
	t2.revenue 
from tab2 as t2 -- из ранее созданного СТЕ
left join ads as a -- присоединяем общую таблицу по затратам
	on t2.utm_source = a.utm_source -- прописываем условия соединения
	and t2.utm_medium = a.utm_medium
	and t2.utm_campaign = a.utm_campaign
	and t2.visit_date = a.campaign_date;
order by revenue desc nulls last, -- сортируем итоговую таблицу
visit_date,
visitors_count desc,
utm_source,
utm_medium,
utm_campaign
limit 15; -- ограничиваем выборку 15 первыми строками

