-- exec usp_restore_database 'test_backup',NULL,NULL,NULL,0

CREATE PROCEDURE usp_restore_database
		@db_name				VARCHAR(100)
		,@res_db_name			VARCHAR(100)	= NULL
		,@DestinationDBPath		VARCHAR(1000)	= NULL
		,@DestinationLogPath	VARCHAR(1000)	= NULL
		,@recovery_flag			INT = 0

AS
BEGIN

	SET NOCOUNT ON 


	DECLARE @backupStartDate		DATETIME 
	DECLARE @backup_set_id_start	INT 
	DECLARE @backup_set_id_end		INT 
	DECLARE @restore_cmd			VARCHAR(MAX)
	DECLARE	@move_cmd				VARCHAR(2000)
	DECLARE	@DestinationDBPath		VARCHAR(1000)
	DECLARE	@DestinationLogPath		VARCHAR(1000)
	

	-- set database to be used 
	IF @res_db_name IS NULL
	SET @res_db_name = @db_name + '_restored1'

	IF @DestinationDBPath IS NULL
	SELECT @DestinationDBPath = 'W:\DATABASE'

	IF @DestinationLogPath IS NULL
	SELECT @DestinationLogPath = 'X:\Logs'

	SELECT @backup_set_id_start = MAX(backup_set_id) 
	FROM msdb.dbo.backupset 
	WHERE database_name = @db_name AND type = 'D' 

	SELECT @backup_set_id_end = MIN(backup_set_id) 
	FROM msdb.dbo.backupset 
	WHERE database_name = @db_name AND type = 'D' 
	AND backup_set_id > @backup_set_id_start 

	IF @backup_set_id_end IS NULL SET @backup_set_id_end = 999999999 

	SELECT @move_cmd = 
	 ' MOVE ''' +   (@db_name) +  ''' TO ''' + @DestinationDBPath + '\' + @res_db_name +'.mdf''' + ', 
	MOVE ''' +  (@db_name +'_log') + '' +  ''' TO ''' +  @DestinationLogPath + '\' + @res_db_name +'.ldf'''+ ',
	REPLACE,
	NOUNLOAD,  
	STATS = 5;'

	SELECT @restore_cmd = ' RESTORE DATABASE ' + @res_db_name + ' FROM DISK = ''' + mf.physical_device_name + ''' WITH NORECOVERY,'  + @move_cmd + CHAR(13) 
	FROM msdb.dbo.backupset b, 
	msdb.dbo.backupmediafamily mf 
	WHERE b.media_set_id = mf.media_set_id 
	AND b.database_name = @db_name 
	AND b.backup_set_id = @backup_set_id_start -1

	SELECT @restore_cmd = @restore_cmd + ' RESTORE LOG ' + @res_db_name + ' FROM DISK = ''' + mf.physical_device_name + ''' WITH NORECOVERY'  + CHAR(13) 
	FROM msdb.dbo.backupset b, 
	msdb.dbo.backupmediafamily mf 
	WHERE b.media_set_id = mf.media_set_id 
	AND b.database_name = @db_name 
	AND b.backup_set_id >= @backup_set_id_start AND b.backup_set_id < @backup_set_id_end 
	AND b.type = 'L' 
	ORDER BY backup_set_id

	IF @recovery_flag = 1
	BEGIN
		SELECT @restore_cmd = @restore_cmd + ' RESTORE DATABASE ' + @res_db_name + ' WITH RECOVERY'
	END

	EXEC(@restore_cmd)

	SET NOCOUNT ON 

END