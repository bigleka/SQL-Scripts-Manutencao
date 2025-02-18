/*
Execute code on destination server to create the stored procedure in the master database.
Create a linked server on the destination server that references the source server.
Execute the stored procedure on the destination server using the linked server name as the @PartnerServer parameter
Optionally include @debug=1 to output the commands that would be executed without actually executing them.
Example: 

exec dba_CopyLogins @ParnterServer = 'PrimaryReplica'
*/

/*
Credit for Original code goes to Robert L Davis aka SQLSoldier.

In the original stored procedure, if the endpoint_id's of an endpoint differ
between the source and destination servers, and the user running the procedure
has permissions on the endpoint, the procedure may try to grant permissions again
and throw an error saying "you cant grant permissions to yourself". This version
fixes that bug.
*/
USE [master]
GO

/****** Object:  StoredProcedure [dbo].[dba_CopyLogins]    Script Date: 8/28/2018 12:03:12 PM ******/
SET ANSI_NULLS ON
    GO

SET QUOTED_IDENTIFIER ON
    GO


CREATE PROCEDURE [dbo].[dba_CopyLogins]
    @PartnerServer SYSNAME,
    @ Debug BIT = 0
AS
-- V2 28-Aug-2018 - Dont try to grant permissions on endpoints if the user running this SP already has them,
-- and the endpoint_ids are different between the partnerserver and local server.
DECLARE
@MaxID INT
,@CurrID INT
,@SQL NVARCHAR(MAX)
,@LoginName SYSNAME
,@IsDisabled INT
,@Type CHAR(1)
,@SID VARBINARY(85)
,@SIDString NVARCHAR(100)
,@PasswordHash VARBINARY(256)
,@PasswordHashString NVARCHAR(300)
,@RoleName SYSNAME
,@Machine SYSNAME
,@PermState NVARCHAR(60)
,@PermName SYSNAME
,@Class TINYINT
,@MajorID INT
,@ErrNumber INT
,@ErrSeverity INT
,@ErrState INT
,@ErrProcedure SYSNAME
,@ErrLine INT
,@ErrMsg NVARCHAR(2048)
DECLARE
@Logins TABLE
(
LoginID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY
,[Name] SYSNAME NOT NULL
,[SID] VARBINARY(85) NOT NULL
,IsDisabled INT NOT NULL
,[Type] CHAR(1) NOT NULL
,PasswordHash VARBINARY(256) NULL
)
DECLARE
@Roles TABLE
(
RoleID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY
,RoleName SYSNAME NOT NULL
,LoginName SYSNAME NOT NULL
)
DECLARE
@Perms TABLE
(
PermID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY
,LoginName SYSNAME NOT NULL
,PermState NVARCHAR(60) NOT NULL
,PermName SYSNAME NOT NULL
,Class TINYINT NOT NULL
,ClassDesc NVARCHAR(60) NOT NULL
,MajorID INT NOT NULL
,SubLoginName SYSNAME NULL
,SubEndPointName SYSNAME NULL
)

SET NOCOUNT ON;

