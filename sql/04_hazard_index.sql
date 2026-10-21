
SET search_path TO public;

BEGIN;

-- Combines the hazard index for PFHxS, PFNA, HFPO-DA, and PFBS

-- Each compound is divided by its health-based concentration, and a total above 1 is above limit
-- Nondetects count as 0, so each value means "at least this high"


-- 1. Create a hazard index table
DROP TABLE IF EXISTS hi_limits;
CREATE TABLE hi_limits (Contaminant TEXT PRIMARY KEY, hbwc_ppt NUMERIC);
INSERT INTO hi_limits VALUES ('PFHxS', 10), ('PFNA', 10), ('HFPO-DA', 10), ('PFBS', 2000);

-- 2. Create a table that shows the hazard index for each sampling event
DROP TABLE IF EXISTS hi_events;
CREATE TABLE hi_events AS
SELECT
    r.PWSID,
    r.FacilityID,
    r.SamplePointID,
    r.CollectionDate,
    r.SampleEventCode,
    SUM(r.lower_ppt / h.hbwc_ppt) AS hazard_quotient,
    COUNT(*) AS result_rows,
    COUNT(DISTINCT r.Contaminant) AS compounds_reported
FROM results r
JOIN hi_limits h ON r.Contaminant = h.Contaminant
GROUP BY r.PWSID, r.FacilityID, r.SamplePointID, r.CollectionDate, r.SampleEventCode;

-- 3. Check the excluded events
SELECT *
FROM hi_events
WHERE compounds_reported <> 4;

-- 4. Avg complete, non-repeated events at each sample point
-- Sample points with no eligible events are excluded from samplepoint_hi
DROP TABLE IF EXISTS samplepoint_hi;
CREATE TABLE samplepoint_hi AS
SELECT PWSID, FacilityID, SamplePointID, ROUND(AVG(hazard_quotient), 6) AS hazard_index
FROM hi_events
WHERE compounds_reported = 4
  AND result_rows = compounds_reported
GROUP BY PWSID, FacilityID, SamplePointID;

-- 5. See the sample points in Delaware with the highest hazard index
SELECT i.PWSName, h.SamplePointID, h.hazard_index,
       CASE WHEN h.hazard_index > 1 THEN 'Above limit' ELSE 'At or below 1 (lower bound)' END AS hi_status
FROM samplepoint_hi h
JOIN pws_info i ON h.PWSID = i.PWSID
WHERE i.State = 'DE'
ORDER BY h.hazard_index DESC
LIMIT 10;

COMMIT;
