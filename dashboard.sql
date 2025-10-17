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
