-- RFM --

-- # Veri setindeki en son alışverişin yapıldığı tarihten 2 gün sonrasını analiz tarihi olarak alınacaktır.


SELECT MAX(InvoiceDate)
FROM [online_retail].[dbo].[Online Retail]

-- 20111212  MAX tarihİN 2GÜN SONRASI TARİHİ.

SELECT 
                                        
--RECENCY , FREQUENCY ,MONETARY DEĞERLERİNİ BULAN SORGULARI BİR TABLODA BİRBİRİNE CUSTOMERID KULLANARAAK BAĞLICAZ   

(SELECT CRM.CustomerID, 
       DATEDIFF(DAY, MAX(CRM.InvoiceDate), '20111209') AS Recency
FROM PLAYGROUND.dbo.CRM AS CRM
GROUP BY CRM.CustomerID) RECENCY,

(SELECT CRM.CustomerID, 
       COUNT(CRM.InvoiceNo) AS Frequency
FROM PLAYGROUND.dbo.CRM AS CRM
GROUP BY CRM.CustomerID) FREQUENCY,
                                      
(SELECT CRM.CustomerID,
    SUM(UnitPrice*Quantity) AS MONETARY
FROM PLAYGROUND.dbo.CRM AS CRM
GROUP BY CRM.CustomerID)  MONETARY

SELECT
RECENCY.CustomerID,
RECENCY.Recency,
FREQUENCY.Frequency,
MONETARY.MONETARY,
NULL RECENCY_SCORE,
NULL FREQUENCY_SCORE,
NULL MONETARY_SCORE
INTO online_retail_data_RFM
FROM (  SELECT CRM.CustomerID, 
        DATEDIFF(DAY, MAX(CRM.InvoiceDate), '20111209') AS Recency
        FROM PLAYGROUND.dbo.CRM AS CRM
        GROUP BY CRM.CustomerID) RECENCY
JOIN (  SELECT CRM.CustomerID, 
        COUNT(CRM.InvoiceNo) AS Frequency
        FROM PLAYGROUND.dbo.CRM AS CRM
        GROUP BY CRM.CustomerID) FREQUENCY
ON  FREQUENCY.CustomerID = RECENCY.CustomerID
JOIN (SELECT CRM.CustomerID,
    SUM(UnitPrice*Quantity) AS MONETARY
    FROM PLAYGROUND.dbo.CRM AS CRM
    GROUP BY CRM.CustomerID) MONETARY
ON MONETARY.CustomerID=Recency.CustomerID

--LAZIM OLDU
DROP TABLE PLAYGROUND.dbo.online_retail_data_rfm



--OLUŞTURULAN RFM TABLOSUNU İNCELEYELİM
SELECT
*
FROM [PLAYGROUND].[dbo].[online_retail_data_RFM]

/*
###############################################################
# RF ve RFM Skorlarının Hesaplanması (Calculating RF and RFM Scores)
###############################################################
#  Recency, Frequency ve Monetary metriklerinin 1-5 arasında skorlara çevrilmesi ve
# Bu skorları recency_score, frequency_score ve monetary_score olarak kaydedilmesi
*/

UPDATE [PLAYGROUND].[dbo].[online_retail_data_RFM]
SET RECENCY_SCORE = (
                    SELECT 
                        SCORE
                    FROM (
                        SELECT RFM.*,
                            NTILE(5) OVER(ORDER BY Recency DESC) SCORE
                        FROM [PLAYGROUND].[dbo].[online_retail_data_RFM] AS RFM
                        )S1
                    WHERE S1.CustomerID = [PLAYGROUND].[dbo].[online_retail_data_RFM].CustomerID
                    )

UPDATE [PLAYGROUND].[dbo].[online_retail_data_RFM]
SET FREQUENCY_SCORE = (
                    SELECT 
                        SCORE
                    FROM (
                        SELECT RFM.*,
                            NTILE(5) OVER(ORDER BY Frequency DESC) SCORE
                        FROM [PLAYGROUND].[dbo].[online_retail_data_RFM] AS RFM
                        )S1
                    WHERE S1.CustomerID = [PLAYGROUND].[dbo].[online_retail_data_RFM].CustomerID
                    )

UPDATE [PLAYGROUND].[dbo].[online_retail_data_RFM]
SET MONETARY_SCORE = (
                    SELECT 
                        SCORE
                    FROM (
                        SELECT RFM.*,
                            NTILE(5) OVER(ORDER BY MONETARY DESC) SCORE
                        FROM [PLAYGROUND].[dbo].[online_retail_data_RFM] AS RFM
                        )S1
                    WHERE S1.CustomerID = [PLAYGROUND].[dbo].[online_retail_data_RFM].CustomerID
                    )

--GÜNCELLENEN RFM TABLOSUNU İNCELEYELİM
SELECT
*
FROM [PLAYGROUND].[dbo].[online_retail_data_RFM]

-- # RECENCY_SCORE ve FREQUENCY_SCORE’u tek bir değişken olarak ifade edilmesi ve RF_SCORE olarak kaydedilmesi
ALTER TABLE [PLAYGROUND].[dbo].[online_retail_data_RFM]
ADD RF_SCORE AS CONCAT(RECENCY_SCORE,FREQUENCY_SCORE)

