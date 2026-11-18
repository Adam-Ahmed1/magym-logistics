CREATE DATABASE LocalDeliveryMarketplace_Team_44;
GO
USE LocalDeliveryMarketplace_Team_44;
GO
-- mohamed mostafa hassan mohamed - 65-33784
CREATE PROCEDURE dbo.createAllTables
AS
BEGIN
    BEGIN TRY
    BEGIN TRANSACTION;
 CREATE TABLE dbo.Zone(
        zone_id int identity(1,1) NOT NULL,
        zone_name varchar(50) NOT NULL UNIQUE,
        delivery_fee decimal(10,2) NOT NULL CHECK (delivery_fee >= 0),
        PRIMARY KEY (zone_id)
    );

    CREATE TABLE dbo.Users
    (
        user_id int identity(1,1) NOT NULL,
        first_name varchar(30) NOT NULL,
        middle_name varchar(30) NULL,
        last_name varchar(30) NOT NULL,
        username varchar(30) NOT NULL UNIQUE,
        password varchar(30) NOT NULL,
        email varchar(100) NOT NULL UNIQUE,
        dob date NULL,
        account_status varchar(20) NOT NULL DEFAULT 'Active' CHECK (account_status IN ('Active', 'Blacklisted')),
        PRIMARY KEY (user_id)
    );

    CREATE TABLE dbo.User_Phone
    (
        user_id int NOT NULL,
        phone char(11) NOT NULL,
        PRIMARY KEY (user_id, phone),
        CONSTRAINT FK_User_Phone_user_id FOREIGN KEY (user_id) REFERENCES dbo.Users(user_id)
    );

    CREATE TABLE dbo.Admin
    
    (
        admin_id int NOT NULL,
        role varchar(20) NOT NULL DEFAULT 'Super Admin' CHECK (role IN ('Super Admin', 'Zone Admin')),
        zone_id int NULL,
        PRIMARY KEY (admin_id),
        CONSTRAINT FK_Admin_admin_id FOREIGN KEY (admin_id) REFERENCES dbo.Users(user_id),
        CONSTRAINT FK_Admin_zone_id FOREIGN KEY (zone_id) REFERENCES dbo.Zone(zone_id)
    );

    CREATE TABLE dbo.Partner
    (
        partner_id int NOT NULL,
        PRIMARY KEY (partner_id),
        CONSTRAINT FK_Partner_partner_id FOREIGN KEY (partner_id) REFERENCES dbo.Users(user_id)
    );

    CREATE TABLE dbo.Rider
    (
        rider_id int NOT NULL,
        vehicle_type varchar(30) NOT NULL,
        plate_no varchar(15) NOT NULL UNIQUE,
        license_no varchar(20) NOT NULL UNIQUE,
        is_available bit NOT NULL DEFAULT 1,
        zone_id int NOT NULL,
        PRIMARY KEY (rider_id),
        CONSTRAINT FK_Rider_rider_id FOREIGN KEY (rider_id) REFERENCES dbo.Users(user_id),
        CONSTRAINT FK_Rider_zone_id FOREIGN KEY (zone_id) REFERENCES dbo.Zone(zone_id)
    );

    CREATE TABLE dbo.Customer
    (
        customer_id int NOT NULL,
        wallet_balance decimal(10,2) NOT NULL DEFAULT 0 CHECK (wallet_balance >= 0),
        PRIMARY KEY (customer_id),
        CONSTRAINT FK_Customer_customer_id FOREIGN KEY (customer_id) REFERENCES dbo.Users(user_id)
    );

    CREATE TABLE dbo.Address
      (
        address_id int identity(1,1) NOT NULL,
        description varchar(150) NOT NULL,
        is_active bit NOT NULL DEFAULT 1,
        customer_id int NOT NULL,
        zone_id int NOT NULL,
        PRIMARY KEY (address_id),
        CONSTRAINT FK_Address_customer_id FOREIGN KEY (customer_id) REFERENCES dbo.Customer(customer_id),
        CONSTRAINT FK_Address_zone_id FOREIGN KEY (zone_id) REFERENCES dbo.Zone(zone_id)
    );

    CREATE TABLE dbo.Card
    (
        card_id int identity(1,1) NOT NULL,
        card_no char(16) NOT NULL,
        card_holder_name varchar(100) NOT NULL,
        expiration_date date NOT NULL,
        customer_id int NOT NULL,
        PRIMARY KEY (card_id),
        CONSTRAINT FK_Card_customer_id FOREIGN KEY (customer_id) REFERENCES dbo.Customer(customer_id),
        UNIQUE (customer_id, card_no)
    );

    CREATE TABLE dbo.Business (
        business_id int identity(1,1) NOT NULL,
        name varchar(100) NOT NULL,
        description varchar(255) NULL,
        link_website varchar(255) NULL,
        opening_hour time NOT NULL,
        closing_hour time NOT NULL,
        expected_delivery_time int NOT NULL CHECK (expected_delivery_time > 0),
        status varchar(20) NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Active', 'Suspended', 'Rejected')),
        suspension_reason varchar(255) NULL,
        partner_id int NOT NULL UNIQUE,
        zone_id int NOT NULL,
        PRIMARY KEY (business_id),
        CONSTRAINT FK_Business_partner_id FOREIGN KEY (partner_id) REFERENCES dbo.Partner(partner_id),
        CONSTRAINT FK_Business_zone_id FOREIGN KEY (zone_id) REFERENCES dbo.Zone(zone_id)
    );

    CREATE TABLE dbo.Business_Phone
    (
        business_id int NOT NULL,
        phone char(11) NOT NULL,
        PRIMARY KEY (business_id, phone),
        CONSTRAINT FK_Business_Phone_business_id FOREIGN KEY (business_id) REFERENCES dbo.Business(business_id)
    );

    CREATE TABLE dbo.Restaurant
    (
        business_id int NOT NULL,
        cuisine_type varchar(50) NOT NULL,
        food_category varchar(50) NOT NULL,
        PRIMARY KEY (business_id),
        CONSTRAINT FK_Restaurant_business_id FOREIGN KEY (business_id) REFERENCES dbo.Business(business_id)
    );

    CREATE TABLE dbo.Pharmacy
    (
        business_id int NOT NULL,
        pharmacy_type varchar(50) NOT NULL,
        PRIMARY KEY (business_id),
        CONSTRAINT FK_Pharmacy_business_id FOREIGN KEY (business_id) REFERENCES dbo.Business(business_id)
    );

    CREATE TABLE dbo.Blacklist
    (
        customer_id int NOT NULL,
        admin_id int NOT NULL,
        reason varchar(255) NOT NULL,
        PRIMARY KEY (customer_id),
        CONSTRAINT FK_Blacklist_customer_id FOREIGN KEY (customer_id) REFERENCES dbo.Customer(customer_id),
        CONSTRAINT FK_Blacklist_admin_id FOREIGN KEY (admin_id) REFERENCES dbo.Admin(admin_id)
    );

    CREATE TABLE dbo.Product
    (
        product_id int identity(1,1) NOT NULL,
        name varchar(100) NOT NULL,
        description varchar(255) NULL,
        category varchar(50) NOT NULL,
        price decimal(10,2) NOT NULL CHECK (price > 0),
        discount_amount decimal(10,2) NOT NULL DEFAULT 0,
        is_available bit NOT NULL DEFAULT 1,
        business_id int NOT NULL,
        PRIMARY KEY (product_id),
        CONSTRAINT FK_Product_business_id FOREIGN KEY (business_id) REFERENCES dbo.Business(business_id),
        CHECK (discount_amount >= 0 AND discount_amount <= 0.5 * price)
    );

    CREATE TABLE dbo.Favorite_Business
    (
        customer_id int NOT NULL,
        business_id int NOT NULL,
        PRIMARY KEY (customer_id, business_id),
        CONSTRAINT FK_Favorite_Business_customer_id FOREIGN KEY (customer_id) REFERENCES dbo.Customer(customer_id),
        CONSTRAINT FK_Favorite_Business_business_id FOREIGN KEY (business_id) REFERENCES dbo.Business(business_id)
    );

    CREATE TABLE dbo.Favorite_Product
    (
        customer_id int NOT NULL,
        product_id int NOT NULL,
        PRIMARY KEY (customer_id, product_id),
        CONSTRAINT FK_Favorite_Product_customer_id FOREIGN KEY (customer_id) REFERENCES dbo.Customer(customer_id),
        CONSTRAINT FK_Favorite_Product_product_id FOREIGN KEY (product_id) REFERENCES dbo.Product(product_id)
    );

    CREATE TABLE dbo.Voucher
   (
        voucher_id int identity(1,1) NOT NULL,
        promo_code varchar(30) NOT NULL UNIQUE,
        is_percentage bit NOT NULL,
        amount decimal(10,2) NOT NULL CHECK (amount > 0),
        expiry_date date NOT NULL,
        status varchar(20) NOT NULL DEFAULT 'Unused' CHECK (status IN ('Unused', 'Used')),
        customer_id int NOT NULL,
        PRIMARY KEY (voucher_id),
        CONSTRAINT FK_Voucher_customer_id FOREIGN KEY (customer_id) REFERENCES dbo.Customer(customer_id)
    );

    CREATE TABLE dbo.Cart
    (
        cart_id int identity(1,1) NOT NULL,
        status varchar(20) NOT NULL DEFAULT 'Active' CHECK (status IN ('Active', 'Checked Out')),
        created_at datetime NOT NULL DEFAULT GETDATE(),
        customer_id int NOT NULL,
        address_id int NOT NULL,
        PRIMARY KEY (cart_id),
        CONSTRAINT FK_Cart_customer_id FOREIGN KEY (customer_id) REFERENCES dbo.Customer(customer_id),
        CONSTRAINT FK_Cart_address_id FOREIGN KEY (address_id) REFERENCES dbo.Address(address_id)
    );

    CREATE TABLE dbo.CartItem
    (
        cart_id int NOT NULL,
        product_id int NOT NULL,
        quantity int NOT NULL CHECK (quantity BETWEEN 1 AND 10),
        notes varchar(255) NULL,
        unit_price decimal(10,2) NULL,
        PRIMARY KEY (cart_id, product_id),
        CONSTRAINT FK_CartItem_cart_id FOREIGN KEY (cart_id) REFERENCES dbo.Cart(cart_id),
        CONSTRAINT FK_CartItem_product_id FOREIGN KEY (product_id) REFERENCES dbo.Product(product_id)
    );

    CREATE TABLE dbo.Orders
    (
        order_id int identity(1,1) NOT NULL,
        order_date datetime NOT NULL,
        status varchar(20) NOT NULL DEFAULT 'Placed' CHECK (status IN ('Placed', 'In Progress', 'Delivered', 'Cancelled')),
        discount_amount decimal(10,2) NOT NULL DEFAULT 0,
        total_amount decimal(10,2) NOT NULL,
        cart_id int NOT NULL UNIQUE,
        zone_id int NOT NULL,
        voucher_id int NULL,
        PRIMARY KEY (order_id),
        CONSTRAINT FK_Orders_cart_id FOREIGN KEY (cart_id) REFERENCES dbo.Cart(cart_id),
        CONSTRAINT FK_Orders_zone_id FOREIGN KEY (zone_id) REFERENCES dbo.Zone(zone_id),
        CONSTRAINT FK_Orders_voucher_id FOREIGN KEY (voucher_id) REFERENCES dbo.Voucher(voucher_id)
    );

    CREATE TABLE dbo.SubOrder
    (
        suborder_id int identity(1,1) NOT NULL,
        status varchar(20) NOT NULL DEFAULT 'Placed' CHECK (status IN ('Placed', 'Assigned', 'Picked Up', 'Delivered', 'Cancelled')),
        total_price decimal(10,2) NOT NULL,
        delivery_fee decimal(10,2) NOT NULL,
        order_id int NOT NULL,
        business_id int NOT NULL,
        PRIMARY KEY (suborder_id),
        CONSTRAINT FK_SubOrder_order_id FOREIGN KEY (order_id) REFERENCES dbo.Orders(order_id),
        CONSTRAINT FK_SubOrder_business_id FOREIGN KEY (business_id) REFERENCES dbo.Business(business_id),
        UNIQUE (order_id, business_id)
    );

    CREATE TABLE dbo.Delivery
    (
        delivery_id int identity(1,1) NOT NULL,
        assigned_at datetime NOT NULL,
        picked_up_at datetime NULL,
        delivered_at datetime NULL,
        tracking_time int NULL,
        rider_rating int NULL CHECK (rider_rating BETWEEN 1 AND 5),
        suborder_id int NOT NULL UNIQUE,
        rider_id int NOT NULL,
        PRIMARY KEY (delivery_id),
        CONSTRAINT FK_Delivery_suborder_id FOREIGN KEY (suborder_id) REFERENCES dbo.SubOrder(suborder_id),
        CONSTRAINT FK_Delivery_rider_id FOREIGN KEY (rider_id) REFERENCES dbo.Rider(rider_id)
    );

    CREATE TABLE dbo.Payment
    (
        payment_id int identity(1,1) NOT NULL,
        amount decimal(10,2) NOT NULL,
        currency varchar(3) NOT NULL DEFAULT 'EGP' CHECK (currency IN ('EGP')),
        method varchar(20) NOT NULL CHECK (method IN ('Cash', 'Card', 'Wallet')),
        transaction_date datetime NOT NULL,
        refunded_amount decimal(10,2) NOT NULL DEFAULT 0,
        order_id int NOT NULL UNIQUE,
        card_id int NULL,
        PRIMARY KEY (payment_id),
        CONSTRAINT FK_Payment_order_id FOREIGN KEY (order_id) REFERENCES dbo.Orders(order_id),
        CONSTRAINT FK_Payment_card_id FOREIGN KEY (card_id) REFERENCES dbo.Card(card_id),
        CHECK (refunded_amount <= amount)
    );

    CREATE TABLE dbo.Feedback
    (
        feedback_id int identity(1,1) NOT NULL,
        headline varchar(100) NOT NULL,
        description varchar(500) NULL,
        rating int NOT NULL CHECK (rating BETWEEN 1 AND 5),
        feedback_date datetime NOT NULL DEFAULT GETDATE(),
        suborder_id int NOT NULL UNIQUE,
        PRIMARY KEY (feedback_id),
        CONSTRAINT FK_Feedback_suborder_id FOREIGN KEY (suborder_id) REFERENCES dbo.SubOrder(suborder_id)
    );

    COMMIT TRANSACTION;
    RETURN 0;
    END TRY
    BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    RETURN -1;
    END CATCH;
