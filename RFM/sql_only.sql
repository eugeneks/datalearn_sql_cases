WITH orders AS (
SELECT
  InvoiceNo
  , InvoiceDate
  , CustomerID
  , SUM(Quantity*UnitPrice) AS Price
  , MAX(InvoiceDate) OVER() + INTERVAL '1' DAY  AS Now
FROM 
  sales
WHERE 
  CustomerID IS NOT NULL
GROUP BY 
  InvoiceNo
  , InvoiceDate
  , CustomerID
)
, base AS (
SELECT 
  CustomerID
  , MIN(datediff(Now, InvoiceDate)) AS Recency
  , COUNT(DISTINCT InvoiceNo) AS Frequency
  , SUM(Price) AS Monetary
FROM
  orders
WHERE 
    InvoiceDate >= Now - INTERVAL '365' DAY
GROUP BY 
  CustomerID
)
, bins AS(
SELECT
     percentile(Recency, 0.2) AS R_20
    , percentile(Recency, 0.4) AS R_40
    , percentile(Recency, 0.6) AS R_60
    , percentile(Recency, 0.8) AS R_80

    , percentile(Frequency, 0.2) AS F_20
    , percentile(Frequency, 0.4) AS F_40
    , percentile(Frequency, 0.6) AS F_60
    , percentile(Frequency, 0.8) AS F_80

    , percentile(Monetary, 0.2) AS M_20
    , percentile(Monetary, 0.4) AS M_40
    , percentile(Monetary, 0.6) AS M_60
    , percentile(Monetary, 0.8) AS M_80
FROM 
    base
)
, rfm AS(
SELECT
 CustomerID
  , Recency
  , Frequency
  , Monetary
  , CASE 
         WHEN Recency <= R_20 THEN 5
         WHEN Recency <= R_40 THEN 4
         WHEN Recency <= R_60 THEN 3
         WHEN Recency <= R_80 THEN 2
         ELSE 1
    END AS R
 , CASE 
         WHEN Frequency <= F_20 THEN 1
         WHEN Frequency <= F_40 THEN 2
         WHEN Frequency <= F_60 THEN 3
         WHEN Frequency <= F_80 THEN 4
         ELSE 5
    END AS F
   , CASE 
         WHEN Monetary <= M_20 THEN 1
         WHEN Monetary <= M_40 THEN 2
         WHEN Monetary <= M_60 THEN 3
         WHEN Monetary <= M_80 THEN 4
         ELSE 5
    END AS M 
FROM
  base
CROSS JOIN 
  bins
)
SELECT
    *
    , Concat(r,f,m ) AS RFM_Score
FROM 
    rfm
ORDER BY 
    CustomerID

    ;

WITH seg_map AS(
SELECT 
  map(
  '[1-2][1-2]','hibernating',
   '[1-2][3-4]', 'at risk',
   '[1-2]5', 'can not loose',
   '3[1-2]', 'about to sleep',
   '33', 'need attention',
   '[3-4][4-5]', 'loyal customers',
   '41', 'promising',
   '51', 'new customers',
   '[4-5][2-3]', 'potential loyalists',
   '5[4-5]', 'champions'
  ) AS seg
)
,  segments AS(
SELECT
  rfm.*
  , explode(seg) AS (segKey, segValue) 
FROM
  rfm
CROSS JOIN
  seg_map
)
SELECT
  CustomerID
  , Recency
  , Frequency
  , Monetary
  , R
  , F
  , M
  , RFM_Score
  , segValue AS Segment
FROM 
  segments 
WHERE 
  concat(R,F) REGEXP segKey