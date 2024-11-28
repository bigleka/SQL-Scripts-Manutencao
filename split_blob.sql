-- O objetivo desse conjunto de scripts é criar uma alternativa para armazenar Blobs no banco de dados sem ter que criar colunas varchar(max) nvarchar(max) etc.
-- ao invés da inserção ocorrer diretamente na tabela, a operação acontece por uma procedure que vai receber o objeto Blob, ela vai separar a operação em diversos
-- pedaços limitados pelo tamanho da coluna na tabela de registro e vai inserir esses pedaços da tabela segundo uma ordem sequencial
-- para reaver o registro remontado de uma forma utilizável, o select deve acontecer contra uma função que vai remontar o resultado para uma forma entendível.

-- Esse modelo se mostra vantajoso nos cenários onde, sem a necessidade de uma coluna Blob, podemos usar compressão de tabelas melhores, manutenção online de índices, etc.
-- Esse modelo acaba acarretando em um pensamento diferente quando trata-se de atualizar o registro Blob, uma vez que a limitante é o tamanho da coluna, o interessante fica
-- em marcar o registro como inativado e adicionar outro como ativo, ou apagar o anterior e inserir o novo registro

--Tabela exemplo:
CREATE TABLE Dados (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Sequencial INT NOT NULL,
    Parte VARCHAR(1000) NOT NULL,
    Identificador UNIQUEIDENTIFIER DEFAULT NEWID() -- ou você pode usar INT se preferir
);
--Aqui podemos colocar compressão Page, Row, ColumnStore

-- Procedure que vai fazer a separação do Blob
ALTER PROCEDURE dbo.InserirDados
    @dado NVARCHAR(MAX)
AS
BEGIN
    DECLARE @identificador UNIQUEIDENTIFIER = NEWID(); --UUID que vamos usar na função para recuperar o registro remontado
    DECLARE @tamanho_parte INT = 1000; -- um limitador baseado no tamanho da coluna da tabela Dados
    DECLARE @parte NVARCHAR(1000);
    DECLARE @sequencial INT = 1;

    WHILE LEN(@dado) > 0
    BEGIN
        SET @parte = LEFT(@dado, @tamanho_parte);
        SET @dado = SUBSTRING(@dado, @tamanho_parte + 1, LEN(@dado));

        INSERT INTO dados (sequencial, parte, identificador)
        VALUES (@sequencial, @parte, @identificador);

        SET @sequencial = @sequencial + 1;
    END
	Select @identificador
END;


-- Função para remontar os dados do Blob
CREATE FUNCTION dbo.ReconstruirDados(@identificador UNIQUEIDENTIFIER)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @resultado NVARCHAR(MAX);

    SELECT @resultado = (
        SELECT parte 
        FROM dados 
        WHERE identificador = @identificador 
        ORDER BY sequencial 
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)');

    RETURN @resultado;
END;
