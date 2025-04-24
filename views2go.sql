/*
este script gera os comando para a criação de views para ajudar na extração de dados onde precisa ser removida alguma coluna ou convertido algum tipo de dado
Exemplo: este script ignora a coluna rowversion e executa a conversão de colunas bit para int (devido a problema de ferramentas de extração considerar bit como boleano 
ou precisar executar conversão explicita na importação de dados)
*/
-- Criar uma tabela temporária para armazenar as informações das colunas
CREATE TABLE #ColumnList (
    TableName NVARCHAR(255),
    ColumnName NVARCHAR(255)
)

-- Inicializar variáveis
DECLARE @TableName NVARCHAR(255)
DECLARE @ColumnName NVARCHAR(255)
DECLARE @SQL NVARCHAR(MAX)

-- Cursor para percorrer as tabelas de usuário
DECLARE table_cursor CURSOR FOR
select name from sys.objects v1
where v1.type in ('U')
and v1.is_ms_shipped = 0
and name not in (select REPLACE(name,'view2go_','') from sys.objects where type = 'V')

OPEN table_cursor

FETCH NEXT FROM table_cursor INTO @TableName

-- Loop através das tabelas de usuário
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Cursor para percorrer as colunas de cada tabela
    DECLARE column_cursor CURSOR FOR
    SELECT COLUMN_NAME
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = @TableName
	and COLUMN_NAME NOT IN ('coluna_rowversion')

    OPEN column_cursor

    FETCH NEXT FROM column_cursor INTO @ColumnName

    -- Construir o comando SELECT para a tabela atual
    SET @SQL = 'create view view2go_' + @TableName + ' AS
	SELECT '

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName AND COLUMN_NAME = @ColumnName AND DATA_TYPE = 'bit')
        BEGIN
            -- Se a coluna for do tipo bit, adicione um CAST para int
            SET @SQL = @SQL + 'CAST(' + @ColumnName + ' AS int) AS ' + @ColumnName + ', '
        END
        ELSE
        BEGIN
            SET @SQL = @SQL + @ColumnName + ', '
        END

        FETCH NEXT FROM column_cursor INTO @ColumnName
    END

    -- Remover a última vírgula e espaço
    SET @SQL = LEFT(@SQL, LEN(@SQL) - 1)

    SET @SQL = @SQL + ' FROM ' + @TableName + ' with (nolock) 
	GO'

    PRINT @SQL -- Exibir o comando SELECT para a tabela atual (opcional)

    -- Fechar e desaloca o cursor das colunas da tabela atual
    CLOSE column_cursor
    DEALLOCATE column_cursor

    FETCH NEXT FROM table_cursor INTO @TableName
END

-- Fechar e desaloca o cursor das tabelas de usuário
CLOSE table_cursor
DEALLOCATE table_cursor

-- Remover a tabela temporária
DROP TABLE #ColumnList