END;
GO

EXEC dbo.createAllTables;
GO

-- mohamed mostafa hassan mohamed - 65-33784
CREATE PROCEDURE dbo.dropAllTables
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DROP TABLE dbo.Feedback;
        DROP TABLE dbo.Payment;
        DROP TABLE dbo.Delivery;
        DROP TABLE dbo.SubOrder;
        DROP TABLE dbo.Orders;
        DROP TABLE dbo.CartItem;
        DROP TABLE dbo.Cart;
        DROP TABLE dbo.Voucher;
        DROP TABLE dbo.Favorite_Product;
        DROP TABLE dbo.Favorite_Business;
        DROP TABLE dbo.Product;
        DROP TABLE dbo.Blacklist;
        DROP TABLE dbo.Pharmacy;
        DROP TABLE dbo.Restaurant;
        DROP TABLE dbo.Business_Phone;
        DROP TABLE dbo.Business;
        DROP TABLE dbo.Card;
        DROP TABLE dbo.Address;
        DROP TABLE dbo.Customer;
        DROP TABLE dbo.Rider;
        DROP TABLE dbo.Partner;
        DROP TABLE dbo.Admin;
        DROP TABLE dbo.User_Phone;
        DROP TABLE dbo.Users;
        DROP TABLE dbo.Zone;

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        RETURN -1;
    END CATCH;
END;
GO

-- mohamed mostafa hassan mohamed - 65-33784
CREATE PROCEDURE dbo.dropAllProceduresFunctionsViews
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
            DROP PROCEDURE IF EXISTS dbo.Customer_Register;
            DROP PROCEDURE IF EXISTS dbo.Partner_Register;
            DROP PROCEDURE IF EXISTS dbo.Rider_Register;
            DROP PROCEDURE IF EXISTS dbo.Change_Password;
            DROP PROCEDURE IF EXISTS dbo.Create_Admin;
            DROP PROCEDURE IF EXISTS dbo.Approve_Business;
            DROP PROCEDURE IF EXISTS dbo.Reject_Business;
            DROP PROCEDURE IF EXISTS dbo.Assign_Admin_Zone;
            DROP PROCEDURE IF EXISTS dbo.Issue_Voucher;
            DROP PROCEDURE IF EXISTS dbo.Blacklist_Customer;
            DROP PROCEDURE IF EXISTS dbo.Lift_Customer_Blacklist;
            DROP PROCEDURE IF EXISTS dbo.Submit_Feedback;
            DROP PROCEDURE IF EXISTS dbo.Rate_Rider;
            DROP PROCEDURE IF EXISTS dbo.Mark_Picked_Up;
            DROP PROCEDURE IF EXISTS dbo.Mark_Delivered;
            DROP PROCEDURE IF EXISTS dbo.Suspend_Business;
            DROP PROCEDURE IF EXISTS dbo.Reinstate_Business;
            DROP PROCEDURE IF EXISTS dbo.Create_Zone;
            DROP PROCEDURE IF EXISTS dbo.Update_Zone_Fee;
            DROP PROCEDURE IF EXISTS dbo.clearAllTables;
            DROP PROCEDURE IF EXISTS dbo.dropAllTables;
            DROP PROCEDURE IF EXISTS dbo.createAllTables;
            DROP PROCEDURE IF EXISTS dbo.Register_Business;
            DROP PROCEDURE IF EXISTS dbo.Update_Business_Info;
            DROP PROCEDURE IF EXISTS dbo.Upsert_Product;
            DROP PROCEDURE IF EXISTS dbo.Toggle_Product_Status;
            DROP PROCEDURE IF EXISTS dbo.Set_Product_Promotion;
            DROP PROCEDURE IF EXISTS dbo.Add_Customer_Address;
            DROP PROCEDURE IF EXISTS dbo.Update_Delete_Customer_Address;
            DROP PROCEDURE IF EXISTS dbo.Reorder;
            DROP PROCEDURE IF EXISTS dbo.Change_Active_Address;
            DROP PROCEDURE IF EXISTS dbo.Add_Card;
            DROP PROCEDURE IF EXISTS dbo.Create_Cart;
            DROP PROCEDURE IF EXISTS dbo.Add_To_Cart;
            DROP PROCEDURE IF EXISTS dbo.Remove_From_Cart;
            DROP PROCEDURE IF EXISTS dbo.Checkout_Cart;
            DROP PROCEDURE IF EXISTS dbo.Cancel_Order;
            DROP PROCEDURE IF EXISTS dbo.Toggle_Favorite;
            DROP PROCEDURE IF EXISTS dbo.Set_Rider_Availability;
            DROP FUNCTION IF EXISTS dbo.CustomerLoginValidation;
            DROP FUNCTION IF EXISTS dbo.PartnerLoginValidation;
            DROP FUNCTION IF EXISTS dbo.RiderLoginValidation;
            DROP FUNCTION IF EXISTS dbo.AdminLoginValidation;
            DROP FUNCTION IF EXISTS dbo.TopRiders;
            DROP FUNCTION IF EXISTS dbo.BusinessFeedbackOverview;
            DROP FUNCTION IF EXISTS dbo.Recommended_Products;
            DROP FUNCTION IF EXISTS dbo.My_Earnings;
            DROP FUNCTION IF EXISTS dbo.My_Rating_Summary;
            DROP FUNCTION IF EXISTS dbo.Reconcile_Order_Totals;
            DROP FUNCTION IF EXISTS dbo.Platform_Health_Snapshot;
            DROP FUNCTION IF EXISTS dbo.ZoneOrderReport;
            DROP FUNCTION IF EXISTS dbo.Daily_Revenue_Report;
            DROP FUNCTION IF EXISTS dbo.BusinessRefunds;
            DROP FUNCTION IF EXISTS dbo.BusinessSalesReport;
            DROP FUNCTION IF EXISTS dbo.Calculate_Voucher_Discount;
            DROP FUNCTION IF EXISTS dbo.My_Order_History;
            DROP FUNCTION IF EXISTS dbo.My_Favorites;
            DROP FUNCTION IF EXISTS dbo.My_Active_Deliveries;
            DROP FUNCTION IF EXISTS dbo.My_Delivery_History;
            DROP FUNCTION IF EXISTS dbo.Search_Platform;
            DROP FUNCTION IF EXISTS dbo.Nearby_Businesses_By_Category;
            DROP FUNCTION IF EXISTS dbo.Search_Platform_Helper;
            DROP VIEW IF EXISTS dbo.ActiveVouchers;
            DROP VIEW IF EXISTS dbo.BusinessesPerZone;
            DROP VIEW IF EXISTS dbo.allBusinessProfiles;
            DROP VIEW IF EXISTS dbo.BusinessRatingsSummary;
            DROP VIEW IF EXISTS dbo.PendingBusinessApprovals;
            DROP VIEW IF EXISTS dbo.RiderPerformanceSummary;
            DROP VIEW IF EXISTS dbo.TopSellingProducts;
            DROP VIEW IF EXISTS dbo.ZoneDeliveryPerformance;
            DROP FUNCTION IF EXISTS dbo.GetBusinessType_Helper;
        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        RETURN -1;
    END CATCH;
END;
GO

-- mohamed mostafa hassan mohamed - 65-33784
CREATE PROCEDURE dbo.clearAllTables
AS
BEGIN
    DECLARE @result int;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC @result = dbo.dropAllTables;
        IF @result = 0
            EXEC @result = dbo.createAllTables;

        IF @result <> 0
        BEGIN
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            RETURN @result;
        END;

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        RETURN -1;
    END CATCH;
END;
GO

-- Returns business type, 'Restaurant' or 'Pharmacy'
-- Adam Ahmed Ibrahim - 65-33775
CREATE FUNCTION dbo.GetBusinessType_Helper(@business_id INT)
RETURNS VARCHAR(15)
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Restaurant R
        WHERE R.business_id = @business_id
    )
    RETURN 'Restaurant';
    
    RETURN 'Pharmacy';
END

-- Adam Ahmed Ibrahim - 65-33775
GO
CREATE VIEW dbo.allBusinessProfiles
AS
    SELECT
        B.business_id,
        B.[name] AS business_name,
        dbo.GetBusinessType_Helper(B.business_id) AS business_type,
        Z.zone_name,
        U.first_name + ' ' + U.last_name AS partner_name,
        B.[status],
        B.opening_hour,
        B.closing_hour
    FROM Business B
    INNER JOIN [Partner] P ON P.partner_id = B.partner_id
    INNER JOIN Users U ON U.[user_id] = P.partner_id
    INNER JOIN [Zone] Z ON Z.zone_id = B.zone_id;
GO

-- mohamed mostafa hassan mohamed - 65-33784
CREATE VIEW dbo.BusinessesPerZone
AS
SELECT z.zone_id, z.zone_name, COUNT(b.business_id) AS business_count
FROM dbo.Zone z
LEFT JOIN dbo.Business b ON b.zone_id = z.zone_id AND b.status = 'Active'
GROUP BY z.zone_id, z.zone_name;
GO

GO
--Maryam Mustafa Abdelwahab- 64-3003
CREATE VIEW dbo.BusinessRatingsSummary
AS
SELECT b.business_id, b.name AS business_name,
CAST(AVG(CAST(f.rating AS decimal(10,2))) AS decimal(10,2)) AS avg_rating, COUNT(f.feedback_id) as 
ratings_count
FROM dbo.Business b
LEFT JOIN dbo.SubOrder AS s ON s.business_id = b.business_id
LEFT JOIN dbo.Feedback AS f ON f.suborder_id = s.suborder_id
GROUP BY b.business_id, b.name;
GO

-- Gelan Ahmed 64-1998
CREATE VIEW dbo.ActiveVouchers
AS
SELECT voucher_id, promo_code, customer_id, is_percentage, amount, expiry_date
FROM dbo.Voucher
WHERE status = 'Unused'
AND expiry_date >= CAST(GETDATE() AS date);
GO

-- Adam Ahmed Ibrahim - 65-33775
GO
CREATE VIEW dbo.PendingBusinessApprovals
AS
    SELECT
        B.business_id,
        B.[name] AS business_name,
        dbo.GetBusinessType_Helper(B.business_id) AS business_type,
        Z.zone_name,
        U.first_name + ' ' + U.last_name AS partner_name
    FROM Business B
    INNER JOIN [Zone] Z ON Z.zone_id = B.zone_id
    INNER JOIN [Partner] P ON P.partner_id = B.partner_id
    INNER JOIN Users U ON U.[user_id] = P.partner_id
    WHERE B.[status] = 'Pending'
GO

-- Maryam Mustafa Abdelwahab - 64-3003
CREATE VIEW dbo.RiderPerformanceSummary
AS 
SELECT r.rider_id, u.first_name + ' ' + u.last_name AS rider_name,
z.zone_name, COUNT(CASE WHEN s.status='Delivered' THEN 1 END) AS completed_deliveries,
CAST(AVG(CAST(d.rider_rating AS decimal(10,2))) as decimal(10,2)) as avg_rating
FROM dbo.Rider r
INNER JOIN dbo.Users as u ON u.user_id=r.rider_id
INNER JOIN dbo.Zone AS z ON z.zone_id=r.zone_id
LEFT JOIN dbo.Delivery AS d ON d.rider_id=r.rider_id
LEFT JOIN dbo.SubOrder AS s ON s.suborder_id=d.suborder_id
GROUP BY r.rider_id,u.first_name,u.last_name,r.zone_id,z.zone_name;
GO

-- Adam Ahmed Ibrahim - 65-33775
GO
CREATE VIEW dbo.TopSellingProducts
AS
SELECT TOP 10
    CI.product_id,
    P.[name] AS product_name,
    B.[name] AS business_name,
    dbo.GetBusinessType_Helper(B.business_id) AS business_type,
    SUM(CI.quantity) AS units_sold,
    SUM(CI.quantity * CI.unit_price) AS total_revenue
FROM Cart C
INNER JOIN CartItem CI ON CI.cart_id = C.cart_id
INNER JOIN Orders O ON O.cart_id = C.cart_id
INNER JOIN SubOrder SO ON SO.order_id = O.order_id
INNER JOIN [Product] P ON P.product_id = CI.product_id
INNER JOIN Business B ON B.business_id = P.business_id AND B.business_id = SO.business_id
WHERE SO.[status] <> 'Cancelled'
GROUP BY
    CI.product_id,
    P.[name],
    B.[name],
    dbo.GetBusinessType_Helper(B.business_id)
ORDER BY units_sold DESC, CI.product_id ASC
GO

-- Maryam Mustafa Abdelwahab - 64-3003
CREATE VIEW dbo.ZoneDeliveryPerformance
AS
SELECT z.zone_id , z.zone_name , COUNT(dd.delivery_id) AS delivery_count,
CAST(AVG(CAST(dd.tracking_time as decimal(10,2))) as decimal(10,2)) as avg_tracking_time
FROM dbo.Zone z
LEFT JOIN ( select o.zone_id , d.delivery_id , d.tracking_time FROM dbo.Orders AS o 
INNER JOIN dbo.SubOrder AS s ON s.order_id=o.order_id
INNER JOIN dbo.Delivery AS d ON d.suborder_id=s.suborder_id
WHERE s.status='Delivered')
AS  dd ON dd.zone_id=z.zone_id
GROUP BY z.zone_id,z.zone_name;
GO

