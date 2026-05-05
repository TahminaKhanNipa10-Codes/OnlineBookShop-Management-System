USE MASTER 
GO

USE OnlineBookShop_BD
GO

---------------------------------------------------------
-- 1. DATA INSERTION (DML) --
---------------------------------------------------------

-- Users
INSERT INTO Users (Name, Email, Password, Address, ContactNo) 
VALUES ('Alve', 'alve@gmail.com', '147258', 'CTG', '01812575275'),
       ('Alif', 'alif@gmail.com', '369258', 'CTG', '01710311748'),
       ('Tahmid', 'tahmid@gmail.com', '147258', 'CTG', '01812575275');

-- Categories
INSERT INTO Categories (CategoryName, Description) 
VALUES ('Fiction', 'Stories and Novels based in imagination'),
       ('Non-Fiction', 'Books based on real events or people'),
       ('History', 'Book related to historical events and figures'),
       ('Science And Technology', 'Books related on science and innovation');

-- Books
INSERT INTO Books (CategoryID, BookTitle, Author, Description, Baseprice, ISBN, PublishedDate) 
VALUES (1, 'Ayna Ghor', 'Humayon Ahmed', 'Famous Novel', 100, '9785632145632', '1995-10-25'),
       (1, 'Putul Nacer Itikotha', 'Manik Bandopaddhay', 'Classic literature', 150, '97856321456985', '1955-05-05'),
       (2, 'Tale of Two Cities', 'Charles Dickens', 'Historical fiction', 400, '9785632145635', '2024-10-01'),
       (1, 'Pride & Prejudice', 'Jane Austen', 'Romantic novel', 300, '97856321456582', '1989-10-25');

-- ItemVariant
INSERT INTO ItemVariant (BookID, Format, Price) 
VALUES (1, 'HardCover', 100),
       (2, 'Paperback', 300),
       (3, 'E-Book', 150),
       (4, 'HardCover', 400);

-- Stocks
INSERT INTO Stocks (VariantID, QuantityAvailable, LastUpdated)
VALUES (1, 50, GETDATE()),
       (2, 100, GETDATE()),
       (3, 75, GETDATE());

-- Orders
INSERT INTO Orders (UserID, OrderDate, Status, TotalAmount, TotalpriceAfterDiscount) 
VALUES (1, GETDATE(), 'Pending', 150, 128),
       (2, GETDATE(), 'Approved', 150, 128);

-- OrderDetails
INSERT INTO OrderDetails (OrderID, BookID, UserID, VariantID, Quantity, UnitPrice) 
VALUES (1, 1, 1, 1, 1, 100.00),
       (2, 2, 2, 3, 1, 300.00);

-- Wishlists
INSERT INTO Wishlists (WishlistID, UserID, BookID, DateAdded) 
VALUES (1, 1, 2, GETDATE()),
       (2, 2, 1, GETDATE());

-- Couriers
INSERT INTO Couriers (CourierName, ContactNumber, DliveryArea) 
VALUES ('Pathao Express', '01911223344', 'Dhaka'),
       ('Sundarban Courier', '01899887766', 'Chittagong');

-- ShippingDetails
INSERT INTO ShippingDetails (OrderID, CourierId, EstimatedDeliveryDates, DeliveryStatus)
VALUES (1, 1, '2025-09-15', 'Pending'),
       (2, 2, '2025-09-16', 'Shipped');
GO

---------------------------------------------------------
-- 2. ADVANCED QUERIES --
---------------------------------------------------------

-- Derived Table
SELECT dt.UserID, dt.TotalOrders
FROM (
    SELECT UserID, COUNT(OrderID) AS TotalOrders
    FROM Orders
    GROUP BY UserID
) AS dt
WHERE dt.TotalOrders >= 1;

-- Inner JOIN with Subquery
SELECT o.OrderID, Name, TotalAmount
FROM Orders o
JOIN Users u ON o.UserID = u.UserID
WHERE o.UserID IN 
	(SELECT UserID FROM Orders GROUP BY UserID HAVING COUNT(OrderID) >= 1);

-- UNION ALL
SELECT OrderID, UserID, TotalAmount, 'High Value' AS Category
FROM Orders
WHERE TotalAmount > (SELECT AVG(TotalAmount) FROM Orders)
UNION ALL
SELECT OrderID, UserID, TotalAmount, 'Low Value' AS Category
FROM Orders
WHERE TotalAmount <= (SELECT AVG(TotalAmount) FROM Orders);

-- ROLLUP
SELECT BookID, SUM(Quantity) AS TotalSold
FROM OrderDetails
GROUP BY ROLLUP(BookID);

-- CUBE
SELECT Name, YEAR(o.OrderDate) AS OrderYear, SUM(o.TotalAmount) AS TotalSales
FROM Orders o
JOIN Users u ON u.UserID = o.UserID
GROUP BY CUBE(Name, YEAR(o.OrderDate));

-- GROUPING SETS
SELECT BookID, UserID, SUM(Quantity) AS TotalSold
FROM OrderDetails
GROUP BY GROUPING SETS ((BookID), (UserID), (BookID, UserID));

-- OVER, RANK & ANY/SOME Clauses
SELECT O.OrderID, UserID, TotalAmount, 
       RANK() OVER (ORDER BY O.TotalAmount DESC) AS OrderRank
FROM Orders O
WHERE TotalAmount >= 100
   OR TotalAmount = ANY (SELECT TotalAmount FROM Orders WHERE UserID = O.UserID);

-- CTE with Loop
DECLARE @i INT = 1;
WHILE @i <= 5
BEGIN
    IF @i NOT IN (3)
    BEGIN
        WITH MyCTE AS (SELECT @i AS [Number])
        SELECT * FROM MyCTE;
    END
    SET @i = @i + 1;
END
GO

-- IF..ELSE & GOTO
DECLARE @num INT = 7
IF (@num % 2 = 0)
  PRINT 'Even number'
ELSE
BEGIN
   PRINT 'Odd number'
   GOTO FinalStep;
END

FinalStep:
   PRINT 'GOTO Statement Executed.';
GO

-- Setting Commands
SET ANSI_NULLS ON
SET NOCOUNT ON
SET DATEFORMAT dmy
GO