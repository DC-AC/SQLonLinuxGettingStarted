CREATE OR ALTER PROCEDURE InMemory.Insert500ThousandVehicleLocations
WITH NATIVE_COMPILATION, SCHEMABINDING
AS
BEGIN ATOMIC WITH
(
    TRANSACTION ISOLATION LEVEL = SNAPSHOT,
    LANGUAGE = N'English'
)
    DECLARE @Counter int = 0;
    WHILE @Counter < 500000
    BEGIN
        INSERT InMemory.VehicleLocations
            (RegistrationNumber, TrackedWhen, Longitude, Latitude)
        VALUES
            (N'EA-232-JB', SYSDATETIME(), 125.4, 132.7);
        SET @Counter += 1;
    END;
    RETURN 0;
END;
GO

--Rerun with Natively Compiled Stored Procedure

declare @start datetime2
set @start = SYSDATETIME()
EXECUTE InMemory.Insert500ThousandVehicleLocations
select datediff(ms,@start, sysdatetime()) as 'insert into memory-optimized table using native compilation (in ms)'
GO
