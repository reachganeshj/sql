/* 

Script Title - SQL Server Blocked Process Email 
Script Written by - Ganesh Jayaraman
Script Details - Schedule this script in SQL Job to capture details about blocked queries in SQL
Details Captured are:
spid | blocked | cpu | physical_io| memusage| hostname | program_name | cmd | loginame | killcmd | query

*/

CREATE PROCEDURE [dbo].[usp_Job_blocked_processes]
	@imail_profile_name		VARCHAR(300),
	@irecipients			VARCHAR(300)
WITH ENCRYPTION 
AS
BEGIN

	SET NOCOUNT ON
	SET QUOTED_IDENTIFIER OFF

	
	DECLARE @tbl_blocked_processes TABLE
			(	spid				INT
				,blocked			INT
				,cpu				BIGINT
				,physical_io		BIGINT
				,memusage			BIGINT
				,hostname			VARCHAR(500)
				,program_name		VARCHAR(500)
				,cmd				VARCHAR(5000)
				,loginame			VARCHAR(150)
				,killcmd			VARCHAR(150)
				,query				VARCHAR(2000)				
			)

	DECLARE  @dbccinputbuffer TABLE 
		(eventtype		VARCHAR(100),
		parameters		INT, 
		eventinfo		VARCHAR(1000),
		spid			INT
		)

	DECLARE @query					VARCHAR(8000)
	DECLARE @bodyfull				NVARCHAR(MAX)
	DECLARE @cdxml					NVARCHAR(MAX)
	DECLARE @cdbody					NVARCHAR(MAX)
	DECLARE @dbcccstr				VARCHAR(200)
	DECLARE @spid					INT
	DECLARE @bspid					INT

	INSERT INTO @tbl_blocked_processes(spid	,blocked,cpu,physical_io,memusage,hostname,program_name,cmd,loginame,killcmd)
	SELECT spid,blocked , cpu,physical_io,memusage,hostname,program_name,cmd,loginame, 'kill ' + convert(varchar,blocked)
	FROM SYSPROCESSES WHERE BLOCKED > 0

	INSERT INTO @tbl_blocked_processes(spid	,blocked,cpu,physical_io,memusage,hostname,program_name,cmd,loginame,killcmd)
	SELECT spid,blocked , cpu,physical_io,memusage,hostname,program_name,cmd,loginame, null + convert(varchar,blocked)
	FROM SYSPROCESSES WHERE spid in ( select blocked from @tbl_blocked_processes)
	
	IF EXISTS ( SELECT 'X' FROM @tbl_blocked_processes)
	BEGIN

		SELECT @spid = spid , @bspid = blocked
		FROM SYSPROCESSES WHERE BLOCKED > 0

		select @dbcccstr = 'dbcc inputbuffer(' + convert(varchar,@spid) + ')'

		insert into @dbccinputbuffer(eventtype,parameters,eventinfo)
		exec(@dbcccstr)

		update @dbccinputbuffer set spid = @spid

		select @dbcccstr = 'dbcc inputbuffer(' + convert(varchar,@bspid) + ')'

		insert into @dbccinputbuffer(eventtype,parameters,eventinfo)
		exec(@dbcccstr)

		update @dbccinputbuffer set spid = @bspid where spid is null

		UPDATE @tbl_blocked_processes SET query = eventinfo 
		FROM @tbl_blocked_processes t , @dbccinputbuffer d 
		WHERE t.spid = d.spid

		SELECT @bodyfull = '<html><body><U><H2>Blocked DB Queries</H2></U>'

		-- select * from @tbl_blocked_processes
	
		BEGIN
		
		SET @cdxml = CAST(( SELECT CONVERT(VARCHAR(20),spid,100) as 'td',
		'', blocked as 'td',
		'', [cmd] as 'td' ,
		'', [hostname] as 'td',
		'', [program_name] as 'td',
		'', [loginame] as 'td',
		'', cpu as 'td',
		'', physical_io as 'td',
		'', memusage as 'td',
		'', killcmd as 'td',
		'', query as 'td'
		FROM @tbl_blocked_processes
		FOR XML PATH('tr'),ELEMENTS) AS VARCHAR(MAX))

	
		SET @cdbody =' 
		<table border = 1> 
		<tr>
		<th> spid </th> <th> Blockedby </th> <th> Command </th> <th> Hostname </th> <th> Program </th> <th> Login </th> <th> CPU </th> <th> IO </th> <th> Memory </th> <th> KillCMD </th> <th> Query </th> </tr>'  
	
		SET @cdbody = @cdbody + @cdxml +'</table>'
		END
		
		SELECT @bodyfull = @bodyfull + ISNULL(@cdbody,'') + '</body></html>'

		-- SELECT @bodyfull
	
		EXEC msdb.dbo.sp_send_dbmail  
		@profile_name =  @imail_profile_name,  
		@subject = '[Blocked DB Queries]',
		@recipients = @irecipients,  
		@body_format= 'HTML',
		@body = @bodyfull,
		@attach_query_result_as_file = 0 ;  

  	END

	SET NOCOUNT OFF

END