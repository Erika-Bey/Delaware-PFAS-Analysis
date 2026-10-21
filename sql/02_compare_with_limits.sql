
SET search_path TO public;

BEGIN;

-- Compares each regulated compound with its federal limit, then avgs results by sample point and PWS
-- (Also assigns a priority level for each PWS!)

-- (Limits are from the 2024 federal rule)


-- 1. Create a table of regulated compounds and their limits (ppt)
DROP TABLE IF EXISTS limits;
CREATE TABLE limits (Contaminant TEXT PRIMARY KEY, limit_ppt NUMERIC);
INSERT INTO limits VALUES ('PFOA', 4), ('PFOS', 4), ('PFHxS', 10), ('PFNA', 10), ('HFPO-DA', 10);


-- 2. For each sample point, avg the concentration of sampling events per compound
DROP TABLE IF EXISTS samplepoint_averages;
CREATE TEMP TABLE samplepoint_averages AS
SELECT
    r.PWSID,
    r.FacilityID,
    r.SamplePointID,
    r.Contaminant,
    ROUND(AVG(r.lower_ppt), 6) AS lower_ppt,
    ROUND(AVG(r.upper_ppt), 6) AS upper_ppt,
    COUNT(*) AS samples,
    SUM(r.detected) AS detects,
    l.limit_ppt
FROM public.results r
JOIN public.limits l ON r.Contaminant = l.Contaminant
GROUP BY
    r.PWSID, r.FacilityID, r.SamplePointID, r.Contaminant, l.limit_ppt;

-- 3. Create a table that shows the status of each sample point:
--    Above limit: lower bound is above the limit
--    Possible: lower bound is at or below the limit, upper bound is above it
--    Below limit: upper bound is at or below the limit
DROP TABLE IF EXISTS public.samplepoint_results;
CREATE TABLE public.samplepoint_results AS
SELECT
    samplepoint_averages.*,
    lower_ppt / limit_ppt AS ratio_to_limit,
    CASE
        WHEN lower_ppt > limit_ppt THEN 'Above limit'
        WHEN upper_ppt > limit_ppt THEN 'Possible'
        ELSE 'Below limit'
    END AS status
FROM samplepoint_averages;

-- 4. Create a table that shows the status of each PWS
--    (use the worst status among its sample points)
DROP TABLE IF EXISTS pws_info;
CREATE TABLE pws_info AS
SELECT PWSID, MIN(PWSName) AS PWSName, MIN(State) AS State, MIN(Size) AS Size
FROM results
GROUP BY PWSID;

DROP TABLE IF EXISTS public.pws_summary;
CREATE TABLE public.pws_summary AS
SELECT
    PWSID,
    MAX(ratio_to_limit) AS max_ratio,
    COUNT(DISTINCT CASE
        WHEN status = 'Above limit' THEN Contaminant
    END) AS compounds_above_limit, -- number of compounds above limit
    CASE
        WHEN SUM(CASE WHEN status = 'Above limit' THEN 1 ELSE 0 END) > 0
            THEN 'Above limit' -- if any sample points are above limit, PWS is above limit
        WHEN SUM(CASE WHEN status = 'Possible' THEN 1 ELSE 0 END) > 0
            THEN 'Possible'
        ELSE 'Below limit'
    END AS status
FROM public.samplepoint_results
GROUP BY PWSID;


-- 5. Create a table that adds priority levels for each PWS (may be modified)
--    Level 3 = highest priority (x2 the limit or more)
--    Level 2 = above limit
--    Level 1 = resample 
--              (the lower-bound avg is at or below
--              a limit, but the upper-bound avg exceeds it)
--              (Nondetect uncertainty prevents a definite classification, so
--              prioritize follow-up sampling!)
DROP TABLE IF EXISTS pws_levels;
CREATE TABLE pws_levels AS
SELECT
    s.PWSID,
    i.PWSName,
    i.State,
    i.Size,
    s.max_ratio,
    s.compounds_above_limit,
    s.status,
    CASE
        WHEN s.status = 'Above limit' AND s.max_ratio >= 2 THEN 'Level 3: well above limit'
        WHEN s.status = 'Above limit' THEN 'Level 2: above limit'
        WHEN s.status = 'Possible' THEN 'Level 1: resample'
        ELSE 'Below or at limits'
    END AS level
FROM pws_summary s
JOIN pws_info i ON s.PWSID = i.PWSID;

COMMIT;
