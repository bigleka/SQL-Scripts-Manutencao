/*
monta a estrutura de dependencias das tabelas de um banco de dados SQL Server
*/

WITH dependencies AS (
    SELECT 
        FK.TABLE_NAME AS Obj,
        PK.TABLE_NAME AS Depends
    FROM 
        INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS C
    INNER JOIN 
        INFORMATION_SCHEMA.TABLE_CONSTRAINTS FK ON C.CONSTRAINT_NAME = FK.CONSTRAINT_NAME
    INNER JOIN 
        INFORMATION_SCHEMA.TABLE_CONSTRAINTS PK ON C.UNIQUE_CONSTRAINT_NAME = PK.CONSTRAINT_NAME
),
no_dependencies AS (
    SELECT 
        name AS Obj
    FROM 
        sys.objects
    WHERE 
        name NOT IN (SELECT Obj FROM dependencies)
        AND type = 'U'
),
recursiv AS (
    SELECT 
        Obj AS [Table],
        CAST('' AS VARCHAR(MAX)) AS DependsON,
        0 AS LVL
    FROM 
        no_dependencies

    UNION ALL

    SELECT 
        d.Obj AS [Table],
        CAST(IIF(r.LVL > 0, r.DependsON + ' > ', '') + d.Depends AS VARCHAR(MAX)),
        r.LVL + 1 AS LVL
    FROM 
        dependencies d
    INNER JOIN 
        recursiv r ON d.Depends = r.[Table]
    WHERE 
        r.LVL < 10 -- Limite de recursão para evitar loops infinitos
)
SELECT DISTINCT 
    SCHEMA_NAME(O.schema_id) AS [TableSchema],
    R.[Table],
    R.DependsON,
    R.LVL
FROM 
    recursiv R
INNER JOIN 
    sys.objects O ON R.[Table] = O.name
ORDER BY 
    R.LVL,
    R.[Table]
OPTION (MAXRECURSION 10); -- Limite de recursão