-- Gelan Ahmed 64-1998
CREATE PROCEDURE dbo.Customer_Register
@first_name varchar(30), @middle_name varchar(30), @last_name varchar(30),
@username varchar(30), @password varchar(30), @email varchar(100),
@phone char(11), @dob date
AS
BEGIN
    IF @first_name IS NULL OR LTRIM(RTRIM(@first_name)) = ''
       OR @last_name IS NULL OR LTRIM(RTRIM(@last_name)) = ''
       OR @username IS NULL OR LTRIM(RTRIM(@username)) = ''
       OR @password IS NULL OR @password = ''
       OR @email IS NULL OR @email NOT LIKE '%_@_%._%'
       OR @phone IS NULL OR LEN(@phone) <> 11 OR @phone LIKE '%[^0-9]%'
       OR (@dob IS NOT NULL AND @dob > CAST(GETDATE() AS date))
        RETURN -1;

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE username = @username OR email = @email)
        RETURN -2;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Users (first_name, middle_name, last_name, username, password, email, dob)
        VALUES (@first_name, @middle_name, @last_name, @username, @password, @email, @dob);

        DECLARE @user_id int = SCOPE_IDENTITY();

        INSERT INTO dbo.User_Phone (user_id, phone)
        VALUES (@user_id, @phone);

        INSERT INTO dbo.Customer (customer_id, wallet_balance)
        VALUES (@user_id, 0);

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() IN (2601, 2627)
            RETURN -2;

        RETURN -1;
    END CATCH;
END;
GO

-- Gelan Ahmed 64-1998
CREATE PROCEDURE dbo.Partner_Register
@first_name varchar(30), @middle_name varchar(30), @last_name varchar(30),
@username varchar(30), @password varchar(30), @email varchar(100),
@phone char(11), @dob date
AS
BEGIN
    IF @first_name IS NULL OR LTRIM(RTRIM(@first_name)) = ''
       OR @last_name IS NULL OR LTRIM(RTRIM(@last_name)) = ''
       OR @username IS NULL OR LTRIM(RTRIM(@username)) = ''
       OR @password IS NULL OR LTRIM(RTRIM(@password)) = ''
       OR @email IS NULL OR @email NOT LIKE '%_@_%._%'
       OR @phone IS NULL OR LEN(@phone) <> 11 OR @phone LIKE '%[^0-9]%'
       OR (@dob IS NOT NULL AND @dob > CAST(GETDATE() AS date))
        RETURN -1;

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE username = @username OR email = @email)
        RETURN -2;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Users (first_name, middle_name, last_name, username, password, email, dob)
        VALUES (@first_name, @middle_name, @last_name, @username, @password, @email, @dob);

        DECLARE @user_id int = SCOPE_IDENTITY();

        INSERT INTO dbo.User_Phone (user_id, phone)
        VALUES (@user_id, @phone);

        INSERT INTO dbo.Partner (partner_id)
        VALUES (@user_id);

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() IN (2601, 2627)
            RETURN -2;

        RETURN -1;
    END CATCH;
END;
GO

-- Gelan Ahmed 64-1998
CREATE PROCEDURE dbo.Rider_Register
    @first_name varchar(30),
    @middle_name varchar(30),
    @last_name varchar(30),
    @username varchar(30),
    @password varchar(30),
    @email varchar(100),
    @phone char(11),
    @dob date,
    @vehicle_type varchar(30),
    @plate_no varchar(15),
    @license_no varchar(20),
    @zone_id int
AS
BEGIN
    SET NOCOUNT ON;

    IF @first_name IS NULL OR LTRIM(RTRIM(@first_name)) = ''
       OR @last_name IS NULL OR LTRIM(RTRIM(@last_name)) = ''
       OR @username IS NULL OR LTRIM(RTRIM(@username)) = ''
       OR @password IS NULL OR LTRIM(RTRIM(@password)) = ''
       OR @email IS NULL OR @email NOT LIKE '%_@_%._%'
       OR @phone IS NULL OR LEN(@phone) <> 11 OR @phone LIKE '%[^0-9]%'
       OR (@dob IS NOT NULL AND @dob > CAST(GETDATE() AS date))
       OR @vehicle_type IS NULL OR LTRIM(RTRIM(@vehicle_type)) = ''
       OR @plate_no IS NULL OR LTRIM(RTRIM(@plate_no)) = ''
       OR @license_no IS NULL OR LTRIM(RTRIM(@license_no)) = ''
       OR @zone_id IS NULL
        RETURN -1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Zone WHERE zone_id = @zone_id)
        RETURN -1;

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE username = @username OR email = @email)
       OR EXISTS (SELECT 1 FROM dbo.Rider WHERE plate_no = @plate_no OR license_no = @license_no)
        RETURN -2;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Users (first_name, middle_name, last_name, username, password, email, dob)
        VALUES (@first_name, @middle_name, @last_name, @username, @password, @email, @dob);

        DECLARE @user_id int = SCOPE_IDENTITY();

        INSERT INTO dbo.User_Phone (user_id, phone)
        VALUES (@user_id, @phone);

        INSERT INTO dbo.Rider (rider_id, vehicle_type, plate_no, license_no, is_available, zone_id)
        VALUES (@user_id, @vehicle_type, @plate_no, @license_no, 1, @zone_id);

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() IN (2601, 2627)
            RETURN -2;

        RETURN -1;
    END CATCH;
END;
GO

-- Gelan Ahmed 64-1998
CREATE FUNCTION dbo.CustomerLoginValidation
(@username varchar(30), @password varchar(30))
RETURNS bit
AS
BEGIN
    IF @username IS NULL OR @password IS NULL
        RETURN 0;

    IF EXISTS (SELECT 1
               FROM dbo.Users u
               INNER JOIN dbo.Customer c ON c.customer_id = u.user_id
               WHERE u.username = @username
               AND u.password = @password COLLATE Latin1_General_CS_AS
               AND u.account_status = 'Active')
        RETURN 1;

    RETURN 0;
END;
GO

-- Gelan Ahmed 64-1998
CREATE FUNCTION dbo.PartnerLoginValidation
(@username varchar(30), @password varchar(30))
RETURNS bit
AS
BEGIN
    IF @username IS NULL OR @password IS NULL
        RETURN 0;

    IF EXISTS (SELECT 1
               FROM dbo.Users u
               INNER JOIN dbo.Partner p ON p.partner_id = u.user_id
               WHERE u.username = @username
               AND u.password = @password COLLATE Latin1_General_CS_AS
               AND u.account_status = 'Active')
        RETURN 1;

    RETURN 0;
END;
GO

-- Gelan Ahmed 64-1998
CREATE FUNCTION dbo.RiderLoginValidation
(
    @username varchar(30),
    @password varchar(30)
)
RETURNS bit
AS
BEGIN
    DECLARE @success bit = 0;

    IF EXISTS (
        SELECT 1
        FROM dbo.Users u
        INNER JOIN dbo.Rider r
            ON r.rider_id = u.user_id
        WHERE u.username = @username
          AND u.password = @password COLLATE Latin1_General_CS_AS
          AND u.account_status = 'Active'
    )
        SET @success = 1;

    RETURN @success;
END;
GO

-- Gelan Ahmed 64-1998
CREATE FUNCTION dbo.AdminLoginValidation
(
    @username varchar(30),
    @password varchar(30)
)
RETURNS bit
AS
BEGIN
    DECLARE @success bit = 0;

    IF EXISTS (
        SELECT 1
        FROM dbo.Users u
        INNER JOIN dbo.Admin a
            ON a.admin_id = u.user_id
        WHERE u.username = @username
          AND u.password = @password COLLATE Latin1_General_CS_AS
          AND u.account_status = 'Active'
    )
        SET @success = 1;

    RETURN @success;
END;
GO

-- Gelan Ahmed 64-1998
CREATE PROCEDURE dbo.Change_Password
    @user_id int,
    @old_password varchar(30),
    @new_password varchar(30),
    @new_password_repeat varchar(30),
    @success bit OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @success = 0;

    IF @user_id IS NULL
       OR @old_password IS NULL OR LTRIM(RTRIM(@old_password)) = ''
       OR @new_password IS NULL OR LTRIM(RTRIM(@new_password)) = ''
       OR @new_password_repeat IS NULL OR LTRIM(RTRIM(@new_password_repeat)) = ''
        RETURN -1;

   
    IF @new_password COLLATE Latin1_General_CS_AS
       <> @new_password_repeat COLLATE Latin1_General_CS_AS
        RETURN -1;

    BEGIN TRY
        
        UPDATE dbo.Users
        SET password = @new_password
        WHERE user_id = @user_id
          AND password = @old_password COLLATE Latin1_General_CS_AS;

     
        IF @@ROWCOUNT = 1
        BEGIN
            SET @success = 1;
            RETURN 0;
        END;

        RETURN -1;
    END TRY
    BEGIN CATCH
        SET @success = 0;
        RETURN -1;
    END CATCH;
END;
GO


-- Gelan Ahmed 64-1998
CREATE PROCEDURE dbo.Create_Admin
    @first_name varchar(30),
    @middle_name varchar(30),
    @last_name varchar(30),
    @username varchar(30),
    @password varchar(30),
    @email varchar(100),
    @phone char(11),
    @dob date,
    @role varchar(20),
    @zone_id int,
    @super_admin_id int
AS
BEGIN
    SET NOCOUNT ON;

    IF @first_name IS NULL OR LTRIM(RTRIM(@first_name)) = ''
       OR @last_name IS NULL OR LTRIM(RTRIM(@last_name)) = ''
       OR @username IS NULL OR LTRIM(RTRIM(@username)) = ''
       OR @password IS NULL OR LTRIM(RTRIM(@password)) = ''
       OR @email IS NULL OR @email NOT LIKE '%_@_%._%'
       OR @phone IS NULL OR LEN(@phone) <> 11 OR @phone LIKE '%[^0-9]%'
       OR (@dob IS NOT NULL AND @dob > CAST(GETDATE() AS date))
       OR @super_admin_id IS NULL
        RETURN -1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Admin
                   WHERE admin_id = @super_admin_id AND role = 'Super Admin')
        RETURN -3;

    IF @role IS NULL
        SET @role = 'Super Admin';

    IF @role NOT IN ('Super Admin', 'Zone Admin')
        RETURN -1;

    SET @role = CASE WHEN @role = 'Zone Admin' THEN 'Zone Admin' ELSE 'Super Admin' END;

    IF @role = 'Super Admin' AND @zone_id IS NOT NULL
        RETURN -1;

    IF @role = 'Zone Admin'
       AND (@zone_id IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Zone WHERE zone_id = @zone_id))
        RETURN -1;

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE username = @username OR email = @email)
        RETURN -2;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Users (first_name, middle_name, last_name, username, password, email, dob)
        VALUES (@first_name, @middle_name, @last_name, @username, @password, @email, @dob);

        DECLARE @user_id int = SCOPE_IDENTITY();

        INSERT INTO dbo.User_Phone (user_id, phone)
        VALUES (@user_id, @phone);

        INSERT INTO dbo.Admin (admin_id, role, zone_id)
        VALUES (@user_id, @role, @zone_id);

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() IN (2601, 2627)
            RETURN -2;

        RETURN -1;
    END CATCH;
END;
GO

-- Gelan Ahmed 64-1998
CREATE PROCEDURE dbo.Approve_Business
    @business_id int,
    @admin_id int
AS
BEGIN
    SET NOCOUNT ON;

    IF @business_id IS NULL OR @admin_id IS NULL
        RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Business
        WHERE business_id = @business_id
    )
        RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Admin
        WHERE admin_id = @admin_id
    )
        RETURN -3;

    IF EXISTS (
        SELECT 1
        FROM dbo.Admin a
        INNER JOIN dbo.Business b
            ON b.business_id = @business_id
        WHERE a.admin_id = @admin_id
          AND a.role = 'Zone Admin'
          AND (a.zone_id IS NULL OR a.zone_id <> b.zone_id)
    )
        RETURN -3;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Business
        WHERE business_id = @business_id
          AND status = 'Pending'
    )
        RETURN -4;

    UPDATE dbo.Business
    SET status = 'Active'
    WHERE business_id = @business_id;

    RETURN 0;
END;
GO

-- Gelan Ahmed 64-1998
CREATE PROCEDURE dbo.Reject_Business
    @business_id int,
    @admin_id int
AS
BEGIN
    SET NOCOUNT ON;

    IF @business_id IS NULL OR @admin_id IS NULL
        RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Business
        WHERE business_id = @business_id
    )
        RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Admin
        WHERE admin_id = @admin_id
    )
        RETURN -3;

    IF EXISTS (
        SELECT 1
        FROM dbo.Admin a
        INNER JOIN dbo.Business b
            ON b.business_id = @business_id
        WHERE a.admin_id = @admin_id
          AND a.role = 'Zone Admin'
          AND (a.zone_id IS NULL OR a.zone_id <> b.zone_id)
    )
        RETURN -3;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Business
        WHERE business_id = @business_id
          AND status = 'Pending'
    )
        RETURN -4;

    UPDATE dbo.Business
    SET status = 'Rejected'
    WHERE business_id = @business_id;

    RETURN 0;
END;
GO

-- mohamed mostafa hassan mohamed - 65-33784
CREATE FUNCTION dbo.BusinessRefunds(@business_id int)
RETURNS TABLE
AS
RETURN
(
SELECT s.order_id, c.customer_id, p.method,
    CASE WHEN s.total_price + s.delivery_fee > p.amount - p.refunded_amount
         THEN p.amount - p.refunded_amount
         ELSE s.total_price + s.delivery_fee
    END AS refund_amount
FROM dbo.SubOrder s
INNER JOIN dbo.Orders o ON o.order_id = s.order_id
INNER JOIN dbo.Cart c ON c.cart_id = o.cart_id
INNER JOIN dbo.Payment p ON p.order_id = o.order_id
WHERE s.business_id = @business_id AND s.status IN ('Placed', 'Assigned')
);
GO

