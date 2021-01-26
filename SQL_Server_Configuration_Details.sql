/* 

Script Title - SQL Server Configuration Details 
Script Written by - Ganesh Jayaraman
Script Details - USe this script to capture details about the SQL Server
Details Captured are:
Server Version Details | DB File Details | DB Size Database Details | Config & Memory Details
Startup Parameters & Protocol Details | Last Backup Details

*/
SET NOCOUNT ON

	DECLARE @TABLE_VER TABLE 
		(ProductVersion VARCHAR(50)
		,ProductLevel VARCHAR(50)
		,Edition VARCHAR(100)
		,DotNetVersion VARCHAR(100)
		,Collation VARCHAR(100),
		Instance VARCHAR(100)
		,MachineName VARCHAR(100)
		,ServerName VARCHAR(100),
		Clustering VARCHAR(50)
		,Authentication VARCHAR(100)
		)

	INSERT INTO @TABLE_VER (ProductVersion,ProductLevel,Edition,DotNetVersion,Collation,Instance,MachineName,ServerName,Clustering,Authentication)
	SELECT
	CONVERT(VARCHAR,SERVERPROPERTY('ProductVersion')) AS ProductVersion,
	CONVERT(VARCHAR,SERVERPROPERTY('ProductLevel')) AS ProductLevel,
	CONVERT(VARCHAR,SERVERPROPERTY('Edition')) AS Edition,
	CONVERT(VARCHAR,SERVERPROPERTY('BuildClrVersion')) AS DotNetVersion,
	CONVERT(VARCHAR,SERVERPROPERTY('Collation')) AS Collation,
	CONVERT(VARCHAR,SERVERPROPERTY('InstanceName')) as Instance,
	CONVERT(VARCHAR,SERVERPROPERTY('MachineName')) AS MachineName,
	CONVERT(VARCHAR,SERVERPROPERTY('ServerName')) AS ServerName,
	CASE SERVERPROPERTY('IsClustered') 
	WHEN 1 THEN 'Clustered' ELSE 'Non-Clustered' END AS 'Clustering',
	CASE SERVERPROPERTY('IsIntegratedSecurityOnly') 
	WHEN 1 THEN 'Windows Authentication'
	ELSE 'Both Windows & SQL' END AS 'Authentication'

	SELECT ' Server Version Details'
	UNION
	SELECT '**************************************************************'
	UNION
	SELECT '1>ServerName is: ' + ServerName FROM @TABLE_VER
	UNION
	SELECT '2>MachineName is: ' + MachineName FROM @TABLE_VER
	UNION
	SELECT '3>Instance is: ' + ISNULL(Instance,'Default') FROM @TABLE_VER
	UNION
	SELECT '4>ProductVersion is: ' + ProductVersion FROM @TABLE_VER
	UNION
	SELECT '5>ProductLevel is: ' + ProductLevel FROM @TABLE_VER
	UNION
	SELECT '6>Edition is: ' + Edition FROM @TABLE_VER
	UNION
	SELECT '7>DotNetVersion is: ' + DotNetVersion FROM @TABLE_VER
	UNION
	SELECT '8>Server Collation is: ' + Collation FROM @TABLE_VER
	UNION
	SELECT '9>Authentication is: ' + Authentication FROM @TABLE_VER
	UNION
	SELECT '91>Clustering is: ' + Clustering FROM @TABLE_VER

	SELECT ' File Details'
	UNION
	SELECT '**************************************************************'
	UNION
	SELECT '1>System Databases Data Path is: ' + SUBSTRING(filename,1,LEN(filename) - CHARINDEX('\',REVERSE(filename)))
	FROM master..sysaltfiles where DB_NAME(dbid) = 'master' AND fileid = 1
	UNION
	SELECT '2>System Databases Log Path is: ' + SUBSTRING(filename,1,LEN(filename) - CHARINDEX('\',REVERSE(filename)))
	FROM master..sysaltfiles where DB_NAME(dbid) = 'master' AND fileid = 2
	UNION
	SELECT '3>TempDB Databases Data Path is: ' + SUBSTRING(filename,1,LEN(filename) - CHARINDEX('\',REVERSE(filename)))
	FROM master..sysaltfiles where DB_NAME(dbid) = 'tempdb' AND fileid <> 2
	UNION
	SELECT '4>TempDB Databases Log Path is: ' + SUBSTRING(filename,1,LEN(filename) - CHARINDEX('\',REVERSE(filename)))
	FROM master..sysaltfiles where DB_NAME(dbid) = 'tempdb' AND fileid = 2
	UNION
	SELECT '5>User Databases Data Path is: ' + SUBSTRING(filename,1,LEN(filename) - CHARINDEX('\',REVERSE(filename)))
	FROM master..sysaltfiles where DB_NAME(dbid) not in ('master','msdb','model','tempdb') AND fileid <> 2
	UNION
	SELECT '6>User Databases Log Path is: ' + SUBSTRING(filename,1,LEN(filename) - CHARINDEX('\',REVERSE(filename)))
	FROM master..sysaltfiles where DB_NAME(dbid) not in ('master','msdb','model','tempdb') AND fileid = 2

	SELECT ' Database Details'
	UNION
	select 'Database:' + DB_NAME(dbid) +  'Size(in MB) is : ' + CONVERT(VARCHAR,SUM(size/128)) + ' MB' from master..sysaltfiles group by dbid
	SELECT '**************************************************************'
	UNION
	select ' Config & Memory Details'
	UNION
	SELECT 'Config: ' + convert(varchar,name) + ' | Value: ' + convert(varchar,value_in_use) 
	from sys.configurations where value_in_use <> 0
	and configuration_id not in ( 115,116,117,505,1126,1127,1519,1520,1531,1536,1538,1540,1541,1543,1544,1557,
	1563,1565,1567,1568,1573,1575,16387)
	UNION
	select 'Minimum Memory (in MB): ' + convert(varchar,value_in_use )
	from sys.configurations where name in ('min server memory (MB)')
	union
	select 'Maximum Memory (in MB): ' + convert(varchar,value_in_use )
	from sys.configurations where name in ('max server memory (MB)')
	union
	SELECT 'Logical CPU Count: ' + convert(varchar,cpu_count) + ', Physical CPU Count: ' 
	+ convert(varchar,cpu_count / hyperthread_ratio)
	FROM sys.dm_os_sys_info

	DECLARE @table_err TABLE (LogDate datetime,Processinfo VARCHAR(50),Params VARCHAR(7000))
	DECLARE @I INTEGER
	
	SELECT @I = 0
	
	WHILE @I < 10
	BEGIN
		 INSERT INTO  @table_err
		 EXEC master..xp_readerrorlog @I,1,N'Server',N'Startup'
		 INSERT INTO  @table_err
		 EXEC master..xp_readerrorlog @I,1,N'Server',N'Server local connection'
		 INSERT INTO  @table_err
		 EXEC master..xp_readerrorlog @I,1,N'Server',N'listening'

		 IF (SELECT COUNT('X') FROM @table_err) > 0
		 SELECT @I = 100

		 SELECT @I = @I + 1
	END

	SELECT ' Startup Parameters & Protocol Details'
	UNION
	SELECT '**************************************************************'
	UNION
	SELECT Params FROM @table_err


	SELECT ' Backup Details'
	UNION
	SELECT '**************************************************************'
	UNION
	select 'Last Full Backup of ' + CONVERT(varchar,database_name) + ' happened on ' + 
	  convert(varchar,backup_finish_date) + '.Size of Backup(in MB) is ' +
	  convert(varchar,cast(backup_size/1048576 as DECIMAL(10, 2))) + '.Database Recovery is ' +
	  convert(varchar,recovery_model) + char(13) +
	  'Backed up to ' + case device_type when 2 then 'Disk' when 5 then 'Tape' when 7 then 'Virtual Device' end 
	  + '.Backup Path is ' + physical_device_name
	from msdb..backupset o , msdb..backupmediafamily f
	where backup_finish_date = ( select max(backup_finish_date) from msdb..backupset i 
											  where i.database_name = o.database_name and type = 'D') 
	and type = 'D' and database_name in ( select name from master..sysdatabases)
	and o.media_set_id = f.media_set_id
	UNION
	select 'Last Differential Backup of ' + CONVERT(varchar,database_name) + ' happened on ' + 
	  convert(varchar,backup_finish_date) + '.Size of Backup(in MB) is ' +
	  convert(varchar,cast(backup_size/1073741824 as DECIMAL(10, 2))) 
	from msdb..backupset o 
	where backup_finish_date = ( select max(backup_finish_date) from msdb..backupset i 
											  where i.database_name = o.database_name and type = 'I') 
	and type = 'I' and database_name in ( select name from master..sysdatabases)
	UNION
	select 'Last Log Backup of ' + CONVERT(varchar,database_name) + ' happened on ' + 
	  convert(varchar,backup_finish_date) + '.Size of Backup(in MB) is ' +
	  convert(varchar,cast(backup_size/1073741824 as DECIMAL(10, 2))) 
	from msdb..backupset o 
	where backup_finish_date = ( select max(backup_finish_date) from msdb..backupset i 
											  where i.database_name = o.database_name and type = 'L') 
	and type = 'L' and database_name in ( select name from master..sysdatabases)
