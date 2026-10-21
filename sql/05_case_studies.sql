
SET search_path TO public;

-- Sampling history for the three case-study PWS:
-- Georgetown = DE0000592, MSC = DE0000634, Veolia (formerly SUEZ) = DE0000564


-- GEORGETOWN --

-- All sample points
SELECT DISTINCT FacilityID, SamplePointID, SamplePointName, SamplePointType, FacilityWaterType
FROM results
WHERE PWSID = 'DE0000592';

-- Every sampling event, including events where nothing was detected.
-- total_detected_ppt is NULL when nothing was detected (not a measured zero).
SELECT
    CollectionDate,
    SampleEventCode,
    SamplePointID,
    ROUND(SUM(CASE WHEN detected = 1 THEN lower_ppt END), 1) AS total_detected_ppt,
    SUM(detected) AS compounds_detected
FROM results
WHERE PWSID = 'DE0000592'
GROUP BY CollectionDate, FacilityID, SamplePointID, SampleEventCode
ORDER BY CollectionDate, SamplePointID, SampleEventCode;

-- The status against federal limits
SELECT SamplePointID, Contaminant, lower_ppt, upper_ppt, limit_ppt, ratio_to_limit, detects, samples, status
FROM samplepoint_results
WHERE PWSID = 'DE0000592'
ORDER BY SamplePointID, ratio_to_limit DESC;

-- Hazard index
SELECT SamplePointID, hazard_index
FROM samplepoint_hi
WHERE PWSID = 'DE0000592';


-- MSC --
-- All sample points
SELECT DISTINCT FacilityID, SamplePointID, SamplePointName, SamplePointType, FacilityWaterType
FROM results
WHERE PWSID = 'DE0000634';

-- Every sampling event, including events where nothing was detected.
SELECT
    CollectionDate,
    SampleEventCode,
    SamplePointID,
    ROUND(SUM(CASE WHEN detected = 1 THEN lower_ppt END), 1) AS total_detected_ppt,
    SUM(detected) AS compounds_detected
FROM results
WHERE PWSID = 'DE0000634'
GROUP BY CollectionDate, FacilityID, SamplePointID, SampleEventCode
ORDER BY CollectionDate, SamplePointID, SampleEventCode;

-- Which compounds were detected? (PFBA and PFPeA have no federal limit)
SELECT CollectionDate, Contaminant, lower_ppt
FROM results
WHERE PWSID = 'DE0000634' AND detected = 1
ORDER BY CollectionDate, Contaminant;
-- Checking every compound tested
SELECT SamplePointID, Contaminant, lower_ppt, upper_ppt, limit_ppt, ratio_to_limit, detects, samples, status
FROM samplepoint_results
WHERE PWSID = 'DE0000634';


-- VEOLIA (FORMERLY SUEZ) --
-- All sample points
SELECT DISTINCT FacilityID, SamplePointID, SamplePointName, SamplePointType, FacilityWaterType
FROM results
WHERE PWSID = 'DE0000564';

-- Every sampling event, including events where nothing was detected.
SELECT
    CollectionDate,
    SampleEventCode,
    SamplePointID,
    ROUND(SUM(CASE WHEN detected = 1 THEN lower_ppt END), 1) AS total_detected_ppt,
    SUM(detected) AS compounds_detected
FROM results
WHERE PWSID = 'DE0000564'
GROUP BY CollectionDate, FacilityID, SamplePointID, SampleEventCode
ORDER BY CollectionDate, SamplePointID, SampleEventCode;
-- Checking every compound tested
SELECT SamplePointID, Contaminant, lower_ppt, upper_ppt, limit_ppt, ratio_to_limit, detects, samples, status
FROM samplepoint_results
WHERE PWSID = 'DE0000564'
ORDER BY SamplePointID, ratio_to_limit DESC;

SELECT SamplePointID, hazard_index
FROM samplepoint_hi
WHERE PWSID = 'DE0000564';


-- A table you can use to choose PWS for more case studies: --
SELECT
    l.PWSName,
    l.Size,
    l.max_ratio,
    l.compounds_above_limit,
    COUNT(DISTINCT CASE WHEN p.status <> 'Below limit' THEN ROW(p.FacilityID, p.SamplePointID) END) AS flagged_points,
    COUNT(DISTINCT ROW(p.FacilityID, p.SamplePointID)) AS sampling_points,
    l.level
FROM pws_levels l
JOIN samplepoint_results p ON l.PWSID = p.PWSID
WHERE l.State = 'DE' AND l.status <> 'Below limit'
GROUP BY l.PWSID, l.PWSName, l.Size, l.max_ratio, l.compounds_above_limit, l.level
ORDER BY l.max_ratio DESC;
