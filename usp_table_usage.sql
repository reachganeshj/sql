/* 
Script Title - SQL Server Tables Usage
Script Written by - Ganesh Jayaraman
Script Details - Use this procedure to find table rows and used and unused space in each tables
Provide table name as input to find details about a specific table
*/

-- exec usp_table_usage 'SalesOrderDetail'
-- exec usp_table_usage 

CREATE PROCEDURE usp_table_usage
	@tbl_name VARCHAR(200) = '%'
AS
BEGIN

	SET QUOTED_IDENTIFIER ON

	SET NOCOUNT ON

	DECLARE @AllDBRowCounts TABLE 
		(
		DBName				VARCHAR(100),
		SchemaName			VARCHAR(100),
		TableName			VARCHAR(200),
		RowCounts			BIGINT,
		Used_MB				NUMERIC(30,2),
		Unused_MB			NUMERIC(30,2), 
		Total_MB			NUMERIC(30,2)
		)


	INSERT INTO @AllDBRowCounts
	EXEC master.sys.sp_MSforeachdb @command1 = N'USE [?];
	IF "?" NOT IN ( ''master'' ,''model'',''msdb'',''tempdb'')
	BEGIN
		SELECT
		db_name() AS DBName,
		s.Name AS SchemaName,
		t.Name AS TableName,
		p.rows AS RowCounts,
		CAST(ROUND((SUM(a.used_pages) / 128.00), 2) AS NUMERIC(36, 2)) AS Used_MB,
		CAST(ROUND((SUM(a.total_pages) - SUM(a.used_pages)) / 128.00, 2) AS NUMERIC(36, 2)) AS Unused_MB,
		CAST(ROUND((SUM(a.total_pages) / 128.00), 2) AS NUMERIC(36, 2)) AS Total_MB
		FROM sys.tables t
		INNER JOIN sys.indexes i ON t.OBJECT_ID = i.object_id
		INNER JOIN sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
		INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
		INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
		GROUP BY t.Name, s.Name, p.Rows
	END
	'

	SELECT * 
	FROM @AllDBRowCounts 
	WHERE TableName like @tbl_name
	ORDER BY DBName,RowCounts desc

END
