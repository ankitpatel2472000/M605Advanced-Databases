-- ============================================================================
-- Created By: Ankit
-- Description: queries with joins and index test
-- ============================================================================

USE logistics_fleet;

-- 1.Output: 10 rows shows top-earning drivers, vehicle, order count, total revenue, and weight kg.
SELECT 
    c.courier_id,
    c.full_name,
    c.vehicle_type,
    COUNT(DISTINCT o.order_id) AS total_orders_delivered,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_revenue,
    ROUND(SUM(oi.weight_kg * oi.quantity), 2) AS total_weight_kg
FROM couriers c
INNER JOIN orders o ON c.courier_id = o.courier_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status = 'DELIVERED'
GROUP BY c.courier_id, c.full_name, c.vehicle_type
HAVING total_orders_delivered > 0
ORDER BY total_revenue DESC
LIMIT 10;

-- 2.Output: Shows each city zone with its traffic level, total waiting orders.
SELECT 
    z.zone_id,
    z.zone_name,
    z.congestion_level,
    COUNT(o.order_id) AS pending_active_orders ,
    COUNT(DISTINCT s.courier_id) AS total_rostered_couriers
FROM delivery_zones z
LEFT JOIN orders o ON z.zone_id = o.zone_id AND o.status IN ('PENDING', 'ASSIGNED', 'IN_TRANSIT')
LEFT JOIN shifts s ON z.zone_id = s.assigned_zone_id AND s.end_time >= NOW()
GROUP BY z.zone_id, z.zone_name, z.congestion_level
ORDER BY pending_active_orders DESC;

-- 3.Output: Orders currently IN_TRANSIT weighing over 2.00 kg, courier name, vehicle, and hourly wages.
SELECT 
    c.courier_id,
    c.full_name,
    c.vehicle_type,
    s.base_pay,
    o.order_id,
    SUM(oi.quantity * oi.weight_kg) AS total_package_weight
FROM couriers c
INNER JOIN shifts s ON c.courier_id = s.courier_id
INNER JOIN orders o ON c.courier_id = o.courier_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status = 'IN_TRANSIT'
GROUP BY c.courier_id, c.full_name, c.vehicle_type, s.base_pay, o.order_id
HAVING total_package_weight > 2.00;

-- 4.Output: Execution plan showing index usage ('indx_orders_courier_status'), access type 'ref', and minimal scanned rows.
EXPLAIN 
SELECT o.order_id,o.status,o.courier_id, o.customer_name, o.order_total, z.zone_name
FROM orders o
INNER JOIN delivery_zones z ON o.zone_id = z.zone_id
WHERE o.status = 'ASSIGNED' AND o.courier_id = 12;

-- 5.Output: 10 highest-value orders tagged with dynamic dispatch categories 
-- ('Urgent Dispatch', 'Active Delivery', etc.).
SELECT 
    order_id,
    customer_name,
    order_total,
    status,
    CASE 
        WHEN status = 'PENDING' AND order_total >= 50.00 THEN 'Urgent Dispatch'
        WHEN status = 'IN_TRANSIT' THEN 'Active Delivery'
        WHEN status = 'DELIVERED' THEN 'Completed'
        ELSE 'Standard Handling'
    END AS dispatch_priority
FROM orders
ORDER BY order_total DESC
LIMIT 10;

-- 6. Audit Test: trigger and inspect the log
SELECT * FROM order_audit_logs; -- before delete order_audit_logs table

DELETE FROM orders WHERE order_id = 210; -- also delete from order_items Due to ON DELETE CASCADE

-- Verify the trigger insert log
SELECT * FROM order_audit_logs; -- after delete order_audit_logs table
-- ============================================================================
-- 7. ACID TRANSACTION, ROLLBACK, COMMIT & LOCKING (INSERT DEMO)
-- ============================================================================
START TRANSACTION;-- Step 1: transaction block
-- Step 2: Insert record for testing
INSERT INTO vehicle_maintenance_logs (courier_id, service_date, maintenance_type, cost, workshop_name, notes)
VALUES (1, '2026-09-05', 'Brake Inspection', 149.50, 'Central Berlin Fleet Hub', 'TRANSACTION_TEST_LOG');
SELECT maintenance_id, courier_id, maintenance_type, cost, notes -- Step 3: Verify the inserted record
FROM vehicle_maintenance_logs 
WHERE notes = 'TRANSACTION_TEST_LOG';
-- Step 4: Revert insertion
ROLLBACK;

-- Step 5: Verify the record was discarded
SELECT maintenance_id, courier_id, maintenance_type, cost, notes 
FROM vehicle_maintenance_logs 
WHERE notes = 'TRANSACTION_TEST_LOG';


-- Part B: Row Lock and Commit
START TRANSACTION;

-- lock on a single order
SELECT * FROM orders 
WHERE order_id = 10 
FOR UPDATE;

-- Commit and release lock
COMMIT;









