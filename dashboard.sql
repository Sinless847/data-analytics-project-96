--посетители по дням
SELECT
    'day' AS period_type,
    DATE_TRUNC('day', visit_date) AS period,
    COUNT(DISTINCT visitor_id) AS unique_visitors,
    COUNT(*) AS total_sessions
FROM sessions
WHERE visit_date BETWEEN '2023-06-01' AND '2023-07-01'
GROUP BY DATE_TRUNC('day', visit_date)
ORDER BY period;
--источники трафика
SELECT
    source,
    DATE(visit_date) AS period,
    COUNT(DISTINCT visitor_id) AS unique_visitors,
    COUNT(*) AS sessions
FROM sessions
WHERE
    visit_date BETWEEN '2023-06-01' AND '2023-07-01'
    AND source IN ('google', 'organic', 'vk', 'yandex')
GROUP BY
    DATE(visit_date),
    source
ORDER BY period ASC, unique_visitors DESC;
--лиды по дням и источникам
SELECT
    s.source,
    DATE(l.created_at) AS period,
    COUNT(DISTINCT l.lead_id) AS leads_count
FROM sessions AS s
INNER JOIN leads AS l ON s.visitor_id = l.visitor_id
WHERE
    l.created_at BETWEEN '2023-06-01' AND '2023-07-01'
    AND s.source IN ('google', 'organic', 'vk', 'yandex')
GROUP BY DATE(l.created_at), s.source
ORDER BY period ASC, leads_count DESC;
--лиды по источникам
SELECT
    s.source,
    COUNT(DISTINCT l.lead_id) AS leads_count
FROM sessions AS s
INNER JOIN leads AS l ON s.visitor_id = l.visitor_id
WHERE
    l.created_at BETWEEN '2023-06-01' AND '2023-07-01'
    AND s.source IN ('google', 'organic', 'vk', 'yandex')
GROUP BY s.source
ORDER BY leads_count DESC;
--количество посетителей с разбивкой источников перехода
SELECT
    source,
    CASE EXTRACT(ISODOW FROM visit_date)
        WHEN 1 THEN '1monday'
        WHEN 2 THEN '2tuesday'
        WHEN 3 THEN '3wednesday'
        WHEN 4 THEN '4thursday'
        WHEN 5 THEN '5friday'
        WHEN 6 THEN '6saturday'
        WHEN 7 THEN '7sunday'
    END AS day_of_week,
    COUNT(DISTINCT visitor_id) AS unique_visitors
FROM sessions
WHERE visit_date BETWEEN '2023-06-01' AND '2023-07-01'
GROUP BY
    EXTRACT(ISODOW FROM visit_date),
    source
ORDER BY
    EXTRACT(ISODOW FROM visit_date),
    unique_visitors DESC;
--затраты на вк и яндекс
SELECT
    period,
    source,
    total_spent
FROM (
    SELECT
        campaign_date AS period,
        'yandex' AS source,
        SUM(daily_spent) AS total_spent
    FROM ya_ads
    WHERE campaign_date BETWEEN '2023-06-01' AND '2023-07-01'
    GROUP BY campaign_date

    UNION ALL

    SELECT
        campaign_date AS period,
        'vk' AS source,
        SUM(daily_spent) AS total_spent
    FROM vk_ads
    WHERE campaign_date BETWEEN '2023-06-01' AND '2023-07-01'
    GROUP BY campaign_date
) AS combined_data
ORDER BY period, source;
--окупаемость каналов
WITH revenue_data AS (
    SELECT
        s.source,
        COALESCE(SUM(CASE WHEN l.status_id = 142 THEN l.amount ELSE 0 END), 0)
            AS revenue
    FROM sessions AS s
    LEFT JOIN leads AS l ON s.visitor_id = l.visitor_id
    WHERE
        s.visit_date BETWEEN '2023-06-01' AND '2023-07-01'
        AND s.source IN ('yandex', 'vk')
    GROUP BY s.source
),

cost_data AS (
    SELECT
        'yandex' AS source,
        SUM(daily_spent) AS consumption
    FROM ya_ads
    WHERE campaign_date BETWEEN '2023-06-01' AND '2023-07-01'

    UNION ALL

    SELECT
        'vk' AS source,
        SUM(daily_spent) AS consumption
    FROM vk_ads
    WHERE campaign_date BETWEEN '2023-06-01' AND '2023-07-01'
)

SELECT
    r.source,
    r.revenue,
    c.consumption,
    r.revenue - c.consumption AS profit,
    CASE
        WHEN
            c.consumption > 0
            THEN ROUND((r.revenue - c.consumption) * 100.0 / c.consumption, 2)
        ELSE 0
    END AS romi_percent
FROM revenue_data AS r
INNER JOIN cost_data AS c ON r.source = c.source
ORDER BY r.source;
--расчет ключевых метрик
WITH ranked_clicks AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        l.lead_id,
        l.amount,
        l.closing_reason,
        l.status_id,
        ROW_NUMBER() OVER (
            PARTITION BY s.visitor_id
            ORDER BY s.visit_date DESC
        ) AS rn
    FROM sessions AS s
    LEFT JOIN
        leads AS l
        ON s.visitor_id = l.visitor_id AND s.visit_date <= l.created_at
    WHERE s.medium != 'organic'
),

spendings AS (
    SELECT
        DATE(campaign_date) AS campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY 1, 2, 3, 4
    UNION DISTINCT
    SELECT
        DATE(campaign_date) AS campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY 1, 2, 3, 4
),

agg_tab AS (
    SELECT
        utm_source,
        utm_medium,
        utm_campaign,
        DATE(visit_date) AS visit_date,
        COUNT(visitor_id) AS visitors_count,
        COUNT(lead_id) AS leads_count,
        COUNT(lead_id) FILTER (
            WHERE status_id = 142
        ) AS purchases_count,
        SUM(amount) AS revenue
    FROM ranked_clicks
    WHERE rn = 1
    GROUP BY 1, 2, 3, 4
    ORDER BY
        8 DESC NULLS LAST, 4, 5 DESC, 1 ASC, 2 ASC, 3 ASC
),

tabs AS (
    SELECT
        agg_tab.visit_date,
        agg_tab.utm_source,
        agg_tab.utm_medium,
        agg_tab.utm_campaign,
        agg_tab.visitors_count,
        sp.total_cost,
        agg_tab.leads_count,
        agg_tab.purchases_count,
        agg_tab.revenue
    FROM agg_tab
    INNER JOIN spendings AS sp
        ON
            agg_tab.utm_source = sp.utm_source
            AND agg_tab.utm_medium = sp.utm_medium
            AND agg_tab.utm_campaign = sp.utm_campaign
            AND agg_tab.visit_date = sp.campaign_date
    ORDER BY 9 DESC NULLS LAST, 1, 5 DESC, 2, 3, 4
)

SELECT
    utm_source,
    CASE
        WHEN SUM(visitors_count) = 0 THEN 0
        ELSE ROUND(SUM(total_cost) / SUM(visitors_count), 2)
    END AS cpu,
    CASE
        WHEN SUM(leads_count) = 0 THEN 0
        ELSE ROUND(SUM(total_cost) / SUM(leads_count), 2)
    END AS cpl,
    CASE
        WHEN SUM(purchases_count) = 0 THEN 0
        ELSE ROUND(SUM(total_cost) / SUM(purchases_count), 2)
    END AS cppu,
    ROUND(
        100.0 * (SUM(revenue) - SUM(total_cost)) / SUM(total_cost), 2
    ) AS roi
FROM tabs
GROUP BY 1;
