-- Kullanýcýlarýn departmanlarýný tutar.
CREATE TABLE UserDepartment(
DepartmentId INT IDENTITY(1,1) PRIMARY KEY,
DepartmentName VARCHAR(100) UNIQUE
);

-- Kullanýcýlarýn hesap durumlarýný tutar (Aktif, Pasif vb.)
CREATE TABLE AccountStatus(
aStatusId INT PRIMARY KEY IDENTITY(1,1),
aStatusName VARCHAR(30) UNIQUE
);

-- Kullanýcý bilgilerini tutar.
CREATE TABLE Users(
UserId INT PRIMARY KEY IDENTITY(1,1),
UserName VARCHAR(50) UNIQUE NOT NULL,
Name_ VARCHAR(50) NOT NULL,
Surname_ VARCHAR(50) NOT NULL,
PasswordHash VARCHAR(256) NOT NULL,
Dept_id INT FOREIGN KEY REFERENCES UserDepartment(DepartmentId) NOT NULL,
e_mail VARCHAR(100) UNIQUE NOT NULL,
role_ BIT NOT NULL, -- admin:1, user:0
CreateDate DATETIME NOT NULL,
AccountStatus_id INT FOREIGN KEY REFERENCES AccountStatus(aStatusId) NULL,
is_on_leave BIT NOT NULL, -- izinde:0(sisteme eriþemez) izinde deðil:1
access_request_pending BIT NOT NULL, -- istek var:1  istek yok:0

CHECK (
        e_mail LIKE '%_@__%.__%' -- Temel formatý zorlar(a@bb.cc)
        AND e_mail NOT LIKE '% %'      -- Boþluk olamaz
        AND e_mail NOT LIKE '%@%@%'    -- Ýki tane @ olamaz
        AND e_mail NOT LIKE '@%'       -- @ ile baþlayamaz
        AND e_mail NOT LIKE '%@.'      -- '@.' yan yana olamaz
    )
);


-- Ürünlerin kategorilerini tutar
CREATE TABLE ProductCategory (
    CategoryId INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName VARCHAR(50) UNIQUE NOT NULL
);

-- Ürünlerin birimlerini tutar (Adet, Litre, Kg vb.)
CREATE TABLE ProductUnit (
    UnitId INT IDENTITY(1,1) PRIMARY KEY,
    UnitName VARCHAR(30) UNIQUE NOT NULL
);

-- Ürünlerin depodaki konumlarýný tutar (Depo 3, Raf 1, Bölüm 2 ->D3-R1-B2 vb.)
CREATE TABLE WareHouseLocation (
    LocationId INT IDENTITY(1,1) PRIMARY KEY,
    LocationName VARCHAR(30) UNIQUE NOT NULL
);

-- Ürünlerin durumunu tutar (Yeni, Arýzalý, Bakýmda vb.)
CREATE TABLE ProductStatus (
    pStatusId INT IDENTITY(1,1) PRIMARY KEY,
    pStatusName VARCHAR(100) UNIQUE NOT NULL
);

-- Ürünlerin ana tablosu
CREATE TABLE Products (
    ProductId INT IDENTITY(1,1) PRIMARY KEY,
    ProductName VARCHAR(50) NOT NULL,
    ProductCode VARCHAR(30) UNIQUE NOT NULL,
    Category_id INT FOREIGN KEY REFERENCES ProductCategory(CategoryId) NOT NULL,
    Quantity DECIMAL(18, 4) NOT NULL,
    Unit_id INT FOREIGN KEY REFERENCES ProductUnit(UnitId) NOT NULL,
    EntryDate DATETIME NOT NULL DEFAULT GETDATE(),
    WarrantyEndDate DATE NOT NULL, -- Garanti bitiþ tarihi
    Location_id INT FOREIGN KEY REFERENCES WareHouseLocation(LocationId) NOT NULL,
    Status_id INT FOREIGN KEY REFERENCES ProductStatus(pStatusId) NOT NULL,
    AddedByUser_id INT FOREIGN KEY REFERENCES Users(UserId) NULL,
	CHECK (EntryDate <= WarrantyEndDate),
	CHECK (Quantity >= 0)
);


-- Stok giriþ/çýkýþ hareketlerini tutan tablo
CREATE TABLE Transactions ( 
	TransactionId INT IDENTITY(1,1) PRIMARY KEY,
    Product_id INT FOREIGN KEY REFERENCES Products(ProductId) NOT NULL,
    User_id_ INT FOREIGN KEY REFERENCES Users(UserId) NOT NULL,
    TransactionType BIT NOT NULL DEFAULT 0, -- (giriþ:1, çýkýþ:0)
    Amount INT NOT NULL DEFAULT 0,
    TransactionDate DATETIME NOT NULL DEFAULT GETDATE(),
    Note VARCHAR(MAX)
  );


-- Bakým sonrasý durumlarý tutar (Tamir Edildi, Hurdaya Ayrýldý vb.)
CREATE TABLE MaintenanceStatus (
    mStatusId INT IDENTITY(1,1) PRIMARY KEY,
    mStatusName VARCHAR(50) UNIQUE NOT NULL
);

-- Bakým ve onarým kayýtlarýný tutan tablo
CREATE TABLE Maintenance (
    MaintenanceId INT IDENTITY(1,1) PRIMARY KEY,
    Product_id INT FOREIGN KEY REFERENCES Products(ProductId) NOT NULL,
    PerformedByUser_id INT FOREIGN KEY REFERENCES Users(UserId) NOT NULL,
    MaintenanceStartDate DATETIME NOT NULL,
    MaintenanceEndDate DATETIME NULL, -- Dönüþ tarihi bilinmeyebilir bu nedenle NULL olabilir.
    Description_ VARCHAR(MAX), 
    StatusAfter_id INT FOREIGN KEY REFERENCES MaintenanceStatus(mStatusId)
);


-- Loglama için eylem isimlerini tutar (Oluþturma, Güncelleme, Silme vb.)
CREATE TABLE LogActions (
    ActionId INT IDENTITY(1,1) PRIMARY KEY,
    ActionName VARCHAR(100) UNIQUE NOT NULL
);

-- Loglama için tablo isimlerini tutar
CREATE TABLE TableName (
    TableId INT IDENTITY(1,1) PRIMARY KEY,
    TableName VARCHAR(30) UNIQUE NOT NULL
);

-- Tüm eylemlerin loglarýný tutan denetim tablosu
CREATE TABLE Logs (
    LogId INT IDENTITY(1,1) PRIMARY KEY,
    User_id_ INT FOREIGN KEY REFERENCES Users(UserId) NOT NULL,
    Action_id INT FOREIGN KEY REFERENCES LogActions(ActionId) NOT NULL,
    TableAffected_id INT FOREIGN KEY REFERENCES TableName(TableId),
    record_id INT NULL, -- Hangi satýrýn etkilendiðinin ID'si
    ActionDate DATETIME NOT NULL DEFAULT GETDATE()
);