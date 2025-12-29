CREATE PROCEDURE sp_KullaniciEkle--
    -- Dýþarýdan (Python'dan) gelecek parametreler
    @KullaniciAdi NVARCHAR(50),
	@Ad NVARCHAR(50),
    @Soyad NVARCHAR(50),
    @Sifre NVARCHAR(255),     -- HASH'li þifre buraya gelecek
    @Departman NVARCHAR(100), -- Veya ID kullanýyorsan INT
	@Eposta NVARCHAR(100)
AS
BEGIN
    -- NOCOUNT ON: "1 satýr etkilendi" mesajýný gizler, performansý artýrýr.
    SET NOCOUNT ON;

    -- Kullanýcý adý daha önce alýnmýþ mý
    IF EXISTS (SELECT 1 FROM Users WHERE UserName = @KullaniciAdi)
    BEGIN
        -- Hata fýrlat
        RAISERROR('Bu kullanýcý adý zaten kullanýlýyor.', 16, 1);
        RETURN;
    END
    -- Kayýt Ýþlemi
    INSERT INTO Users (UserName,Name_,Surname_,PasswordHash,Dept_id,e_mail,role_,CreateDate,AccountStatus_id,is_on_leave,access_request_pending)
    VALUES (@KullaniciAdi, @Ad, @Soyad, @Sifre, @Departman, @Eposta, 0, GETDATE(), 3, 0, 1)

	SELECT CAST(SCOPE_IDENTITY() AS INT);
END
GO

CREATE PROCEDURE sp_KullaniciSorgula--
	@Eposta NVARCHAR(100)
AS
BEGIN
	SET NOCOUNT ON;
	-- Kullanýcýyý E-Posta adresine göre bul ve tüm bilgileri getir
    SELECT 
        UserName,        -- Session için lazým
        Name_,          -- Session için lazým
        Surname_,       -- Session için lazým
        role_,          -- Yönlendirme (Admin/User) için lazým
        PasswordHash,   -- Python'da kontrol etmek için lazým
		AccountStatus_id
    FROM Users 
    WHERE e_mail = @Eposta
END
GO

CREATE PROCEDURE sp_KullaniciGuncelle--
	@username NVARCHAR(50),
	@YeniAd NVARCHAR(50)=NULL,
    @YeniSoyad NVARCHAR(50)=NULL,
    @YeniEmail NVARCHAR(100)=NULL,
    @YeniDepartmanID INT =NULL,-- Departman tablosundan ID gelir
	@Erisim_izni BIT =NULL
AS
BEGIN
	SET NOCOUNT ON;

	-- Kullanýcý var mý diye son bir kontrol (Güvenlik)
    IF NOT EXISTS (SELECT 1 FROM Users WHERE UserName = @username)
    BEGIN
        RAISERROR('Güncellenecek kullanýcý bulunamadý!', 16, 1);
        RETURN;
    END

	UPDATE Users
    SET Name_ = ISNULL(@YeniAd,Name_),
        Surname_ = ISNULL(@YeniSoyad,Surname_),
        e_mail = ISNULL(@YeniEmail,e_mail),
        Dept_id = ISNULL(@YeniDepartmanID, Dept_id),
		access_request_pending = ISNULL(@Erisim_izni,access_request_pending)
	WHERE UserName = @username
END
GO

CREATE PROCEDURE sp_KullaniciIdGetir --
@username NVARCHAR(50)
AS
BEGIN
	DECLARE @Userid INT

	SELECT @Userid=UserId FROM Users WHERE UserName=@username
	SELECT @Userid AS UserId;
END

CREATE Procedure sp_StokGuncelle --
@productId INT,
@userId INT, 
@transactionType BIT,
@quantity INT,
@transDate DATETIME,
@aciklama VARCHAR(MAX)
AS
BEGIN
	SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Products WHERE ProductId = @productId)

    BEGIN
        RAISERROR('Ürün bulunamadý!', 16, 1);
        RETURN;
    END

    INSERT INTO Transactions(Product_id,User_id_,TransactionType,Amount,TransactionDate,Note)
	VALUES(@productId, @userId, @transactionType, @quantity, @transDate, @aciklama)
END
GO

--Tabloda ekisiklik farkedildi ve müdahale edildi
ALTER TABLE Maintenance
ADD QuantityOnMaintenance DECIMAL(18,2)

CREATE PROCEDURE sp_BakimdakiUrunler --
@statusID INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT M.MaintenanceId, p.ProductName, p.ProductCode, p.Quantity, S.mStatusName, M.QuantityOnMaintenance ,M.MaintenanceStartDate ,p.ImagePath 
	FROM (SELECT MaintenanceId, MaintenanceStartDate, Product_id, StatusAfter_id, QuantityOnMaintenance FROM Maintenance 
			WHERE (StatusAfter_id NOT IN (7, 9,10)) AND (@statusID=0 OR StatusAfter_id=@statusID)) 
			AS M
	INNER JOIN Products p ON M.Product_id=p.ProductId
	INNER JOIN MaintenanceStatus S ON M.StatusAfter_id=S.mStatusId
	
