INSERT INTO ProductCategory(CategoryName) VALUES 
('Elektronik ve Aviyonik'),
('Mühimmat ve Patlayýcýlar'),
('Silah Yedek Parçalarý'),
('Haberleþme ve Radar'),
('Zýrhlý Araç Parçalarý'),
('Optik ve Elektro-Optik'),
('KBRN Koruyucu Ekipman'),
('ÝHA Yer Sistemleri');

INSERT INTO ProductUnit (UnitName) VALUES 
('Adet'),           -- ID: 1
('Kutu'),           -- ID: 2
('Sandýk'),         -- ID: 3
('Kilogram'),       -- ID: 4
('Litre'),          -- ID: 5
('Metre'),          -- ID: 6
('Metrekare'),      -- ID: 7
('Takým/Set'),      -- ID: 8
('Varil'),          -- ID: 9
('Paket'),          -- ID: 10
('Palet');          -- ID: 11

ALTER TABLE WareHouseLocation
ADD LocationType NVARCHAR(50), -- Raf tipi (Raf, Palet vb.)
    Capacity INT DEFAULT 100;  -- Kapasite

INSERT INTO WareHouseLocation (LocationName, LocationType, Capacity) VALUES 
-- A BLOK (Elektronik ve Hassas)
('A-01-01', 'Raf (Küçük)', 50),
('A-01-02', 'Raf (Küçük)', 50),
('A-01-03', 'Raf (Küçük)', 50),

-- B BLOK (Aðýr Mühimmat)
('B-01-01', 'Palet Alaný', 500),
('B-01-02', 'Palet Alaný', 500),
('B-02-01', 'Aðýr Yük Rafý', 200),

-- C BLOK (KBRN - Özel)
('C-01-01', 'Kilitli Dolap', 20),
('C-01-02', 'Kilitli Dolap', 20),

-- D BLOK (Genel)
('D-01-01', 'Genel Raf', 150),
('D-01-02', 'Genel Raf', 150);

INSERT INTO ProductStatus (pStatusName) VALUES 
-- 1. KULLANILABÝLÝR DURUMLAR
('Faal / Operasyonel'),
('Yeni (Kullanýlmamýþ)'),
('Rezerve Edildi'),

-- 2. BAKIM & ONARIM DURUMLARI
('Bakýmda'),
('Arýzalý / Gayrifaal'),
('Kalibrasyon Bekliyor'),
('Eksik Parçalý'),

-- 3. HURDA & ÝMHA DURUMLARI
('HEK (Hurda)'),
('Kayýp / Çalýntý'),
('Kullaným Ömrü Dolmuþ');

