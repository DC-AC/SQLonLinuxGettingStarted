-- Note the time to insert 500 thousand location rows using on-disk
declare @start datetime2
set @start = SYSDATETIME()

DECLARE @RegistrationNumber nvarchar(20);
DECLARE @TrackedWhen datetime2(2);
DECLARE @Longitude decimal(18,4);
DECLARE @Latitude decimal(18,4);

DECLARE @Counter int = 0;
SET NOCOUNT ON;

BEGIN TRAN
WHILE @Counter < 500000
BEGIN
    -- create some dummy data
    SET @RegistrationNumber = N'EA' + RIGHT(N'00' + CAST(@Counter % 100 AS nvarchar(10)), 3) + N'-GL';
    SET @TrackedWhen = SYSDATETIME();
    SET @Longitude = RAND() * 100;
    SET @Latitude = RAND() * 100;

    EXEC OnDisk.InsertVehicleLocation @RegistrationNumber, @TrackedWhen, @Longitude, @Latitude;

    SET @Counter += 1;
END
COMMIT

select datediff(ms,@start, sysdatetime()) as 'insert into disk-based table (in ms)'
GO

-- Now insert the same number of location rows using in-memory and natively compiled
declare @start datetime2
set @start = SYSDATETIME()

DECLARE @RegistrationNumber nvarchar(20);
DECLARE @TrackedWhen datetime2(2);
DECLARE @Longitude decimal(18,4);
DECLARE @Latitude decimal(18,4);

DECLARE @Counter int = 0;
SET NOCOUNT ON;

BEGIN TRAN
WHILE @Counter < 500000
BEGIN
    -- create some dummy data
    SET @RegistrationNumber = N'EA' + RIGHT(N'00' + CAST(@Counter % 100 AS nvarchar(10)), 3) + N'-GL';
    SET @TrackedWhen = SYSDATETIME();
    SET @Longitude = RAND() * 100;
    SET @Latitude = RAND() * 100;

    EXEC InMemory.InsertVehicleLocation @RegistrationNumber, @TrackedWhen, @Longitude, @Latitude;

    SET @Counter += 1;
END
COMMIT

select datediff(ms,@start, sysdatetime()) as 'insert into memory-optimized table (in ms)'
GO