END
GO

CREATE PROCEDURE sp_BakimdaOlamayanUrunler --
AS
BEGIN
	SET NOCOUNT ON;

	SELECT P.ProductId, P.ProductName, P.ProductCode, P.Quantity, S.pStatusName, P.ImagePath
	FROM Products P
	INNER JOIN ProductStatus S ON P.Status_id=S.pStatusId
	WHERE P.Status_id IN (1,2,3) AND P.Quantity > 0
	
END
GO

CREATE PROCEDURE sp_BakimDetaylariniGetir--
@maintenance_id INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT  M.Product_id, P.ProductName, P.ProductCode, P.Quantity, M.QuantityOnMaintenance, S.mStatusName, M.MaintenanceStartDate, M.MaintenanceId,
	M.StatusAfter_id, L.LocationName, M.Description_,
	(SELECT ISNULL(SUM(QuantityOnMaintenance), 0) FROM Maintenance WHERE Product_id = M.Product_id AND StatusAfter_id NOT IN (7, 9,10)),
	P.ImagePath
	FROM (SELECT MaintenanceId, Product_id, StatusAfter_id, Description_, MaintenanceStartDate, QuantityOnMaintenance FROM Maintenance WHERE MaintenanceId=@maintenance_id) AS M
	INNER JOIN Products P ON P.ProductId=M.Product_id
	INNER JOIN MaintenanceStatus S ON S.mStatusId=M.StatusAfter_id
	LEFT JOIN WareHouseLocation L ON P.Location_id=L.LocationId
END
GO

CREATE PROCEDURE sp_UrunGecmisiniGetir --
@product_id INT
AS
BEGIN
    SET NOCOUNT ON;

	SELECT CONCAT(U.Name_, ' ', U.Surname_) AS NameSurname, M.MaintenanceStartDate, M.MaintenanceEndDate, M.Description_, S.mStatusName, M.QuantityOnMaintenance
    FROM (SELECT PerformedByUser_id, 
                StatusAfter_id, 
                MaintenanceStartDate, 
                MaintenanceEndDate, 
                Description_, 
                QuantityOnMaintenance
            FROM Maintenance 
            WHERE Product_id = @product_id
        ) AS M
    INNER JOIN MaintenanceStatus S ON M.StatusAfter_id=S.mStatusId
    LEFT JOIN Users U ON M.PerformedByUser_id=U.UserId
    ORDER BY M.MaintenanceStartDate DESC
END
GO


CREATE PROCEDURE sp_Rapor_Urunler --
@kategory_id INT = NULL,
@adet DECIMAL(18,2)= NULL
AS
BEGIN
	SET NOCOUNT ON;

	SELECT P.ImagePath, P.ProductCode, P.ProductName, C.CategoryName, CONCAT(CAST(P.Quantity AS INT),' ', U.UnitName), P.EntryDate,
	P.WarrantyEndDate, W.LocationName, S.pStatusName, Us.UserName
	FROM (SELECT ProductId,ProductName,ProductCode, Quantity, EntryDate, WarrantyEndDate, 
                ImagePath, Category_id, Unit_id, Location_id, Status_id, AddedByUser_id
            FROM Products
            WHERE 
                (@kategory_id IS NULL OR Category_id = @kategory_id)
                AND
                (@adet IS NULL OR Quantity <= @adet)
        ) AS P
	INNER JOIN ProductCategory C ON P.Category_id=C.CategoryId
	INNER JOIN ProductUnit U ON P.Unit_id=U.UnitId
	INNER JOIN WareHouseLocation W ON P.Location_id=W.LocationId
	LEFT JOIN ProductStatus S ON P.Status_id=S.pStatusId
	INNER JOIN Users Us ON P.AddedByUser_id=Us.UserId

END
GO

CREATE PROCEDURE sp_Rapor_Islemler --
@Tarih DATETIME =NULL,
@IslemTipi BIT =NULL
AS
BEGIN
	SELECT P.ImagePath, T.TransactionDate, P.ProductCode, P.ProductName, U.UserName, 
		CASE 
            WHEN T.TransactionType = 1 THEN 'Giriþ'
            ELSE 'Çýkýþ' 
        END AS IslemTuruYazisi,
		T.Amount, T.Note
	FROM (SELECT TransactionDate,Product_id,User_id_,TransactionType,Amount,Note
		FROM Transactions
		WHERE (@Tarih IS NULL OR TransactionDate >= @Tarih)
			AND
			(@IslemTipi IS NULL OR TransactionType = @IslemTipi)
		)AS T
	INNER JOIN Products P ON T.Product_id=P.ProductId
	INNER JOIN Users U ON T.User_id_=U.UserId
