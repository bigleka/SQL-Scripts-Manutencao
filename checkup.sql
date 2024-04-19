/*
Versao: 1.07
Data: 20200408
Por: Ricardo Leka
Site: https://leka.com.br
email: ricardo@leka.com.br
twitter:@bigleka
Este script é para SQL 2005/2008/R2/2012/2014+

*/

/*
Esse script deve ser executado em pedaços,
você executar apenas a parte que interessa e vai copiando o resultado para o excel ou bloco de notas
*/
raiserror ('Esse script é para ser executado por partes, você está executando tudo de uma vez,,,',20,-1) with log
GO

/*
Vamos ver se você é importante o suficiente para rodar essas querys
o nível necessário é sysadmin
*/
IF (IS_SRVROLEMEMBER('sysadmin') = 0)
    RAISERROR('Seu usuário não é importante o suficiente,,,', 15, -1);
ELSE IF (IS_SRVROLEMEMBER('sysadmin') IS NULL)
    RAISERROR('A server role que seu usuário está não é valida,,,', 15, -1);
ELSE IF (IS_SRVROLEMEMBER('sysadmin') = 1)
    PRINT 'Legal, podemos continuar,,,';
GO

/*
Versao do SQL
Traz informacoes interessante sobre o nome da maquina, se tem instancia, versao de produto,
SP, collation da instancia, se esta ou nao em cluster
*/

Print 'Versao de SQL'
SELECT CAST(SERVERPROPERTY('MachineName') AS VARCHAR(30)) AS MachineName,
       CAST(SERVERPROPERTY('InstanceName') AS VARCHAR(30)) AS Instance,
       CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(30)) AS ProductVersion,
       CAST(SERVERPROPERTY('ProductLevel') AS VARCHAR(30)) AS ProductLevel,
       CAST(SERVERPROPERTY('Edition') AS VARCHAR(30)) AS Edition,
       (CASE SERVERPROPERTY('EngineEdition')
            WHEN 1 THEN
                'Personal or Desktop'
            WHEN 2 THEN
                'Standard'
            WHEN 3 THEN
                'Enterprise'
        END
       ) AS EngineType,
       CAST(SERVERPROPERTY('LicenseType') AS VARCHAR(30)) AS LicenseType,
       SERVERPROPERTY('NumLicenses') AS #Licenses,
       (CASE SERVERPROPERTY('IsIntegratedSecurityOnly')
            WHEN 0 THEN
                'Mista'
            WHEN 1 THEN
                'Integrada'
        END
       ) AS [IsIntegratedSecurityOnly],
       SERVERPROPERTY('Collation') AS Collation,
       (CASE SERVERPROPERTY('IsClustered')
            WHEN 0 THEN
                'Nao'
            WHEN 1 THEN
                'Sim'
        END
       ) AS Cluster;

SELECT @@VERSION AS [SQL Server Details];

exec xp_msver

/*
Backup FULL

Uma das informacoes mais importantes, tem backup?
*/

Print 'Backup FULL'

SELECT d.name,
       MAX(b.backup_finish_date) AS [ultima data do backup]
FROM master.sys.databases d
    LEFT OUTER JOIN msdb.dbo.backupset b
        ON d.name = b.database_name
           AND b.type = 'D'
WHERE d.database_id NOT IN ( 2, 3 )
GROUP BY d.name
ORDER BY 2 DESC;

/*
Backup LOG

Outra informacao muito importante,,,,
*/

Print 'Backup Log'
SELECT d.name,
       MAX(b.backup_finish_date) AS [ultima data do backup]
FROM master.sys.databases d
    LEFT OUTER JOIN msdb.dbo.backupset b
        ON d.name = b.database_name
           AND b.type = 'L'
WHERE d.database_id NOT IN ( 2, 3 )
      AND d.recovery_model <> 3
GROUP BY d.name
ORDER BY 2 DESC;


/*
Localizacao dos backups

Se houve backup, pra onde ele foi?
*/

Print 'Localizacao dos Backups'

SELECT TOP 100
       a.database_name,
       b.physical_device_name
FROM msdb.dbo.backupmediafamily b
    INNER JOIN msdb.dbo.backupset a
        ON b.media_set_id = a.media_set_id
WHERE a.type = 'D'
ORDER BY a.backup_start_date DESC;

SELECT TOP 100
       a.database_name,
       b.physical_device_name
FROM msdb.dbo.backupmediafamily b
    INNER JOIN msdb.dbo.backupset a
        ON b.media_set_id = a.media_set_id
WHERE a.type = 'L'
ORDER BY a.backup_start_date DESC;


/*
A quanto tempo existe historico de backup?

No SQL 2k, havia um grande problema de performance quando o historico ficava muito grande.
*/

Print 'Backup History'

SELECT TOP 1
       backup_start_date
FROM msdb.dbo.backupset WITH (NOLOCK)
ORDER BY backup_set_id ASC;

/*
Informacoes sobre o SO
(SQL Server 2008 R2 SP1 ou superior)
para saber mais sobre Windows release (http://msdn.microsoft.com/en-us/library/ms724832(VS.85).aspx)
para saber mais sobre SKU (http://msdn.microsoft.com/en-us/library/ms724358.aspx)
*/

SELECT windows_release,
       windows_service_pack_level,
       windows_sku,
       os_language_version
FROM sys.dm_os_windows_info WITH (NOLOCK)
OPTION (RECOMPILE);

/*
Informacoes sobre o Servico do SQL Server
o principal ponto ver o service_account
(SQL Server 2008 R2 SP1 ou superior)
*/

SELECT servicename,
       startup_type_desc,
       status_desc,
       last_startup_time,
       service_account,
       is_clustered,
       cluster_nodename
FROM sys.dm_server_services WITH (NOLOCK)
OPTION (RECOMPILE);

/*
Informacao sobre o fabricante do hardware
se o errorlog nao foi reciclado
*/

EXEC xp_readerrorlog 0, 1, "Manufacturer";

/*
Informacao sobre o processador
*/

EXEC xp_instance_regread 'HKEY_LOCAL_MACHINE',
                         'HARDWARE\DESCRIPTION\System\CentralProcessor\0',
                         'ProcessorNameString';

/*
quantos processadores existem, quanto de memoria tem no servidor
*/
SELECT cpu_count,
       affinity_type_desc,
       (physical_memory_kb) / 1024 AS [memory in MB]
FROM sys.dm_os_sys_info;

/*
quais processadores estao disponiveis para o SQL?
*/

SELECT cpu_id,
       status,
       is_online
FROM sys.dm_os_schedulers
WHERE status = 'VISIBLE ONLINE';

/*
Informacoes no registro sobre o SQL
*/
SELECT registry_key,
       value_name,
       value_data