-- mohamed mostafa hassan mohamed - 65-33784
CREATE PROCEDURE dbo.Suspend_Business
@business_id int, @admin_id int, @reason varchar(255)
AS
BEGIN
    IF @business_id IS NULL OR @admin_id IS NULL OR @reason IS NULL OR @reason = ''
        RETURN -1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Admin WHERE admin_id = @admin_id)
        RETURN -3;

    IF EXISTS (SELECT 1
               FROM dbo.Admin a INNER JOIN dbo.Business b ON a.zone_id <> b.zone_id
               WHERE a.admin_id = @admin_id AND a.role = 'Zone Admin'
               AND b.business_id = @business_id)
        RETURN -3;

    IF NOT EXISTS (SELECT 1 FROM dbo.Business
                   WHERE business_id = @business_id AND status = 'Active')
        RETURN -4;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Customer
        SET wallet_balance = wallet_balance +
            (SELECT SUM(r.refund_amount) FROM dbo.BusinessRefunds(@business_id) r
             WHERE r.customer_id = Customer.customer_id
             AND r.method <> 'Cash')
        WHERE customer_id IN (SELECT customer_id FROM dbo.BusinessRefunds(@business_id)
                              WHERE method <> 'Cash');

        UPDATE dbo.Payment
        SET refunded_amount = refunded_amount +
            (SELECT r.refund_amount FROM dbo.BusinessRefunds(@business_id) r
             WHERE r.order_id = Payment.order_id)
        WHERE order_id IN (SELECT order_id FROM dbo.BusinessRefunds(@business_id));

        UPDATE dbo.SubOrder
        SET status = 'Cancelled'
        WHERE business_id = @business_id AND status IN ('Placed', 'Assigned');

        UPDATE dbo.Orders
        SET status = CASE
            WHEN NOT EXISTS (SELECT 1 FROM dbo.SubOrder s
                             WHERE s.order_id = Orders.order_id
                             AND s.status <> 'Cancelled') THEN 'Cancelled'
            WHEN NOT EXISTS (SELECT 1 FROM dbo.SubOrder s
                             WHERE s.order_id = Orders.order_id
                             AND s.status NOT IN ('Cancelled', 'Delivered')) THEN 'Delivered'
            WHEN EXISTS (SELECT 1 FROM dbo.SubOrder s
                         WHERE s.order_id = Orders.order_id
                         AND s.status IN ('Picked Up', 'Delivered')) THEN 'In Progress'
            ELSE 'Placed'
        END
        WHERE order_id IN (SELECT order_id FROM dbo.SubOrder
                          WHERE business_id = @business_id AND status = 'Cancelled');

        UPDATE dbo.Voucher
        SET status = 'Unused'
        WHERE voucher_id IN
            (SELECT voucher_id FROM dbo.Orders
             WHERE status = 'Cancelled'
             AND order_id IN (SELECT order_id FROM dbo.SubOrder
                          WHERE business_id = @business_id AND status = 'Cancelled'));

        UPDATE dbo.Orders
        SET voucher_id = NULL
        WHERE status = 'Cancelled'
        AND order_id IN (SELECT order_id FROM dbo.SubOrder
                          WHERE business_id = @business_id AND status = 'Cancelled');

        UPDATE dbo.Product
        SET is_available = 0
        WHERE business_id = @business_id;

        UPDATE dbo.Business
        SET status = 'Suspended', suspension_reason = @reason
        WHERE business_id = @business_id;

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        RETURN -1;
    END CATCH
END;
GO

-- mohamed mostafa hassan mohamed - 65-33784
CREATE PROCEDURE dbo.Reinstate_Business
@business_id int, @super_admin_id int
AS
BEGIN
    IF @business_id IS NULL OR @super_admin_id IS NULL
        RETURN -1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Admin
                   WHERE admin_id = @super_admin_id AND role = 'Super Admin')
        RETURN -3;

    IF NOT EXISTS (SELECT 1 FROM dbo.Business
                   WHERE business_id = @business_id AND status = 'Suspended')
        RETURN -4;

    UPDATE dbo.Business
    SET status = 'Active', suspension_reason = NULL
    WHERE business_id = @business_id;
    RETURN 0;
END;
GO

-- mohamed mostafa hassan mohamed - 65-33784
CREATE PROCEDURE dbo.Create_Zone
@zone_name varchar(50), @delivery_fee decimal(10,2), @super_admin_id int
AS
BEGIN
    IF @zone_name IS NULL OR @zone_name = '' OR @delivery_fee IS NULL
       OR @delivery_fee < 0 OR @super_admin_id IS NULL
        RETURN -1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Admin
                   WHERE admin_id = @super_admin_id AND role = 'Super Admin')
        RETURN -3;

    IF EXISTS (SELECT 1 FROM dbo.Zone WHERE zone_name = @zone_name)
        RETURN -2;

    INSERT INTO dbo.Zone (zone_name, delivery_fee)
    VALUES (@zone_name, @delivery_fee);
    RETURN 0;
END;
GO

-- mohamed mostafa hassan mohamed - 65-33784
CREATE PROCEDURE dbo.Update_Zone_Fee
@zone_id int, @new_fee decimal(10,2), @super_admin_id int
AS
BEGIN
    IF @zone_id IS NULL OR @new_fee IS NULL OR @new_fee < 0 OR @super_admin_id IS NULL
        RETURN -1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Admin
                   WHERE admin_id = @super_admin_id AND role = 'Super Admin')
        RETURN -3;

    UPDATE dbo.Zone
    SET delivery_fee = @new_fee
    WHERE zone_id = @zone_id;
    RETURN 0;
END;
GO

-- Gelan Ahmed 64-1998
CREATE PROCEDURE dbo.Assign_Admin_Zone
    @admin_id int,
    @zone_id int,
    @super_admin_id int
AS
BEGIN
    SET NOCOUNT ON;

    IF @admin_id IS NULL
       OR @zone_id IS NULL
       OR @super_admin_id IS NULL
        RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Admin
        WHERE admin_id = @super_admin_id
    ) OR NOT EXISTS (
        SELECT 1
        FROM dbo.Admin
        WHERE admin_id = @admin_id
    )
    RETURN -1;

    IF EXISTS (
        SELECT 1
        FROM dbo.Admin
        WHERE admin_id = @super_admin_id
            AND role <> 'Super Admin'
    )
    RETURN -3;

    IF EXISTS (
        SELECT 1
        FROM dbo.Admin
        WHERE admin_id = @admin_id
            AND role <> 'Zone Admin'
    )
    RETURN -1;

    UPDATE dbo.Admin
    SET zone_id = @zone_id
    WHERE admin_id = @admin_id;

    RETURN 0;
END;
GO
-- Gelan Ahmed 64-1998
CREATE PROCEDURE dbo.Issue_Voucher
    @customer_id int,
    @promo_code varchar(30),
    @is_percentage bit,
    @amount decimal(10,2),
    @expiry_date date,
    @admin_id int
AS
BEGIN
    SET NOCOUNT ON;
    IF @customer_id IS NULL
       OR @promo_code IS NULL OR LTRIM(RTRIM(@promo_code)) = ''
       OR @is_percentage IS NULL
       OR @amount IS NULL OR @amount <= 0
       OR @expiry_date IS NULL
       OR @admin_id IS NULL
        RETURN -1;

    IF @is_percentage = 1 AND (@amount < 1 OR @amount > 100)
        RETURN -1;

    IF @expiry_date < CAST(GETDATE() AS date)
        RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Customer
        WHERE customer_id = @customer_id
    )
        RETURN -1;

    IF EXISTS (
        SELECT 1
        FROM dbo.Users
        WHERE user_id = @customer_id
          AND account_status = 'Blacklisted'
    )
        RETURN -3;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Admin
        WHERE admin_id = @admin_id
    )
        RETURN -3;

    IF EXISTS (
        SELECT 1
        FROM dbo.Voucher
        WHERE promo_code = @promo_code
    )
        RETURN -2;

    BEGIN TRY
        INSERT INTO dbo.Voucher
            (promo_code, is_percentage, amount, expiry_date, status, customer_id)
        VALUES
            (@promo_code, @is_percentage, @amount, @expiry_date, 'Unused', @customer_id);

        RETURN 0;
    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() IN (2601, 2627)
            RETURN -2;

        RETURN -1;
    END CATCH;
END;
GO

-- Gelan Ahmed 64-1998
CREATE PROCEDURE dbo.Blacklist_Customer
@customer_id int, @admin_id int, @reason varchar(255)
AS
BEGIN
    IF @customer_id IS NULL OR @admin_id IS NULL OR @reason IS NULL OR LTRIM(RTRIM(@reason)) = ''
        RETURN -1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE customer_id = @customer_id)
        RETURN -1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Admin WHERE admin_id = @admin_id)
        RETURN -3;


    IF EXISTS (SELECT 1 FROM dbo.Admin ad
               WHERE ad.admin_id = @admin_id AND ad.role = 'Zone Admin'
               AND NOT EXISTS (SELECT 1 FROM dbo.Address a
                               WHERE a.customer_id = @customer_id AND a.zone_id = ad.zone_id))
        RETURN -3;


    IF EXISTS (SELECT 1 FROM dbo.Users
               WHERE user_id = @customer_id AND account_status = 'Blacklisted')
        RETURN -4;

    DECLARE @order_id int = 0, @result int;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Users
        SET account_status = 'Blacklisted'
        WHERE user_id = @customer_id;

        INSERT INTO dbo.Blacklist (customer_id, admin_id, reason)
        VALUES (@customer_id, @admin_id, @reason);

        WHILE 1 = 1
        BEGIN
            SELECT @order_id = MIN(o.order_id)
            FROM dbo.Orders o
            INNER JOIN dbo.Cart c ON c.cart_id = o.cart_id
            WHERE c.customer_id = @customer_id
            AND o.order_id > @order_id
            AND o.status <> 'Cancelled'
            AND NOT EXISTS (SELECT 1 FROM dbo.SubOrder s
                            WHERE s.order_id = o.order_id
                            AND s.status IN ('Picked Up', 'Delivered'));

            IF @order_id IS NULL
                BREAK;

            EXEC @result = dbo.Cancel_Order @order_id;

            IF @result <> 0
            BEGIN
                IF @@TRANCOUNT > 0
                    ROLLBACK TRANSACTION;
                RETURN -1;
            END;
        END;

        DELETE FROM dbo.Voucher
        WHERE customer_id = @customer_id AND status = 'Unused';

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        RETURN -1;
    END CATCH;
END;
GO

-- Gelan Ahmed 64-1998
CREATE PROCEDURE dbo.Lift_Customer_Blacklist
    @customer_id int,
    @admin_id int
AS
BEGIN
    SET NOCOUNT ON;

    IF @customer_id IS NULL OR @admin_id IS NULL
        RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Customer
        WHERE customer_id = @customer_id
    )
        RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Admin
        WHERE admin_id = @admin_id
    )
        RETURN -3;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Blacklist
        WHERE customer_id = @customer_id
    )
        RETURN -4;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Blacklist
        WHERE customer_id = @customer_id
          AND admin_id = @admin_id
    )
        RETURN -3;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Users
        SET account_status = 'Active'
        WHERE user_id = @customer_id;

        DELETE FROM dbo.Blacklist
        WHERE customer_id = @customer_id;

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        RETURN -1;
    END CATCH;
END;
GO
-- mohamed mostafa hassan mohamed - 65-33784
CREATE FUNCTION dbo.ZoneOrderReport(@zone_id int, @from_date date, @to_date date)
RETURNS TABLE
AS
RETURN
(
    SELECT z.zone_id, z.zone_name, COUNT(o.order_id) AS number_of_orders,
           CAST(AVG(o.total_amount) AS decimal(10,2)) AS avg_order_total,
           CAST(ISNULL((SELECT SUM(s.total_price) * 0.10
                        FROM dbo.SubOrder s INNER JOIN dbo.Orders o2 ON o2.order_id = s.order_id
                        WHERE o2.zone_id = z.zone_id AND o2.status <> 'Cancelled'
                        AND s.status <> 'Cancelled'
                        AND CAST(o2.order_date AS date) BETWEEN @from_date AND @to_date), 0)
                AS decimal(10,2)) AS platform_commission
    FROM dbo.Zone z
    LEFT JOIN dbo.Orders o ON o.zone_id = z.zone_id AND o.status <> 'Cancelled'
         AND CAST(o.order_date AS date) BETWEEN @from_date AND @to_date
    WHERE z.zone_id = @zone_id AND @from_date <= @to_date
    GROUP BY z.zone_id, z.zone_name
);
GO

-- Maryam Mustafa 64-3003
CREATE FUNCTION dbo.TopRiders (@from_date date, @to_date date)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP 5
           ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC, r.rider_id ASC) AS rider_rank,
           r.rider_id,
           u.first_name + ' ' + u.last_name AS rider_name,
           COUNT(*) AS completed_delivery_count
    FROM dbo.Rider AS r
    INNER JOIN dbo.Users AS u ON u.user_id = r.rider_id
    INNER JOIN dbo.Delivery AS d ON d.rider_id = r.rider_id
    INNER JOIN dbo.SubOrder AS s ON s.suborder_id = d.suborder_id
    WHERE s.status = 'Delivered'
      AND CAST(d.delivered_at AS date) BETWEEN @from_date AND @to_date
    GROUP BY r.rider_id, u.first_name, u.last_name
    ORDER BY rider_rank
);
GO


