--Проект Онлайн-школа (шаг 4)
--Считаем метрики 
with tab as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number()
        over (partition by s.visitor_id order by s.visit_date desc) as rn
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium != 'organic'
),

last_paid_click as (
    select
        date(visit_date) visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        cast(count(visitor_id) as numeric) as visitors_count,
        cast(count(lead_id) as numeric) as leads_count,
        count(closing_reason) filter (where status_id = 142) as purchases_count,
        sum(amount) as revenue
    from tab
    where rn = 1
    group by
        date(visit_date),
        utm_source,
        utm_medium,
        utm_campaign
),

ads as (
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads
    group by
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign
    union
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign
    order by campaign_date
)

select
    lpv.utm_source,
    case
        when sum(lpv.visitors_count) = 0 then 0
        else round(sum(a.total_cost) / sum(lpv.visitors_count))
    end as cpu,
    case
        when sum(lpv.leads_count) = 0 then 0
        else round(sum(a.total_cost) / sum(lpv.leads_count))
    end as cpl,
    case
        when sum(lpv.purchases_count) = 0 then 0
        else round(sum(a.total_cost) / sum(lpv.purchases_count))
    end as cppu,
    case
        when sum(a.total_cost) = 0 then 0
        else
            round(
                (sum(lpv.revenue) - sum(a.total_cost))
                * 100.00
                / sum(a.total_cost)
            )
    end as roi
from last_paid_click as lpv
left join ads as a
    on
        lpv.utm_source = a.utm_source
        and lpv.utm_medium = a.utm_medium
        and lpv.utm_campaign = a.utm_campaign
        and lpv.visit_date = a.campaign_date
where lpv.utm_source = 'vk' or lpv.utm_source = 'yandex'
group by
    lpv.utm_source
order by
    roi desc nulls last;

--Считаем конверсии из клика в лид, из лида в оплату
with tab as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number()
        over (partition by s.visitor_id order by s.visit_date desc) as rn
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium != 'organic'
),

last_paid_click as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date(visit_date) as visit_date,
        count(visitor_id) as visitors_count,
        count(lead_id) as leads_count,
        count(closing_reason) filter (where status_id = 142) as purchases_count,
        sum(amount) as revenue
    from tab
    where rn = 1
    group by
        date(visit_date),
        utm_source,
        utm_medium,
        utm_campaign
)

select
    utm_source,
    round(sum(leads_count) * 100.00 / sum(visitors_count), 2) as click_lead,
    case
        when sum(leads_count) = 0 then 0
        else round(sum(purchases_count) * 100.00 / sum(leads_count), 2)
    end as lead_pay
from last_paid_click
where utm_source = 'vk' or utm_source = 'yandex'
group by
    utm_source
order by lead_pay desc;

-- Считаем количество дней, за которое закрываются 90% лидов
with tab as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number()
        over (partition by s.visitor_id order by s.visit_date desc) as rn
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium != 'organic'
),

tab2 as (
    select *
    from tab
    where rn = 1
)

select
    percentile_disc(0.9)
    within group (order by date_trunc('day', created_at - visit_date))
from tab2;