END
GO

CREATE PROCEDURE sp_Rapor_Bakimlar --
@statusID INT = NULL,
@Tarih DATETIME = NULL
AS
BEGIN
	SELECT P.ImagePath, P.ProductName, CONCAT(CAST(M.QuantityOnMaintenance AS INT),' ', Un.UnitName), M.MaintenanceStartDate, M.MaintenanceEndDate, M.Description_, S.mStatusName, U.UserName
	FROM (SELECT Product_id, MaintenanceStartDate, MaintenanceEndDate, Description_, StatusAfter_id, PerformedByUser_id, QuantityOnMaintenance
			FROM Maintenance
			WHERE (@statusID IS NULL OR StatusAfter_id = @statusID)
				AND
				(@Tarih IS NULL OR MaintenanceStartDate >= @Tarih)
			)AS M
	INNER JOIN Products P ON M.Product_id=P.ProductId
	LEFT JOIN MaintenanceStatus S ON M.StatusAfter_id=S.mStatusId
	INNER JOIN Users U ON M.PerformedByUser_id=U.UserId
	LEFT JOIN ProductUnit Un ON P.Unit_id=Un.UnitId
	ORDER BY M.MaintenanceStartDate DESC
END
GO

CREATE PROCEDURE sp_Rapor_Loglar --
@Tarih DATETIME = NULL
AS
BEGIN
	SELECT L.LogId, A.ActionName, A.Description_, ActionDate, U.UserName, CONCAT(U.Name_ ,' ',U.Surname_) AS NameSurname, 
			D.DepartmentName, T.TableName
	FROM (SELECT LogId, User_id_, TableAffected_id, Action_id, ActionDate 
			FROM Logs
			WHERE (@Tarih IS NULL OR ActionDate>=@Tarih)
		)AS L
	INNER JOIN LogActions A ON L.Action_id=A.ActionId
	LEFT JOIN Users U ON L.User_id_=U.UserId
	LEFT JOIN UserDepartment D ON U.Dept_id=D.DepartmentId
	LEFT JOIN TableName T ON L.TableAffected_id=T.TableId
END
GO

ALTER PROCEDURE sp_urunEkle--
@p_name VARCHAR(50),
@p_code VARCHAR(30),
@p_category_id INT,
@p_quantity DECIMAL(18,4),
@p_unit_id INT,
@p_entryDate DATETIME,
@p_warrantyendDate DATE,
@p_location_id INT,
@p_status_id INT,
@p_user_id INT,
@p_imagePath NVARCHAR(255)
AS
BEGIN
	SET NOCOUNT ON;
	IF EXISTS (SELECT 1 FROM Products WHERE ProductCode = @p_code)
    BEGIN
        -- Hata fýrlat
        RAISERROR('Bu ürün zaten envanterde var kullanýlýyor.', 16, 1);
        RETURN;
    END 
	INSERT INTO 
	Products(ProductName,ProductCode,Category_id,Quantity,Unit_id,EntryDate,WarrantyEndDate,Location_id,Status_id,AddedByUser_id,ImagePath)
	VALUES(@p_name,@p_code,@p_category_id,@p_quantity,@p_unit_id,@p_entryDate,@p_warrantyendDate,@p_location_id,@p_status_id,@p_user_id,@p_imagePath)
	SELECT CAST(SCOPE_IDENTITY() AS INT);
END
GO


ALTER PROCEDURE sp_UrunleriGetir--
@UrunId INT = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SELECT P.ProductId, P.ProductName, P.ProductCode, CONCAT(CAST(P.Quantity AS INT),' ', U.UnitName), P.EntryDate, P.WarrantyEndDate, L.LocationName, S.pStatusName, C.CategoryId, L.LocationId,S.pStatusId, P.ImagePath
	FROM Products P
	INNER JOIN ProductUnit U ON P.Unit_id=U.UnitId
	INNER JOIN WareHouseLocation L ON P.Location_id=L.LocationId
	INNER JOIN ProductStatus S ON P.Status_id=S.pStatusId
	INNER JOIN ProductCategory C ON P.Category_id=C.CategoryId
	WHERE (@UrunId IS NULL OR P.ProductId=@UrunId)
END
GO

CREATE PROCEDURE sp_urunGuncelle--
@HedefUrunId INT=NULL, 
@p_name VARCHAR(50)=NULL,
@p_category_id INT=NULL,
@p_unit_id INT=NULL,
@p_warrantyendDate DATE=NULL,
@p_location_id INT=NULL,
@p_status_id INT=NULL,
@p_imagePath NVARCHAR(255)=NULL
AS
BEGIN
	SET NOCOUNT ON;
	UPDATE Products
	SET
	ProductName = ISNULL(@p_name,ProductName),
	Category_id = ISNULL(@p_category_id, Category_id),
    Unit_id = ISNULL(@p_unit_id, Unit_id),
    WarrantyEndDate = ISNULL(@p_warrantyendDate, WarrantyEndDate),
    Location_id = ISNULL(@p_location_id, Location_id),
    Status_id = ISNULL(@p_status_id, Status_id),
	ImagePath = ISNULL(@p_imagePath, ImagePath)
	WHERE ProductId = @HedefUrunId