-- mohamed mostafa hassan mohamed - 65-33784
CREATE FUNCTION dbo.Daily_Revenue_Report(@report_date date)
RETURNS TABLE
AS
RETURN
(
    SELECT z.zone_name, CAST('Restaurant' AS varchar(20)) AS business_type,
           COUNT(*) AS number_of_suborders,
           CAST(SUM(s.total_price) AS decimal(10,2)) AS gross_sales,
           CAST(SUM(s.delivery_fee) AS decimal(10,2)) AS delivery_fees,
           CAST(SUM(s.total_price) * 0.10 AS decimal(10,2)) AS platform_commission
    FROM dbo.Orders o
    INNER JOIN dbo.Zone z ON z.zone_id = o.zone_id
    INNER JOIN dbo.SubOrder s ON s.order_id = o.order_id
    INNER JOIN dbo.Restaurant r ON r.business_id = s.business_id
    WHERE CAST(o.order_date AS date) = @report_date AND s.status <> 'Cancelled'
    GROUP BY z.zone_id, z.zone_name

    UNION ALL

    SELECT z.zone_name, CAST('Pharmacy' AS varchar(20)), COUNT(*),
           CAST(SUM(s.total_price) AS decimal(10,2)),
           CAST(SUM(s.delivery_fee) AS decimal(10,2)),
           CAST(SUM(s.total_price) * 0.10 AS decimal(10,2))
    FROM dbo.Orders o
    INNER JOIN dbo.Zone z ON z.zone_id = o.zone_id
    INNER JOIN dbo.SubOrder s ON s.order_id = o.order_id
    INNER JOIN dbo.Pharmacy p ON p.business_id = s.business_id
    WHERE CAST(o.order_date AS date) = @report_date AND s.status <> 'Cancelled'
    GROUP BY z.zone_id, z.zone_name
);
GO

-- Adam Ahmed Ibrahim - 65-33775
GO
CREATE PROCEDURE dbo.Register_Business
    @partner_id INT,
    @name VARCHAR(100),
    @description VARCHAR(255),
    @link_website VARCHAR(255),
    @zone_id INT,
    @opening_hour TIME,
    @closing_hour TIME,
    @expected_delivery_time INT,
    @phone CHAR(11),
    @business_type VARCHAR(20),
    @cuisine_type VARCHAR(50),
    @food_category VARCHAR(50),
    @pharmacy_type VARCHAR(50)
AS
BEGIN
    IF @name IS NULL
        OR @opening_hour IS NULL
        OR @closing_hour IS NULL
        OR @expected_delivery_time IS NULL
        OR @expected_delivery_time <= 0
        OR @partner_id IS NULL
        OR @zone_id IS NULL
        OR @phone IS NULL
        OR LEN(@phone) <> 11
        OR @phone LIKE '%[^0-9]%'
        OR @business_type IS NULL
        OR @business_type NOT IN ('Restaurant', 'Pharmacy')
    RETURN -1;

    IF @business_type = 'Restaurant'
        AND (@cuisine_type IS NULL OR @food_category IS NULL)
    RETURN -1;

    IF @business_type = 'Pharmacy'
        AND (@pharmacy_type IS NULL)
    RETURN -1;

    DECLARE @business_id INT;

    SELECT @business_id = B.business_id
    FROM Business B
    WHERE B.partner_id = @partner_id;

    -- If this partner registered before
    IF @business_id IS NOT NULL
    BEGIN
        -- They already have a business
        IF EXISTS (
            SELECT 1
            FROM Business B
            WHERE B.business_id = @business_id
                AND B.[status] IN ('Active', 'Pending', 'Suspended')
        )
        RETURN -2;

        -- They registered before but the business was rejected
        -- Updating business info
        BEGIN TRY
            BEGIN TRANSACTION
                UPDATE dbo.Business
                SET [name] = @name,
                    [description] = @description,
                    link_website = @link_website,
                    opening_hour = @opening_hour,
                    closing_hour = @closing_hour,
                    expected_delivery_time = @expected_delivery_time,
                    [status] = 'Pending',
                    suspension_reason = NULL,
                    zone_id = @zone_id
                WHERE business_id = @business_id;

                -- Updating phone number
                DELETE FROM dbo.Business_Phone
                WHERE business_id = @business_id;

                INSERT INTO dbo.Business_Phone (business_id, phone)
                VALUES (@business_id, @phone);

                -- Updating business type
                DELETE FROM dbo.Restaurant
                WHERE business_id = @business_id;

                DELETE FROM dbo.Pharmacy
                WHERE business_id = @business_id;

                IF @business_type = 'Restaurant'
                BEGIN
                    INSERT INTO dbo.Restaurant (business_id, cuisine_type, food_category)
                    VALUES (@business_id, @cuisine_type, @food_category);
                END
                ELSE
                BEGIN
                    INSERT INTO dbo.Pharmacy (business_id, pharmacy_type)
                    VALUES (@business_id, @pharmacy_type);
                END
            COMMIT TRANSACTION
            RETURN 0;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
            BEGIN
                ROLLBACK TRANSACTION;
            END
            RETURN -1;
        END CATCH
    END

    BEGIN TRY
        BEGIN TRANSACTION
            INSERT INTO dbo.Business (
            [name],
            [description],
            link_website,
            opening_hour,
            closing_hour,
            expected_delivery_time,
            partner_id,
            zone_id
            )
            VALUES (
                @name,
                @description,
                @link_website,
                @opening_hour,
                @closing_hour,
                @expected_delivery_time,
                @partner_id,
                @zone_id
            );

            SELECT @business_id = B.business_id
            FROM dbo.Business B
            WHERE B.partner_id = @partner_id;

            INSERT INTO dbo.Business_Phone (business_id, phone)
            VALUES (@business_id, @phone);

            IF @business_type = 'Restaurant'
            BEGIN
                INSERT INTO dbo.Restaurant (business_id, cuisine_type, food_category)
                VALUES (@business_id, @cuisine_type, @food_category);
            END
            ELSE
            BEGIN
                INSERT INTO dbo.Pharmacy (business_id, pharmacy_type)
                VALUES (@business_id, @pharmacy_type);
            END

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END
        RETURN -1;
    END CATCH
END
GO

-- Adam Ahmed Ibrahim - 65-33775
GO
CREATE PROCEDURE dbo.Update_Business_Info
    @business_id INT,
    @opening_hour TIME,
    @closing_hour TIME,
    @phone CHAR(11),
    @link_website VARCHAR(255)
AS
BEGIN
    IF @business_id IS NULL
        OR @opening_hour IS NULL
        OR @closing_hour IS NULL
        OR @phone IS NULL
        OR LEN(@phone) <> 11
        OR @phone LIKE '%[^0-9]%'
    RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM Business
        WHERE business_id = @business_id
    )
    RETURN -1;

    IF EXISTS (
        SELECT 1
        FROM Business_Phone BP
        WHERE BP.business_id = @business_id
            AND BP.phone = @phone
    )
    RETURN -2;

    BEGIN TRY
        BEGIN TRANSACTION;
            UPDATE Business
            SET opening_hour = @opening_hour,
                closing_hour = @closing_hour,
                link_website = @link_website
            WHERE business_id = @business_id;

            INSERT INTO Business_Phone (business_id, phone)
            VALUES (@business_id, @phone)

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        RETURN -1;
    END CATCH;
END
GO

-- Adam Ahmed Ibrahim - 65-33775
GO
CREATE PROCEDURE dbo.Upsert_Product
    @business_id INT,
    @product_id INT,
    @name VARCHAR(100),
    @description VARCHAR(255),
    @category VARCHAR(50),
    @price DECIMAL(10,2),
    @is_available BIT
AS
BEGIN
    IF @business_id IS NULL
        OR @name IS NULL
        OR @category IS NULL
        OR @price IS NULL
        OR @price <= 0
        OR @is_available IS NULL
    RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM Business
        WHERE business_id = @business_id
    )
    RETURN -1;

    IF EXISTS (
        SELECT 1
        FROM Business
        WHERE business_id = @business_id
            AND [status] = 'Suspended'
    )
    RETURN -4;

    IF @product_id IS NULL
    BEGIN
        BEGIN TRY
            INSERT INTO dbo.[Product] (
                [name],
                [description],
                category,
                price,
                is_available,
                business_id
            )
            VALUES (
                @name,
                @description,
                @category,
                @price,
                @is_available,
                @business_id
            );
        END TRY
        BEGIN CATCH
            RETURN -1;
        END CATCH;
    END
    ELSE
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM [Product]
            WHERE product_id = @product_id
        )
        RETURN -1;

        -- Owned by another business
        IF EXISTS (
            SELECT 1
            FROM [Product]
            WHERE product_id = @product_id
                AND business_id <> @business_id
        )
        RETURN -3;

        -- Violation of discount constraint on products
        IF EXISTS (
            SELECT 1
            FROM [Product]
            WHERE product_id = @product_id
                AND business_id = @business_id
                AND discount_amount > 0.5 * @price
        )
        RETURN -1;

        BEGIN TRY
            UPDATE dbo.[Product]
            SET [name] = @name,
                [description] = @description,
                category = @category,
                price = @price,
                is_available = @is_available
            WHERE product_id = @product_id
                AND business_id = @business_id;
        END TRY
        BEGIN CATCH
            RETURN -1;
        END CATCH;
    END

    RETURN 0;
END
GO

-- Adam Ahmed Ibrahim - 65-33775
GO
CREATE PROCEDURE Toggle_Product_Status
    @product_id INT,
    @is_available BIT
AS
BEGIN
    IF @product_id IS NULL
        OR @is_available IS NULL
    RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM [Product]
        WHERE product_id = @product_id
    )
    RETURN -1;

    -- Suspended business
    IF @is_available = 1
        AND EXISTS (
            SELECT 1
            FROM [Product] P
            INNER JOIN Business B ON B.business_id = P.business_id
            WHERE P.product_id = @product_id
                AND B.[status] = 'Suspended'
        )
    RETURN -4;

    UPDATE [Product]
    SET is_available = @is_available
    WHERE product_id = @product_id;

    RETURN 0;
END
GO

-- Adam Ahmed Ibrahim - 65-33775
GO
CREATE PROCEDURE dbo.Set_Product_Promotion
    @product_id INT,
    @discount_amount DECIMAL(10,2)
AS
BEGIN
    IF @product_id IS NULL
        OR @discount_amount IS NULL
        OR @discount_amount < 0
    RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM [Product]
        WHERE product_id = @product_id
    )
    RETURN -1;

    -- Invalid discount amount
    IF EXISTS (
        SELECT 1
        FROM [Product]
        WHERE product_id = @product_id
            AND @discount_amount > 0.5 * price
    )
    RETURN -1;

    UPDATE [Product]
    SET discount_amount = @discount_amount
    WHERE product_id = @product_id;

    RETURN 0;
END
GO

-- Adam Ahmed Ibrahim - 65-33775
GO
CREATE FUNCTION BusinessSalesReport(@business_id INT, @from_date DATE, @to_date DATE)
RETURNS TABLE
AS
RETURN
(
    SELECT
        P.product_id,
        P.[name] AS product_name,
        SUM(CI.quantity) AS units_sold,
        SUM(CI.quantity * CI.unit_price) AS revenue_per_product 
    FROM Business B
    INNER JOIN SubOrder SO ON
        SO.[status] <> 'Cancelled'
        AND SO.business_id = B.business_id
    INNER JOIN Orders O ON
        (CAST(O.order_date AS DATE) BETWEEN @from_date AND @to_date)
        AND O.order_id = SO.order_id
    INNER JOIN [Product] P ON P.business_id = B.business_id
    INNER JOIN CartItem CI ON CI.product_id = P.product_id
    INNER JOIN Cart C ON
        C.cart_id = O.cart_id
        AND C.cart_id = CI.cart_id
    WHERE B.business_id = @business_id
    GROUP BY P.product_id, P.[name]
)
GO

-- Maryam Mustafa Abdelwahab - 64-3003
GO
CREATE FUNCTION dbo.BusinessFeedbackOverview (@business_id int)
RETURNS TABLE
AS
RETURN
(
  SELECT CAST(AVG(CAST(f.rating AS decimal(10,2))) as decimal (10,2)) AS avg_rating, 
  COUNT(*) AS number_of_feedbacks, COUNT(CASE WHEN f.rating=5 THEN 1 END) AS five_star,
  COUNT(CASE WHEN f.rating = 4 THEN 1 END) AS four_star,
           COUNT(CASE WHEN f.rating = 3 THEN 1 END) AS three_star,
           COUNT(CASE WHEN f.rating = 2 THEN 1 END) AS two_star,
           COUNT(CASE WHEN f.rating = 1 THEN 1 END) AS one_star
    FROM dbo.Feedback AS f
    INNER JOIN dbo.SubOrder AS s ON s.suborder_id=f.suborder_id
    where s.business_id=@business_id
    HAVING EXISTS (SELECT 1 FROM dbo.Business WHERE business_id=@business_id));
GO

GO
--yehia tamer mohamed 64-1694
CREATE PROCEDURE Add_Customer_Address 
@customer_id INT, @description VARCHAR(150), @zone_id INT
AS BEGIN
    IF @customer_id IS NULL OR @zone_id IS NULL OR @description IS NULL OR @description=''
        RETURN -1;
    ELSE IF NOT EXISTS (SELECT * FROM Customer WHERE customer_id=@customer_id) OR NOT EXISTS (SELECT * FROM Zone where zone_id=@zone_id)
        RETURN -1;
    ELSE
        BEGIN
            BEGIN TRY
                BEGIN TRANSACTION;
                    DECLARE @new_id INT;
                  
                    INSERT INTO Address (customer_id,description,zone_id) VALUES
                    (@customer_id,@description,@zone_id);

                    SET @new_id=SCOPE_IDENTITY(); --this gets the id for the latest insert

                    UPDATE Address SET is_active=0 WHERE address_id<>@new_id AND customer_id=@customer_id;
                COMMIT TRANSACTION;
                RETURN 0;
            END TRY

            BEGIN CATCH
                IF @@TRANCOUNT>0
                    ROLLBACK TRANSACTION;
                RETURN -1;
            END CATCH
        END
END
GO

