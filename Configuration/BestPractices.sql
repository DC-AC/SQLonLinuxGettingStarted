/******  BEST PRACTICES  ******/

--Edit line 69/70 for proper TempDB file sizes. For testing volume is set to 2 GB, for prod use the line of code which gets the volume size
--Trace Flag 3226    Suppress the backup transaction log entries from the SQL Server Log

USE MASTER
GO


/* Disable SA Login */
ALTER LOGIN [sa] DISABLE;
GO

--modify model database
ALTER DATABASE model SET RECOVERY SIMPLE;
GO
ALTER DATABASE model MODIFY FILE (NAME = modeldev, FILEGROWTH = 100MB);
GO

ALTER DATABASE model MODIFY FILE (NAME = modellog, FILEGROWTH = 100MB);
GO


--modify msdb database
ALTER DATABASE msdb SET RECOVERY SIMPLE;
GO
ALTER DATABASE msdb MODIFY FILE (NAME = msdbdata, FILEGROWTH = 100MB);
GO

ALTER DATABASE msdb MODIFY FILE (NAME = msdblog, FILEGROWTH = 100MB);
GO

--modify master database
ALTER DATABASE master SET RECOVERY SIMPLE;
GO
ALTER DATABASE master MODIFY FILE (NAME = master, FILEGROWTH = 100MB);
GO

ALTER DATABASE master MODIFY FILE (NAME = mastlog, FILEGROWTH = 100MB);
GO

sp_configure 'set advanced options', 1
GO
RECONFIGURE WITH OVERRIDE
GO

/******  CONFIGURE TEMPDB  DATA FILES ******/

DECLARE @sql_statement NVARCHAR(4000) ,
    @data_file_path NVARCHAR(100) ,
    @drive_size_gb INT ,
    @individ_file_size INT ,
    @number_of_files INT;




SELECT  @data_file_path = ( SELECT DISTINCT
                                    ( LEFT(physical_name,
                                           LEN(physical_name) - CHARINDEX('\',
                                                              REVERSE(physical_name))
                                           + 1) )
                            FROM    sys.master_files mf
                                    INNER JOIN sys.[databases] d ON mf.[database_id] = d.[database_id]
                            WHERE   d.name = 'tempdb'
                                    AND type = 0
                          );
--Input size of drive holding temp DB files here
--Use this for a test system with a fixed tempdb of 8 GB
SELECT  @drive_size_gb = 8;

--Use this line for a production system, where you wish to pre-fill the drive
--SELECT @DRIVE_SIZE_GB=total_bytes/1024/1024/1024 from sys.dm_os_volume_stats (2,1)


SELECT  @number_of_files = COUNT(*)
FROM    sys.master_files
WHERE   database_id = 2
        AND type = 0;
SELECT  @individ_file_size = ( @drive_size_gb * 1024 * .8 )
        / ( @number_of_files );
	
/*
PRINT '-- TEMP DB Configuration --'
PRINT 'Temp DB Data Path: ' + @data_file_path
PRINT 'File Size in MB: ' +convert(nvarchar(25),@individ_file_size)
PRINT 'Number of files: '+convert(nvarchar(25), @number_of_files)
*/

WHILE @number_of_files > 0
    BEGIN
        IF @number_of_files = 1 -- main tempdb file, move and re-size
            BEGIN
                SELECT  @sql_statement = 'ALTER DATABASE tempdb MODIFY FILE (NAME = tempdev, SIZE = '
                        + CONVERT(NVARCHAR(25), @individ_file_size)
                        + ', filename = ' + NCHAR(39) + @data_file_path
                        + 'tempdb.mdf' + NCHAR(39) 
                        + ', FILEGROWTH = 100MB);';
            END;
        ELSE -- numbered tempdb file, add and re-size
            BEGIN
                SELECT  @sql_statement = 'ALTER DATABASE tempdb MODIFY FILE (NAME = temp'
                        + CONVERT(NVARCHAR(25), @number_of_files)
                        + ',filename = ' + NCHAR(39) + @data_file_path
                        + 'tempdb_mssql_'
                        + CONVERT(NVARCHAR(25), @number_of_files) + '.ndf'
                        + NCHAR(39) + ', SIZE = '
                        + CONVERT(VARCHAR(25), @individ_file_size)
              
                        + ', FILEGROWTH = 100MB);';
            END;
		
        EXEC sp_executesql @statement = @sql_statement;
        PRINT @sql_statement;
		
        SELECT  @number_of_files = @number_of_files - 1;
    END;
									  
				
