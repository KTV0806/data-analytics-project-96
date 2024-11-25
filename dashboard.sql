--Проект Онлайн-школа (шаг 4)
--Считаем метрики 
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
    select
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
    t2.utm_source,
    t2.utm_medium,
    t2.utm_campaign,
    case
        when sum(visitors_count) = 0 then 0
        else round(sum(a.total_cost) / sum(t2.visitors_count))
    end as cpu,
    case
        when sum(t2.leads_count) = 0 then 0
        else round(sum(a.total_cost) / sum(t2.leads_count))
    end as cpl,
    case
        when sum(t2.purchases_count) = 0 then 0
        else round(sum(a.total_cost) / sum(t2.purchases_count))
    end as cppu,
    case
        when sum(a.total_cost) = 0 then 0
        else
            round(
                (sum(t2.revenue) - sum(a.total_cost))
                * 100.00
                / sum(a.total_cost)
            )
    end as roi
from tab2 as t2 -- из ранее созданного СТЕ
left join ads as a -- присоединяем общую таблицу по затратам
    on
        t2.utm_source = a.utm_source -- прописываем условия соединения
        and t2.utm_medium = a.utm_medium
        and t2.utm_campaign = a.utm_campaign
        -- ограничиваем выборку 15 первыми строками
        and t2.visit_date = a.campaign_date
group by 1, 2, 3
order by 7 nulls last
limit 26;

--Считаем конверсии из клика в лид, из лида в оплату
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
)

select
    utm_source,
    sum(leads_count) / sum(visitors_count) as click_lead,
    case
        when sum(leads_count) = 0 then 0
        else sum(purchases_count) / sum(leads_count)
    end as lead_pay
from tab2 -- выбираем ранее созданный СТЕ
group by 1-- группируем по первому столбцу
order by 2 desc
limit 8;

--Затраты на рекламу по дням недели
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
    select
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
    t2.visitors_count,
    t2.utm_source,
    t2.utm_medium,
    a.total_cost,
    t2.leads_count,
    t2.purchases_count,
    t2.revenue,
    to_char(t2.visit_date, 'Day') as visit_date
from tab2 as t2
left join ads as a
    on
        t2.utm_source = a.utm_source
        and t2.utm_medium = a.utm_medium
        and t2.utm_campaign = a.utm_campaign
        and t2.visit_date = a.campaign_date
order by extract('isodow' from t2.visit_date);
   
-- Считаем количество дней, за которое закрываются 90% лидов
with tab as (
    select
        visitor_id, -- выбираем столбец с ID для дальнейшего соединения
        max(visit_date) as mx_visit -- определяем последний визит 
    from sessions --за основу берем таблицу sessions
    -- задаем условие на визит с платных сервисов (не = 'organic')
    where medium != 'organic'
    group by 1 -- группируем по первому полю
)
, tab2 as (
	select
    	--выбираем необходимые столбцы
    	s.visit_date,
    	l.lead_id,
    	l.created_at,
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
	where s.medium != 'organic' and status_id  = 142
	group by 1, 2, 3, 4, 5
)

select 
    percentile_disc(0.9) within group (order by date_trunc('day', created_at - visit_date))
from tab2;
