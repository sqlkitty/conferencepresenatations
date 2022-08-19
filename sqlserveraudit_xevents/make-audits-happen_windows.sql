--******************
--Don't just run the whole thing.
--Run this step by step to learn!
--******************
DECLARE @msg NVARCHAR(MAX);
SET @msg = N'Did you mean to run this whole script?' + CHAR(10)
    + N'MAKE SURE YOU ARE RUNNING AGAINST A TEST ENVIRONMENT ONLY!'

RAISERROR(@msg,20,1) WITH LOG;
GO

--setup audit in gui 
--setup server audit in gui with 
--SERVER_OBJECT_CHANGE_GROUP

--add testing db and see that it doesn't appear in the audit in the gui 
USE master 
CREATE DATABASE testing 

--add DATABASE_CHANGE_GROUP to server audit
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification] 
WITH (STATE = OFF); 
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification]
ADD (DATABASE_CHANGE_GROUP)
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification] 
WITH (STATE = ON);

--drop and create testing db to see it in audit query
DROP DATABASE testing 
CREATE DATABASE testing 

--how to see all the columns in the audit file 
SELECT *
FROM sys.fn_get_audit_file ('e:\audits\*.sqlaudit',default,default)
where  DATEADD(mi, DATEPART(TZ, SYSDATETIMEOFFSET()), event_time) > DATEADD(HOUR, -24, GETDATE())
order by DATEADD(mi, DATEPART(TZ, SYSDATETIMEOFFSET()), event_time) desc 

--limits to what i've found useful and shows the audit actions associated with the statements captured
--converts from UTC to the server's timezone when you run this query 
SELECT distinct DATEADD(mi, DATEPART(TZ, SYSDATETIMEOFFSET()), event_time) as event_time, 
aa.name as audit_action,statement,succeeded, server_instance_name, 
database_name, schema_name, session_server_principal_name, server_principal_name, 
object_Name, file_name, client_ip, application_name, host_name
FROM sys.fn_get_audit_file ('e:\audits\*.sqlaudit',default,default) af
INNER JOIN sys.dm_audit_actions aa ON aa.action_id = af.action_id
where  DATEADD(mi, DATEPART(TZ, SYSDATETIMEOFFSET()), event_time) > DATEADD(HOUR, -24, GETDATE())
order by DATEADD(mi, DATEPART(TZ, SYSDATETIMEOFFSET()), event_time) desc

--create a login to see if the server audit picks that up
CREATE LOGIN [testing] WITH PASSWORD=N'testing1234!', DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=ON
GO

--add SERVER_PRINCIPAL_CHANGE_GROUP 
USE master
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification] 
WITH (STATE = OFF); 
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification]
ADD (SERVER_PRINCIPAL_CHANGE_GROUP)
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification] 
WITH (STATE = ON);

--drop and recreate login to see it in audit query
DROP LOGIN [testing]
CREATE LOGIN [testing] WITH PASSWORD=N'testing1234!', DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=ON

--grants perms to that login on a db and see that the server audit doesn't pick that up
USE [testing]
CREATE USER [testing] FOR LOGIN [testing] WITH DEFAULT_SCHEMA=[dbo]
USE [testing]
ALTER ROLE [db_datareader] ADD MEMBER [testing]
USE [testing]
ALTER ROLE [db_datawriter] ADD MEMBER [testing]

--add database_role_member_change_group to the server audit 
USE master
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification] 
WITH (STATE = OFF); 
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification]
ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP), 
ADD (DATABASE_PRINCIPAL_CHANGE_GROUP)
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification] 
WITH (STATE = ON);

--drop/readd testing login and see the server audit now picks that up 
USE [testing]
DROP USER [testing]
USE [testing]
CREATE USER [testing] FOR LOGIN [testing] WITH DEFAULT_SCHEMA=[dbo]
USE [testing]
ALTER ROLE [db_datareader] ADD MEMBER [testing]
USE [testing]
ALTER ROLE [db_datawriter] ADD MEMBER [testing]