-- TODO: Consider type
;DECLARE @sqlmemory INT
with physical_mem (physical_memory_mb) as
(
 select physical_memory_kb / 1024 
 from sys.dm_os_sys_info
)
select @sqlmemory =
 -- Reserve 1 GB for OS 
 -- TODO: Handling of < 1 GB RAM
 physical_memory_mb - 1024 - 
 ( 
 case 
 -- If 16 GB or more, reserve an additional 4 GB
 when physical_memory_mb >= 16384 then 4092
 -- If between 4 and 16 GB, reserve 1 GB for every 4 GB
 -- TODO: Clarify if 4 GB is inclusive or exclusive minimum. This is exclusive.
 -- TODO: Clarify if 16 GB is inclusive or exclusive maximum. This is inclusive.
 when physical_memory_mb > 4092 and physical_memory_mb < 16384 then physical_memory_mb / 4 
 else 0 end
 )
 -
 (
 case 
 -- Reserve 1 GB for every 8 GB above 16 GB
 -- TODO: Clarify if 16 GB is inclusive or exclusive minimum. This is exclusive.
 when physical_memory_mb > 16384 then ( physical_memory_mb - 16384 )/ 8
 else 0
 end
 )
from physical_mem

 

EXEC sp_configure 'max server memory', @sqlmemory;
 -- change to #GB * 1024, leave 2 GB per system for OS, 4GB if over 16GB RAM
RECONFIGURE WITH OVERRIDE;

/*SELECT MaxDOP for Server Based on CPU Count */

BEGIN

    DECLARE @cpu_Countdop INT;
    SELECT  @cpu_Countdop = cpu_count
    FROM    sys.dm_os_sys_info dosi;

    EXEC sp_configure 'show advanced options', 1;
    RECONFIGURE WITH OVERRIDE;
    EXEC sp_configure 'max degree of parallelism', @cpu_Countdop;
    RECONFIGURE WITH OVERRIDE;
END;

EXEC sp_configure 'xp_cmdshell', 0;
GO
RECONFIGURE;
GO

EXEC sp_configure 'remote admin connections', 1;
GO
RECONFIGURE;
GO
EXEC sp_configure 'backup compression default', 1;
RECONFIGURE WITH OVERRIDE;
GO
sp_configure 'show advanced options', 1; 
GO
RECONFIGURE WITH OVERRIDE;
GO
sp_configure 'Database Mail XPs', 1; 
GO
RECONFIGURE; 
GO
EXEC sp_configure 'show advanced options', 1;
GO
RECONFIGURE;
GO
EXEC sp_configure 'cost threshold for parallelism', 35;
GO
RECONFIGURE;
GO
-------------------------------------------------------------
--  Database Mail Simple Configuration Template.
--
--  This template creates a Database Mail profile, an SMTP account and 
--  associates the account to the profile.
--  The template does not grant access to the new profile for
--  any database principals.  Use msdb.dbo.sysmail_add_principalprofile
--  to grant access to the new profile for users who are not
--  members of sysadmin.
-------------------------------------------------------------

DECLARE @profile_name sysname ,
    @account_name sysname ,
    @SMTP_servername sysname ,
    @email_address NVARCHAR(128) ,
    @display_name NVARCHAR(128) ,
    @err NVARCHAR(2000);

-- Profile name. Replace with the name for your profile
SELECT  @profile_name = 'dbmail_profile';