FROM sys.dm_server_registry WITH (NOLOCK)
OPTION (RECOMPILE);

/*
permicoes do usuario que inicia o SQL
*/
sp_configure 'show advanced options', 1
reconfigure

sp_configure 'xp_cmdshell', 1
reconfigure

xp_cmdshell "whoami /priv"

sp_configure 'xp_cmdshell', 0
reconfigure

sp_configure 'show advanced options', 0
reconfigure

/*
Se o SQL estiver em cluster qual o nome do host atual?
*/
SELECT NodeName
FROM sys.dm_os_cluster_nodes WITH (NOLOCK)
OPTION (RECOMPILE);

/*
Pega algumas informacoes interessantes como
nome, owner, data de criação, dbid, Modo de Compatiblidade das bases, recovery model, versao e status

ATENCAO: Lembre-se que a ideia do script eh de apenas ver o que tem,
caso encontre alguma base com status diferente de online ele nao faz nada
e na teoria ainda nao eh a hora de voce fazer. Apenas reporte.
*/

PRINT 'Nome, owner, dbcreate, dbid, cmptlvl, recovery, version, status';

SELECT name AS [NAME],
       SUSER_SNAME(owner_sid) AS [Owner],
       CONVERT(NVARCHAR(11), create_date) AS [Data Criacao],
       database_id AS [DBID],
       compatibility_level,
       DATABASEPROPERTYEX(name, 'recovery') AS [Recovery Model],
       page_verify_option_desc AS [Page Verify],
       (CASE is_auto_create_stats_on
            WHEN 0 THEN
                'Nao'
            WHEN 1 THEN
                'Sim'
        END
       ) AS [is_auto_create_stats_on],
       (CASE is_auto_update_stats_on
            WHEN 0 THEN
                'Nao'
            WHEN 1 THEN
                'Sim'
        END
       ) AS [is_auto_update_stats_on],
       (CASE is_auto_update_stats_async_on
            WHEN 0 THEN
                'Nao'
            WHEN 1 THEN
                'Sim'
        END
       ) AS [is_auto_update_stats_async_on],
       (CASE is_parameterization_forced
            WHEN 0 THEN
                'Nao'
            WHEN 1 THEN
                'Sim'
        END
       ) AS [is_parameterization_forced],
       snapshot_isolation_state_desc,
       (CASE is_read_committed_snapshot_on
            WHEN 0 THEN
                'Nao'
            WHEN 1 THEN
                'Sim'
        END
       ) AS [is_read_committed_snapshot_on],
       (CASE is_auto_close_on
            WHEN 0 THEN
                'Nao'
            WHEN 1 THEN
                'Sim'
        END
       ) AS [is_auto_close_on],
       (CASE is_auto_shrink_on
            WHEN 0 THEN
                'Nao'
            WHEN 1 THEN
                'Sim'
        END
       ) AS [is_auto_shrink_on],
       DATABASEPROPERTYEX(name, 'status') AS [Status]
FROM master.sys.databases;


/*
Quais traces estão habilitados no SQL?
*/

Print 'Quais Traces estão habilitados'

DBCC TRACESTATUS

/*
Quando o SQL Server foi instalado?
*/

Print 'Quando o SQL Server foi instalado'

SELECT @@SERVERNAME AS [Server Name],
       createdate AS [Instalacao do SQL Server]
FROM sys.syslogins
WHERE [sid] = 0x010100000000000512000000;

/*
Quando foi que o DBCC CHECKDB rodou pela última vez?

Isso eh tao bom quando retorna alguma coisa,,,
*/

Print 'DBCC CHECKDB'
CREATE TABLE #temp
(
    ParentObject VARCHAR(255),
    [Object] VARCHAR(255),
    Field VARCHAR(255),
    [Value] VARCHAR(255)
);

CREATE TABLE #DBCCResults
(
    ServerName VARCHAR(255),
    DBName VARCHAR(255),
    LastCleanDBCCDate DATETIME
);

EXEC master.dbo.sp_MSforeachdb @command1 = 'USE ? INSERT INTO #temp EXECUTE (''DBCC DBINFO WITH TABLERESULTS'')',
                               @command2 = 'INSERT INTO #DBCCResults SELECT @@SERVERNAME, ''?'', Value FROM #temp WHERE Field = ''dbi_dbccLastKnownGood''',
                               @command3 = 'TRUNCATE TABLE #temp';

SELECT DISTINCT
       ServerName,
       DBName,
       CASE LastCleanDBCCDate
           WHEN '1900-01-01 00:00:00.000' THEN
               'Nunca rodou DBCC CHECKDB'
           ELSE
               CAST(LastCleanDBCCDate AS VARCHAR)
       END AS LastCleanDBCCDate
FROM #DBCCResults
ORDER BY 3;

DROP TABLE #temp,
           #DBCCResults;

/*
Existem páginas corrompidas?
*/

Print 'Páginas corrompidas'

SELECT *
FROM msdb..suspect_pages;

/*
Essa query é apenas para SQL Server 2008 e SQL Server 2008 R2 quando você tem Mirror configurado
ele vai analisar se houve necessidade de recuperação de página corrompida.
*/

Print 'Recuperaçãp de página usando o mirror'

SELECT *
FROM sys.dm_db_mirroring_auto_page_repair

/*
Quem faz parte do sysadmin ou securityadmin

Quantas outras pessoas podem acessar o SQL e fazer algum tipo de estrago?
*/
SELECT l.name AS [Nome],
       (CASE l.denylogin
            WHEN 0 THEN
                'Nao'
            WHEN 1 THEN
                'Sim'
        END
       ) AS [Negado],
       (CASE l.isntname
            WHEN 0 THEN
                'Nao'
            WHEN 1 THEN
                'Sim'
        END
       ) AS [nt nome],
       (CASE l.isntgroup
            WHEN 0 THEN
                'Nao'
            WHEN 1 THEN
                'Sim'
        END
       ) AS [nt grupo],
       (CASE l.isntuser
            WHEN 0 THEN
                'Nao'
            WHEN 1 THEN
                'Sim'
        END
       ) AS [nt user]
FROM master.dbo.syslogins l
WHERE l.sysadmin = 1
      OR l.securityadmin = 1
ORDER BY l.isntgroup,
         l.isntname,
         l.isntuser;

/*
Users

Quais sao os usuarios de Windows e os de SQL
Preste atencao quais sao os usuarios, pode ter mais do que precisa,,,,
*/

Print 'Usuarios windows e SQL'

SELECT name AS [Name],
       (CASE isntname
            WHEN 0 THEN
                'SQL Server Standard'
            WHEN 1 THEN
                'Windows Authentication'
        END
       ) AS [Type]
FROM master.sys.syslogins;

