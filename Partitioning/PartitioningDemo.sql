/* Partitioning with Clustered Columnstore Index
This demo builds upon the “expanded” and Clustered Columnstore Indexed version of the Facts.Orders table in the WideWorldImportersDW database built in the previous demonstration.
Create Needed Database Objects
Create the Partition Function to define boundary values to create yearly partitions within the table. Run the following TSQL
*/

CREATE PARTITION FUNCTION FactOrder_OrderDateKey_PartitionFunction (date)
	AS RANGE RIGHT FOR VALUES (	 '2013-01-01'
								,'2014-01-01'
								,'2015-01-01'
								,'2016-01-01'
								,'2017-01-01'
								)

/* Create the Partition Scheme, which will assign the file groups where data in each partition will be stored.
“Historical” partitions will be stored on a secondary filegroup, while more-recent partitions remain on the PRIMARY filegroup.
Run the following TSQL:
*/

CREATE PARTITION SCHEME FactOrder_Big_CCI_OrderDateKey_PartitionScheme
	AS PARTITION FactOrder_Big_CCI_OrderDateKey_PartitionFunction
	TO ( [UserData]
		,[UserData]
		,[UserData]
		,[PRIMARY]
		,[PRIMARY]
		,[PRIMARY]
		)

/* Partition the Data
Once the partitions have been defined, the index(es) on the table need to be rebuilt so that they align with the partition. 
This will actually move the data so that it is stored in the filegroups defined by the partition scheme.
Clustered Columnstore Indexes cannot be rebuilt directly to partition align them, 
so the first step will be to drop the existing clustered columnstore index using this TSQL:
*/

DROP INDEX [CCI_Orders] ON [Fact].[Order_Big_CCI]

/* Create a rowstore clustered index on the table, aligned with the proper partition scheme. 
This will move row data to the appropriate filegroup as defined in the scheme. This step will take some time. */

CREATE CLUSTERED INDEX [CCI_Order_Big_CCI] ON [fact].[Order_Big_CCI]
(
	[Order Key] ASC,
	[Order Date Key] ASC
)WITH (MAXDOP = 0) 
on FactOrder_Big_CCI_OrderDateKey_PartitionScheme([Order Date Key])
GO

/* Recreate the clustered columnstore index on the table, replacing the previously-created clusterd index which will 
inherit its alignment with the partition scheme:
*/ 

CREATE CLUSTERED COLUMNSTORE INDEX [CCI_Order_Big_CCI] ON [Fact].[Order_Big_CCI]
WITH (MAXDOP = 0, DROP_EXISTING = ON)
ON FactOrder_Big_CCI_OrderDateKey_PartitionScheme([Order Date Key])

/* To view the row distribution among the partitions and corresponding filegroups, run the following query: */


SELECT p.partition_number, fg.name, p.rows 
	FROM sys.partitions p 
		INNER JOIN sys.allocation_units au 
			ON au.container_id = p.hobt_id 
		INNER JOIN sys.filegroups fg 
			ON fg.data_space_id = au.data_space_id 
	WHERE p.object_id = OBJECT_ID('fact.Order_Big_CCI')
		AND au.type = 1

/* Switch Partitions
This final section will demonstrate how data loaded into another table—such as a staged table—can be switched 
into the existing partitioned table.
Create data to serve as newly-loaded stage data destined for the Fact.Order_Big_CCI table. 
This data contains rows from 2017.
*/

SELECT 
	 [Order Key] = ISNULL(ROW_NUMBER() OVER(ORDER BY (SELECT NULL)),-1) 
	,[City Key] 
	,[Customer Key] 
 	,[Stock Item Key] 
 	,DATEADD(yy, 1, [Order Date Key]) as [Order Date Key]
 	,[Picked Date Key] 
 	,[Salesperson Key] 
 	,[Picker Key] 
 	,[WWI Order ID] 
 	,[WWI Backorder ID] 
 	,[Description] 
 	,[Package] 
 	,[Quantity] 
 	,[Unit Price] 
 	,[Tax Rate] 
 	,[Total Excluding Tax] 
 	,[Tax Amount] 
 	,[Total Including Tax] 
 	,[Lineage Key] 
 INTO [dbo].[Staged_Order_Rows] 
 FROM [Fact].[Order] o
 CROSS JOIN 
 (SELECT * FROM SYS.columns WHERE object_id < 50) tmp 
	where o.[Order Date Key] >= '2013-01-01'
		and o.[Order Date Key] < '2014-01-01'

--Create a clustered columnstore index on the stage table that matches the one on the target fact table: 
CREATE CLUSTERED COLUMNSTORE INDEX [CCI_Order_Big_CCI] ON [dbo].[Staged_Order_Rows]
ON [UserData];

--In order to switch the contents of a table into a partitioned table, the source table must have a constraint(s) on the columns that correspond to the values that would be allowed in the target partition of the target table. In this case, the “stage” table must have values in the Staged Order Row restricted to only the year 2017. The following constraint will accomplish this task:
ALTER TABLE [dbo].[Staged_Order_Rows] 
ADD CONSTRAINT OrderDateKeyConstraint CHECK ([Order Date Key] >= '2017-01-01' and [Order Date Key] < '2018-01-01') ;  

--The following TSQL will switch in the data from the “stage” table to partition 6 (the 2017 partition) within Fact.Order_Big_CCI:
ALTER TABLE [dbo].[Staged_Order_Rows]
	SWITCH TO [Fact].[Order_Big_CCI] PARTITION 6

--Re-run the query from Step 4 in the previous section to observe the rowcounts in the target table, and the below query to note that there are no rows remaining in the “stage” table:
select count(*)
	from [dbo].[Staged_Order_Rows]

