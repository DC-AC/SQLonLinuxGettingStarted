/* This query will combine data from the Application.People table with data from the CustomFields column which is JSON data 
using the OPENJSON Function and combine it with other data from the table in a tabular view.
*/

select FullName, LogonName, EmailAddress, Title, CommissionRate
from Application.People
 cross apply OPENJSON(CustomFields)
             WITH(Title nvarchar(50), HireDate datetime2, OtherLanguages nvarchar(max) as json,
                  PrimarySalesTerritory nvarchar(50), CommissionRate float)
 
 --The next query uses the JSON_QUERY function to return a JSON fragement in query results
 
SELECT PersonID,FullName,
 JSON_QUERY(CustomFields,'$.OtherLanguages') AS Languages
FROM Application.People


--Next You can see a simple exmaple of how JSON_MODIFY is used.

DECLARE @info NVARCHAR(100)='{"name":"John","skills":["C#","SQL"]}'

PRINT @info

-- Multiple updates  

SET @info=JSON_MODIFY(JSON_MODIFY(JSON_MODIFY(@info,'$.name','Mike'),'$.surname','Smith'),'append $.skills','Azure')

PRINT @info

--This example can be used to increment a value

DECLARE @stats NVARCHAR(100)='{"click_count": 173}'

PRINT @stats

-- Increment value  

SET @stats=JSON_MODIFY(@stats,'$.click_count',
 CAST(JSON_VALUE(@stats,'$.click_count') AS INT)+1)

PRINT @stats

--Enable Actual Execution Plan Collection for this query (Ctrl+M in SSMS)

set statistics time, io on
SELECT PersonID, PreferredName, JSON_VALUE(UserPreferences, '$.theme') as Theme
FROM Application.People
WHERE JSON_VALUE(UserPreferences, '$.theme') = N'blitzer'

ALTER TABLE Application.People SET (SYSTEM_VERSIONING = OFF)
GO
ALTER TABLE Application.People 
ADD vPrefTheme AS JSON_VALUE(UserPreferences,'$.theme')
GO

CREATE INDEX NCI_people_json_userpref_theme
ON Application.People(vPrefTheme)  
INCLUDE (PersonID, PreferredName)
GO
ALTER TABLE Application.People SET (SYSTEM_VERSIONING = ON)
GO

--See if the index is used in this rerun of the query

SELECT PersonID, PreferredName, JSON_VALUE(UserPreferences, '$.theme') as Theme
FROM Application.People
WHERE JSON_VALUE(UserPreferences, '$.theme') = N'blitzer'