--yehia tamer mohamed 64-1694
CREATE PROCEDURE Update_Delete_Customer_Address 
@customer_id INT, @address_id INT, @description VARCHAR(150), @zone_id INT, @action VARCHAR(20)
AS BEGIN
    IF @customer_id IS NULL OR @address_id IS NULL OR @action IS NULL OR @action NOT IN ('update','delete')
        RETURN -1;
    ELSE IF @customer_id<>(SELECT customer_id FROM Address where address_id=@address_id)
        RETURN -3;
    ELSE IF NOT EXISTS(SELECT * FROM Address WHERE customer_id=@customer_id AND address_id=@address_id)
        RETURN -1;
    ELSE IF EXISTS (
        SELECT * FROM Address a
        INNER JOIN Customer cu on cu.customer_id=a.customer_id
        INNER JOIN Cart ca on ca.customer_id=cu.customer_id AND ca.address_id=a.address_id
        INNER JOIN Orders o on o.cart_id=ca.cart_id
        WHERE a.address_id=@address_id AND o.status IN ('Placed','In Progress')
    )
        RETURN -4;
    ELSE
        BEGIN
             IF @action='update'
                BEGIN

                    IF @description IS NULL OR @description='' OR @zone_id IS NULL
                        RETURN -1;
                    BEGIN TRY 
                        UPDATE Address SET description=@description,zone_id=@zone_id
                        WHERE address_id=@address_id;

                        RETURN 0;
                    END TRY
                    BEGIN CATCH
                        RETURN -1;
                    END CATCH
                END
             ELSE
                BEGIN
                    
                    IF EXISTS (
                        SELECT * FROM Address a
                        INNER JOIN Customer cu on cu.customer_id=a.customer_id
                        INNER JOIN Cart ca on ca.customer_id=cu.customer_id
                        WHERE ca.address_id=@address_id
                    )
                        RETURN -4;

                    BEGIN TRY
                        DELETE FROM Address
                        WHERE address_id=@address_id;

                        RETURN 0;
                    END TRY
                    BEGIN CATCH
                        RETURN -1;
                    END CATCH
                END
       END
END
GO

--yehia tamer mohamed 64-1694
CREATE PROCEDURE Change_Active_Address
@customer_id INT, @new_address_id INT
AS BEGIN
    IF @customer_id IS NULL OR @new_address_id IS NULL
        RETURN -1;
    ELSE IF @customer_id<>(SELECT customer_id FROM Address WHERE address_id=@new_address_id)
        RETURN -3;
    ELSE IF NOT EXISTS(SELECT * FROM Address WHERE customer_id=@customer_id AND address_id=@new_address_id)
        RETURN -1;
    ELSE
        BEGIN
            BEGIN TRY
                BEGIN TRANSACTION;

                UPDATE Address SET is_active=0 WHERE address_id<>@new_address_id AND customer_id=@customer_id;
                UPDATE Address SET is_active=1 WHERE address_id=@new_address_id AND customer_id=@customer_id;

                COMMIT TRANSACTION;
                RETURN 0;
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT>0
                    ROLLBACK TRANSACTION;
                RETURN -1;
            END CATCH
        END
END
GO

--yehia tamer mohamed 64-1694
CREATE PROCEDURE Add_Card
@customer_id INT, @card_no CHAR(16), @card_holder_name VARCHAR(100), @expiration_date DATE
AS BEGIN
    IF @customer_id IS NULL OR @card_no IS NULL OR @card_holder_name IS NULL OR @card_holder_name='' OR @expiration_date IS NULL
        RETURN -1;
    ELSE IF LEN(@card_no)<>16 OR @card_no LIKE '%[^0-9]%' --contains anything thats not a digit
        RETURN -1;
    ELSE IF @expiration_date<CAST(GETDATE() AS DATE)
        RETURN -1;
    ELSE IF EXISTS (SELECT * FROM Card WHERE customer_id=@customer_id AND card_no=@card_no)
        RETURN -2;
    ELSE
        BEGIN
            BEGIN TRY
                INSERT INTO Card (customer_id,card_no,card_holder_name,expiration_date) VALUES
                (@customer_id,@card_no,@card_holder_name,@expiration_date);
                RETURN 0;
            END TRY
            BEGIN CATCH
                RETURN -1;
            END CATCH
        END
END
GO

--yehia tamer mohamed 64-1694
CREATE PROCEDURE Create_Cart 
@customer_id INT
AS BEGIN
    IF @customer_id IS NULL
        RETURN -1;
    ELSE IF (SELECT account_status FROM Customer c INNER JOIN Users u on u.user_id=c.customer_id AND c.customer_id=@customer_id)='Blacklisted'
        RETURN -3;

    DECLARE @address_id INT
    SELECT @address_id=address_id FROM Address
    WHERE is_active=1 AND customer_id=@customer_id;

    IF @address_id IS NULL
        RETURN -1;
    ELSE IF EXISTS(SELECT * FROM Cart c INNER JOIN Address a on c.address_id=a.address_id AND c.customer_id=@customer_id AND a.address_id=@address_id WHERE c.status='Active')
        RETURN -2;
    ELSE
        BEGIN 
            BEGIN TRY
                INSERT INTO Cart (customer_id,address_id) VALUES (@customer_id,@address_id);
                RETURN 0;
            END TRY
            BEGIN CATCH
                RETURN -1;
            END CATCH
        END
END
GO

--yehia tamer mohamed 64-1694
CREATE PROCEDURE Add_To_Cart
@cart_id INT, @product_id INT, @quantity INT, @notes VARCHAR(255)
AS BEGIN
    IF @cart_id IS NULL OR @product_id IS NULL OR @quantity IS NULL
        RETURN -1;
    ELSE IF NOT EXISTS(SELECT * FROM Cart WHERE cart_id=@cart_id)
    OR NOT EXISTS(SELECT * FROM Product WHERE product_id=@product_id)
        RETURN -1;
    ELSE IF @quantity<1
        RETURN -1;
    ELSE IF @quantity>10
        RETURN -6;

    DECLARE @zone_id INT,@address_id INT, @business_id INT;

    SELECT @zone_id=z.zone_id,@business_id=b.business_id FROM Product p
    INNER JOIN Business b on p.business_id=b.business_id
    INNER JOIN Zone z on z.zone_id=b.zone_id
    WHERE p.product_id=@product_id;

    SELECT @address_id=c.address_id FROM Cart c
    INNER JOIN Address a on a.address_id=c.address_id AND c.cart_id=@cart_id;

    IF (SELECT is_active FROM Address WHERE address_id=@address_id)<>1 OR (SELECT status from Cart WHERE cart_id=@cart_id)<>'Active'
        RETURN -4;
    ELSE IF NOT EXISTS (
        SELECT * FROM Address WHERE address_id=@address_id AND zone_id=@zone_id
    )
        RETURN -5;
    ELSE IF (SELECT is_available FROM Product WHERE product_id=@product_id)=0 OR (SELECT status FROM Business WHERE business_id=@business_id)<>'Active'
        RETURN -4;
    ELSE
        BEGIN 
            DECLARE @count_items INT;

            SELECT @count_items=quantity FROM CartItem WHERE product_id=@product_id AND cart_id=@cart_id;

            IF @count_items IS NULL
                BEGIN
                    BEGIN TRY
                        INSERT INTO CartItem (cart_id,product_id,quantity,notes) VALUES
                        (@cart_id,@product_id,@quantity,@notes);
                        RETURN 0;
                    END TRY
                    BEGIN CATCH
                        RETURN -1;
                     END CATCH
                END
           ELSE
               BEGIN
                    IF @quantity+@count_items>10
                        RETURN -6;
                    ELSE
                        BEGIN
                            BEGIN TRY
                                UPDATE CartItem SET quantity=@count_items+@quantity,notes=ISNULL(@notes,(SELECT notes FROM CartItem WHERE cart_id=@cart_id AND product_id=@product_id)) WHERE cart_id=@cart_id AND product_id=@product_id;
                            RETURN 0;
                            END TRY
                            BEGIN CATCH
                                RETURN -1;
                            END CATCH
                        END
               END
        END
END
GO

--yehia tamer mohamed 64-1694
CREATE PROCEDURE Remove_From_Cart
@cart_id INT, @product_id INT
AS BEGIN
    IF @cart_id IS NULL OR @product_id IS NULL
        RETURN -1;
    ELSE IF NOT EXISTS(SELECT * FROM Cart WHERE cart_id=@cart_id)
        RETURN -1;
    ELSE IF (SELECT status FROM Cart WHERE cart_id=@cart_id)='Checked Out'
        RETURN -4;
    ELSE IF NOT EXISTS(SELECT * FROM CartItem  WHERE cart_id=@cart_id)
        RETURN -9;
    ELSE IF NOT EXISTS(SELECT * FROM CartItem  WHERE cart_id=@cart_id AND product_id=@product_id)
        RETURN -1;
    ELSE
        BEGIN
            BEGIN TRY
                DELETE CartItem WHERE cart_id=@cart_id AND product_id=@product_id;
                RETURN 0;
            END TRY
            BEGIN CATCH
                RETURN -1;
            END CATCH
        END
END
GO

