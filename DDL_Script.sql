USE MASTER 
DECLARE @data_path NVARCHAR (256);
SET @data_path = (SELECT SUBSTRING(physical_name, 1, CHARINDEX(N'master.mdf', LOWER (physical_name))-1)
	FROM master.sys.master_files
	WHERE database_id = 1 and file_id = 1)

EXEC ('CREATE database OnlineBookShop_BD
ON PRIMARY (Name = OnlineBookShop_BD_DATA, Filename = ''' + @data_path + 'OnlineBookShop_BD_DATA.mdf'', size = 25MB, MAXSIZE = UNLIMITED, FILEGROWTH = 5%)
LOG ON (Name = OnlineBookShop_BD_LOG, Filename = ''' + @data_path + 'OnlineBookShop_BD_LOG.ldf'', size = 10MB, MAXSIZE = 100MB, FILEGROWTH = 1MB)
')
GO

USE OnlineBookShop_BD
GO

-- 1. Users Table
CREATE TABLE Users
(
 Userid INT PRIMARY KEY IDENTITY NOT NULL,
 Name  NVARCHAR (50) NOT NULL,
 Email VARCHAR (60) UNIQUE, 
 Password NVARCHAR(50),
 Address VARCHAR (50),
 ContactNo NVARCHAR (40),
 IsActive BIT DEFAULT 1
)
GO

-- 2. Categories Table
CREATE TABLE Categories
(
 CategoryID INT PRIMARY KEY IDENTITY NOT NULL,
 CategoryName NVARCHAR (80),
 Description NVARCHAR (250) NULL 
)
GO

-- 3. Books Table
CREATE TABLE Books
(
 BookID INT PRIMARY KEY IDENTITY NOT NULL,
 CategoryID INT FOREIGN KEY REFERENCES Categories (CategoryID), 
 BookTitle NVARCHAR (50),
 Author NVARCHAR (50),
 Description NVARCHAR (200),
 Baseprice Decimal (10,2),
 ISBN NVARCHAR(60) UNIQUE, 
 BookCover VARBINARY(MAX), 
 PublishedDate DATETIME,
 Summary NVARCHAR(500) SPARSE NULL
)
GO

-- 4. ItemVariant Table
CREATE TABLE ItemVariant
(
 VariantID INT PRIMARY KEY IDENTITY NOT NULL,
 BookID INT FOREIGN KEY REFERENCES Books (BookID),
 Format NVARCHAR (70) CHECK (Format in ('HardCover','Paperback','E-Book')),                
 Price DECIMAL (30,2)
)
GO

-- 5. OffersAndDiscount Table
CREATE TABLE OffersAndDiscount
(
 OfferID INT PRIMARY KEY IDENTITY NOT NULL ,
 BookID INT FOREIGN KEY REFERENCES Books (BookID),
 Discount DECIMAL (20,2),
 StartTime DATETIME ,
 EndTime DATETIME
)
GO

-- 6. Orders Table
CREATE TABLE Orders
(
 OrderId INT PRIMARY KEY IDENTITY NOT NULL ,
 UserID INT FOREIGN KEY REFERENCES Users(Userid),
 OrderDate DATETIME DEFAULT GETDATE(),																				
 Status NVARCHAR (80) check (Status in('Pending','OnShipping','Shipped','Approved')),				
 TotalAmount MONEY NOT NULL ,
 TotalpriceAfterDiscount Money
)
GO

-- 7. Payments Table
CREATE TABLE Payments
(
 PaymentID INT PRIMARY KEY IDENTITY NOT NULL ,
 UserId INT FOREIGN KEY REFERENCES Users(Userid),
 OrderID INT FOREIGN KEY REFERENCES Orders (OrderID),
 PaymentMethod NVARCHAR (50) CHECK (PaymentMethod in ('COD','Card','Bkash','Nagad','Rocket')),                
 PaymentStatus NVARCHAR (50) CHECK (PaymentStatus In ('Paid','Failed','Refund')),
 PaymentDate DATETIME DEFAULT GETDATE(),
 PaymentReceived DECIMAL (12,2)
)
GO

-- 8. OrderDetails Table
CREATE TABLE OrderDetails
(
 OrderDetailID INT PRIMARY KEY IDENTITY NOT NULL,
 OrderID INT FOREIGN KEY REFERENCES Orders (OrderID),
 BookID INT FOREIGN KEY REFERENCES Books (BookID),
 UserId INT FOREIGN KEY REFERENCES Users(Userid),
 VariantID INT FOREIGN KEY REFERENCES ItemVariant (VariantID),
 Quantity NUMERIC (10,2),
 UnitPrice DECIMAL (10,2)
)
GO

-- 9. Reviews Table
CREATE TABLE Reviews
(
 ReviewID SMALLINT PRIMARY KEY IDENTITY NOT NULL,
 UserID INT FOREIGN KEY REFERENCES Users(Userid),
 BookID INT FOREIGN KEY REFERENCES Books (BookID),
 Rating int Check (Rating BETWEEN 1 AND 5),
 Comment NVARCHAR (50),
 ReviewPhoto VARBINARY(MAX), 
 ReviewDate SMALLDATETIME
)
GO

-- 10. Wishlists Table
CREATE TABLE Wishlists
(
 WishlistID INT UNIQUE NOT NULL, 
 UserID INT FOREIGN KEY REFERENCES Users(Userid),
 BookID INT FOREIGN KEY REFERENCES Books (BookID),
 DateAdded Datetime 
)
GO

-- 11. Couriers Table
CREATE TABLE Couriers
(
 CourierId INT PRIMARY KEY IDENTITY NOT NULL ,
 CourierName NVARCHAR (70),
 ContactNumber NVARCHAR (50),															 
 DliveryArea NVARCHAR (60)
)
GO

-- 12. Stocks Table
CREATE TABLE Stocks
(
 StockID INT PRIMARY KEY IDENTITY NOT NULL ,
 VariantID INT FOREIGN KEY REFERENCES ItemVariant (VariantID),
 QuantityAvailable BIGINT,
 LastUpdated DATETIME
)
GO

-- 13. ShippingDetails Table
CREATE TABLE ShippingDetails
(
 ShipmentID Int PRIMARY KEY IDENTITY NOT NULL,
 OrderID Int FOREIGN KEY REFERENCES Orders (OrderID) NOT NULL,
 CourierId Int FOREIGN KEY REFERENCES Couriers (CourierId),
 EstimatedDeliveryDates Date,
 DeliveryStatus NVARCHAR(50)
)
GO

-- 14. Complains Table
CREATE TABLE Complains
(
 ComplainID Int PRIMARY KEY IDENTITY NOT NULL,
 UserID INT FOREIGN KEY REFERENCES Users(Userid) NOT NULL,
 Complain NVARCHAR (50)
)
GO

-- 15. Returns Table
CREATE TABLE Returns
(
 ReturnID INT PRIMARY KEY IDENTITY NOT NULL,								
 OrderID INT FOREIGN KEY REFERENCES Orders (OrderID) NOT NULL ,
 ValidReason NVARCHAR (120) 
)
GO

-- 16. Schema & AppSupportInfo
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Bookshop')
BEGIN
    EXEC('CREATE SCHEMA Bookshop')
END
GO

CREATE TABLE Bookshop.AppSupportInfo
(
 InfoID INT PRIMARY KEY IDENTITY,
 AboutUs NVARCHAR(100),
 HelpCenter NVARCHAR(100),
 CreatedAt DATETIME DEFAULT GETDATE()
)
GO

---------------------------------------------------------
-- ADVANCED FEATURES (Functions, Procedures, Triggers) --
---------------------------------------------------------

-- Scalar Function
CREATE FUNCTION fn_GetDiscountedPrice (
    @BasePrice DECIMAL(10,2),
    @Discount DECIMAL(20,2)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN @BasePrice - (@BasePrice * @Discount / 100)
END
GO

-- Stored Procedure for Order Placement
CREATE PROCEDURE PC_OrderPlace
    @UserID INT,
    @BookID INT,
    @VariantID INT,
    @Quantity INT,
    @UnitPrice DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON
    DECLARE @AvailableStock INT, @OrderID INT, @TotalAmount MONEY     
    BEGIN TRY
        BEGIN TRANSACTION
            SELECT @AvailableStock = QuantityAvailable FROM Stocks WHERE VariantID = @VariantID
            IF @AvailableStock IS NULL RAISERROR('No stock found.', 16, 1)
            IF @AvailableStock < @Quantity RAISERROR('Stock Out.', 16, 1)

            SET @TotalAmount = @UnitPrice * @Quantity;
            INSERT INTO Orders (UserID, OrderDate, Status, TotalAmount) 
            VALUES (@UserID, GETDATE(), 'Approved', @TotalAmount)
            SET @OrderID = SCOPE_IDENTITY()

            INSERT INTO OrderDetails (OrderID, BookID, UserID, VariantID, Quantity, UnitPrice)
            VALUES (@OrderID, @BookID, @UserID, @VariantID, @Quantity, @UnitPrice)

            UPDATE Stocks SET QuantityAvailable = QuantityAvailable - @Quantity, LastUpdated = GETDATE()
            WHERE VariantID = @VariantID
        COMMIT
        PRINT 'Order ID: ' + CAST(@OrderID AS NVARCHAR)
    END TRY
    BEGIN CATCH
        ROLLBACK
        PRINT 'Error: ' + ERROR_MESSAGE()
    END CATCH
END
GO

-- INSTEAD OF Trigger
CREATE TRIGGER trg_InsBooks
ON Books
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM inserted WHERE Baseprice < 0)
        RAISERROR('Invalid price.', 16, 1);
    ELSE
        INSERT INTO Books (CategoryID, BookTitle, Author, Description, Baseprice, ISBN, PublishedDate)
        SELECT CategoryID, BookTitle, Author, Description, Baseprice, ISBN, PublishedDate FROM inserted;
END
GO

-- View with Encryption
CREATE VIEW dbo.OrderSummaryView
WITH ENCRYPTION
AS
SELECT u.UserID, Name, COUNT(o.OrderID) AS TotalOrders, SUM(o.TotalAmount) AS TotalSpent
FROM dbo.Users u
JOIN dbo.Orders o ON u.UserID = o.UserID
GROUP BY u.UserID, u.Name
GO

--CustomerInfo View
CREATE VIEW dbo.CustomerInfo
AS
SELECT 
    Userid AS CustomerID, 
    Name AS CustomerName, 
    Email, 
    ContactNo, 
    Address
FROM dbo.Users
GO

-- Indexing
CREATE CLUSTERED INDEX IX_Customner_Wishlists ON Wishlists(WishlistID);
CREATE NONCLUSTERED INDEX IX_Books_BookTitle ON Books(BookTitle);
GO