--create a testing table and see if it's in audit query 
USE [testing]
CREATE TABLE [dbo].[testing](
	[testing] [nchar](10) NULL
) ON [PRIMARY]

--it didn't appear in the audit 
--bc it needs schema_object_change_group to server audit 
USE master
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification] 
WITH (STATE = OFF); 
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification]
ADD (SCHEMA_OBJECT_CHANGE_GROUP)
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification] 
WITH (STATE = ON);

--drop the table we just created and look in audit query 
USE [testing]
DROP TABLE [dbo].[testing]

USE [testing]
CREATE TABLE [dbo].[testing](
	[testing] [nchar](10) NULL
) ON [PRIMARY]

--setup perms on an object and see if the audit picks up that change 
USE [testing]
GRANT ALTER ON [dbo].[testing] TO [testing]



--setup db audit with schema_object_permission_change_group on testing db via gui 
USE master
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification] 
WITH (STATE = OFF); 
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification]
ADD (SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP)
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification] 
WITH (STATE = ON);

--setup perms on an object and see if the audit picks up that change 
USE [testing]
GRANT ALTER ON [dbo].[testing] TO [testing]

--insert to the testing more table and see that the audit doesn't pick that up 
USE [testing]
INSERT INTO [dbo].[testing]
([testing]) VALUES ('as testing')

--add insert auditing on the testing_more table on db audit
USE [master]
CREATE SERVER AUDIT [AuditSpecification_testingdb]
TO FILE 
(FILEPATH = N'e:\audits\testing\'
,MAXSIZE = 10 MB
,MAX_FILES = 10
,RESERVE_DISK_SPACE = OFF
) WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE)
ALTER SERVER AUDIT [AuditSpecification_testingdb] WITH (STATE = ON)

USE [testing]
CREATE DATABASE AUDIT SPECIFICATION [DatabaseAuditSpecification_testingtables]
FOR SERVER AUDIT [AuditSpecification_testingdb]
ADD (INSERT ON OBJECT::[dbo].[testing] BY [public])
WITH (STATE = ON)
GO

--run insert again and see that it's now in the audit results
--with subfolder in path to audit file 
USE [testing]
INSERT INTO [dbo].[testing]
([testing]) VALUES ('as testing')


--login as testing user and run the same insert 
--and see that it's in the audit results but with a different user listed 
USE [testing]
INSERT INTO [dbo].[testing]
([testing]) VALUES ('as testing')

--filter out ubuntusql1\ubuntusql1$
USE master
ALTER SERVER AUDIT AuditSpecification 
WITH (STATE = OFF); 
ALTER SERVER AUDIT [AuditSpecification]
WHERE [session_server_principal_name]<>'ubuntusql1\ubuntusql1$'
ALTER SERVER AUDIT AuditSpecification 
WITH (STATE = ON); 

--show how to script out the audits 
--modify and script out 

--disable the audits
USE master;
IF EXISTS (select name from sys.server_file_audits where name = 'AuditSpecification') 
BEGIN
ALTER SERVER AUDIT AuditSpecification 
WITH (STATE = OFF); 
END;

USE master;
IF EXISTS (select name from sys.server_file_audits where name = 'AuditSpecification_testingdb') 
BEGIN
ALTER SERVER AUDIT AuditSpecification_testingdb 
WITH (STATE = OFF); 
END;

USE master;
IF EXISTS (select name from sys.server_audit_specifications where name = 'ServerAuditSpecification')
BEGIN
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification] 
WITH (STATE = OFF); 
END;

USE testing;
IF EXISTS (select name from sys.database_audit_specifications where name = 'DatabaseAuditSpecification_testingtables')
BEGIN
ALTER DATABASE AUDIT SPECIFICATION [DatabaseAuditSpecification_testingtables] 
WITH (STATE = OFF); 
END;

--refresh in gui to see they are disabled 

--drop the audits - remember this doesn't delete the files on disks
USE master;
IF EXISTS (select name from sys.server_file_audits where name = 'AuditSpecification')
BEGIN
DROP SERVER AUDIT [AuditSpecification]
END;