--yehia tamer mohamed 64-1694
CREATE FUNCTION dbo.Calculate_Voucher_Discount (@voucher_id INT,@order_subtotal DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS BEGIN
    DECLARE @amount DECIMAL(10,2),@status VARCHAR(20),@is_percentage BIT,@expiry_date DATE,@discount_amount DECIMAL(10,2);

    IF @voucher_id IS NULL 
        RETURN 0.0;

    ELSE IF @order_subtotal<=0 OR @order_subtotal IS NULL
        RETURN -1;

    ELSE IF NOT EXISTS(
        SELECT * FROM Voucher 
        WHERE voucher_id=@voucher_id
    )
        RETURN 0.0;
    
    SELECT @is_percentage=is_percentage,@status=status,@expiry_date=expiry_date,@discount_amount=amount FROM Voucher
    WHERE voucher_id=@voucher_id

    IF @status='Used' OR @expiry_date<CAST(GETDATE() AS DATE)
        RETURN 0.0;

    IF @is_percentage=1
        SELECT @amount=(@discount_amount/100)*@order_subtotal;
    ELSE IF @order_subtotal<@discount_amount
        SELECT @amount=@order_subtotal;
    ELSE
        SELECT @amount=@discount_amount;
    
    RETURN @amount;
END
GO
--yehia tamer mohamed 64-1694
CREATE PROCEDURE Checkout_Cart
@cart_id INT, @voucher_id INT, @payment_method VARCHAR(20), @card_id INT
AS BEGIN
    IF @cart_id IS NULL OR @payment_method IS NULL
        RETURN -1;

    IF NOT EXISTS(SELECT * FROM Cart WHERE cart_id=@cart_id)
    OR @payment_method NOT IN ('Cash','Card','Wallet')
        RETURN -1;

    IF @card_id IS NOT NULL
        BEGIN
            IF NOT EXISTS(SELECT * FROM Card WHERE card_id=@card_id)
                RETURN -1;
        END
    
    IF (SELECT status FROM Cart WHERE cart_id=@cart_id)<>'Active'
        RETURN -4;

    IF NOT EXISTS(
        SELECT * FROM CartItem ca 
        INNER JOIN Cart c ON c.cart_id=ca.cart_id AND c.cart_id=@cart_id
    )
        RETURN -9;

    DECLARE @customer_id INT,@address_id INT,@zone_id INT,@delivery_fee DECIMAL(10,2),@now TIME = CAST(CURRENT_TIMESTAMP AS TIME);

    SELECT @customer_id=customer_id,@address_id=address_id FROM Cart WHERE cart_id=@cart_id;

    SELECT @zone_id=a.zone_id,@delivery_fee=z.delivery_fee FROM Address a
    INNER JOIN Zone z ON z.zone_id=a.zone_id
    WHERE a.address_id=@address_id;

    IF (SELECT account_status FROM Users u INNER JOIN Customer c ON c.customer_id=u.user_id AND c.customer_id=@customer_id)='Blacklisted'
        RETURN -3;

    IF (SELECT is_active FROM Address WHERE address_id=@address_id)<>1
        RETURN -4;

    IF EXISTS(
        SELECT * FROM CartItem ca 
        INNER JOIN Product p ON p.product_id=ca.product_id
        INNER JOIN Business b ON p.business_id=b.business_id
        WHERE cart_id=@cart_id AND (p.is_available=0 OR b.status<>'Active')
    )
        RETURN -4;

    IF (
        SELECT a.zone_id FROM Address a
        INNER JOIN Zone z ON z.zone_id=a.zone_id
        WHERE a.address_id=@address_id
    )
    <>
    SOME (
        SELECT b.zone_id FROM Business b
        INNER JOIN Product p ON b.business_id=p.business_id
        INNER JOIN CartItem ca ON ca.product_id=p.product_id
        WHERE ca.cart_id=@cart_id
    )
        RETURN -5;

    IF EXISTS (
        SELECT * FROM CartItem ca 
        INNER JOIN Product p ON p.product_id=ca.product_id AND ca.cart_id=@cart_id
        INNER JOIN Business b on b.business_id=p.business_id
        WHERE NOT(
            b.opening_hour=b.closing_hour 
            OR (@now>=b.opening_hour AND @now<b.closing_hour) 
            OR (b.opening_hour>b.closing_hour AND (@now>=b.opening_hour OR @now<b.closing_hour))
        )
    )
            RETURN -4;

    IF @voucher_id IS NOT NULL
        BEGIN
            IF NOT EXISTS(SELECT * FROM Voucher WHERE voucher_id=@voucher_id)
                RETURN -1;

            IF (SELECT status FROM Voucher WHERE voucher_id=@voucher_id)<>'Unused'
                RETURN -4;

            IF (SELECT customer_id FROM Voucher WHERE voucher_id=@voucher_id)<>@customer_id
                RETURN -3;

            IF (SELECT expiry_date FROM Voucher WHERE voucher_id=@voucher_id)<CAST(GETDATE() AS DATE)
                RETURN -1;
        END

    DECLARE @subtotal DECIMAL(10,2),@fees DECIMAL(10,2),@discount DECIMAL(10,2),@total DECIMAL(10,2),@business_count INT;

    SELECT @subtotal=SUM(ca.quantity * (p.price-p.discount_amount)),@business_count=COUNT(DISTINCT b.business_id) FROM CartItem ca
    INNER JOIN Product p ON p.product_id=ca.product_id
    INNER JOIN Business b ON p.business_id=b.business_id
    WHERE ca.cart_id=@cart_id;

    SELECT @fees=@business_count*@delivery_fee,@discount=dbo.Calculate_Voucher_Discount(@voucher_id,@subtotal);
     
    SELECT @total=@subtotal + @fees - @discount;

    IF @payment_method='Card'
        BEGIN
            IF @card_id IS NULL 
            OR (SELECT expiration_date FROM Card WHERE card_id=@card_id)<CAST(GETDATE() AS DATE) 
            OR (SELECT customer_id FROM Card WHERE card_id=@card_id)<>@customer_id
                RETURN -7;
        END
   
   IF @payment_method='Wallet'
       BEGIN
           IF (SELECT wallet_balance FROM Customer WHERE customer_id=@customer_id)<@total  
               RETURN -7;
       END

   IF NOT EXISTS (
       SELECT * FROM Rider r
       INNER JOIN Users u ON r.rider_id=u.user_id
       WHERE r.zone_id=@zone_id AND r.is_available=1 AND u.account_status='Active'
   )
       RETURN -8;
   
   DECLARE @order_id INT, @suborder_id INT, @rider_id INT;

   BEGIN TRY
       BEGIN TRANSACTION
            UPDATE ca
            SET ca.unit_price=p.price-p.discount_amount
            FROM CartItem ca
            INNER JOIN Product p ON ca.product_id=p.product_id
            WHERE ca.cart_id=@cart_id;

            INSERT INTO Orders (order_date,discount_amount,total_amount,cart_id,zone_id,voucher_id) VALUES
            (GETDATE(),@discount,@total,@cart_id,@zone_id,@voucher_id);

            SET @order_id=SCOPE_IDENTITY();

            INSERT INTO SubOrder (total_price,delivery_fee,order_id,business_id)
            SELECT SUM(ca.quantity*ca.unit_price),@delivery_fee,@order_id,b.business_id FROM CartItem ca
            INNER JOIN Product p ON ca.product_id=p.product_id
            INNER JOIN Business b ON b.business_id=p.business_id
            WHERE ca.cart_id=@cart_id
            GROUP BY b.business_id

            WHILE EXISTS(SELECT * FROM SubOrder WHERE order_id=@order_id AND status='Placed')
                BEGIN
                    SELECT @suborder_id=MIN(suborder_id) FROM SubOrder WHERE order_id=@order_id AND status='Placed';

                    SELECT TOP 1 @rider_id=r.rider_id FROM Rider r
                    INNER JOIN Users u ON u.user_id=r.rider_id
                    LEFT OUTER JOIN Delivery d ON d.rider_id=r.rider_id
                    LEFT OUTER JOIN SubOrder s ON s.suborder_id=d.suborder_id AND s.status IN ('Assigned','Picked Up')
                    WHERE r.is_available=1 AND u.account_status='Active' AND r.zone_id=@zone_id
                    GROUP BY r.rider_id
                    ORDER BY COUNT(s.suborder_id),r.rider_id;

                    INSERT INTO Delivery (assigned_at,suborder_id,rider_id) VALUES
                    (GETDATE(),@suborder_id,@rider_id);

                    UPDATE SubOrder SET status='Assigned' WHERE suborder_id=@suborder_id;
                END

            IF @voucher_id IS NOT NULL
                UPDATE Voucher SET status='Used' WHERE voucher_id=@voucher_id;

            IF @payment_method<>'Card'
                SET @card_id = NULL;

            INSERT INTO Payment (amount,method,transaction_date,order_id,card_id) VALUES
            (@total,@payment_method,GETDATE(),@order_id,@card_id);

            IF @payment_method='Wallet'
                UPDATE Customer SET wallet_balance=wallet_balance-@total WHERE customer_id=@customer_id;

            UPDATE Cart SET status='Checked Out' WHERE cart_id=@cart_id;

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0
            ROLLBACK TRANSACTION;
        RETURN -1;
    END CATCH
END
GO

--yehia tamer mohamed 64-1694
CREATE PROCEDURE Cancel_Order
@order_id INT
AS BEGIN

    IF @order_id IS NULL
        RETURN -1;

    IF NOT EXISTS(SELECT * FROM Orders WHERE order_id=@order_id)
        RETURN -1;

    IF (SELECT status FROM Orders WHERE order_id=@order_id) = 'Cancelled'
        RETURN -4;

    IF EXISTS(
        SELECT * FROM Orders o
        INNER JOIN SubOrder s on o.order_id=s.order_id
        WHERE s.status IN ('Delivered','Picked Up') AND o.order_id=@order_id
    )
        RETURN -4;

    BEGIN TRANSACTION;

        DECLARE @payment_id INT, @voucher_id INT,@remaining_amount DECIMAL(10,2),@customer_id INT,@method VARCHAR(20);

        SELECT @voucher_id=voucher_id FROM Orders WHERE order_id=@order_id
            
        SELECT @payment_id=p.payment_id,@remaining_amount=p.amount-p.refunded_amount,@method=p.method,@customer_id=c.customer_id FROM Payment p
        INNER JOIN Orders o ON o.order_id=p.order_id
        INNER JOIN Cart c on c.cart_id=o.cart_id
        WHERE p.order_id=@order_id;

        IF @voucher_id IS NOT NULL
            BEGIN
                BEGIN TRY
                    UPDATE Voucher SET status='Unused' WHERE voucher_id=@voucher_id;
                END TRY
                BEGIN CATCH
                     IF @@TRANCOUNT>0
                         ROLLBACK TRANSACTION;
                     RETURN -1;
                END CATCH
            END
                
        BEGIN TRY
            UPDATE Orders SET voucher_id=NULL,status='Cancelled' WHERE order_id=@order_id;
            UPDATE Payment SET refunded_amount=refunded_amount+@remaining_amount WHERE payment_id=@payment_id;
            UPDATE SubOrder SET status='Cancelled' WHERE order_id=@order_id;
            
            IF @method<>'Cash'
                UPDATE Customer SET wallet_balance=wallet_balance+@remaining_amount WHERE customer_id=@customer_id;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT>0
                ROLLBACK TRANSACTION;
            RETURN -1;
        END CATCH
    COMMIT TRANSACTION;
    RETURN 0;
END
GO

--yehia tamer mohamed 64-1694
CREATE PROCEDURE Reorder
@order_id INT,@address_id INT
AS BEGIN
    IF @order_id IS NULL OR @address_id IS NULL
        RETURN -1;
    IF NOT EXISTS(SELECT * FROM Orders WHERE order_id=@order_id) OR NOT EXISTS(SELECT * FROM Address WHERE address_id=@address_id)
        RETURN -1;

    DECLARE @customer_id INT,@zone_id INT, @cart_id INT;

    SELECT @customer_id=c.customer_id,@zone_id=o.zone_id,@cart_id=c.cart_id FROM Orders o
    INNER JOIN Cart c ON c.cart_id=o.cart_id
    WHERE o.order_id=@order_id;

    IF (SELECT u.account_status FROM Customer c INNER JOIN Users u ON u.user_id=c.customer_id AND c.customer_id=@customer_id )='Blacklisted'
        RETURN -3;

    ELSE IF NOT EXISTS(SELECT * FROM Address WHERE customer_id=@customer_id AND address_id=@address_id)
        RETURN -3;

    ELSE IF @zone_id<>(SELECT zone_id FROM Address WHERE address_id=@address_id)
        RETURN -5;

    ELSE IF EXISTS(
        SELECT * FROM Cart c
        WHERE c.status='Active' AND c.customer_id=@customer_id AND c.address_id=@address_id
    )
        RETURN -2;

    ELSE IF NOT EXISTS(
        SELECT * FROM CartItem ca
        INNER JOIN Product p ON p.product_id=ca.product_id
        INNER JOIN Business b on p.business_id=b.business_id
        WHERE p.is_available=1 AND b.status='Active' AND ca.cart_id=@cart_id
    )
        RETURN -9;

    ELSE
        BEGIN
                BEGIN TRANSACTION;
                    IF (SELECT is_active FROM Address WHERE address_id=@address_id)=0
                    BEGIN
                        DECLARE @error_code INT;
                        EXEC @error_code=Change_Active_Address @customer_id, @address_id;
                        IF @error_code<>0
                            BEGIN
                                IF @@TRANCOUNT>0
                                    ROLLBACK TRANSACTION;
                                RETURN @error_code;
                            END
                    END

                    BEGIN TRY
                        DECLARE @new_cart_id INT;
                        INSERT INTO Cart (customer_id,address_id) VALUES (@customer_id,@address_id);
                        SET @new_cart_id=SCOPE_IDENTITY();

                        INSERT INTO CartItem (cart_id,product_id, quantity, notes)
                        SELECT @new_cart_id, ca.product_id, quantity, notes FROM CartItem ca
                        INNER JOIN Cart c ON ca.cart_id=c.cart_id AND c.cart_id=@cart_id
                        INNER JOIN Product p ON p.product_id=ca.product_id AND p.is_available=1
                        INNER JOIN Business b ON b.business_id=p.business_id AND b.status='Active';

                        COMMIT TRANSACTION;
                        RETURN 0;
   
                    END TRY
                    BEGIN CATCH
                        IF @@TRANCOUNT>0
                            ROLLBACK TRANSACTION;
                        RETURN -1;
                    END CATCH
     END
END
GO

-- Maryam Mustafa -64-3003
GO
CREATE PROC dbo.Submit_Feedback
@suborder_id int,
@headline varchar(100),
@description varchar(5000),
@rating int
AS
BEGIN
    IF @suborder_id IS NULL OR @headline IS NULL OR LTRIM(RTRIM(@headline)) = ''
       OR @rating IS NULL OR @rating NOT BETWEEN 1 AND 5
        RETURN -1;

    IF NOT EXISTS (SELECT 1 FROM dbo.SubOrder
                   WHERE suborder_id = @suborder_id AND status = 'Delivered')
        RETURN -4;

    IF EXISTS (SELECT 1 FROM dbo.Feedback WHERE suborder_id = @suborder_id)
        RETURN -2;

    BEGIN TRY
        INSERT INTO dbo.Feedback (headline, description, rating, feedback_date, suborder_id)
        VALUES (@headline, @description, @rating, GETDATE(), @suborder_id);

        RETURN 0;
    END TRY
    BEGIN CATCH
        RETURN -1;
    END CATCH;
END;
GO

-- Maryam Mustafa 64-3003
GO
CREATE PROCEDURE dbo.Rate_Rider
    @suborder_id int,
    @rider_rating int
AS
BEGIN
    IF @suborder_id IS NULL OR @rider_rating IS NULL OR @rider_rating NOT BETWEEN 1 AND 5
        RETURN -1;

    IF NOT EXISTS (SELECT 1 FROM dbo.SubOrder
                   WHERE suborder_id = @suborder_id AND status = 'Delivered')
        RETURN -4;

    IF EXISTS (SELECT 1 FROM dbo.Delivery
               WHERE suborder_id = @suborder_id AND rider_rating IS NOT NULL)
        RETURN -2;

    BEGIN TRY
        UPDATE dbo.Delivery
        SET rider_rating = @rider_rating
        WHERE suborder_id = @suborder_id;

        RETURN 0;
    END TRY
    BEGIN CATCH
        RETURN -1;
    END CATCH;
END;
GO

--yehia tamer mohamed 64-1694
CREATE FUNCTION My_Order_History (@customer_id INT)
RETURNS TABLE
AS RETURN(
    SELECT o.order_id, o.order_date, z.zone_name, o.status, COUNT(s.suborder_id) number_of_suborders, o.discount_amount,o.total_amount, p.method payment_method, p.refunded_amount
    FROM Orders o INNER JOIN Zone z ON z.zone_id=o.zone_id
    INNER JOIN SubOrder s ON s.order_id=o.order_id
    LEFT OUTER JOIN  Payment p on p.order_id=o.order_id
    INNER JOIN Cart c on c.cart_id=o.cart_id
    WHERE c.customer_id=@customer_id
    GROUP BY o.order_id, o.order_date, z.zone_name, o.status, o.discount_amount,o.total_amount, p.method, p.refunded_amount
);
GO


-- Adam Ahmed Ibrahim - 65-33775
GO
CREATE PROCEDURE Toggle_Favorite
    @customer_id INT,
    @item_id INT,
    @item_type VARCHAR(20)
AS
BEGIN
    IF @customer_id IS NULL
        OR @item_id IS NULL
        OR @item_type IS NULL
        OR @item_type NOT IN ('Business', 'Product')
    RETURN -1;

    IF NOT EXISTS (
        SELECT 1
        FROM Customer
        WHERE customer_id = @customer_id
    )
    RETURN -1;

    IF @item_type = 'Business'
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM Business
            WHERE business_id = @item_id
        )
        RETURN -1;

        IF EXISTS (
            SELECT 1
            FROM Favorite_Business
            WHERE customer_id = @customer_id
                AND business_id = @item_id
        )
        BEGIN
            DELETE FROM Favorite_Business
            WHERE customer_id = @customer_id
                AND business_id = @item_id;
        END
        ELSE
        BEGIN
            INSERT INTO Favorite_Business(customer_id, business_id)
            VALUES (@customer_id, @item_id);
        END
    END
    ELSE
    BEGIN
        IF NOT EXISTS (
                SELECT 1
                FROM [Product]
                WHERE product_id = @item_id
            )
        RETURN -1;

        IF EXISTS (
            SELECT 1
            FROM Favorite_Product
            WHERE customer_id = @customer_id
                AND product_id = @item_id
        )
        BEGIN
            DELETE FROM Favorite_Product
            WHERE customer_id = @customer_id
                AND product_id = @item_id;
        END
        ELSE
        BEGIN
            INSERT INTO Favorite_Product(customer_id, product_id)
            VALUES (@customer_id, @item_id);
        END
    END
    RETURN 0;
