/*
Script check_index 
checks if ref_* columns in all tables of schema dbo are properly indexed
if @create_index param is set to 'N' (DEFAULT), then it only checks which ref_columns are not indexed
if @create_index is set to 'Y' it also creates  a proper index named as 'ix_tablename_column'
if @print_index is set to 'Y' it prints the sql ddl statement that creates the index (defaults to 'N')
if @Help TINYINT = 1 print usages info
*/

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

DECLARE @DB_NAME AS NVARCHAR(50)
DECLARE @tablename AS NVARCHAR(100)
DECLARE @cmd NVARCHAR(1000)
DECLARE @cmd2 NVARCHAR(1000)
DECLARE @cmd_cr_indx NVARCHAR(1000)
DECLARE @i AS INT = 0;
DECLARE @col AS NVARCHAR(256)
DECLARE @idx_name NVARCHAR(50)
DECLARE @create_index NVARCHAR(1) = 'N'
DECLARE @print_index NVARCHAR(1) = 'Y'
DECLARE @help TINYINT = 0
IF @help = 1
BEGIN 
  PRINT N'------------------------------------------------------------------------------------------'
  PRINT N'Script ''check_create_index'' 
It checks if ref_* columns in all tables of schema dbo are properly indexed
If @create_index param is set to  (DEFAULT), then it only checks which ref_columns are not indexed
If @create_index is set to ''Y'' it also creates  a proper index named as ''ix_tablename_column''
If @print_index is set to ''Y'' it prints the sql ddl statement that creates the index (defaults to ''N'')
If @Help TINYINT = 1 print usages info'
    PRINT N'------------------------------------------------------------------------------------------'
  RETURN;
END

SELECT @tablename = DB_NAME()
PRINT 'Database: ' + @tablename + CHAR(13)
PRINT '--------------------------------------------------------------------' + CHAR(13)

DECLARE cur_tablen CURSOR FOR 
	SELECT objects.name
	FROM sys.objects objects 
	INNER JOIN sys.schemas schemas ON objects.[schema_id] = schemas.[schema_id]
	WHERE objects.[type] = 'U' AND schemas.[name] = 'dbo' ORDER BY name ASC

OPEN cur_tablen
FETCH NEXT FROM cur_tablen INTO @tablename

WHILE @@FETCH_STATUS = 0
BEGIN	
	SET @cmd2 ='DECLARE col_cur CURSOR READ_ONLY FOR
				  SELECT name
				  FROM sys.columns c
				  WHERE c.object_id = OBJECT_ID(''' + @tablename +''') AND name  LIKE ''%ref%''			 
				  AND NOT EXISTS (			
					SELECT ic.column_id  FROM 
					sys.index_columns ic 
					WHERE ic.object_id = OBJECT_ID(''' + @tablename + ''')
					AND COL_NAME(ic.object_id,ic.column_id) LIKE ''%ref%''
					AND ic.column_id = c.column_id)'; 
	EXEC(@cmd2)
	OPEN col_cur
	
	FETCH NEXT FROM col_cur INTO @col
	WHILE @@FETCH_STATUS = 0	
	BEGIN
		SET @i = @i+1	
		PRINT 'Table ' + CAST(@tablename AS NVARCHAR(100)) + ' column ' + CAST(@col AS  NVARCHAR(50)) + ' has no index' 
		SET @idx_name = 'ix_' + @tablename + '_ref_' + @col
		
		SET @cmd_cr_indx = 'IF NOT EXISTS (SELECT name FROM sys.indexes 
								WHERE name = ''' + @idx_name + ''' AND object_id = object_id(''dbo.' + @tablename + '''))
							BEGIN
								CREATE NONCLUSTERED INDEX [' + @idx_name + '] ON [dbo].[' + @tablename + '] ([' + @col + '])
								PRINT  ''Index ' + @idx_name + ' has been created ''
							END
							ELSE 
							BEGIN
								PRINT ''Index ' + @idx_name + ' already exists ''
							END'
			
    IF  @print_index = 'Y'
    BEGIN
    	PRINT CHAR(13) + CAST	(@cmd_cr_indx AS NVARCHAR (1000)) + CHAR(13)	
    END    
	
		IF @create_index = 'Y'
			EXEC(@cmd_cr_indx)

		FETCH NEXT FROM col_cur INTO @col
	END

	CLOSE col_cur
	DEALLOCATE col_cur
	
	FETCH NEXT FROM cur_tablen INTO @tablename
END

CLOSE cur_tablen;
DEALLOCATE cur_tablen;

PRINT '--------------------------------------------------------------------' + CHAR(13)
IF @create_index = 'N'
	PRINT 'Found ' + CAST(@i AS NVARCHAR(5)) + ' columns without proper indexes'

IF @create_index = 'Y'
	PRINT 'Indexing complete'