-- Account information. Replace with the information for your account.
SELECT  @account_name = 'SQL Mail';
SELECT  @SMTP_servername = 'smtp.domain.com';
SELECT  @email_address = 'youremail@domain.com';
SELECT  @display_name = 'SQL Server ' + @@servername + ' DBMail';
SELECT  @err = '''The specified Database Mail profile ' + @profile_name
        + ' already exists.''';
		
-- Verify the specified account and profile do not already exist.
IF EXISTS ( SELECT  *
            FROM    msdb.dbo.sysmail_profile
            WHERE   name = @profile_name )
    BEGIN
        RAISERROR(@err, 16, 1);
        GOTO done;
    END;

IF EXISTS ( SELECT  *
            FROM    msdb.dbo.sysmail_account
            WHERE   name = @account_name )
    BEGIN
        RAISERROR(@err, 16, 1);
        GOTO done;
    END;


	
-- Start a transaction before adding the account and the profile
BEGIN TRANSACTION ;

DECLARE @rv INT;
 
SELECT @err='Failed to create the specified Database Mail account '+@account_name
    
-- Add the account
EXECUTE @rv=msdb.dbo.sysmail_add_account_sp
    @account_name = @account_name,
    @email_address = @email_address,
    @display_name = @display_name,
    @mailserver_name = @SMTP_servername;

IF @rv<>0
BEGIN
    RAISERROR(@err, 16, 1) ;
    GOTO done;
END

-- Add the profile
EXECUTE @rv=msdb.dbo.sysmail_add_profile_sp
    @profile_name = @profile_name ;

IF @rv<>0
BEGIN
    RAISERROR(@err, 16, 1);
      ROLLBACK TRANSACTION;
    GOTO done;
END;

-- Associate the account with the profile.
EXECUTE @rv=msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = @profile_name,
    @account_name = @account_name,
    @sequence_number = 1 ;

IF @rv<>0
BEGIN
    RAISERROR('Failed to associate the speficied profile with the specified account (DB mailer).', 16, 1) ;
      ROLLBACK TRANSACTION;
    GOTO done;
END;

COMMIT TRANSACTION;

done:


DECLARE @msg VARCHAR(1000);
SELECT  @msg = 'Automated Success Message for server ' + @@servername; 

EXEC msdb.dbo.sp_send_dbmail @profile_name = @profile_name,
    @recipients = 'email@domain.com',
    @body = 'The install finished successfully.', @subject = @msg;
GO

/*Configure SQL Agent Alerts */

USE [msdb];

EXEC dbo.sp_add_operator @name = N'The DBA Team', @enabled = 1,
    @email_address = N'email@domain.com', @pager_address = N'email@domain.com',
    @weekday_pager_start_time = 000000, @weekday_pager_end_time = 235959;
GO

USE [msdb];
GO
EXEC msdb.dbo.sp_add_alert @name = N'Severity 016', @message_id = 0,
    @severity = 16, @enabled = 1, @delay_between_responses = 60,
    @include_event_description_in = 1,
    @job_id = N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 016',
    @operator_name = N'The DBA Team', @notification_method = 7;
GO
EXEC msdb.dbo.sp_add_alert @name = N'Severity 017', @message_id = 0,
    @severity = 17, @enabled = 1, @delay_between_responses = 60,
    @include_event_description_in = 1,
    @job_id = N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 017',
    @operator_name = N'The DBA Team', @notification_method = 7;
GO
EXEC msdb.dbo.sp_add_alert @name = N'Severity 018', @message_id = 0,
    @severity = 18, @enabled = 1, @delay_between_responses = 60,
    @include_event_description_in = 1,
    @job_id = N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 018',
    @operator_name = N'The DBA Team', @notification_method = 7;
GO
EXEC msdb.dbo.sp_add_alert @name = N'Severity 019', @message_id = 0,
    @severity = 19, @enabled = 1, @delay_between_responses = 60,
    @include_event_description_in = 1,
    @job_id = N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 019',
    @operator_name = N'The DBA Team', @notification_method = 7;