END
GO

CREATE PROCEDURE sp_Urun_Sil--
@SilinecekUrun_id INT
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRANSACTION -- Ýþlemi baþlat

    BEGIN TRY
		--Önce bu ürünün hareketlerini silinir
		DELETE FROM Transactions WHERE Product_id =  @SilinecekUrun_id
		DELETE FROM Maintenance WHERE Product_id =  @SilinecekUrun_id
		--Sonra ürünün kendisini silinir
		DELETE FROM Products WHERE ProductId = @SilinecekUrun_id

		COMMIT TRANSACTION -- Hata yoksa her þeyi onayla
    END TRY
	--Hata Varsa:
    BEGIN CATCH
        -- Eðer yukarýda bir hata olursa buraya düþer
        ROLLBACK TRANSACTION -- Yapýlan tüm silmeleri geri al.
        -- Hatayý kullanýcýya bildir
        THROW; 
    END CATCH
END
GO


CREATE PROCEDURE sp_KullanicilariGetir--
@HesapDurumu INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT Name_, Surname_,UserName, e_mail, D.DepartmentName, 
			CASE 
				WHEN U.role_ = 1 THEN 'Admin'
				ELSE 'User' 
			END AS Rol,
			CASE 
				WHEN U.access_request_pending = 1 THEN 'Ýstek VAR'
				ELSE 'Ýstek YOK' 
			END AS IstekDuruumu
			
	FROM Users U
	INNER JOIN UserDepartment D ON U.Dept_id=D.DepartmentId
	WHERE AccountStatus_id=@HesapDurumu
END
GO


ALTER PROCEDURE sp_TumKullanicilariGetir--
AS
BEGIN
	SET NOCOUNT ON;

	SELECT UserId, Name_, Surname_,UserName, D.DepartmentName, 
			CASE 
				WHEN U.role_ = 1 THEN 'Admin'
				ELSE 'User' 
			END AS Rol,
			S.aStatusName
	FROM Users U
	INNER JOIN UserDepartment D ON U.Dept_id=D.DepartmentId
	INNER JOIN AccountStatus S ON U.AccountStatus_id=S.aStatusId
END
GO

CREATE PROCEDURE sp_KullaniciAl--
@user_id INT
AS
BEGIN
	SET NOCOUNT ON;
	SELECT  Name_, Surname_,UserName, e_mail, Dept_id, role_, CreateDate, AccountStatus_id, is_on_leave, access_request_pending
	FROM Users 
	WHERE UserId=@user_id
END
GO

CREATE PROCEDURE sp_KullaiciBilgileriniGuncelle
@user_id INT,
@dept_id INT = NULL,
@role_ BIT = NULL,
@accountStatus_id INT = NULL,
@on_leave BIT= NULL,
@requestpending BIT =NULL
AS
BEGIN
	UPDATE Users
	SET
		Dept_id = ISNULL(@dept_id,Dept_id),
		role_ = ISNULL(@role_, role_),
		AccountStatus_id = ISNULL(@accountStatus_id, AccountStatus_id),
		is_on_leave = ISNULL(@on_leave, is_on_leave),
		access_request_pending = ISNULL(@requestpending,access_request_pending)
	WHERE UserId=@user_id
END
GO

CREATE PROCEDURE sp_VerileriLogla--
@userId INT,
@actionId INT,
@tableId INT = NULL,
@recordId INT = NULL
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRANSACTION -- Ýþlemi baþlat

    BEGIN TRY
	INSERT Logs (User_id_,Action_id,TableAffected_id,record_id,ActionDate)
	VALUES (@userId,@actionId,@tableId,@recordId,GETDATE())

	COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
        -- Eðer yukarýda bir hata olursa buraya düþer
        ROLLBACK TRANSACTION -- Yapýlan tüm silmeleri geri al.
        -- Hatayý kullanýcýya bildir
        THROW; 
    END CATCH
END
GO

CREATE PROCEDURE sp_sifreDegistir--
@user_id INT,
@kullanici_adi VARCHAR(50),
@e_mail VARCHAR(100),
@yeniSifre VARCHAR(256)
AS
BEGIN
	SET NOCOUNT ON;
	UPDATE Users
	SET PasswordHash=@yeniSifre
	WHERE UserId=@user_id and UserName=@kullanici_adi and e_mail=@e_mail
END
GO