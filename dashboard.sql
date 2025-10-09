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
WITH metrics_data AS (
    SELECT
        s.source,
        COUNT(DISTINCT s.visitor_id) AS visitors_count,
        COUNT(DISTINCT l.lead_id) AS leads_count,
        COUNT(DISTINCT CASE WHEN l.status_id = 142 THEN l.lead_id END)
            AS purchases_count,
        COALESCE(SUM(CASE WHEN l.status_id = 142 THEN l.amount ELSE 0 END), 0)
            AS revenue,
        (
            CASE
                WHEN s.source = 'yandex'
                    THEN (
                        SELECT SUM(ya.daily_spent)
                        FROM ya_ads AS ya
                        WHERE
                            ya.campaign_date BETWEEN '2023-06-01'
                            AND '2023-07-01'
                    )
                WHEN s.source = 'vk' THEN (
                    SELECT SUM(vk.daily_spent)
                    FROM vk_ads AS vk
                    WHERE vk.campaign_date BETWEEN '2023-06-01' AND '2023-07-01'
                )
            END
        ) AS total_cost
    FROM sessions AS s
    LEFT JOIN leads AS l
        ON s.visitor_id = l.visitor_id
    WHERE
        s.visit_date BETWEEN '2023-06-01' AND '2023-07-01'
        AND s.source IN ('yandex', 'vk')
    GROUP BY s.source
)

SELECT
    source AS channel,
    -- CPU
    ROUND(total_cost / NULLIF(visitors_count, 0), 2) AS cpu,
    -- CPL
    ROUND(total_cost / NULLIF(leads_count, 0), 2) AS cpl,
    -- CPPU
    ROUND(total_cost / NULLIF(purchases_count, 0), 2) AS cppu,
    -- ROI
    ROUND((revenue - total_cost) * 100.0 / NULLIF(total_cost, 0), 2)
        AS roi_percent
FROM metrics_data
ORDER BY source;