/*
Usuarios com senha em branco ou senha com o mesmo nome
*/
SELECT SERVERPROPERTY('machinename') AS 'Server Name',
       ISNULL(SERVERPROPERTY('instancename'), SERVERPROPERTY('machinename')) AS 'Instance Name',
       name AS 'Login com senha em branco'
FROM master.sys.sql_logins
WHERE PWDCOMPARE('', password_hash) = 1
ORDER BY name
OPTION (MAXDOP 1);

SELECT SERVERPROPERTY('machinename') AS 'Server Name',
       ISNULL(SERVERPROPERTY('instancename'), SERVERPROPERTY('machinename')) AS 'Instance Name',
       name AS 'Login com senha igual ao nome'
FROM master.sys.sql_logins
WHERE PWDCOMPARE(name, password_hash) = 1
ORDER BY name
OPTION (MAXDOP 1);
/*
usuários sem base associada
*/
CREATE TABLE #UsrSemBase
(
    LoginName NVARCHAR(MAX),
    DBname NVARCHAR(MAX),
    Username NVARCHAR(MAX),
    AliasName NVARCHAR(MAX)
);

INSERT INTO #UsrSemBase
EXEC master..sp_MSloginmappings;

SELECT *
FROM #UsrSemBase
WHERE DBname IS NULL
ORDER BY DBname,
         Username;

DROP TABLE #UsrSemBase;
/*
Usuarios x Bases

Esse aqui nao deve demorar muito,,,
apenas gera um relacionamento dos usuarios que estao nas bases
compare com a quantidade de usuarios que voce pegou na lista acima
*/

/*
Versão para SQL Server 2005/2008/2008R2/2012
*/
Print 'Usuarios por Bases'

