-- Проект "Онлайн-школа" (шаг 3, витрина Aggregate_Last_Paid_Click)
with tab as (
    select
        s.visitor_id,
        max(s.visit_date) as mx_visit
    from sessions as s
    where s.medium != 'organic'
    group by 1
),

lst_paid_click as (
    select
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
    from tab as t
    inner join sessions as s
        on
            t.visitor_id = s.visitor_id
            and t.mx_visit = s.visit_date
    left join leads as l
        on
            t.visitor_id = l.visitor_id
            and t.mx_visit <= l.created_at
    where s.medium != 'organic'
),

tab2 as (
    select 
        date(lpc.visit_date) as visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        count(lpc.visitor_id) as visitors_count,
        count(lpc.lead_id) as leads_count,
        count(lpc.closing_reason)
        filter (where lpc.status_id = 142) as purchases_count,
        sum(lpc.amount) as revenue
    from lst_paid_click as lpc
    group by 1, 2, 3, 4
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
        t2.revenue desc nulls last,
    t2.visit_date asc,
    t2.visitors_count desc,
    t2.utm_source asc,
    t2.utm_medium asc,
    t2.utm_campaign asc
limit 15;
