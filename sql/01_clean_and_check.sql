
SET search_path TO public;

BEGIN;

-- (Code is written for PostgreSQL)

-- Cleans the raw UCMR5 data and performs quality checks!
-- A result view is saved at the end


-- CHECKS --

-- This candidate key uniquely identifies a sampling event for a compound:
-- PWSID, FacilityID, SamplePointID, CollectionDate, SampleEventCode, Contaminant
-- 1. Make sure that none of these are missing:
SELECT *
FROM ucmr5_raw
WHERE PWSID IS NULL
   OR FacilityID IS NULL
   OR SamplePointID IS NULL
   OR CollectionDate IS NULL
   OR SampleEventCode IS NULL
   OR Contaminant IS NULL;

-- 2. Make sure these are the right candidate keys
-- (there should be no repeated results)
SELECT PWSID, CASE WHEN State = 'DE' THEN '' ELSE FacilityID END AS FacilityID,
       SamplePointID, CollectionDate, SampleEventCode, Contaminant, COUNT(*) AS row_count
FROM ucmr5_raw
GROUP BY PWSID, CASE WHEN State = 'DE' THEN '' ELSE FacilityID END,
         SamplePointID, CollectionDate, SampleEventCode, Contaminant
HAVING COUNT(*) > 1
LIMIT 20;

-- 3. Make sure there are only 2 result signs ('=' for detected compounds and '<' for nondetects)
SELECT AnalyticalResultsSign, COUNT(*) AS row_count
FROM ucmr5_raw
GROUP BY AnalyticalResultsSign;

-- 4. Make sure all detected rows have a value (this should output 0)
SELECT COUNT(*) AS detected_without_value
FROM ucmr5_raw
WHERE AnalyticalResultsSign = '=' AND AnalyticalResultValue IS NULL;

-- 5. Make sure the minimum reporting limit by compound stays the same
SELECT Contaminant, MIN(MRL) AS min_mrl, MAX(MRL) AS max_mrl, COUNT(*) AS row_count
FROM ucmr5_raw
GROUP BY Contaminant
ORDER BY Contaminant;



-- CLEANING --

--  1. Remove lithium (not a PFAS)
--  2. Convert values from ug/L to ppt (x 1000)
--  3. Nondetects (<) are NOT measured zeros, so handle with 2 bounds:
--       lower_ppt: nondetect counts as 0
--       upper_ppt: nondetect counts as its reporting limit
DROP VIEW IF EXISTS public.results;
CREATE OR REPLACE VIEW results AS
SELECT
    PWSID,
    PWSName,
    State,
    Size,
    FacilityID,
    SamplePointID,
    SamplePointName,
    SamplePointType,
    FacilityWaterType,
    CollectionDate,
    Contaminant,
    CASE WHEN AnalyticalResultsSign = '=' THEN 1 ELSE 0 END AS detected,
    MRL * 1000 AS mrl_ppt,
    CASE WHEN AnalyticalResultsSign = '=' THEN AnalyticalResultValue * 1000 ELSE 0 END AS lower_ppt,
    CASE WHEN AnalyticalResultsSign = '=' THEN AnalyticalResultValue * 1000 ELSE MRL * 1000 END AS upper_ppt,
    SampleEventCode
FROM ucmr5_raw
WHERE Contaminant <> 'lithium';

COMMIT;

SELECT * FROM public.results LIMIT 20;