CREATE TABLE #UsrDataMapping
(
    [database_name] [sysname] NULL,
    [name] [sysname] NULL,
    [schema] [sysname] NULL
);
EXEC sp_MSforeachdb 'insert into #UsrDataMapping SELECT ''?'' as DBNAME,
--u.name AS [Name],
SUSER_SNAME(sid) AS [Name],
ISNULL(u.default_schema_name,N'''') AS [DefaultSchema]
FROM
[?].sys.database_principals AS u
LEFT OUTER JOIN [?].sys.database_permissions AS dp ON dp.grantee_principal_id = u.principal_id
WHERE
(u.type in (''U'', ''S'', ''G'', ''C'', ''K''))
and dp.state = ''G''
';
SELECT *
FROM #UsrDataMapping
ORDER BY database_name;
DROP TABLE #UsrDataMapping;

/*
Versão para 2000
*/

create table #UsrDataMapping(
[database_name] [sysname] NULL,
[name] [sysname] NULL
)
EXEC sp_MSforeachdb 'insert into #UsrDataMapping SELECT ''?'' as DBNAME,
--u.name AS [Name],
SUSER_SNAME(u.sid) AS [Name]
FROM
[?].dbo.sysusers AS u
LEFT OUTER JOIN [?].dbo.syspermissions AS dp ON dp.grantee = u.u_id
'
select distinct database_name, name from #UsrDataMapping
where name is not null
order by database_name
drop table #UsrDataMapping
/*
Membros de roles
*/

create table ##RolesMembers
(
[Database] sysname,
RoleName sysname,
MemberName sysname
)

exec dbo.sp_MSforeachdb 'insert into ##RolesMembers select ''[?]'', ''['' + r.name + '']'', ''['' + m.name + '']''
from [?].sys.database_role_members rm
inner join [?].sys.database_principals r on rm.role_principal_id = r.principal_id
inner join [?].sys.database_principals m on rm.member_principal_id = m.principal_id
-- where r.name = ''db_owner'' and m.name != ''dbo'' -- you may want to uncomment this line';

select * from ##RolesMembers
order by [Database], [RoleName]

drop table ##RolesMembers

/*
usuários órfãos
*/

create table ##OrphanedUsers
(
[Database] sysname,
Username sysname
)


exec dbo.sp_MSforeachdb 'insert into ##OrphanedUsers select ''[?]'', UserName = name
from [?].sys.sysusers
where issqluser = 1
and (sid is not null and sid <> 0x0)
and (len(sid) <= 16)
and suser_sname(sid) is null;'


select * from ##OrphanedUsers with (nolock)
drop table ##OrphanedUsers
/*
Objetos em bases de sistema

Coisas que nao deveriam estar neste lugar
*/

Print 'Coisas no lugar errado'

SELECT *
FROM master.sys.tables
WHERE name NOT IN ( 'spt_fallback_db', 'spt_fallback_dev', 'spt_fallback_usg', 'spt_monitor', 'spt_values',
                    'MSreplication_options'
                  )
      AND is_ms_shipped = 0;
SELECT *
FROM master.sys.procedures
WHERE name NOT IN ( 'sp_MSrepl_startup', 'sp_MScleanupmergepublisher' )
      AND is_ms_shipped = 0;
SELECT *
FROM model.sys.tables;
SELECT *
FROM model.sys.procedures;

/*
Start up Stored procedure

Achou alguma procedure aqui? estranho,,, veja o que ela faz,,,
pode ser o mau esperando um boot,,,
*/

SELECT *
FROM master.INFORMATION_SCHEMA.ROUTINES
WHERE OBJECTPROPERTY(OBJECT_ID(ROUTINE_NAME), 'ExecIsStartup') = 1

/*
Quem mais existe em server-level
*/

SELECT *
FROM sysservers

/*
Usuarios com acesso ao linkedserver
*/

SELECT S.srvname ,
 U.rmtloginame ,
 SUSER_SNAME(U.loginsid) AS [local_login]
FROM sysservers AS S
 INNER JOIN sys.sysoledbusers AS U ON S.srvid = U.rmtsrvid

/*
Agora mais informacoes sobre as bases

classico,,, nada fora do comum,,,
*/

SELECT *
FROM sysdatabases

/*
Onde estao os arquivos

onde eles estao? quantos sao?
*/

SELECT DB_NAME(database_id),
       name,
       type_desc,
       physical_name
FROM sys.master_files;

/*
--versão antiga

CREATE TABLE #ArquivosDB
(
    [Banco] [sysname] NOT NULL,
    [file_guid] [SMALLINT] NULL,
    [Local] [NVARCHAR](260) NOT NULL,
);
EXEC dbo.sp_MSforeachdb 'INSERT INTO #ArquivosDB SELECT ''[?]'' AS database_name, groupid, filename FROM [?].dbo.sysfiles';
SELECT Banco,
       (CASE file_guid
            WHEN 0 THEN
                'Log'
            ELSE
                'Data'
        END
       ),
       Local
FROM #ArquivosDB
ORDER BY Banco,
         file_guid DESC;
DROP TABLE #ArquivosDB;
*/

/*
TempDB

voce deve ter visto a quantidade de datafiles para o TempDB na query acima
mas sera que eh um problema?
query para contencao de TempDB
(http://sqlcat.com/sqlcat/b/technicalnotes/archive/2011/01/25/table-valued-functions-and-tempdb-contention.aspx)
*/

SELECT r.session_id ,
 r.status ,
 r.command ,
 r.database_id ,
 r.blocking_session_id ,
 r.wait_type ,
 AVG(r.wait_time) AS [WaitTime] ,
 r.wait_resource
FROM sys.dm_exec_requests AS r
 INNER JOIN sys.dm_exec_sessions AS s ON ( r.session_id = s.session_id )
WHERE r.wait_type IS NOT NULL
 AND s.is_user_process = 1
GROUP BY GROUPING SETS(( r.session_id ,
 r.status ,
 r.command ,
 r.database_id ,
 r.blocking_session_id ,
 r.wait_type ,
 r.wait_time ,
 r.wait_resource
 ), ( ))

/*
Triggers

isso pode demorar um pouco,,,
e mais ainda pra ler,,,,
*/

PRINT 'Triggers';

EXEC dbo.sp_MSforeachdb 'SELECT ''[?]'' AS Banco, o.name AS Tabela, t.* FROM [?].sys.triggers t INNER JOIN [?].sys.objects o ON t.parent_id = o.object_id';

/*
Alguns Waits

Nao zere o contador, apenas veja o que tem,,,
*/

Print 'Alguns Waits'

WITH [Waits]
AS (SELECT [wait_type],
           [wait_time_ms] / 1000.0 AS [WaitS],
           ([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
           [signal_wait_time_ms] / 1000.0 AS [SignalS],
           [waiting_tasks_count] AS [WaitCount],
           100.0 * [wait_time_ms] / SUM([wait_time_ms]) OVER () AS [Percentage],
           ROW_NUMBER() OVER (ORDER BY [wait_time_ms] DESC) AS [RowNum]
    FROM sys.dm_os_wait_stats
    WHERE [wait_type] NOT IN (   N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP',
                                 N'BROKER_TO_FLUSH', N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE', N'CHKPT',
                                 N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE', N'CXCONSUMER',

                                 -- DBmirror
                                 N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE', N'DBMIRROR_WORKER_QUEUE',
                                 N'DBMIRRORING_CMD', N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE', N'EXECSYNC',
                                 N'FSAGENT', N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX',

                                 -- AG
                                 N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', N'HADR_LOGCAPTURE_WAIT',
                                 N'HADR_NOTIFICATION_DEQUEUE', N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',
                                 N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP', N'LOGMGR_QUEUE', N'MEMORY_ALLOCATION_EXT',
                                 N'ONDEMAND_TASK_QUEUE', N'PARALLEL_REDO_DRAIN_WORKER', N'PARALLEL_REDO_LOG_CACHE',
                                 N'PARALLEL_REDO_TRAN_LIST', N'PARALLEL_REDO_WORKER_SYNC',
                                 N'PARALLEL_REDO_WORKER_WAIT_WORK', N'PREEMPTIVE_OS_FLUSHFILEBUFFERS',
                                 N'PREEMPTIVE_XE_GETTARGETSTATE', N'PWAIT_ALL_COMPONENTS_INITIALIZED',
                                 N'PWAIT_DIRECTLOGCONSUMER_GETNEXT', N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
                                 N'QDS_ASYNC_QUEUE', N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
                                 N'QDS_SHUTDOWN_QUEUE', N'REDO_THREAD_PENDING_WORK', N'REQUEST_FOR_DEADLOCK_SEARCH',
                                 N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH', N'SLEEP_DBSTARTUP',
                                 N'SLEEP_DCOMSTARTUP', N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
                                 N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP', N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
                                 N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT', N'SOS_WORK_DISPATCHER',
                                 N'SP_SERVER_DIAGNOSTICS_SLEEP', N'SQLTRACE_BUFFER_FLUSH',
                                 N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', N'SQLTRACE_WAIT_ENTRIES', N'VDI_CLIENT_OTHER',
                                 N'WAIT_FOR_RESULTS', N'WAITFOR', N'WAITFOR_TASKSHUTDOWN', N'WAIT_XTP_RECOVERY',
                                 N'WAIT_XTP_HOST_WAIT', N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', N'WAIT_XTP_CKPT_CLOSE',
                                 N'XE_DISPATCHER_JOIN', N'XE_DISPATCHER_WAIT', N'XE_TIMER_EVENT'
                             )
          AND [waiting_tasks_count] > 0)
SELECT MAX([W1].[wait_type]) AS [WaitType],
       CAST(MAX([W1].[WaitS]) AS DECIMAL(16, 2)) AS [Wait_S],
       CAST(MAX([W1].[ResourceS]) AS DECIMAL(16, 2)) AS [Resource_S],
       CAST(MAX([W1].[SignalS]) AS DECIMAL(16, 2)) AS [Signal_S],
       MAX([W1].[WaitCount]) AS [WaitCount],
       CAST(MAX([W1].[Percentage]) AS DECIMAL(5, 2)) AS [Percentage],
       CAST((MAX([W1].[WaitS]) / MAX([W1].[WaitCount])) AS DECIMAL(16, 4)) AS [AvgWait_S],
       CAST((MAX([W1].[ResourceS]) / MAX([W1].[WaitCount])) AS DECIMAL(16, 4)) AS [AvgRes_S],
       CAST((MAX([W1].[SignalS]) / MAX([W1].[WaitCount])) AS DECIMAL(16, 4)) AS [AvgSig_S]
FROM [Waits] AS [W1]
    INNER JOIN [Waits] AS [W2]
        ON [W2].[RowNum] <= [W1].[RowNum]
GROUP BY [W1].[RowNum]
HAVING SUM([W2].[Percentage]) - MAX([W1].[Percentage]) < 95; -- percentage threshold
GO

/*
Querys de alto custo
*/

SELECT TOP (1)
       MAX(query) AS sample_query,
       SUM(execution_count) AS cnt,
       SUM(total_worker_time) AS cpu,
       SUM(total_physical_reads) AS reads,
       SUM(total_logical_reads) AS logical_reads,
       SUM(total_elapsed_time) AS duration
FROM
(
    SELECT QS.*,
           --sq.query_plan,
           SUBSTRING(   ST.text,
                        (QS.statement_start_offset / 2) + 1,
                        ((CASE statement_end_offset
                              WHEN -1 THEN
                                  DATALENGTH(ST.text)
                              ELSE
                                  QS.statement_end_offset
                          END - QS.statement_start_offset
                         ) / 2
                        ) + 1
                    ) AS query
    FROM sys.dm_exec_query_stats AS QS
        CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) AS ST
        CROSS APPLY sys.dm_exec_plan_attributes(QS.plan_handle) AS PA
    --cross apply sys.dm_exec_query_plan (QS.plan_handle) sq
    WHERE PA.attribute = 'dbid'
          AND PA.value = DB_ID()
) AS D --Alterar aqui para verificar alguma base específica
GROUP BY query
ORDER BY duration DESC;

/*
Frangmentacao de indices

se voce achou que o de Triggers demorou,,, imagina esse,,,,

esse tem que rodar banco a banco
*/

Print 'Fragmentacao de indices'

SELECT db.name AS databaseName,
       ps.object_id AS objectID,
       ps.index_id AS indexID,
       ps.partition_number AS partitionNumber,
       ps.avg_fragmentation_in_percent AS fragmentation,
       ps.page_count
FROM sys.databases db
    INNER JOIN sys.dm_db_index_physical_stats(NULL, NULL, NULL, NULL, N'Limited') ps
        ON db.database_id = ps.database_id
WHERE ps.index_id > 0
      AND ps.page_count > 100
      AND ps.avg_fragmentation_in_percent > 30
OPTION (MAXDOP 1);

/*
Índices hipotéticos
*/
CREATE TABLE #hipotetico
(
    banco sysname NULL,
    table_name sysname NULL,
    index_name sysname NULL
);
INSERT INTO #hipotetico
EXEC dbo.sp_MSforeachdb '
select ''[?]'' AS banco, object_name(object_id) AS tabela, name from [?].sys.indexes where is_hypothetical = 1
';
SELECT *
FROM #hipotetico;

DROP TABLE #hipotetico;

/*

Índices faltantes
*/

SELECT migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) AS improvement_measure,
       DB_NAME(mid.database_id) AS DatabaseName,
       OBJECT_NAME(mid.[object_id], mid.database_id) AS ObjectName,
       'CREATE INDEX [missing_index_' + CONVERT(VARCHAR, mig.index_group_handle) + '_'
       + CONVERT(VARCHAR, mid.index_handle) + '_' + LEFT(PARSENAME(mid.statement, 1), 32) + ']' + ' ON '
       + mid.statement + ' (' + ISNULL(mid.equality_columns, '') + CASE
                                                                       WHEN mid.equality_columns IS NOT NULL
                                                                            AND mid.inequality_columns IS NOT NULL THEN
                                                                           ','
                                                                       ELSE
                                                                           ''
                                                                   END + ISNULL(mid.inequality_columns, '') + ')'
       + ISNULL(' INCLUDE (' + mid.included_columns + ')', '') AS create_index_statement,
       migs.*,
       mid.database_id,
       mid.[object_id]
FROM sys.dm_db_missing_index_groups mig
    INNER JOIN sys.dm_db_missing_index_group_stats migs
        ON migs.group_handle = mig.index_group_handle
    INNER JOIN sys.dm_db_missing_index_details mid
        ON mig.index_handle = mid.index_handle
WHERE migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) > 10
--AND mid.database_id = DB_ID() -- descomente aqui para executar em uma base específica, ou colocando o Database ID ou coloque no contexto do banco
ORDER BY migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) DESC;

/*
Índices sem uso
*/


SELECT o.name,
       indexname = i.name,
       i.index_id,
       reads = user_seeks + user_scans + user_lookups,
       writes = user_updates,
       rows =
       (
           SELECT SUM(p.rows)
           FROM sys.partitions p
           WHERE p.index_id = s.index_id
                 AND s.object_id = p.object_id
       ),
       CASE
           WHEN s.user_updates < 1 THEN
               100
           ELSE
               1.00 * (s.user_seeks + s.user_scans + s.user_lookups) / s.user_updates
       END AS reads_per_write,
       'DROP INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(c.name) + '.' + QUOTENAME(OBJECT_NAME(s.object_id)) AS 'drop statement'
FROM sys.dm_db_index_usage_stats s
    INNER JOIN sys.indexes i
        ON i.index_id = s.index_id
           AND s.object_id = i.object_id
    INNER JOIN sys.objects o
        ON s.object_id = o.object_id
    INNER JOIN sys.schemas c
        ON o.schema_id = c.schema_id
WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
      AND s.database_id = DB_ID()
      AND i.type_desc = 'nonclustered'
      AND i.is_primary_key = 0
      AND i.is_unique_constraint = 0
      AND
      (
          SELECT SUM(p.rows)
          FROM sys.partitions p
          WHERE p.index_id = s.index_id
                AND s.object_id = p.object_id
      ) > 10000
ORDER BY reads;

/*
Essa query mostra algumas informações sobre a fragmentação dos índices e estatísticas
mas o mais interessante é a coluna lastStatsUpdate
*/
CREATE TABLE #estatisticas
(
    Banco sysname,
    table_schema sysname,
    table_name sysname,
    index_name sysname,
    table_id BIGINT,
    index_id TINYINT,
    groupid TINYINT,
    modifiedRows BIGINT,
    rowcnt BIGINT,
    ModifiedPct DECIMAL(18, 8),
    lastStatsUpdate DATETIME,
    Processed VARCHAR(5)
);
EXEC dbo.sp_MSforeachdb 'INSERT INTO #estatisticas
SELECT ''[?]'',
schemas.name AS table_schema ,
 tbls.name AS table_name ,
 i.name AS index_name ,
 i.id AS table_id ,
 i.indid AS index_id ,
 i.groupid ,
 i.rowmodctr AS modifiedRows ,
 ( SELECT MAX(rowcnt)
 FROM sysindexes i2
 WHERE i.id = i2.id
 AND i2.indid < 2
 ) AS rowcnt ,
 CONVERT(DECIMAL(18, 8), CONVERT(DECIMAL(18, 8), i.rowmodctr)
 / CONVERT(DECIMAL(18, 8), ( SELECT MAX(rowcnt)
 FROM sysindexes i2
 WHERE i.id = i2.id
 AND i2.indid < 2
 ))) AS ModifiedPct ,
 STATS_DATE(i.id, i.indid) AS lastStatsUpdate ,
 ''False'' AS Processed

FROM [?].sys.sysindexes i
 INNER JOIN [?].sys.sysobjects tbls ON i.id = tbls.id
 INNER JOIN [?].sys.sysusers schemas ON tbls.uid = schemas.uid
 INNER JOIN [?].information_schema.tables tl ON tbls.name = tl.table_name
 AND schemas.name = tl.table_schema
 AND tl.table_type = ''BASE TABLE''
WHERE 0 < i.indid
 AND i.indid < 255
 AND table_schema <> ''sys''
 AND i.rowmodctr <> 0
 AND ( SELECT MAX(rowcnt)
 FROM [?].sys.sysindexes i2
 WHERE i.id = i2.id
 AND i2.indid < 2
 ) > 0

';
SELECT *
FROM #estatisticas
ORDER BY lastStatsUpdate DESC;

DROP TABLE #estatisticas;

/*
Configurações da instância

Isso mostra como esta configurado hoje, e nao como estava configurado...
*/

EXEC dbo.sp_configure 'show advanced options', 1
GO
RECONFIGURE
GO
EXEC dbo.sp_configure

/*
Extended Stored Procedures

procure por qualquer coisa fora do padrao...
*/

EXEC sp_helpextendedproc;
GO

/*
Email

O SQL envia email?
*/

/*
Pule para a próxima linha,,,
esse é apenas um teste para saber se vc está executando todo o script ou está indo por partes
*/
raiserror ('Eu já escrevi que esse script é para ser executado por partes,,,',20,-1) with log
GO

PRINT 'Email';

EXEC msdb.dbo.sp_send_dbmail @recipients = 'seuemail@aqui.com.br',
                             @body = @@SERVERNAME,
                             @subject = 'Testando SQL Server Database Mail - veja no corpo o nome do servidor';
GO


/*
Jobs

Simples,,, quais sao, a quem pertence e se estao ativos,,,
NAO tente corrigir-los agora,,, entenda o que eles fazem ou deveriam fazer,,,
*/
PRINT 'Jobs';

SELECT name AS [Name],
       SUSER_SNAME(owner_sid) AS [Owner],
       (CASE enabled
            WHEN 0 THEN
                'Nao'
            WHEN 1 THEN
                'Sim'
        END
       ) AS [Enable],
       description AS [Description]
FROM msdb.dbo.sysjobs_view
ORDER BY Name;

/*
Informação detalhada sobre os Jobs

*/

USE msdb
GO
SELECT /*S.job_id,*/ S.job_name AS [Nome do Job],
                     S.is_job_enabled AS [Job],
                     S.is_schedule_enabled AS [Agenda],
                     SUSER_SNAME(S.job_owner) AS [Owner],
                     S.schedule_name,
                     S.Description AS [Descriçao],
                     AVG(((H.run_duration / 1000000) * 86400)
                         + (((H.run_duration - ((H.run_duration / 1000000) * 1000000)) / 10000) * 3600)
                         + (((H.run_duration - ((H.run_duration / 10000) * 10000)) / 100) * 60)
                         + (H.run_duration - (H.run_duration / 100) * 100)
                        ) AS [MédiaDeDuraçao(s)]
--    ,number_of_runs = count(1)
FROM
(
    SELECT SJ.job_id,
           SJ.owner_sid AS job_owner,
           SJ.name AS job_name,
           SJ.enabled AS is_job_enabled,
           SS.enabled AS is_schedule_enabled,
           SS.name AS schedule_name,
           CASE freq_type
               WHEN 1 THEN
                   'Ocorre em ' + STUFF(RIGHT(active_start_date, 4), 3, 0, '/') + '/' + LEFT(active_start_date, 4)
                   + ' as '
                   + REPLACE(
                                RIGHT(CONVERT(
                                                 VARCHAR(30),
                                                 CAST(CONVERT(
                                                                 VARCHAR(8),
                                                                 STUFF(
                                                                          STUFF(
                                                                                   RIGHT('000000'
                                                                                         + CAST(active_start_time AS VARCHAR(10)), 6),
                                                                                   3,
                                                                                   0,
                                                                                   ':'
                                                                               ),
                                                                          6,
                                                                          0,
                                                                          ':'
                                                                      ),
                                                                 8
                                                             ) AS DATETIME)/* hh:mm:ss 24H */,
                                                 9
                                             ), 14),
                                ':000',
                                ' '
                            ) /* HH:mm:ss:000AM/PM then replace the :000 with space.*/
               WHEN 4 THEN
                   'Ocorre a cada ' + CAST(freq_interval AS VARCHAR(10)) + ' dia(s) '
                   + CASE freq_subday_type
                         WHEN 1 THEN
                             'a(s) '
                             + LTRIM(REPLACE(
                                                RIGHT(CONVERT(
                                                                 VARCHAR(30),
                                                                 CAST(CONVERT(
                                                                                 VARCHAR(8),
                                                                                 STUFF(
                                                                                          STUFF(
                                                                                                   RIGHT('000000'
                                                                                                         + CAST(active_start_time AS VARCHAR(10)), 6),
                                                                                                   3,
                                                                                                   0,
                                                                                                   ':'
                                                                                               ),
                                                                                          6,
                                                                                          0,
                                                                                          ':'
                                                                                      ),
                                                                                 8
                                                                             ) AS DATETIME),
                                                                 9
                                                             ), 14),
                                                ':000',
                                                ' '
                                            )
                                    )
                         WHEN 2 THEN
                             'a cada ' + CAST(freq_subday_interval AS VARCHAR(10)) + ' segundo(s)'
                         WHEN 4 THEN
                             'a cada ' + CAST(freq_subday_interval AS VARCHAR(10)) + ' minuto(s)'
                         WHEN 8 THEN
                             'a cada ' + CAST(freq_subday_interval AS VARCHAR(10)) + ' hora(s)'
                         ELSE
                             ''
                     END
                   + CASE
                         WHEN freq_subday_type IN ( 2, 4, 8 ) /* repeat seconds/mins/hours */
           THEN
                             ' entre '
                             + LTRIM(REPLACE(
                                                RIGHT(CONVERT(
                                                                 VARCHAR(30),
                                                                 CAST(CONVERT(
                                                                                 VARCHAR(8),
                                                                                 STUFF(
                                                                                          STUFF(
                                                                                                   RIGHT('000000'
                                                                                                         + CAST(active_start_time AS VARCHAR(10)), 6),
                                                                                                   3,
                                                                                                   0,
                                                                                                   ':'
                                                                                               ),
                                                                                          6,
                                                                                          0,
                                                                                          ':'
                                                                                      ),
                                                                                 8
                                                                             ) AS DATETIME),
                                                                 9
                                                             ), 14),
                                                ':000',
                                                ' '
                                            )
                                    ) + ' e '
                             + LTRIM(REPLACE(
                                                RIGHT(CONVERT(
                                                                 VARCHAR(30),
                                                                 CAST(CONVERT(
                                                                                 VARCHAR(8),
                                                                                 STUFF(
                                                                                          STUFF(
                                                                                                   RIGHT('000000'
                                                                                                         + CAST(active_end_time AS VARCHAR(10)), 6),
                                                                                                   3,
                                                                                                   0,
                                                                                                   ':'
                                                                                               ),
                                                                                          6,
                                                                                          0,
                                                                                          ':'
                                                                                      ),
                                                                                 8
                                                                             ) AS DATETIME),
                                                                 9
                                                             ), 14),
                                                ':000',
                                                ' '
                                            )
                                    )
                         ELSE
                             ''
                     END
               WHEN 8 THEN
                   'Ocorre a cada ' + CAST(freq_recurrence_factor AS VARCHAR(10)) + ' semana(s) em '
                   + REPLACE(   CASE
                                    WHEN freq_interval & 1 = 1 THEN
                                        'Domingo, '
                                    ELSE
                                        ''
                                END + CASE
                                          WHEN freq_interval & 2 = 2 THEN
                                              'Segunda, '
                                          ELSE
                                              ''
                                      END + CASE
                                                WHEN freq_interval & 4 = 4 THEN
                                                    'Terça, '
                                                ELSE
                                                    ''
                                            END + CASE
                                                      WHEN freq_interval & 8 = 8 THEN
                                                          'Quarta, '
                                                      ELSE
                                                          ''
                                                  END + CASE
                                                            WHEN freq_interval & 16 = 16 THEN
                                                                'Quinta, '
                                                            ELSE
                                                                ''
                                                        END + CASE
                                                                  WHEN freq_interval & 32 = 32 THEN
                                                                      'Sexta, '
                                                                  ELSE
                                                                      ''
                                                              END + CASE
                                                                        WHEN freq_interval & 64 = 64 THEN
                                                                            'Sabado, '
                                                                        ELSE
                                                                            ''
                                                                    END + '|',
                                ', |',
                                ' '
                            ) /* get rid of trailing comma */
                   + CASE freq_subday_type
                         WHEN 1 THEN
                             'a(s) '
                             + LTRIM(REPLACE(
                                                RIGHT(CONVERT(
                                                                 VARCHAR(30),
                                                                 CAST(CONVERT(
                                                                                 VARCHAR(8),
                                                                                 STUFF(
                                                                                          STUFF(
                                                                                                   RIGHT('000000'
                                                                                                         + CAST(active_start_time AS VARCHAR(10)), 6),
                                                                                                   3,
                                                                                                   0,
                                                                                                   ':'
                                                                                               ),
                                                                                          6,
                                                                                          0,
                                                                                          ':'
                                                                                      ),
                                                                                 8
                                                                             ) AS DATETIME),
                                                                 9
                                                             ), 14),
                                                ':000',
                                                ' '
                                            )
                                    )
                         WHEN 2 THEN
                             'a cada ' + CAST(freq_subday_interval AS VARCHAR(10)) + ' segundo(s)'
                         WHEN 4 THEN
                             'a cada ' + CAST(freq_subday_interval AS VARCHAR(10)) + ' minuto(s)'
                         WHEN 8 THEN
                             'a cada ' + CAST(freq_subday_interval AS VARCHAR(10)) + ' hora(s)'
                         ELSE
                             ''
                     END
                   + CASE
                         WHEN freq_subday_type IN ( 2, 4, 8 ) /* repeat seconds/mins/hours */
           THEN
                             ' entre '
                             + LTRIM(REPLACE(
                                                RIGHT(CONVERT(
                                                                 VARCHAR(30),
                                                                 CAST(CONVERT(
                                                                                 VARCHAR(8),
                                                                                 STUFF(
                                                                                          STUFF(
                                                                                                   RIGHT('000000'
                                                                                                         + CAST(active_start_time AS VARCHAR(10)), 6),
                                                                                                   3,
                                                                                                   0,
                                                                                                   ':'
                                                                                               ),
                                                                                          6,
                                                                                          0,
                                                                                          ':'
                                                                                      ),
                                                                                 8
                                                                             ) AS DATETIME),
                                                                 9
                                                             ), 14),
                                                ':000',
                                                ' '
                                            )
                                    ) + ' e '
                             + LTRIM(REPLACE(
                                                RIGHT(CONVERT(
                                                                 VARCHAR(30),
                                                                 CAST(CONVERT(
                                                                                 VARCHAR(8),
                                                                                 STUFF(
                                                                                          STUFF(
                                                                                                   RIGHT('000000'
                                                                                                         + CAST(active_end_time AS VARCHAR(10)), 6),
                                                                                                   3,
                                                                                                   0,
                                                                                                   ':'
                                                                                               ),
                                                                                          6,
                                                                                          0,
                                                                                          ':'
                                                                                      ),
                                                                                 8
                                                                             ) AS DATETIME),
                                                                 9
                                                             ), 14),
                                                ':000',
                                                ' '
                                            )
                                    )
                         ELSE
                             ''
                     END
               WHEN 16 THEN
                   'Ocorre a cada ' + CAST(freq_recurrence_factor AS VARCHAR(10)) + ' mes(s) on ' + 'dia '
                   + CAST(freq_interval AS VARCHAR(10)) + ' deste mes '
                   + CASE freq_subday_type
                         WHEN 1 THEN
                             'a(s) '
                             + LTRIM(REPLACE(
                                                RIGHT(CONVERT(
                                                                 VARCHAR(30),
                                                                 CAST(CONVERT(
                                                                                 VARCHAR(8),
                                                                                 STUFF(
                                                                                          STUFF(
                                                                                                   RIGHT('000000'
                                                                                                         + CAST(active_start_time AS VARCHAR(10)), 6),
                                                                                                   3,
                                                                                                   0,
                                                                                                   ':'
                                                                                               ),
                                                                                          6,
                                                                                          0,
                                                                                          ':'
                                                                                      ),
                                                                                 8
                                                                             ) AS DATETIME),
                                                                 9
                                                             ), 14),
                                                ':000',
                                                ' '
                                            )
                                    )
                         WHEN 2 THEN
                             'a cada ' + CAST(freq_subday_interval AS VARCHAR(10)) + ' segundo(s)'
                         WHEN 4 THEN
                             'a cada ' + CAST(freq_subday_interval AS VARCHAR(10)) + ' minutos(s)'
                         WHEN 8 THEN
                             'a cada ' + CAST(freq_subday_interval AS VARCHAR(10)) + ' horas(s)'
                         ELSE
                             ''
                     END
                   + CASE
                         WHEN freq_subday_type IN ( 2, 4, 8 ) /* repeat seconds/mins/hours */
           THEN
                             ' entre '
                             + LTRIM(REPLACE(
                                                RIGHT(CONVERT(
                                                                 VARCHAR(30),
                                                                 CAST(CONVERT(
                                                                                 VARCHAR(8),
                                                                                 STUFF(
                                                                                          STUFF(
                                                                                                   RIGHT('000000'
                                                                                                         + CAST(active_start_time AS VARCHAR(10)), 6),
                                                                                                   3,
                                                                                                   0,
                                                                                                   ':'
                                                                                               ),
                                                                                          6,
                                                                                          0,
                                                                                          ':'
                                                                                      ),
                                                                                 8
                                                                             ) AS DATETIME),
                                                                 9
                                                             ), 14),
                                                ':000',
                                                ' '
                                            )
                                    ) + ' e '
                             + LTRIM(REPLACE(
                                                RIGHT(CONVERT(
                                                                 VARCHAR(30),
                                                                 CAST(CONVERT(
                                                                                 VARCHAR(8),
                                                                                 STUFF(
                                                                                          STUFF(
                                                                                                   RIGHT('000000'
                                                                                                         + CAST(active_end_time AS VARCHAR(10)), 6),
                                                                                                   3,
                                                                                                   0,
                                                                                                   ':'
                                                                                               ),
                                                                                          6,
                                                                                          0,
                                                                                          ':'
                                                                                      ),
                                                                                 8
                                                                             ) AS DATETIME),
                                                                 9
                                                             ), 14),
                                                ':000',
                                                ' '
                                            )
                                    )
                         ELSE
                             ''
                     END
               WHEN 32 THEN
                   'Ocorre ' + CASE freq_relative_interval
                                   WHEN 1 THEN
                                       'toda primeira '
                                   WHEN 2 THEN
                                       'toda segunda '
                                   WHEN 4 THEN
                                       'toda terceira '
                                   WHEN 8 THEN
                                       'toda quarta '
                                   WHEN 16 THEN
                                       'na última '
                               END + CASE freq_interval
                                         WHEN 1 THEN
                                             'Domingo'
                                         WHEN 2 THEN
                                             'Segunda'
                                         WHEN 3 THEN
                                             'Terça'
                                         WHEN 4 THEN
                                             'Quarta'
                                         WHEN 5 THEN
                                             'Quinta'
                                         WHEN 6 THEN
                                             'Sexta'
                                         WHEN 7 THEN
                                             'Sabado'
                                         WHEN 8 THEN
                                             'dia'
                                         WHEN 9 THEN
                                             'dia da semana'
                                         WHEN 10 THEN
                                             'final de semana'
                                     END + ' de cada ' + CAST(freq_recurrence_factor AS VARCHAR(10)) + ' mes(s) '
                   + CASE freq_subday_type
                         WHEN 1 THEN
                             'a(s) '
                             + LTRIM(REPLACE(
                                                RIGHT(CONVERT(
                                                                 VARCHAR(30),
                                                                 CAST(CONVERT(
                                                                                 VARCHAR(8),
                                                                                 STUFF(
                                                                                          STUFF(
                                                                                                   RIGHT('000000'
                                                                                                         + CAST(active_start_time AS VARCHAR(10)), 6),
                                                                                                   3,
                                                                                                   0,
                                                                                                   ':'
                                                                                               ),
                                                                                          6,
                                                                                          0,
                                                                                          ':'
                                                                                      ),
                                                                                 8
                                                                             ) AS DATETIME),
                                                                 9
                                                             ), 14),
                                                ':000',
                                                ' '
                                            )
                                    )
                         WHEN 2 THEN
                             'a cada ' + CAST(freq_subday_interval AS VARCHAR(10)) + ' segundo(s)'
                         WHEN 4 THEN
                             'a cada ' + CAST(freq_subday_interval AS VARCHAR(10)) + ' minuto(s)'
                         WHEN 8 THEN
                             'a cada ' + CAST(freq_subday_interval AS VARCHAR(10)) + ' hora(s)'
                         ELSE
                             ''
                     END
                   + CASE
                         WHEN freq_subday_type IN ( 2, 4, 8 ) /* repeat seconds/mins/hours */
           THEN
                             ' entre '
                             + LTRIM(REPLACE(
                                                RIGHT(CONVERT(
                                                                 VARCHAR(30),
                                                                 CAST(CONVERT(
                                                                                 VARCHAR(8),
                                                                                 STUFF(
                                                                                          STUFF(
                                                                                                   RIGHT('000000'
                                                                                                         + CAST(active_start_time AS VARCHAR(10)), 6),
                                                                                                   3,
                                                                                                   0,
                                                                                                   ':'
                                                                                               ),
                                                                                          6,
                                                                                          0,
                                                                                          ':'
                                                                                      ),
                                                                                 8
                                                                             ) AS DATETIME),
                                                                 9
                                                             ), 14),
                                                ':000',
                                                ' '
                                            )
                                    ) + ' e '
                             + LTRIM(REPLACE(
                                                RIGHT(CONVERT(
                                                                 VARCHAR(30),
                                                                 CAST(CONVERT(
                                                                                 VARCHAR(8),
                                                                                 STUFF(
                                                                                          STUFF(
                                                                                                   RIGHT('000000'
                                                                                                         + CAST(active_end_time AS VARCHAR(10)), 6),
                                                                                                   3,
                                                                                                   0,
                                                                                                   ':'
                                                                                               ),
                                                                                          6,
                                                                                          0,
                                                                                          ':'
                                                                                      ),
                                                                                 8
                                                                             ) AS DATETIME),
                                                                 9
                                                             ), 14),
                                                ':000',
                                                ' '
                                            )
                                    )
                         ELSE
                             ''
                     END
               WHEN 64 THEN
                   'Roda quando o serviço do SQL Server Agent iniciar'
               WHEN 128 THEN
                   'Roda quando o computador estiver idle'
           END AS [Description]
    FROM msdb.dbo.sysjobs SJ
        INNER JOIN msdb.dbo.sysjobschedules SJS
            ON SJ.job_id = SJS.job_id
        INNER JOIN msdb.dbo.sysschedules SS
            ON SJS.schedule_id = SS.schedule_id
        INNER JOIN msdb.dbo.syscategories SC
            ON SJ.category_id = SC.category_id
--WHERE SC.name = 'Name from query below'
) S
    INNER JOIN msdb.dbo.sysjobhistory H
        ON S.job_id = H.job_id
           AND H.step_id = 0
WHERE H.run_date >= /* 7 days ago */ CAST(DATEPART(yyyy, DATEADD(d, -7, GETDATE())) AS VARCHAR(10))
                                     + CAST(DATEPART(mm, DATEADD(d, -7, GETDATE())) AS VARCHAR(10))
                                     + CAST(DATEPART(dd, DATEADD(d, -7, GETDATE())) AS VARCHAR(10)) --format getDate once to compare against multiple run_dates
GROUP BY /*S.job_id,*/ S.job_name,
                       S.is_job_enabled,
                       S.is_schedule_enabled,
                       S.job_owner,
                       S.schedule_name,
                       S.Description
ORDER BY S.job_name;