GO
EXEC msdb.dbo.sp_add_alert @name = N'Severity 020', @message_id = 0,
    @severity = 20, @enabled = 1, @delay_between_responses = 60,
    @include_event_description_in = 1,
    @job_id = N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 020',
    @operator_name = N'The DBA Team', @notification_method = 7;
GO
EXEC msdb.dbo.sp_add_alert @name = N'Severity 021', @message_id = 0,
    @severity = 21, @enabled = 1, @delay_between_responses = 60,
    @include_event_description_in = 1,
    @job_id = N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 021',
    @operator_name = N'The DBA Team', @notification_method = 7;
GO
EXEC msdb.dbo.sp_add_alert @name = N'Severity 022', @message_id = 0,
    @severity = 22, @enabled = 1, @delay_between_responses = 60,
    @include_event_description_in = 1,
    @job_id = N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 022',
    @operator_name = N'The DBA Team', @notification_method = 7;
GO
EXEC msdb.dbo.sp_add_alert @name = N'Severity 023', @message_id = 0,
    @severity = 23, @enabled = 1, @delay_between_responses = 60,
    @include_event_description_in = 1,
    @job_id = N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 023',
    @operator_name = N'The DBA Team', @notification_method = 7;
GO
EXEC msdb.dbo.sp_add_alert @name = N'Severity 024', @message_id = 0,
    @severity = 24, @enabled = 1, @delay_between_responses = 60,
    @include_event_description_in = 1,
    @job_id = N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 024',
    @operator_name = N'The DBA Team', @notification_method = 7;
GO
EXEC msdb.dbo.sp_add_alert @name = N'Severity 025', @message_id = 0,
    @severity = 25, @enabled = 1, @delay_between_responses = 60,
    @include_event_description_in = 1,
    @job_id = N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 025',
    @operator_name = N'The DBA Team', @notification_method = 7;
GO
EXEC msdb.dbo.sp_add_alert @name = N'Error Number 823', @message_id = 823,
    @severity = 0, @enabled = 1, @delay_between_responses = 60,
    @include_event_description_in = 1,
    @job_id = N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name = N'Error Number 823',
    @operator_name = N'The DBA Team', @notification_method = 7;
GO
EXEC msdb.dbo.sp_add_alert @name = N'Error Number 824', @message_id = 824,
    @severity = 0, @enabled = 1, @delay_between_responses = 60,
    @include_event_description_in = 1,
    @job_id = N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name = N'Error Number 824',
    @operator_name = N'The DBA Team', @notification_method = 7;
GO
EXEC msdb.dbo.sp_add_alert @name = N'Error Number 825', @message_id = 825,
    @severity = 0, @enabled = 1, @delay_between_responses = 60,
    @include_event_description_in = 1,
    @job_id = N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name = N'Error Number 825',
    @operator_name = N'The DBA Team', @notification_method = 7;
GO
RAISERROR (N'This is test error.', 17,1) WITH LOG

--This script is dependent on Ola Hallengren's maintenance jobs being installed as part of the installation process.
--You can find Ola's repo here: https://github.com/olahallengren/sql-server-maintenance-solution
--Schedules Jobs

USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'DatabaseBackup - SYSTEM_DATABASES - FULL', @name=N'Backups', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20160727, 
		@active_end_date=99991231, 
		@active_start_time=230000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT

GO

USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'DatabaseBackup - USER_DATABASES - FULL', @name=N'Backups', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20160727, 
		@active_end_date=99991231, 
		@active_start_time=230000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT

GO


USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'DatabaseBackup - USER_DATABASES - Log', @name=N'Log Backups', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=15, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20160727, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT

GO


USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'IndexOptimize - USER_DATABASES', @name=N'Index and Stats', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20160727, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT

GO

USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'DatabaseIntegrityCheck - SYSTEM_DATABASES', @name=N'CheckDB', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=64, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20160727, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT

GO

USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'DatabaseIntegrityCheck - USER_DATABASES', @name=N'CheckDB', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=64, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20160727, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT

GO