-- # RECENCY_SCORE ve FREQUENCY_SCORE ve MONETARY_SCORE'u tek bir değişken olarak ifade edilmesi ve RFM_SCORE olarak kaydedilmesi
ALTER TABLE [PLAYGROUND].[dbo].[online_retail_data_RFM]
ADD RFM_SCORE AS CONCAT(RECENCY_SCORE,FREQUENCY_SCORE,MONETARY_SCORE)

-- *
-- ###############################################################
-- # RF Skorlarının Segment Olarak Tanımlanması
-- ###############################################################
-- # Oluşturulan RFM skorların daha açıklanabilir olması için segment tanımlama ve RF_SCORE'u segmentlere çevirme
-- */
-- hibernating '[1-2]%' '[1-2]%'
-- at_Risk [1-2]% [3-4]%
-- cant_loose [1-2]% [5]%
-- about_to_sleep [3]% [1-2]%
-- need_attention [3]% [3]%
-- loyal_customers [3-4]% [4-5]%
-- promising [4]% [1]%
-- new_customers [5]% [1]%
-- potential_loyalists [4-5]% [2-3]%
-- champions [5]% [4-5]%

--SEGMENT adında yeni bir kolon oluşturma

ALTER TABLE [PLAYGROUND].[dbo].[online_retail_data_RFM] 
ADD SEGMENT VARCHAR(50) DEFAULT NULL

SELECT *FROM [PLAYGROUND].[dbo].[online_retail_data_RFM] 

UPDATE [PLAYGROUND].[dbo].[online_retail_data_RFM] 
SET SEGMENT = 'hibernating'
WHERE RECENCY_SCORE LIKE '[1-2]%' AND FREQUENCY_SCORE LIKE '[1-2]%'

UPDATE [PLAYGROUND].[dbo].[online_retail_data_RFM] 
 SET SEGMENT ='at_Risk'
WHERE RECENCY_SCORE LIKE '[1-2]%' AND FREQUENCY_SCORE LIKE '[3-4]%'

-- Can't Loose sınıfının oluşturulması
UPDATE [PLAYGROUND].[dbo].[online_retail_data_RFM] 
 SET SEGMENT ='cant_loose'
WHERE RECENCY_SCORE LIKE '[1-2]%' AND FREQUENCY_SCORE LIKE '[5]%'

-- About to Sleep sınıfının oluşturulması
UPDATE [PLAYGROUND].[dbo].[online_retail_data_RFM] 
 SET SEGMENT ='about_to_sleep'
WHERE RECENCY_SCORE LIKE '[3]%' AND FREQUENCY_SCORE LIKE '[1-2]%'

-- Need Attention sınıfının oluşturulması
UPDATE [PLAYGROUND].[dbo].[online_retail_data_RFM] 
 SET SEGMENT ='need_attention'
WHERE RECENCY_SCORE LIKE '[3]%' AND FREQUENCY_SCORE LIKE '[3]%'

-- Loyal Customers sınıfının oluşturulması
UPDATE [PLAYGROUND].[dbo].[online_retail_data_RFM] 
 SET SEGMENT ='loyal_customers'
WHERE RECENCY_SCORE LIKE '[3-4]%' AND FREQUENCY_SCORE LIKE '[4-5]%'

-- Promising sınıfının oluşturulması
UPDATE [PLAYGROUND].[dbo].[online_retail_data_RFM] 
 SET SEGMENT ='promising'
WHERE RECENCY_SCORE LIKE '[4]%' AND FREQUENCY_SCORE LIKE '[1]%'

-- New Customers sınıfının oluşturulması
UPDATE [PLAYGROUND].[dbo].[online_retail_data_RFM] 
 SET SEGMENT ='new_customers'
WHERE RECENCY_SCORE LIKE '[5]%' AND FREQUENCY_SCORE LIKE '[1]%'

-- Potential Loyalist sınıfının oluşturulması
UPDATE [PLAYGROUND].[dbo].[online_retail_data_RFM] 
 SET SEGMENT ='potential_loyalists'
WHERE RECENCY_SCORE LIKE '[4-5]%' AND FREQUENCY_SCORE LIKE '[2-3]%'

-- Champions sınıfının oluşturulması
UPDATE [PLAYGROUND].[dbo].[online_retail_data_RFM]
SET SEGMENT = 'champions'
WHERE RECENCY_SCORE LIKE '[5]%' AND FREQUENCY_SCORE LIKE '[4-5]%'

--/*
-- ###############################################################
-- #Aksiyon zamanı!
-- ###############################################################
-- # 1. Segmentlerin recency, frequnecy ve monetary ortalamalarını inceleyiniz.
-- */

SELECT 
SEGMENT ,
ROUND(AVG(Recency),0),
ROUND(AVG(Frequency),0),
ROUND(AVG(MONETARY),0)
FROM [PLAYGROUND].[dbo].[online_retail_data_RFM]
GROUP BY SEGMENT