USE master;
IF EXISTS (select name from sys.server_file_audits where name = 'AuditSpecification_testingdb') 
BEGIN
DROP SERVER AUDIT AuditSpecification_testingdb 
END;

USE master;
IF EXISTS (select name from sys.server_audit_specifications where name = 'ServerAuditSpecification')
BEGIN
DROP SERVER AUDIT SPECIFICATION [ServerAuditSpecification]
END;

USE testing;
IF EXISTS (select name from sys.database_audit_specifications where name = 'DatabaseAuditSpecification_testing')
BEGIN
DROP DATABASE AUDIT SPECIFICATION [DatabaseAuditSpecification_testingtables]
END;

USE testing;
IF EXISTS (select name from sys.database_audit_specifications where name = 'DatabaseAuditSpecification_testingtables')
BEGIN
DROP DATABASE AUDIT SPECIFICATION [DatabaseAuditSpecification_testingtables] 
END;

--refresh in gui to see they are gone
--show you can still query the files because they aren't deleted with dropping the audit specification 

--setup audits via scripts 
USE [master]
CREATE SERVER AUDIT [AuditSpecification]
TO FILE 
(	FILEPATH = N'e:\audits\'
	,MAXSIZE = 50 MB
	,MAX_FILES = 4
	,RESERVE_DISK_SPACE = OFF
) WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE)
WHERE ([session_server_principal_name]<>'ubuntusql1\ubuntusql1$'
		and schema_name <>'sys')
ALTER SERVER AUDIT [AuditSpecification] WITH (STATE = ON)

--server audit i usually setup to get all server and db perms and schema changes 
USE [master]
CREATE SERVER AUDIT SPECIFICATION [ServerAuditSpecification]
FOR SERVER AUDIT [AuditSpecification]
ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP),
ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP),
ADD (AUDIT_CHANGE_GROUP),
ADD (DATABASE_PERMISSION_CHANGE_GROUP),
ADD (SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP),
ADD (SERVER_OBJECT_PERMISSION_CHANGE_GROUP),
ADD (DATABASE_OBJECT_CHANGE_GROUP),
ADD (DATABASE_PRINCIPAL_CHANGE_GROUP),
ADD (SERVER_PRINCIPAL_CHANGE_GROUP),
ADD (SERVER_OPERATION_GROUP),
ADD (APPLICATION_ROLE_CHANGE_PASSWORD_GROUP),
ADD (LOGIN_CHANGE_PASSWORD_GROUP),
ADD (SERVER_STATE_CHANGE_GROUP),
ADD (DATABASE_OWNERSHIP_CHANGE_GROUP),
ADD (SCHEMA_OBJECT_OWNERSHIP_CHANGE_GROUP),
ADD (SERVER_OBJECT_OWNERSHIP_CHANGE_GROUP),
ADD (USER_CHANGE_PASSWORD_GROUP),
ADD (SERVER_PERMISSION_CHANGE_GROUP),
ADD (SCHEMA_OBJECT_CHANGE_GROUP),
ADD (DATABASE_CHANGE_GROUP),
ADD (SERVER_OBJECT_CHANGE_GROUP),
ADD (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP),
ADD (DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP)
WITH (STATE = ON)


--only use this db audit if you aren't already auditing the databases in the server audit 
/*USE [testing]
CREATE DATABASE AUDIT SPECIFICATION [DatabaseAuditSpecification_testing]
FOR SERVER AUDIT [AuditSpecification]
ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP),
ADD (AUDIT_CHANGE_GROUP),
ADD (DBCC_GROUP),
ADD (DATABASE_PERMISSION_CHANGE_GROUP),
ADD (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP),
ADD (SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP),
ADD (DATABASE_CHANGE_GROUP),
ADD (DATABASE_OBJECT_CHANGE_GROUP),
ADD (DATABASE_PRINCIPAL_CHANGE_GROUP),
ADD (SCHEMA_OBJECT_CHANGE_GROUP),
ADD (APPLICATION_ROLE_CHANGE_PASSWORD_GROUP),
ADD (DATABASE_OWNERSHIP_CHANGE_GROUP),
ADD (DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP),
ADD (SCHEMA_OBJECT_OWNERSHIP_CHANGE_GROUP),
ADD (USER_CHANGE_PASSWORD_GROUP)
WITH (STATE = ON) */


