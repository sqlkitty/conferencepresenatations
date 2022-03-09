--******************
--Don't just run the whole thing.
--Run this step by step to learn!
--******************
DECLARE @msg NVARCHAR(MAX);
SET @msg = N'Did you mean to run this whole script?' + CHAR(10)
    + N'MAKE SURE YOU ARE RUNNING AGAINST A TEST ENVIRONMENT ONLY!'

RAISERROR(@msg,20,1) WITH LOG;
GO

--setup xevent in gui 
--look at template options 
--not use a template 
/*events to capture 
rpc_completed and sql_batch_completed
global fields 
client_app_name
client_hostname
database_name
server_instance_name
server_principal_name
sql_text
*/

/*create session */ 
CREATE EVENT SESSION [audit_sa] ON SERVER 
ADD EVENT sqlserver.rpc_completed(
    ACTION(sqlserver.client_app_name,
		sqlserver.client_hostname,
		sqlserver.database_name,
		sqlserver.server_instance_name,
		sqlserver.server_principal_name,
		sqlserver.sql_text)),
ADD EVENT sqlserver.sql_batch_completed(
ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.server_instance_name,sqlserver.server_principal_name,sqlserver.sql_text))
ADD TARGET package0.event_file(SET filename=N'E:\audits\audit_sa.xel',max_file_size=(10),max_rollover_files=(10))
WITH (STARTUP_STATE=ON)
GO
ALTER EVENT SESSION [audit_sa]
ON SERVER STATE = START;
GO

/*query a session*/
SELECT n.value('(@timestamp)[1]', 'datetime') as timestamp,
       n.value('(action[@name="sql_text"]/value)[1]', 'nvarchar(max)') as [sql], 
       n.value('(action[@name="client_hostname"]/value)[1]', 'nvarchar(50)') as [client_hostname], 
       n.value('(action[@name="server_principal_name"]/value)[1]', 'nvarchar(50)') as [user],
       n.value('(action[@name="database_name"]/value)[1]', 'nvarchar(50)') as [database_name],
       n.value('(action[@name="client_app_name"]/value)[1]', 'nvarchar(50)') as [client_app_name]
FROM (select cast(event_data as XML) as event_data
FROM sys.fn_xe_file_target_read_file('e:\audits\*.xel', NULL, NULL, NULL)) ed
CROSS APPLY ed.event_data.nodes('event') as q(n)
WHERE n.value('(@timestamp)[1]', 'datetime') >= DATEADD(HOUR, -1, GETDATE())
ORDER BY timestamp desc

ALTER EVENT SESSION [audit_sa] ON SERVER 
DROP EVENT sqlserver.rpc_completed, DROP EVENT sqlserver.sql_batch_completed
ALTER EVENT SESSION [audit_sa] ON SERVER 
ADD EVENT sqlserver.rpc_completed(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.server_instance_name,sqlserver.server_principal_name,sqlserver.sql_text)
    WHERE ([sqlserver].[server_principal_name]=N'sa')), 
ADD EVENT sqlserver.sql_batch_completed(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.server_instance_name,sqlserver.server_principal_name,sqlserver.sql_text)
    WHERE ([sqlserver].[server_principal_name]=N'sa'))
GO

ALTER EVENT SESSION [audit_sa]
ON SERVER STATE = STOP;
GO

DROP EVENT SESSION [audit_sa] ON SERVER 
GO