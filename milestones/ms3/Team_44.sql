-- Milestone 3 Helper implementations
USE LocalDeliveryMarketplace_Team_44;
GO

-- Add any custom helpers below.

-- ============================================================
-- Section 3.6 (Customer: browsing, orders and feedback)
-- ============================================================

-- h_ProductCategories
-- The product categories a customer can browse by (3.6.a), with how many
-- active businesses currently sell at least one available product in each.
CREATE OR ALTER VIEW h_ProductCategories
AS
SELECT p.category,
       COUNT(DISTINCT p.business_id) AS business_count
FROM Product p
INNER JOIN Business b ON b.business_id = p.business_id
WHERE p.is_available = 1
  AND b.status = 'Active'
GROUP BY p.category;
GO

-- h_MyFavoriteBusinesses
-- The businesses a customer marked as favorite (3.6.b). My_Favorites (4.6.p)
-- only returns favorite products, so this lists the favorite businesses.
CREATE OR ALTER FUNCTION h_MyFavoriteBusinesses (@customer_id INT)
RETURNS TABLE
AS
RETURN
(
    SELECT b.business_id,
           b.name AS business_name,
           z.zone_name,
           b.status,
           CASE WHEN b.status = 'Active' THEN 1 ELSE 0 END AS is_orderable
    FROM Favorite_Business fb
    INNER JOIN Business b ON b.business_id = fb.business_id
    INNER JOIN Zone z ON z.zone_id = b.zone_id
    WHERE fb.customer_id = @customer_id
);
GO
