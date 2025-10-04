WITH daily_metrics AS (
    SELECT
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        DATE(s.visit_date) AS visit_date,
        COUNT(DISTINCT s.visitor_id) AS visitors_count,
        COUNT(DISTINCT l.lead_id) AS leads_count,
        COUNT(DISTINCT CASE
            WHEN l.closing_reason = 'Успешно реализовано' OR l.status_id = 142
                THEN l.lead_id
        END) AS purchases_count,
        SUM(CASE
            WHEN l.closing_reason = 'Успешно реализовано' OR l.status_id = 142
                THEN l.amount
        END) AS revenue,
        SUM(COALESCE(ya.daily_spent, 0) + COALESCE(vk.daily_spent, 0))
            AS total_cost
    FROM sessions AS s
    LEFT JOIN leads AS l ON s.visitor_id = l.visitor_id
    LEFT JOIN ya_ads AS ya
        ON
            s.source = ya.utm_source
            AND s.medium = ya.utm_medium
            AND s.campaign = ya.utm_campaign
            AND DATE(s.visit_date) = ya.campaign_date
    LEFT JOIN vk_ads AS vk
        ON
            s.source = vk.utm_source
            AND s.medium = vk.utm_medium
            AND s.campaign = vk.utm_campaign
            AND DATE(s.visit_date) = vk.campaign_date
    GROUP BY
        DATE(s.visit_date),
        s.source,
        s.medium,
        s.campaign
)

SELECT
    visit_date,
    visitors_count,
    utm_source,
    utm_medium,
    utm_campaign,
    total_cost,
    leads_count,
    purchases_count,
    revenue
FROM daily_metrics
ORDER BY
    visit_date ASC,
    visitors_count DESC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC,
    revenue DESC NULLS LAST;