IF CHARINDEX('\', @PartnerServer) > 0
BEGIN
SET @Machine = LEFT (@PartnerServer, CHARINDEX('\', @PartnerServer) - 1);
END
    ELSE
BEGIN
SET @Machine = @PartnerServer;
END

-- Get all Windows logins from principal server
SET @ SQL = 'Select P.name, P.sid, P.is_disabled, P.type, L.password_hash' + CHAR (10) + 'From ' + QUOTENAME(@PartnerServer) + '.master.sys.server_principals P' + CHAR (10) + 'Left Join ' + QUOTENAME(@PartnerServer) + '.master.sys.sql_logins L On L.principal_id = P.principal_id' + CHAR (10) + 'Where P.type In (''U'', ''G'', ''S'')' + CHAR (10) + 'And P.name <> ''sa''' + CHAR (10) + 'And P.name Not Like ''##%'' and p.name not like ''NT SERVICE\%''' + CHAR (10) + 'And CharIndex(''' + @Machine + '\'', P.name) = 0;';

INSERT INTO @Logins ( NAME
                    , SID
                    , IsDisabled
                    , Type
                    , PasswordHash)
    EXEC sp_executesql @ SQL;

-- Get all roles from principal server
SET @ SQL = 'Select RoleP.name, LoginP.name' + CHAR (10) + 'From ' + QUOTENAME(@PartnerServer) + '.master.sys.server_role_members RM' + CHAR (10) + 'Inner Join ' + QUOTENAME(@PartnerServer) + '.master.sys.server_principals RoleP' + CHAR (10) + CHAR (9) + 'On RoleP.principal_id = RM.role_principal_id' + CHAR (10) + 'Inner Join ' + QUOTENAME(@PartnerServer) + '.master.sys.server_principals LoginP' + CHAR (10) + CHAR (9) + 'On LoginP.principal_id = RM.member_principal_id' + CHAR (10) + 'Where LoginP.type In (''U'', ''G'', ''S'')' + CHAR (10) + 'And LoginP.name <> ''sa''' + CHAR (10) + 'And LoginP.name Not Like ''##%'' and LoginP.name not like ''NT Service\%''' + CHAR (10) + 'And RoleP.type = ''R''' + CHAR (10) + 'And CharIndex(''' + @Machine + '\'', LoginP.name) = 0;';

INSERT INTO @Roles ( RoleName
                   , LoginName)
    EXEC sp_executesql @ SQL;

-- Get all explicitly granted permissions
SET @ SQL = 'Select P.name Collate database_default,' + CHAR (10) + 'SP.state_desc, SP.permission_name, SP.class, SP.class_desc, SP.major_id,' + CHAR (10) + 'SubP.name Collate database_default,' + CHAR (10) + 'SubEP.name Collate database_default' + CHAR (10) + 'From ' + QUOTENAME(@PartnerServer) + '.master.sys.server_principals P' + CHAR (10) + 'Inner Join ' + QUOTENAME(@PartnerServer) + '.master.sys.server_permissions SP' + CHAR (10) + CHAR (9) + 'On SP.grantee_principal_id = P.principal_id' + CHAR (10) + 'Left Join ' + QUOTENAME(@PartnerServer) + '.master.sys.server_principals SubP' + CHAR (10) + CHAR (9) + 'On SubP.principal_id = SP.major_id And SP.class = 101' + CHAR (10) + 'Left Join ' + QUOTENAME(@PartnerServer) + '.master.sys.endpoints SubEP' + CHAR (10) + CHAR (9) + 'On SubEP.endpoint_id = SP.major_id And SP.class = 105' + CHAR (10) + 'Where P.type In (''U'', ''G'', ''S'')' + CHAR (10) + 'And P.name <> ''sa''' + CHAR (10) + 'And P.name Not Like ''##%'' and p.name not like ''NT Service\%''' + CHAR (10) + 'And CharIndex(''' + @Machine + '\'', P.name) = 0;'

INSERT INTO @Perms ( LoginName
                   , PermState
                   , PermName
                   , Class
                   , ClassDesc
                   , MajorID
                   , SubLoginName
                   , SubEndPointName)
    EXEC sp_executesql @ SQL;

SELECT @MaxID = MAX(LoginID)
     , @CurrID = 1
FROM @Logins;

WHILE @CurrID <= @MaxID
BEGIN
SELECT @LoginName = NAME
     , @IsDisabled = IsDisabled
     , @Type = [Type]
     , @SID = [SID]
     , @PasswordHash = PasswordHash
FROM @Logins
WHERE LoginID = @CurrID;

IF NOT EXISTS (
SELECT 1
FROM sys.server_principals
WHERE NAME = @LoginName
)
BEGIN
SET @ SQL = 'Create Login ' + QUOTENAME(@LoginName)
    IF @ Type IN ('U','G')
BEGIN
SET @ SQL = @ SQL + ' From Windows;'
END
    ELSE
BEGIN
SET @PasswordHashString = '0x' + CAST ('' AS XML).value('xs:hexBinary(sql:variable("@PasswordHash"))', 'nvarchar(300)');
SET @ SQL = @ SQL + ' With Password = ' + @PasswordHashString + ' HASHED, ';
SET @SIDString = '0x' + CAST ('' AS XML).value('xs:hexBinary(sql:variable("@SID"))', 'nvarchar(100)');
SET @ SQL = @ SQL + 'SID = ' + @SIDString + ';';
END IF @Debug = 0
BEGIN
BEGIN
TRY
EXEC sp_executesql @SQL;
END TRY

BEGIN
CATCH
SET @ErrNumber = ERROR_NUMBER();
SET @ErrSeverity = ERROR_SEVERITY();
SET @ErrState = ERROR_STATE();
SET @ErrProcedure = ERROR_PROCEDURE();
SET @ErrLine = ERROR_LINE();
SET @ErrMsg = ERROR_MESSAGE();

