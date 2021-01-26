/* 
Script Title - SQL Server Intensive Queries 
Script Written by - Ganesh Jayaraman
Script Details - Use this procedure to capture details about the Intensive Queries
cpu_mem_disk_flag values are C for CPU or I for IO intensive
Hours is default 24 hours and could be tweaked to see data for more hours
*/

CREATE PROCEDURE usp_intensive_queries
	@cpu_mem_disk_flag CHAR(1) = 'C'
	, @last_hours INT = 24
	WITH ENCRYPTION
AS
BEGIN

		SET NOCOUNT ON

		IF @cpu_mem_disk_flag = 'C'
		BEGIN
			;WITH CPU_Queries
			AS (
				SELECT 
					 [execution_count]
					,[total_worker_time]/1000  AS [TotalCPUTime_ms]
					,[total_elapsed_time]/1000  AS [TotalDuration_ms]
					,last_execution_time
					,query_hash
					,plan_handle
					,[sql_handle]
					,DATEDIFF(HH,last_execution_time,GETDATE()) as [Hours]
				FROM sys.dm_exec_query_stats
				)

			SELECT TOP 10 t.text as Query, p.query_plan AS XML_Query_Plan,Execution_Count,TotalCPUTime_ms,TotalDuration_ms,last_execution_time
			FROM CPU_Queries C OUTER APPLY sys.dm_exec_query_plan(C.plan_handle) P
			OUTER APPLY sys.dm_exec_sql_text(C.sql_handle) AS t
			WHERE [Hours] < = @last_hours
			ORDER BY [TotalCPUTime_ms] DESC
		END


		IF @cpu_mem_disk_flag = 'I'
		BEGIN
			;WITH IO_Queries
			AS (
				SELECT 
					 [execution_count]
					,total_logical_reads AS [Reads]
					,total_logical_writes AS [Writes]
					,total_logical_reads+total_logical_writes AS [TotalIO]
					,last_execution_time
					,query_hash
					,plan_handle
					,[sql_handle]
					,DATEDIFF(HH,last_execution_time,GETDATE()) as [Hours]
				FROM sys.dm_exec_query_stats
				)

			SELECT TOP 10 t.text as Query, p.query_plan AS XML_Query_Plan,Execution_Count,[Reads],[Writes],[TotalIO]
			FROM IO_Queries C OUTER APPLY sys.dm_exec_query_plan(C.plan_handle) P
			OUTER APPLY sys.dm_exec_sql_text(C.sql_handle) AS t
			WHERE [Hours] < = @last_hours
			ORDER BY [TotalIO] DESC
		END

	SET NOCOUNT OFF

END