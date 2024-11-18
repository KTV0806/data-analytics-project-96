-- Считаем количество дней, за которое закрываются 90% лидов
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
, tab2 as (
select
    --выбираем необходимые столбцы
    s.visit_date,
    lead_id,
    l.created_at,
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
and status_id  = 142
--group by 1,2,3,4,5
)

select 
    percentile_disc(0.9) within group (order by date_trunc('day', created_at - visit_date))
from tab2;