INSERT INTO Products (
    ProductName, 
    ProductCode, 
    Category_id, 
    Quantity, 
    Unit_id, 
    EntryDate, 
    WarrantyEndDate, 
    Location_id, 
    Status_id, 
    AddedByUser_id
) 
VALUES 
('FPGA Geliþtirme Kartý (Askeri Tip)', 'ELK-001', 1, 50.0000, 1, GETDATE(), '2027-11-30', 1, 1, 1),
('Uçuþ Kontrol Bilgisayarý (FCC)', 'ELK-002', 1, 12.0000, 1, GETDATE(), '2028-11-30', 1, 1, 1),
('Yüksek Hýzlý Veri Yolu Kablosu', 'ELK-003', 1, 200.0000, 6, GETDATE(), '2030-11-30', 1, 1, 1),
('120mm Tank Mühimmatý (Eðitim)', 'MHM-101', 2, 500.0000, 1, GETDATE(), '2035-11-30', 4, 1, 1),
('MK-82 Genel Maksat Bombasý Kiti', 'MHM-102', 2, 45.0000, 8, GETDATE(), '2035-11-30', 4, 1, 1),
('5.56mm Fiþek (Sandýk)', 'MHM-103', 2, 1000.0000, 3, GETDATE(), '2035-11-30', 4, 1, 1),
('HK-33 Ýcra Yayý', 'SLH-201', 3, 150.0000, 1, GETDATE(), '2030-11-30', 10, 1, 1),
('MPT-76 Gaz Pistonu', 'SLH-202', 3, 80.0000, 11, GETDATE(), '2030-11-30', 10, 1, 1),
('Kanas Dürbün Montaj Ayaðý', 'SLH-203', 3, 60.0000, 8, GETDATE(), '2030-11-30', 10, 1, 1),
('Aselsan 9661 Telsiz Bataryasý', 'HBR-301', 4, 300.0000, 1, GETDATE(), '2027-11-30', 2, 1, 1),
('Kýsa Dalga Anten Seti', 'HBR-302', 4, 25.0000, 8, GETDATE(), '2030-11-30', 2, 1, 1),
('Sinyal Karýþtýrýcý (Jammer) Modülü', 'HBR-303', 4, 10.0000, 1, GETDATE(), '2027-11-30', 2, 1, 1),
('Altay Tanký Palet Pimi', 'ARC-401', 5, 2000.0000, 1, GETDATE(), '2030-11-30', 6, 1, 1),
('Kirpi Run-Flat Lastik', 'ARC-402', 5, 40.0000, 1, GETDATE(), '2028-11-30', 6, 1, 1),
('Hidrolik Kule Motoru', 'ARC-403', 5, 5.0000, 1, GETDATE(), '2027-11-30', 6, 1, 1),
('Termal Kamera Lensi (Soðutmasýz)', 'OPT-501', 6, 15.0000, 1, GETDATE(), '2027-11-30', 3, 1, 1),
('Lazer Mesafe Ölçer', 'OPT-502', 6, 30.0000, 1, GETDATE(), '2027-11-30', 3, 1, 1),
('M50 Gaz Maskesi Filtresi', 'KBR-601', 7, 500.0000, 2, GETDATE(), '2030-11-30', 8, 1, 1),
('Tam Koruma Tulumu (Tip-3)', 'KBR-602', 7, 100.0000, 8, GETDATE(), '2030-11-30', 8, 1, 1),
('Telemetri Verici Modülü', 'IHA-701', 8, 20.0000, 1, GETDATE(), '2026-11-30', 3, 1, 1),
('Gimbal Sabitleme Aparatý', 'IHA-702', 8, 50.0000, 1, GETDATE(), '2027-11-30', 3, 1, 1);

INSERT INTO MaintenanceStatus (mStatusName) VALUES 
-- 1. BAÞLANGIÇ AÞAMASI
('Arýza Kaydý Açýldý'),      -- Ýlk kayýt aný
('Teknik Ýnceleme Bekliyor'), -- Teknisyen henüz bakmadý

-- 2. ÝÞLEM AÞAMASI
('Ýnceleniyor / Teþhis Aþamasýnda'), -- Þu an üzerinde çalýþýlýyor
('Yedek Parça Bekleniyor'),          -- Parça sipariþ edildi
('Onarým Devam Ediyor'),             -- Parça geldi, tamir sürüyor
('Dýþ Servise Gönderildi'),          -- Kurum içinde yapýlamadý, servise gitti

-- 3. SONUÇ AÞAMASI
('Onarým Tamamlandý'),       -- Tamir bitti, test edilecek
('Test Aþamasýnda'),         -- Kalite kontrol yapýlýyor
('Kullanýma Hazýr'),         -- Her þey bitti, depoya/sahaya dönebilir
('Hurdaya Ayrýldý (HEK)');   -- Tamir edilemedi

ALTER TABLE LogActions
ADD
Description_ NVARCHAR(100);

INSERT INTO LogActions (ActionName, Description_) VALUES 
--OTURUM VE GÜVENLÝK ÝÞLEMLERÝ
('Login', 'Kullanýcý sisteme giriþ yaptý'),
('Logout', 'Kullanýcý çýkýþ yaptý'),
('Failed Login', 'Hatalý þifre denemesi'),
('Register', 'Yeni kullanýcý kaydý oluþturuldu'),
('Password Change', 'Kullanýcý þifresini deðiþtirdi'),

