DECLARE @dbname varchar(20); 
SET @dbname = 'MagicWandServices'; 

DECLARE @config TABLE (
    name nvarchar(35),
    value sql_variant
)

INSERT INTO @config (name, value) 
SELECT name, CASE 
			WHEN value = 1 then 'ON' 
			WHEN value = 0 then 'OFF' 
			ELSE value
			END AS value
FROM sys.database_scoped_configurations
WHERE name <> 'MAXDOP' 

INSERT INTO @config (name, value) 
SELECT name, value
FROM sys.database_scoped_configurations
WHERE name = 'MAXDOP' 


SELECT name = CONCAT('DBCONFIG:',dsc.name), dsc.value, is_value_default, 
				'USE ' + @dbname +'; ALTER DATABASE SCOPED CONFIGURATION SET ' + dsc.name + '=' + convert(nvarchar(35), c.value) + ';' as SQLscript
FROM sys.database_scoped_configurations dsc
INNER JOIN @config c
ON c.name = dsc.name
WHERE is_value_default <> dsc.value

 