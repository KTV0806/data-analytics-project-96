-- Считаем сколько пользователей заходят на сайт (шаг4.1)
select count(distinct visitor_id) from sessions; 

-- Считаем количество привлеченных пользователей по каналам (medium), (шаг 4.2)
select 
	source, -- выбираем столбец с каналами 
	count(distinct visitor_id) -- cчитаем количество привлеченных пользователей
from sessions
group by 1 -- группируем данные по каналам
order by 2 desc; -- сотритуем данные по количеству пользователей от большего к меньшему

--Считаем количество привлеченных пользователей по каналам/дням недели (шаг 4.2)
select 
	source, --выбираем необходимые столбцы
	medium,
	campaign,
	to_char(visit_date, 'Day') as day_of_week, -- выделяем день недели 
	count(distinct visitor_id) cnt_visitors -- cчитаем количество привлеченных пользователей
from sessions
group by 1,2,3,4, extract('isodow' from visit_date) -- группируем данные по каналам, кампаниям и дням недели
order by extract('isodow' from visit_date), 5 desc; -- сортируем данные по дням недели

-- Считаем конверсию из клика в лид, из лида в оплату (шаг 4.4)
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
select 
	utm_source,
	count(visitor_id) as visitors_count, -- считаем количество посетителей
	count(lead_id) as leads_count, -- считаем количество лидов
	count(closing_reason) filter (where status_id = 142) as purchases_count, -- считаем количество успешных сделок
	sum(amount) as revenue -- считаем доход от успешных сделок
from lst_paid_click -- выбираем ранее созданный СТЕ
group by 1 -- группируем по первому столбцу
)

select 
	utm_source,
	-- считаем конверсию из клика в лид
	case when sum(visitors_count) = 0 then 0 else round(sum(leads_count) * 100.00/ sum(visitors_count)) end as click_leads,
	-- считаем конверсию из лида в оплату
	case when sum(leads_count) = 0 then 0 else round(sum(purchases_count) * 100.00 / sum(leads_count)) end as leads_pay
from tab2
group by 1 -- группируем полученные данные по первому столбцу
order by 2 desc, 3 desc; -- сортируем данные по стобцам 2 и 3 от большего к меньшему

-- Проект "Онлайн-школа" (шаг 3, витрина Aggregate_Last_Paid_Click, считаем метрики)
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
),

tab3 as (
select t2.visit_date, -- выбираем необходимые столбцы
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
	and t2.visit_date = a.campaign_date
)

select 
	utm_source,	
	utm_medium,
	utm_campaign,
	case when sum(visitors_count) = 0 then 0 else round(sum(total_cost)/sum(visitors_count)) end as cpu,
	case when sum(leads_count) = 0 then 0 else round(sum(total_cost)/sum(leads_count)) end as cpl,
	case when sum(purchases_count) = 0 then 0 else round(sum(total_cost)/sum(purchases_count)) end as cppu,
	case when sum(total_cost) = 0 then 0 else round((sum(revenue) - sum(total_cost)) * 100/sum(total_cost)) end as roi 
from tab3 
group by 1,2,3
order by 7 desc nulls last
limit 11;