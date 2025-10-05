WITH tab AS (
    SELECT
        visitor_id,
        visit_date,
        source,
        medium,
        campaign
    FROM (
        SELECT
            visitor_id,
            visit_date,
            source,
            medium,
            campaign,
            ROW_NUMBER() OVER (
                PARTITION BY visitor_id
                ORDER BY visit_date DESC
            ) AS last_visit
        FROM sessions
        WHERE medium != 'organic'
    ) AS s
    WHERE last_visit = 1
),

last_paid_click AS (
    SELECT
        t.visitor_id,
        t.visit_date,
        t.source AS utm_source,
        t.medium AS utm_medium,
        t.campaign AS utm_campaign,
        l.lead_id,
        l.amount,
        l.status_id
    FROM tab AS t
    LEFT JOIN leads AS l
        ON
            t.visitor_id = l.visitor_id
            AND t.visit_date < l.created_at
),

ad_cost AS (
    SELECT
        DATE(campaign_date) AS campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY
        DATE(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
    UNION ALL
    SELECT
        DATE(campaign_date) AS campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY
        DATE(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
),

session_history AS (
    SELECT
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        a.total_cost::INTEGER AS total_cost,
        DATE(lpc.visit_date) AS visit_date,
        COUNT(lpc.visitor_id) AS visitors_count,
        COUNT(lpc.lead_id) AS leads_count,
        COUNT(lpc.lead_id) FILTER (
            WHERE lpc.status_id = 142
        ) AS purchases_count,
        SUM(lpc.amount) FILTER (WHERE lpc.status_id = 142) AS revenue
    FROM last_paid_click AS lpc
    LEFT JOIN ad_cost AS a
        ON
            lpc.utm_medium = a.utm_medium
            AND lpc.utm_source = a.utm_source
            AND lpc.utm_campaign = a.utm_campaign
            AND DATE(lpc.visit_date) = a.campaign_date
    GROUP BY
        DATE(lpc.visit_date),
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        a.total_cost
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
FROM session_history
ORDER BY
    revenue DESC NULLS LAST,
    visit_date ASC,
    visitors_count DESC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC;
