CREATE TRIGGER trg_transactionProcessing --
ON Transactions
AFTER INSERT
AS
BEGIN
	UPDATE P
	SET P.Quantity =
		CASE 
			WHEN T.TransactionType = 1 THEN P.Quantity + T.Amount
			WHEN T.TransactionType = 0 THEN P.Quantity - T.Amount
		END
	FROM Products P
	INNER JOIN Inserted T ON P.ProductId=T.Product_id

	IF EXISTS (SELECT 1 FROM Products WHERE Quantity < 0)
	BEGIN
		RAISERROR('Hata: Stok negatif olamaz! Ýþlem iptal edildi.', 16, 1);
		ROLLBACK TRANSACTION; -- Ýþlemi tamamen geri al
	END
END

--Durum Güncellemesi ve Ürünlerin bakýmýnýn tamamlanmasýnda güncellenir
CREATE TRIGGER trg_updateStatus --
ON Maintenance
AFTER UPDATE
AS
BEGIN
	SET NOCOUNT ON;

	UPDATE P
	SET P.Status_id =
		CASE 
			WHEN T.StatusAfter_id IN (1, 3, 5) AND P.Quantity = 0 THEN 4
			WHEN T.StatusAfter_id = 2 OR T.StatusAfter_id=8 THEN 6
			WHEN T.StatusAfter_id = 4  THEN 7
			WHEN T.StatusAfter_id = 6 THEN 5
			WHEN T.StatusAfter_id = 7 OR T.StatusAfter_id=9 THEN 1
			WHEN T.StatusAfter_id = 10 THEN 8
			ELSE P.Status_id
		END,
		P.Quantity = P.Quantity + 
            CASE 
                WHEN T.StatusAfter_id IN (7, 9) AND d.StatusAfter_id NOT IN (7, 9) 
                THEN T.QuantityOnMaintenance
                -- Aksi halde stoða dokunma
                ELSE 0
            END
	FROM Products P
	INNER JOIN Inserted T ON P.ProductId=T.Product_id
	INNER JOIN deleted d ON T.MaintenanceId = d.MaintenanceId

END
GO

--Arýza kaydý açýldýðýnda tetiklenir
CREATE TRIGGER trg_updateQuantity --
ON Maintenance
AFTER INSERT
AS
BEGIN
	UPDATE P
	SET P.Quantity =
		CASE
			WHEN M.StatusAfter_id IN (1,2,3,4,5,6,8,10) THEN P.Quantity - M.QuantityOnMaintenance
		ELSE P.Quantity
		END
	FROM Products P
	INNER JOIN Inserted M ON P.ProductId=M.Product_id
END
GO