--STOK VE ENVANTER ÝÞLEMLERÝ
('Stock In', 'Depoya ürün giriþi yapýldý'),
('Stock Out', 'Depodan ürün çýkýþý yapýldý'),
('Product Add', 'Sisteme yeni bir ürün tanýmlandý'),
('Product Update', 'Ürün bilgileri güncellendi'),
('Product Delete', 'Ürün sistemden silindi'),

--PROFÝL VE KULLANICI YÖNETÝMÝ
('Profile Update', 'Kullanýcý kendi profilini güncelledi'),
('User Update (Admin)', 'Admin tarafýndan kullanýcý bilgisi deðiþtirildi'),
('User Status Change', 'Kullanýcý pasife alýndý veya yetkisi deðiþti'),

--BAKIM VE ONARIM
('Maintenance Start', 'Ürün bakým sürecine alýndý'),
('Maintenance Finish', 'Ürün bakýmý tamamlandý'),
('Scrap Item', 'Ürün hurdaya ayrýldý (HEK)');

INSERT INTO TableName (TableName) VALUES 
--KULLANICI & YETKÝ TABLOLARI
('Users'),
('UserDepartment'),
('AccountStatus'),

--ÜRÜN & ENVANTER TABLOLARI
('Products'),
('ProductCategory'),
('ProductUnit'),
('ProductStatus'),
('WareHouseLocation'),

--BAKIM & ONARIM TABLOLARI
('Maintenance'),
('MaintenanceStatus'),

--HAREKET & LOG TABLOLARI
('Transactions'),
('Logs'),
('LogActions'),
('TableName'); -- Kendi kendini de loglayabilirsin (Meta-Log)


--ImagePath kolonu sonradan eklendi
ALTER TABLE Products ADD ImagePath NVARCHAR(255);

CREATE PROCEDURE sp_imagePathEkleme --
@UrunID INT
AS
BEGIN
	DECLARE @urunKodu VARCHAR(30);
	SELECT @urunKodu=ProductCode FROM Products WHERE ProductId=@UrunID;

	DECLARE @imagePath VARCHAR(255);
	SET @imagePath=@urunKodu+'.png';

	UPDATE Products SET ImagePath=@imagePath WHERE ProductId=@UrunID;
	PRINT 'Baþarýlý: Ürün ID ' + CAST(@UrunID AS NVARCHAR) + ' için resim yolu ' + @imagePath + ' olarak güncellendi.';
END
GO

-- Parametre olarak sadece ürünün ID'sini veriyorsunuz
EXEC sp_imagePathEkleme @UrunID = 1;
EXEC sp_imagePathEkleme @UrunID = 2;
EXEC sp_imagePathEkleme @UrunID = 3;
EXEC sp_imagePathEkleme @UrunID = 4;
EXEC sp_imagePathEkleme @UrunID = 5;
EXEC sp_imagePathEkleme @UrunID = 6;
EXEC sp_imagePathEkleme @UrunID = 7;
EXEC sp_imagePathEkleme @UrunID = 8;
EXEC sp_imagePathEkleme @UrunID = 9;
EXEC sp_imagePathEkleme @UrunID = 10;
EXEC sp_imagePathEkleme @UrunID = 11;
EXEC sp_imagePathEkleme @UrunID = 12;
EXEC sp_imagePathEkleme @UrunID = 13;
EXEC sp_imagePathEkleme @UrunID = 14;
EXEC sp_imagePathEkleme @UrunID = 15;
EXEC sp_imagePathEkleme @UrunID = 16;
EXEC sp_imagePathEkleme @UrunID = 17;
EXEC sp_imagePathEkleme @UrunID = 18;
EXEC sp_imagePathEkleme @UrunID = 19;
EXEC sp_imagePathEkleme @UrunID = 20;
EXEC sp_imagePathEkleme @UrunID = 21;