RAISERROR
    (@ErrMsg,1,1);
END CATCH
END
    ELSE
BEGIN
PRINT @SQL;
END IF @IsDisabled = 1
BEGIN
SET @ SQL = 'Alter Login ' + QUOTENAME(@LoginName) + ' Disable;'
    IF @ Debug = 0
BEGIN
BEGIN
TRY
EXEC sp_executesql @SQL;
END TRY

BEGIN
CATCH
SET @ErrNumber = ERROR_NUMBER();
SET @ErrSeverity = ERROR_SEVERITY();
SET @ErrState = ERROR_STATE();
SET @ErrProcedure = ERROR_PROCEDURE();
SET @ErrLine = ERROR_LINE();
SET @ErrMsg = ERROR_MESSAGE();

RAISERROR
    (@ErrMsg,1,1);
END CATCH
END
    ELSE
BEGIN
PRINT @SQL;
END
END
END

SET @CurrID = @CurrID + 1;
END

SELECT @MaxID = MAX(RoleID)
     , @CurrID = 1
FROM @Roles;

WHILE @CurrID <= @MaxID
BEGIN
SELECT @LoginName = LoginName
     , @RoleName = RoleName
FROM @Roles
WHERE RoleID = @CurrID;

IF NOT EXISTS (
SELECT 1
FROM sys.server_role_members RM
INNER JOIN sys.server_principals RoleP ON RoleP.principal_id = RM.role_principal_id
INNER JOIN sys.server_principals LoginP ON LoginP.principal_id = RM.member_principal_id
WHERE LoginP.type IN (
'U'
,'G'
,'S'
)
AND RoleP.type = 'R'
AND RoleP.NAME = @RoleName
AND LoginP.NAME = @LoginName
)
BEGIN
SET @ SQL = 'alter server role ' + QUOTENAME(@RoleName) + ' add member ' + QUOTENAME(@LoginName)
    IF @ Debug = 0
    EXEC sp_executesql @ SQL
    ELSE
    PRINT @ SQL
END

SET @CurrID = @CurrID + 1;
END

-- Explicitly granted permissions - bug fixes below
declare
@SubEndpointName sysname -- Added
SELECT @MaxID = MAX(PermID)
     , @CurrID = 1
FROM @Perms;

WHILE @CurrID <= @MaxID
BEGIN
SELECT @PermState = PermState
     , @PermName = PermName
     , @Class = Class
     , @LoginName = LoginName
     , @MajorID = MajorID
     , @SubEndpointName = SubEndPointName -- Added
     , @SQL = PermState + SPACE(1) + PermName + SPACE(1) + CASE Class
                                                               WHEN 101
                                                                   THEN 'On Login::' + QUOTENAME(SubLoginName)
                                                               WHEN 105
                                                                   THEN 'On ' + ClassDesc + '::' + QUOTENAME(SubEndPointName)
                                                               ELSE ''
    END + ' To ' + QUOTENAME(LoginName) + ';'
FROM @Perms
WHERE PermID = @CurrID;

IF NOT EXISTS (
SELECT 1
FROM sys.server_principals P
INNER JOIN sys.server_permissions SP ON SP.grantee_principal_id = P.principal_id
LEFT JOIN sys.endpoints SEP on SEP.endpoint_id = SP.major_id --Added
WHERE SP.state_desc = @PermState
AND SP.permission_name = @PermName
AND SP.class = @Class
AND P.NAME = @LoginName
--AND SP.major_id = @MajorID -- Original line commented out
AND (SP.major_id = @MajorID or SEP.name = @SubEndpointName) -- Added OR condition
)
BEGIN
IF @Debug = 0
BEGIN
BEGIN
TRY
EXEC sp_executesql @SQL;
END TRY

BEGIN
CATCH
SET @ErrNumber = ERROR_NUMBER();
SET @ErrSeverity = ERROR_SEVERITY();
SET @ErrState = ERROR_STATE();
SET @ErrProcedure = ERROR_PROCEDURE();
SET @ErrLine = ERROR_LINE();
SET @ErrMsg = ERROR_MESSAGE();
RAISERROR
    (@ErrMsg,1,1);
END CATCH
END
    ELSE
BEGIN
PRINT @SQL;
END
END

SET @CurrID = @CurrID + 1;
END

SET NOCOUNT OFF;

GO
