--Observe the size of the table without the clustered columnstore index
SELECT t.NAME AS TableName
	,s.NAME AS SchemaName
	,p.rows AS RowCounts
	,SUM(a.total_pages) * 8 AS TotalSpaceKB
	,CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS TotalSpaceMB
	,SUM(a.used_pages) * 8 AS UsedSpaceKB
	,CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS UsedSpaceMB
	,(SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB
	,CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)) AS UnusedSpaceMB
FROM sys.tables t
INNER JOIN sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.OBJECT_ID
	AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
LEFT JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.NAME = 'Order_Big_CCI'
GROUP BY t.NAME
	,s.NAME
	,p.Rows
ORDER BY t.NAME TotalSpaceMB 15710.48

--Run the query and observe the IO statistics and the execution time
SET STATISTICS TIME
	,IO ON

SELECT dc.city
	,avg(f.[Total Including Tax]) AS AvgOrderCost
FROM fact.Order_Big_CCI f
INNER JOIN Dimension.City dc ON dc.[City Key] = f.[City Key]
GROUP BY dc.city
HAVING avg(f.[Total Including Tax]) > 700
ORDER BY AvgOrderCost DESC

--Create the Columnstore Index (Note: This will take 5-10 minutes)

CREATE CLUSTERED COLUMNSTORE INDEX CCI_Orders ON Fact.Order_Big_CCI


--Observe the size of the table wit the clustered columnstore index
SELECT t.NAME AS TableName
	,s.NAME AS SchemaName
	,p.rows AS RowCounts
	,SUM(a.total_pages) * 8 AS TotalSpaceKB
	,CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS TotalSpaceMB
	,SUM(a.used_pages) * 8 AS UsedSpaceKB
	,CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS UsedSpaceMB
	,(SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB
	,CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)) AS UnusedSpaceMB
FROM sys.tables t
INNER JOIN sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.OBJECT_ID
	AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
LEFT JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.NAME = 'Order_Big_CCI'
GROUP BY t.NAME
	,s.NAME
	,p.Rows
ORDER BY t.NAME 

--Rerun the Query to Observe CS Performance Improvements

SET STATISTICS TIME
	,IO ON

SELECT dc.city
	,avg(f.[Total Including Tax]) AS AvgOrderCost
FROM fact.Order_Big_CCI f
INNER JOIN Dimension.City dc ON dc.[City Key] = f.[City Key]
GROUP BY dc.city
HAVING avg(f.[Total Including Tax]) > 700
ORDER BY AvgOrderCost DESC