--here's what i do if i need to also audit some tables or other objects
--you will only need a new audit specification if you have another db audit on this db already
--but i don't want to capture things like this with schema and perms changes so i will create another audit specification for this
USE [master]
CREATE SERVER AUDIT [AuditSpecification_testingdb]
TO FILE 
(FILEPATH = N'e:\audits\testing\'
,MAXSIZE = 10 MB
,MAX_FILES = 10
,RESERVE_DISK_SPACE = OFF
) WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE)
ALTER SERVER AUDIT [AuditSpecification_testingdb] WITH (STATE = ON)

USE [testing]
CREATE DATABASE AUDIT SPECIFICATION [DatabaseAuditSpecification_testingtables]
FOR SERVER AUDIT [AuditSpecification_testingdb]
ADD (INSERT ON OBJECT::[dbo].[testing] BY [public])
WITH (STATE = ON)
GO

--create a db to test and it's in a new set of files on disk 
CREATE DATABASE testing2



/*********
if you want to clean up at the end of demo run everything below this comment 
***********/ 

--disable the audits
USE master;
IF EXISTS (select name from sys.server_file_audits where name = 'AuditSpecification')
BEGIN
ALTER SERVER AUDIT AuditSpecification 
WITH (STATE = OFF); 
END;

USE master;
IF EXISTS (select name from sys.server_file_audits where name = 'AuditSpecification_testingdb')
BEGIN
ALTER SERVER AUDIT AuditSpecification_testingdb 
WITH (STATE = OFF); 
END;

USE master;
IF EXISTS (select name from sys.server_audit_specifications where name = 'ServerAuditSpecification')
BEGIN
ALTER SERVER AUDIT SPECIFICATION [ServerAuditSpecification] 
WITH (STATE = OFF); 
END;

USE testing;
IF EXISTS (select name from sys.database_audit_specifications where name = 'DatabaseAuditSpecification_testing')
BEGIN
ALTER DATABASE AUDIT SPECIFICATION [DatabaseAuditSpecification_testing] 
WITH (STATE = OFF); 
END;

USE testing;
IF EXISTS (select name from sys.database_audit_specifications where name = 'DatabaseAuditSpecification_testingtables')
BEGIN
ALTER DATABASE AUDIT SPECIFICATION [DatabaseAuditSpecification_testingtables] 
WITH (STATE = OFF); 
END;

--drop the audits
USE master;
IF EXISTS (select name from sys.server_file_audits where name = 'AuditSpecification')
BEGIN
DROP SERVER AUDIT [AuditSpecification]
END;

USE master;
IF EXISTS (select name from sys.server_file_audits where name = 'AuditSpecification_testingdb')
BEGIN
DROP SERVER AUDIT [AuditSpecification_testingdb]
END;

USE master;
IF EXISTS (select name from sys.server_audit_specifications where name = 'ServerAuditSpecification')
BEGIN
DROP SERVER AUDIT SPECIFICATION [ServerAuditSpecification]
END;

USE testing;
IF EXISTS (select name from sys.database_audit_specifications where name = 'DatabaseAuditSpecification_testing')
BEGIN
DROP DATABASE AUDIT SPECIFICATION [DatabaseAuditSpecification_testing]
END;

IF EXISTS (select name from sys.database_audit_specifications where name = 'DatabaseAuditSpecification_testingtables')
BEGIN
DROP DATABASE AUDIT SPECIFICATION [DatabaseAuditSpecification_testingtables]
END;


USE [master]
ALTER DATABASE [testing] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
DROP DATABASE [testing] 

USE [master]
DROP LOGIN [testing]

ALTER DATABASE [testing2] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
DROP DATABASE testing2


/*if testing user in use 
SELECT login_name, * FROM sys.dm_exec_sessions
WHERE login_name = 'testing'

then kill sessions 
kill 64*/ 