END
GO

-- Adam Ahmed Ibrahim - 65-33775
GO
CREATE FUNCTION My_Favorites(@customer_id INT)
RETURNS TABLE
AS
RETURN
(
    SELECT
        P.product_id,
        P.[name] AS product_name,
        B.[name] AS business_name,
        CASE
            WHEN B.[status] = 'Active'
                AND P.is_available = 1
            THEN 1
            ELSE 0
            END AS is_orderable
    FROM Favorite_Product FP
    INNER JOIN [Product] P ON P.product_id = FP.product_id
    INNER JOIN Business B ON B.business_id = P.business_id
    WHERE FP.customer_id = @customer_id
);
GO

-- Maryam Mustafa AbdelWahab - 64-3003
GO
CREATE FUNCTION dbo.Recommended_Products (@customer_id INT)
RETURNS TABLE
AS 
RETURN
(
    SELECT TOP 10 p.product_id,p.name AS product_name,b.name AS business_name, p.category, p.price-p.discount_amount AS final_price FROM Product p
    INNER JOIN Business b ON b.business_id=p.business_id
    INNER JOIN (SELECT p.category,COUNT(ca.product_id) AS times_ordered FROM CartItem ca
    INNER JOIN Cart c ON c.cart_id=ca.cart_id
    INNER JOIN Orders o ON o.cart_id=c.cart_id
    INNER JOIN Product p ON p.product_id=ca.product_id
    WHERE c.customer_id=@customer_id
    GROUP BY p.category) oc ON oc.category=p.category
    WHERE p.is_available=1
    AND b.status='Active' AND b.zone_id=(SELECT zone_id FROM Address WHERE customer_id=@customer_id AND is_active=1)
    AND NOT EXISTS (SELECT * FROM CartItem ci2 INNER JOIN Cart c2 ON c2.cart_id=ci2.cart_id INNER JOIN Orders o2 ON o2.cart_id=c2.cart_id
    WHERE c2.customer_id=@customer_id AND ci2.product_id=p.product_id)
    ORDER BY oc.times_ordered DESC, p.product_id
);
GO

-- Maryam Mustafa AbdelWahab 64-3003
CREATE PROC dbo.Set_Rider_Availability
@rider_id INT,
@is_available BIT
AS
BEGIN 
 IF @rider_id IS NULL OR @is_available IS NULL
  RETURN -1;
  IF NOT EXISTS (SELECT 1 FROM dbo.Rider WHERE rider_id = @rider_id)
   RETURN -3;
  BEGIN TRY
        UPDATE dbo.Rider
        SET is_available = @is_available
        WHERE rider_id = @rider_id;
        RETURN 0;
   END TRY
   BEGIN CATCH 
   RETURN -1;
   END CATCH;
END;
GO


-- Maryam Mustafa AbdelWahab - 64-3003 
CREATE FUNCTION dbo.My_Active_Deliveries(@rider_int int)
RETURNS TABLE
AS
RETURN ( SELECT d.delivery_id , s.order_id , s.suborder_id , b.name as business_name , 
u.first_name + ' ' + u.last_name as customer_name , a.description AS address_description , 
z.zone_name , s.status , d.assigned_at
FROM dbo.Delivery d 

INNER JOIN dbo.SubOrder AS s ON s.suborder_id=d.suborder_id
INNER JOIN dbo.Business AS b on b.business_id=s.business_id
INNER JOIN dbo.Orders AS o ON o.order_id=s.order_id
INNER JOIN dbo.Zone AS z ON z.zone_id=o.zone_id
INNER JOIN dbo.Cart AS  c ON c.Cart_id = o.cart_id
INNER JOIN dbo.Address AS a ON a.address_id= c.address_id
INNER JOIN dbo.Users AS u ON u.user_id=c.customer_id
WHERE d.rider_id=@rider_int AND s.status IN ('Assigned', 'Picked Up'));
GO

-- Maryam Mustafa - 64-3003
GO
CREATE PROCEDURE dbo.Mark_Picked_Up
@delivery_id int 
AS
BEGIN
    IF @delivery_id IS NULL
        RETURN -1;

    IF NOT EXISTS (SELECT * FROM Delivery WHERE delivery_id = @delivery_id)
        RETURN -1;

    IF (SELECT SubOrder.status FROM Delivery INNER JOIN SubOrder ON SubOrder.suborder_id = Delivery.suborder_id WHERE delivery_id = @delivery_id) IN ('Delivered', 'Cancelled', 'Picked Up')
        RETURN -4;

    DECLARE @order_id INT;

    SELECT @order_id = s.order_id FROM SubOrder s INNER JOIN Delivery d ON s.suborder_id = d.suborder_id WHERE d.delivery_id = @delivery_id;

    BEGIN TRY
        UPDATE SubOrder SET status='Picked Up' WHERE suborder_id=(SELECT suborder_id FROM Delivery WHERE delivery_id=@delivery_id);
        UPDATE Orders SET status='In Progress' WHERE order_id=@order_id;
        UPDATE Delivery SET picked_up_at=GETDATE() WHERE delivery_id=@delivery_id;
        RETURN 0;
    END TRY
    BEGIN CATCH
        RETURN -1;
    END CATCH;

END
GO

-- Maryam Mustafa -64-3003
CREATE PROCEDURE dbo.Mark_Delivered
    @delivery_id int
AS
BEGIN
    IF @delivery_id IS NULL
        RETURN -1;

    IF NOT EXISTS(SELECT * FROM Delivery WHERE delivery_id=@delivery_id)
        RETURN -1;

    DECLARE @suborder_id int, @order_id int;
    DECLARE @now datetime = GETDATE();

    SELECT @suborder_id = s.suborder_id,
           @order_id = s.order_id
    FROM dbo.Delivery AS d
    INNER JOIN dbo.SubOrder AS s ON s.suborder_id = d.suborder_id
    WHERE d.delivery_id = @delivery_id
      AND s.status = 'Picked Up';

    IF @suborder_id IS NULL
        RETURN -4;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Delivery
        SET delivered_at = @now,
            tracking_time = DATEDIFF(MINUTE, picked_up_at, @now)
        WHERE delivery_id = @delivery_id;

        UPDATE dbo.SubOrder
        SET status = 'Delivered'
        WHERE suborder_id = @suborder_id;

        IF NOT EXISTS(SELECT * FROM SubOrder WHERE order_id = @order_id AND status IN ('Placed', 'Assigned', 'Picked Up'))
            UPDATE Orders SET status='Delivered' WHERE order_id=@order_id;
        ELSE
            UPDATE Orders SET status='In Progress' WHERE order_id=@order_id;

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        RETURN -1;
    END CATCH;
END;
GO

-- Maryam Mustafa Abdelwahab - 64-3003
CREATE FUNCTION dbo.My_Earnings (@rider_id int, @from_date date, @to_date date)
RETURNS TABLE
AS
RETURN
(
    SELECT COUNT(*) AS completed_deliveries,
           CAST(ISNULL(SUM(s.delivery_fee), 0) AS decimal(10,2)) AS total_delivery_fees,
           CAST(ISNULL(SUM(s.delivery_fee), 0) * 0.80 AS decimal(10,2)) AS total_earnings
    FROM dbo.Delivery AS d
    INNER JOIN dbo.SubOrder AS s ON s.suborder_id = d.suborder_id
    WHERE d.rider_id = @rider_id
      AND s.status = 'Delivered'
      AND CAST(d.delivered_at AS date) BETWEEN @from_date AND @to_date
    HAVING EXISTS (SELECT 1 FROM dbo.Rider WHERE rider_id = @rider_id)
       AND @from_date <= @to_date
);
GO

-- Maryam Mustafa Abdelwahab - 64-3003
CREATE FUNCTION dbo.My_Rating_Summary(@rider_id INT)
RETURNS TABLE
AS
RETURN
(  SELECT CAST(AVG(CAST(d.rider_rating AS decimal(10,2))) AS decimal(10,2)) AS avg_rating, COUNT(d.rider_rating) AS ratings_count,
COUNT(CASE WHEN d.rider_rating = 5 THEN 1 END) AS five_star,
           COUNT(CASE WHEN d.rider_rating = 4 THEN 1 END) AS four_star,
           COUNT(CASE WHEN d.rider_rating = 3 THEN 1 END) AS three_star,
           COUNT(CASE WHEN d.rider_rating = 2 THEN 1 END) AS two_star,
           COUNT(CASE WHEN d.rider_rating = 1 THEN 1 END) AS one_star
    FROM dbo.Delivery AS d
    WHERE d.rider_id = @rider_id
    HAVING EXISTS (SELECT 1 FROM dbo.Rider WHERE rider_id = @rider_id)
);
GO

-- Maryam Mustafa Abdelwahab - 64-3003
CREATE FUNCTION dbo.My_Delivery_History(@rider_id int , @from_date date , @to_date date)
RETURNS TABLE
AS
RETURN 
( SELECT d.Delivery_id , s.order_id , b.name AS business_name , s.status , d.assigned_at , 
d.picked_up_at , d.delivered_at , d.tracking_time FROM dbo.Delivery as d 

INNER JOIN dbo.SubOrder AS s ON s.suborder_id= d.suborder_id
    INNER JOIN dbo.Business as b on b.business_id= s.business_id
    WHERE d.rider_id=@rider_id AND s.status IN ('Delivered', 'Cancelled') 
    AND CAST(d.assigned_at AS date) BETWEEN @from_date AND @to_date);
    GO

-- Helper
-- Adam Ahmed Ibrahim - 65-33775
CREATE FUNCTION dbo.Search_Platform_Helper(@business_name VARCHAR(100), @keyword VARCHAR(100))
RETURNS INT
AS
BEGIN
    IF @business_name = @keyword
    BEGIN
        RETURN 1;
    END

    IF @business_name LIKE (@keyword + '%')
    BEGIN
        RETURN 2;
    END

    IF @business_name LIKE ('%' + @keyword + '%')
    BEGIN
        RETURN 3;
    END

    RETURN 4;

END
GO

-- Adam Ahmed Ibrahim - 65-33775
GO
CREATE FUNCTION dbo.Search_Platform(@customer_id INT, @keyword VARCHAR(100))
RETURNS TABLE
AS
RETURN
(
    SELECT
        B.business_id,
        B.[name] AS business_name,
        dbo.Search_Platform_Helper(B.[name], @keyword) AS [priority]
    FROM Customer C
    INNER JOIN [Address] A ON A.customer_id = C.customer_id AND A.is_active = 1
    INNER JOIN Business B ON B.zone_id = A.zone_id AND B.[status] = 'Active'
    WHERE C.customer_id = @customer_id
        AND dbo.Search_Platform_Helper(B.[name], @keyword) BETWEEN 1 AND 3
    ORDER BY [priority] ASC
    OFFSET 0 ROWS -- To allow ORDER BY inside a tvf
);
GO


-- Maryam Mustafa Abdelwahab - 64-3003
CREATE FUNCTION dbo.Reconcile_Order_Totals()
RETURNS TABLE
AS
RETURN
(
    SELECT o.order_id,SUM(s.total_price+s.delivery_fee)-o.discount_amount AS expected_total,o.total_amount AS order_total,p.amount AS payment_amount FROM Orders o
    INNER JOIN SubOrder s ON s.order_id = o.order_id
    LEFT OUTER JOIN Payment p ON p.order_id=o.order_id
    GROUP BY o.order_id,o.total_amount,o.discount_amount,p.amount
    HAVING p.amount<>o.total_amount OR p.amount IS NULL OR SUM(s.total_price+s.delivery_fee)-o.discount_amount<>o.total_amount
);
GO

-- Adam Ahmed Ibrahim - 65-33775
GO
CREATE FUNCTION Nearby_Businesses_By_Category(@address_id INT, @product_category VARCHAR(50))
RETURNS TABLE
AS
RETURN
(
    SELECT
        B.business_id,
        B.[name] AS business_name,
        Z.zone_name,
        CASE WHEN Z.zone_id = A.zone_id THEN 1 ELSE 0 END AS same_zone,
        (
            SELECT AVG(CAST(D.tracking_time AS DECIMAL(10,2)))
            FROM Orders O
            INNER JOIN SubOrder SO ON SO.order_id = O.order_id
            INNER JOIN Delivery D ON D.suborder_id = SO.suborder_id
            WHERE O.zone_id = B.zone_id
                AND SO.[status] = 'Delivered'
        ) AS zone_avg_delivery_time
    FROM Business B
    INNER JOIN [Zone] Z ON Z.zone_id = B.zone_id
    INNER JOIN [Address] A ON A.address_id = @address_id
    WHERE B.[status] = 'Active'
        AND EXISTS (
            SELECT 1
            FROM [Product] P
            WHERE P.business_id = B.business_id
                AND P.category = @product_category
                AND P.is_available = 1
        )
    ORDER BY same_zone DESC, zone_avg_delivery_time
    OFFSET 0 ROWS -- To allow ORDER BY inside a TVF
);
GO

--Maryam Mustafa Abdelwahab -64-3003
CREATE FUNCTION dbo.Platform_Health_Snapshot ()
RETURNS TABLE
AS
RETURN
(
    SELECT
        (SELECT COUNT(*) FROM dbo.Business WHERE status = 'Active') AS active_businesses,
        (SELECT COUNT(*) FROM dbo.Rider WHERE is_available = 1) AS available_riders,
        (SELECT COUNT(*) FROM dbo.Orders
         WHERE CAST(order_date AS date) = CAST(GETDATE() AS date)) AS orders_today,
        (SELECT CAST(AVG(CAST(tracking_time AS decimal(10,2))) AS decimal(10,2))
         FROM dbo.Delivery
         WHERE CAST(delivered_at AS date) = CAST(GETDATE() AS date)) AS avg_delivery_time_today,
        (SELECT COUNT(*) FROM dbo.Feedback
         WHERE rating <= 2
           AND CAST(feedback_date AS date) = CAST(GETDATE() AS date)) AS low_ratings_today
);
GO


