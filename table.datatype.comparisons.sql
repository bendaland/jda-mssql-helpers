
DECLARE @Orientation VARCHAR(50)
SET @Orientation = 'H'; --COLUMN NAMES AS COLUMNS
--SET @Orientation = 'V'; --COLUMNS NAME AS ROWS

IF( OBJECT_ID('tempdb..#Tables') IS NOT NULL )
	DROP TABLE #Tables; 
	
IF( OBJECT_ID('tempdb..#Columns') IS NOT NULL )
	DROP TABLE #Columns;  
	
IF( OBJECT_ID('tempdb..#Comparison') IS NOT NULL )
	DROP TABLE #Comparison;  

CREATE TABLE #Tables( 
	ID INT IDENTITY(1,1), TableName VARCHAR(MAX), ColumnName VARCHAR(MAX), ColumnType VARCHAR(MAX), ColumnLength INT, ColumnPercision INT, ColumnScale INT, DataType VARCHAR(MAX) 
);
CREATE TABLE #Columns( 
	ID INT IDENTITY(1,1), TableName VARCHAR(MAX), ColumnName VARCHAR(MAX), ColumnType VARCHAR(MAX), COLTXT VARCHAR(MAX) 
); 

INSERT INTO #Tables( TableName, ColumnName, ColumnType, ColumnLength, ColumnPercision, ColumnScale )
SELECT T.name, C.name, CT.name, C.max_length, C.[precision], C.scale
FROM SYS.tables T
INNER JOIN SYS.columns C ON T.object_id = C.object_id
INNER JOIN SYS.types CT ON C.system_type_id = CT.system_type_id;

UPDATE #Tables SET DataType = CASE 
	WHEN ColumnType IN ('varchar','char') THEN ColumnType + '( ' + CAST(ColumnLength AS VARCHAR) + ' )'
	WHEN ColumnType IN ('datetime2') THEN ColumnType + '( ' + CAST(ColumnScale AS VARCHAR) + ' )'
	WHEN ColumnType IN ('decimal') THEN ColumnType + '( ' + CAST(ColumnPercision AS VARCHAR) + ', ' + CAST(ColumnScale AS VARCHAR) + ' )'
	ELSE ColumnType END;

INSERT INTO #Columns( TableName, ColumnName, ColumnType, COLTXT )
SELECT 'tmpTblComparison', ColumnName, 'varchar', '[' + ColumnName + '] [varchar](100)' COLTXT
FROM (
	SELECT DISTINCT CASE WHEN @Orientation = 'H' THEN ColumnName ELSE TableName END ColumnName FROM #Tables
) A
ORDER BY ColumnName;  

DECLARE 
	@SQL VARCHAR(MAX), 
	@Columns_Pivot VARCHAR(MAX), 
	@Columns_Insert VARCHAR(MAX), 
	@Columns_Select VARCHAR(MAX);	

IF( EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tmpTblComparison]') AND type in (N'U')) )
	DROP TABLE [dbo].[tmpTblComparison];

SET @SQL = (SELECT 'CREATE TABLE [dbo].[tmpTblComparison] ([ComparisonValue] [varchar](100) NOT NULL' + (
	SELECT ', ' + B.COLTXT
	FROM #Columns B
	WHERE B.TableName = A.TableName
	ORDER BY B.ColumnType DESC, B.ColumnName
	FOR XML PATH('')
) + ');'
FROM #Columns A
WHERE A.TableName = 'tmpTblComparison'
GROUP BY A.TableName);

EXEC( @SQL ); 

SELECT @Columns_Pivot = (
	SELECT ', [' + B.ColumnName + ']'
	FROM #Columns B
	ORDER BY B.ColumnName
	FOR XML PATH('')
),
@Columns_Select = CASE WHEN @Orientation = 'H' THEN 'TableName' ELSE 'ColumnName' END + (
	SELECT ', ISNULL(MAX([' + B.ColumnName + ']), '''') ' + B.ColumnName
	FROM #Columns B
	ORDER BY B.ColumnName
	FOR XML PATH('')
);
SET @Columns_Insert = @Columns_Pivot;
SET @Columns_Pivot = RIGHT(@Columns_Pivot, LEN(@Columns_Pivot) - 2);

SET @SQL = N'INSERT INTO tmpTblComparison( [ComparisonValue]' + @Columns_Insert + ')';
SET @SQL += N' SELECT ' + @Columns_Select;
SET @SQL += N' FROM #Tables A';
SET @SQL += N' PIVOT( MAX(DATATYPE) FOR ' + CASE WHEN @Orientation = 'H' THEN 'ColumnName' ELSE 'TableName' END + ' IN ( ' + @Columns_Pivot + ' ) ) P'
SET @SQL += N' GROUP BY ' + CASE WHEN @Orientation = 'H' THEN 'TableName' ELSE 'ColumnName' END; 
SET @SQL += N' ORDER BY ' + CASE WHEN @Orientation = 'H' THEN 'TableName' ELSE 'ColumnName' END + ';'; 

EXEC( @SQL ); 

SELECT * FROM [tmpTblComparison];

IF( EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tmpTblComparison]') AND type in (N'U')) )
	DROP TABLE [dbo].[tmpTblComparison];

DROP TABLE #Tables; 
DROP TABLE #Columns;
