/*setup for querying SQL Server configuration */
DECLARE @tf TABLE (TraceFlag nvarchar(35), status bit,global bit, session bit) 
INSERT INTO @tf execute('DBCC TRACESTATUS(-1)');

DECLARE @config TABLE (
    name nvarchar(35),
    default_value sql_variant
)

/*not all of these settings are in all versions of sql server*/
INSERT INTO @config (name, default_value) VALUES
('access check cache bucket count',0),
('access check cache quota',0),
('ADR cleaner retry timeout (min)', 0), 
('ADR Preallocation Factor', 0),  
('Ad Hoc Distributed Queries',0),
('affinity I/O mask',0),
('affinity64 I/O mask',0),
('affinity mask',0),
('affinity64 mask',0),
('Agent XPs',0), --Changes to 1 when SQL Server Agent is started. Default value is 0 if SQL Server Agent is set to automatic start during Setup.
('allow filesystem enumeration', 0),
('allow polybase export', 0),
('allow updates',0),
('awe enabled',0),
('backup checksum default', 0),
('backup compression default',0),
('blocked process threshold (s)',0),
('c2 audit mode',0),
('clr enabled',0),
('clr strict security', 0), 
('column encryption enclave type', 0),
('common criteria compliance enabled',0),
('contained database authentication', 0), 
('cost threshold for parallelism',5),
('cross db ownership chaining',0),
('cursor threshold',-1),
('Database Mail XPs',0),
('default full-text language',1033),
('default language',0),
('default trace enabled',1),
('disallow results from triggers',0),
('EKM provider enabled',0),
('external scripts enabled', 0), 
('filestream access level',0),
('fill factor (%)',0),
('ft crawl bandwidth (max)',100),
('ft crawl bandwidth (min)',0),
('ft notify bandwidth (max)',100),
('ft notify bandwidth (min)',0),
('hadoop connectivity', 0), 
('index create memory (KB)',0),
('in-doubt xact resolution',0),
('lightweight pooling',0),
('locks',0),
('max degree of parallelism',0),
('max full-text crawl range',4),
('max server memory (MB)',2147483647),
('max text repl size (B)',65536),
('max worker threads',0),
('media retention',0),
('min memory per query (KB)',1024),
('min server memory (MB)',0),
('nested triggers',1),
('network packet size (B)',4096),
('Ole Automation Procedures',0),
('open objects',0),
('optimize for ad hoc workloads',0),
('PH timeout (s)',60),
('precompute rank',0),
('polybase network encryption', 0),
('precompute rank', 0),
('priority boost',0),
('query governor cost limit',0),
('query wait (s)',-1),
('recovery interval (min)',0),
('remote access',1),
('remote admin connections',0),
('remote data archive', 0), 
('remote login timeout (s)',10),
('remote proc trans',0),
('remote query timeout (s)',600),
('Replication XPs',0),
('scan for startup procs',0),
('server trigger recursion',1),
('set working set size',0),
('show advanced options',0),
('SMO and DMO XPs',1),
('SQL Mail XPs',0),
('tempdb metadata memory-optimized', 0), 
('transform noise words',0),
('two digit year cutoff',2049),
('user connections',0),
('user options',0),
('Web Assistant Procedures', 0),
('xp_cmdshell',0)

/* this shows you where your configurations are different from the default values */
SELECT CONCAT('SERVERCONFIG: ', sc.name) as Name, sc.value_in_use as CurrentValue, c.default_value as DefaultValue, 
		'EXEC sp_configure ''' + sc.name + ''', ' + convert(varchar(10), sc.value_in_use) + '; RECONFIGURE WITH OVERRIDE;' as Script
FROM sys.configurations sc
INNER JOIN @config c ON sc.name = c.name
WHERE sc.value <> sc.value_in_use
OR sc.value_in_use <> c.default_value

UNION

SELECT concat('TRACEFLAG: ', TraceFlag), value=status, '0', 'DBCC TRACEON (' + TraceFlag +' ,-1);  ' 
FROM @tf
WHERE global=1 and session=0