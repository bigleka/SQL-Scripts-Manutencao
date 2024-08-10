ALTER PROCEDURE usp_SugerirNovaOrdemChavePrimaria
    @SchemaName NVARCHAR(128),
    @TableName NVARCHAR(128)
AS
BEGIN
	SET ARITHABORT OFF 
	SET ANSI_WARNINGS OFF
    DECLARE @ColumnName NVARCHAR(128);
    DECLARE @Sql NVARCHAR(MAX) = '';
    DECLARE @OrderSuggestions NVARCHAR(MAX) = '';
    DECLARE @DynamicSQL NVARCHAR(MAX);
    DECLARE @Densidade FLOAT;
    DECLARE @OrderTable TABLE (ColumnName NVARCHAR(128), Densidade FLOAT);
    DECLARE @CurrentOrder NVARCHAR(MAX) = '';

    -- Cursor para iterar sobre as colunas da chave primária
    DECLARE ColumnCursor CURSOR FOR
        SELECT COL_NAME(ic.object_id, ic.column_id) 
        FROM sys.indexes AS i 
        INNER JOIN sys.index_columns AS ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id 
        WHERE i.is_primary_key = 1 
        AND OBJECT_NAME(ic.object_id) = @TableName;

    OPEN ColumnCursor;
    FETCH NEXT FROM ColumnCursor INTO @ColumnName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Constrói e executa a consulta SQL dinâmica para calcular a densidade para cada coluna
        SET @DynamicSQL = 'SELECT @DensidadeOUT = (COUNT(DISTINCT ' + QUOTENAME(@ColumnName) + ') * 1.0 / COUNT(*)) FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName);
        EXEC sp_executesql @DynamicSQL, N'@DensidadeOUT FLOAT OUTPUT', @Densidade OUTPUT;

        -- Adiciona os resultados em uma tabela temporária
        INSERT INTO @OrderTable (ColumnName, Densidade) VALUES (@ColumnName, @Densidade);

        -- Constrói a ordem atual
        SET @CurrentOrder += @ColumnName + ', ';

        FETCH NEXT FROM ColumnCursor INTO @ColumnName;
    END

    CLOSE ColumnCursor;
    DEALLOCATE ColumnCursor;

    -- Remove a última vírgula e espaço da ordem atual
    IF LEN(@CurrentOrder) > 0
    BEGIN
        SET @CurrentOrder = LEFT(@CurrentOrder, LEN(@CurrentOrder) - 1);
    END

    -- Constrói a sugestão de ordem com base na densidade
    SELECT @OrderSuggestions += ColumnName + ', '
    FROM @OrderTable
    ORDER BY Densidade ASC, ColumnName;

    -- Remove a última vírgula e espaço
    IF LEN(@OrderSuggestions) > 0
    BEGIN
        SET @OrderSuggestions = LEFT(@OrderSuggestions, LEN(@OrderSuggestions) - 1);
    END

    -- Compara a ordem atual com a sugerida
    IF @CurrentOrder = @OrderSuggestions
    BEGIN
        SELECT @TableName as [Object], 'A ordem atual já é a melhor.' AS SuggestedOrder;
    END
    ELSE
    BEGIN
        -- Retorna a sugestão de ordem
        SELECT @TableName as [Object], @OrderSuggestions AS SuggestedOrder;
    END
END
