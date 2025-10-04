--last_paid_click.csv
WITH last_paid_click AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY s.visitor_id
            ORDER BY
                CASE
                    WHEN
                        s.medium IN (
                            'cpc',
                            'cpm',
                            'cpa',
                            'youtube',
                            'cpp',
                            'tg',
                            'social'
                        )
                        THEN 1
                    ELSE 0
                END DESC,
                s.visit_date DESC
        ) AS rn
    FROM sessions AS s
    WHERE s.medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
)

SELECT
    lpc.visitor_id,
    lpc.visit_date,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    l.lead_id,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id
FROM last_paid_click AS lpc
LEFT JOIN leads AS l ON lpc.visitor_id = l.visitor_id
WHERE lpc.rn = 1
ORDER BY
    l.amount DESC NULLS LAST,
    lpc.visit_date ASC,
    lpc.utm_source ASC,
    lpc.utm_medium ASC,
    lpc.utm_campaign ASC
LIMIT 10;
