
SET search_path TO public;

-- Compares results for Delaware and the US


-- 1. See the number of Delaware PWS in each status
SELECT status, COUNT(*) AS PWS
FROM pws_levels
WHERE State = 'DE'
GROUP BY status
ORDER BY PWS DESC;

-- 2. Rank Delaware PWS by how far above the limit they are
SELECT PWSID, PWSName, max_ratio, compounds_above_limit, status, level
FROM pws_levels
WHERE State = 'DE'
ORDER BY max_ratio DESC;

-- 3. See flagged sample points and compounds (possible/above limit) in Delaware
SELECT i.PWSName, p.*
FROM samplepoint_results p
JOIN pws_info i ON p.PWSID = i.PWSID
WHERE i.State = 'DE' AND p.status <> 'Below limit'
ORDER BY p.status, p.ratio_to_limit DESC;

-- 4. See the number of PWS in Delaware that are a Level 3 Priority at different cutoffs
SELECT c.cutoff, COUNT(l.PWSID) AS PWS
FROM (SELECT 1.5 AS cutoff UNION ALL SELECT 2 UNION ALL SELECT 2.5 UNION ALL SELECT 3) c
LEFT JOIN pws_levels l
       ON l.State = 'DE' AND l.status = 'Above limit' AND l.max_ratio >= c.cutoff
GROUP BY c.cutoff
ORDER BY c.cutoff;

-- 5. See the percentage of PWS above limit by state
--    Display only states with at least 10 included PWS to avoid very small groups
--    (UCMR 5 tests every large system but only some small ones, so this is for context)
SELECT
    State,
    COUNT(*) AS pws,
    SUM(CASE WHEN status = 'Above limit' THEN 1 ELSE 0 END) AS above_limit,
    ROUND(100.0 * SUM(CASE WHEN status = 'Above limit' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_above_limit
FROM pws_levels
GROUP BY State
HAVING COUNT(*) >= 10
ORDER BY pct_above_limit DESC;

-- 6. See the national percentage of PWS that are above limit
SELECT
    COUNT(*) AS pws,
    ROUND(100.0 * SUM(CASE WHEN status = 'Above limit' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_above_limit
FROM pws_levels;

-- 7. See the percentage of Delaware PWS with at least one detection of each compound
SELECT
    Contaminant,
    ROUND(100.0 * SUM(any_detect) / COUNT(*), 3) AS pct_of_pws
FROM (
    SELECT PWSID, Contaminant, MAX(detected) AS any_detect
    FROM results
    WHERE State = 'DE'
    GROUP BY PWSID, Contaminant
) AS system_detections
GROUP BY Contaminant
ORDER BY pct_of_pws DESC;
