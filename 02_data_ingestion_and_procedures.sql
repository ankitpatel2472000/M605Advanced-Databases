-- ============================================================================
-- Created By: Ankit
-- Description: insert records in all table,update order total
-- ============================================================================

USE logistics_fleet;

DELIMITER $$

DROP PROCEDURE IF EXISTS PopulateFleetData$$

CREATE PROCEDURE PopulateFleetData()
BEGIN
    DECLARE i INT DEFAULT 1;

    -- Clear existing data safely
    SET FOREIGN_KEY_CHECKS = 0;
    TRUNCATE TABLE order_items;
    TRUNCATE TABLE orders;
    TRUNCATE TABLE shifts;
    TRUNCATE TABLE couriers;
    TRUNCATE TABLE delivery_zones;
    SET FOREIGN_KEY_CHECKS = 1;

    -- 1. Insert Delivery Zones (Berlin diffrent sectors & postal codes)
    WHILE i <= 110 DO
        INSERT INTO delivery_zones (zone_name, postal_code, congestion_level)
        VALUES (
            CONCAT(
                ELT((i % 10) + 1, 
                    'Mitte', 'Kreuzberg', 'Prenzlauer Berg', 'Charlottenburg', 
                    'Neukölln', 'Friedrichshain', 'Schöneberg', 'Wedding', 
                    'Moabit', 'Pankow'
                ),
                ' - Sector ',
                ((i - 1) DIV 10) + 1
            ),
            CONCAT('10', LPAD(i, 3, '0')),
            -- Normalized to exact ENUM / VARCHAR casing: 'Low', 'Moderate', 'High'
            ELT((i % 3) + 1, 'Low', 'Moderate', 'High')
        );
        SET i = i + 1;
    END WHILE;

    -- 2. Insert Couriers (Realistic names and active ratings)
    SET i = 1;
    WHILE i <= 120 DO
        INSERT INTO couriers (full_name, email,phone_number, vehicle_type, is_active, rating)
        VALUES (
            CONCAT(
                ELT((i % 10) + 1, 
                    'Lukas', 'Sophie', 'Maximilian', 'Anna', 'Felix', 
                    'Laura', 'Jan', 'Elena', 'Niklas', 'Julia'
                ),
                ' ',
                ELT(((i * 3) % 10) + 1, 
                    'Müller', 'Schmidt', 'Schneider', 'Fischer', 'Weber', 
                    'Meyer', 'Wagner', 'Becker', 'Schulz', 'Hoffmann'
                )
            ),
            CONCAT('courier_', i, '@fleetflow.de'),
            CONCAT('+49 151 ', LPAD(i * 73, 8, '0')),
            ELT((i % 4) + 1, 'E-BIKE', 'SCOOTER', 'CAR', 'VAN'),
            IF(i % 10 = 0, FALSE, TRUE),
            ROUND(4.00 + (RAND() * 1.00), 2)
        );
        SET i = i + 1;
    END WHILE;

    -- 3. Insert Shifts (Realistic hourly wage intervals: €15.00 - €22.50)
    SET i = 1;
    WHILE i <= 150 DO
        INSERT INTO shifts (courier_id, assigned_zone_id, start_time, end_time, base_pay)
        VALUES (
            ((i - 1) % 120) + 1,
            ((i - 1) % 110) + 1,
            DATE_SUB(NOW(), INTERVAL (160 - i) HOUR),
            DATE_SUB(NOW(), INTERVAL (152 - i) HOUR),
            ROUND(15.00 + (RAND() * 7.50), 2)
        );
        SET i = i + 1;
    END WHILE;

    -- 4. Insert Orders (Realistic customers, real Berlin streets, status distribution)
    SET i = 1;
    WHILE i <= 220 DO
        INSERT INTO orders (customer_name, delivery_address, zone_id, courier_id, status, order_total, created_at, delivered_at)
        VALUES (
            CONCAT(
                ELT((i % 10) + 1, 
                    'Alexander', 'Marie', 'Christian', 'Katharina', 'Daniel', 
                    'Sarah', 'Florian', 'Lisa', 'Sebastian', 'Hannah'
                ),
                ' ',
                ELT(((i * 7) % 10) + 1, 
                    'Bauer', 'Richter', 'Klein', 'Wolf', 'Schröder', 
                    'Neumann', 'Schwarz', 'Zimmermann', 'Braun', 'Hartmann'
                )
            ),
            CONCAT(
                ELT((i % 8) + 1, 
                    'Torstraße', 'Kastanienallee', 'Sonnenallee', 'Kantstraße', 
                    'Karl-Marx-Allee', 'Warschauer Straße', 'Potsdamer Straße', 'Bernauer Straße'
                ),
                ' ',
                (i * 3) % 150 + 1,
                ', 10',
                LPAD(((i - 1) % 110) + 1, 3, '0'),
                ' Berlin'
            ),
            ((i - 1) % 110) + 1,
            -- orders 1 to 190 have couriers assigned (including courier 12 having ASSIGNED orders)
            IF(i <= 190, 
               IF(i IN (12, 42, 72), 12, ((i - 1) % 120) + 1), 
               NULL
            ),
            -- Guarantees courier 12 has ASSIGNED status so Query 4 yields rows
            IF(i IN (12, 42, 72), 'ASSIGNED', ELT((i % 5) + 1, 'PENDING', 'ASSIGNED', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED')),
            0.00,
            DATE_SUB(NOW(), INTERVAL (240 - i) HOUR),
            IF(i % 5 = 3, DATE_SUB(NOW(), INTERVAL (238 - i) HOUR), NULL)
        );
        SET i = i + 1;
    END WHILE;

    -- 5. Insert Order Items (grocery/e-commerce line items)
    SET i = 1;
    WHILE i <= 350 DO
        INSERT INTO order_items (order_id, item_description, quantity, unit_price, weight_kg)
        VALUES (
            ((i - 1) % 220) + 1,
            ELT((i % 10) + 1,
                'Organic Fresh Produce Box',
                'Cold Brew Coffee Pack (6x)',
                'Whole Grain Bakery Bundle',
                'Oat Milk Barista Edition (4x)',
                'Gourmet Pasta & Sauce Kit',
                'Sparkling Mineral Water Crate',
                'Artisan Cheese Assortment',
                'Eco Household Cleaning Pack',
                'Premium Olive Oil (1L)',
                'Snack & Dried Fruit Pack'
            ),
            (i % 3) + 1,
            ROUND(4.50 + (RAND() * 25.00), 2),
            ROUND(0.40 + (RAND() * 3.50), 2)
        );
        SET i = i + 1;
    END WHILE;

    -- Synchronize order total with calculated item amounts
    UPDATE orders o
    JOIN (
        SELECT order_id, SUM(quantity * unit_price) AS calculated_total
        FROM order_items
        GROUP BY order_id
    ) agg ON o.order_id = agg.order_id
    SET o.order_total = agg.calculated_total;
    
	-- Insert bulk records using csv file
TRUNCATE TABLE vehicle_maintenance_logs;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/maintenance_data.csv'
INTO TABLE vehicle_maintenance_logs
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(courier_id, service_date, maintenance_type, cost, workshop_name, @raw_notes)
SET notes = TRIM(TRAILING '\r' FROM @raw_notes);
-- TRUNCATE TABLE vehicle_maintenance_logs;


	select * from vehicle_maintenance_logs;
END$$

DELIMITER ;

-- Execute the procedure and clean up
CALL PopulateFleetData();
DROP PROCEDURE PopulateFleetData;

-- Verification check: each table insert records
SELECT 'delivery_zones' AS table_name, COUNT(*) AS total_records FROM delivery_zones
UNION ALL
SELECT 'couriers', COUNT(*) FROM couriers
UNION ALL
SELECT 'shifts', COUNT(*) FROM shifts
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items;

-- check bulk insert record
	select * from vehicle_maintenance_logs;
    
