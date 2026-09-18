-- ===========================================================================================================
-- Created By: Ankit
-- Description: DDL definitions, constraints, and indexes for Logistics Fleet
-- ===========================================================================================================

CREATE DATABASE logistics_fleet;
USE logistics_fleet;

-- 1 Table : Delivery Zones
-- Purpose: Defines geographical delivery boundaries and operational status.

CREATE TABLE delivery_zones(
    zone_id INT PRIMARY KEY AUTO_INCREMENT,
    zone_name VARCHAR(100) NOT NULL ,
    postal_code VARCHAR(20) NOT NULL UNIQUE ,
    congestion_level ENUM('High','Low', 'Moderate') NOT NULL DEFAULT 'Moderate',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2 Table: Couriers
-- Purpose: Stores active courier personnel, contact, and ratings.

CREATE TABLE IF NOT EXISTS couriers (
    courier_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone_number VARCHAR(25) NOT NULL UNIQUE,
    vehicle_type ENUM('E-BIKE', 'SCOOTER', 'CAR', 'VAN') NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    rating DECIMAL(3, 2) DEFAULT 5.00 NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_rating CHECK (rating >= 1.00 AND rating <= 5.00)
) ENGINE=InnoDB;

-- 3 Table: Shifts
-- Purpose: Logs operational shifts linked to active couriers and delivery zones.
CREATE TABLE IF NOT EXISTS shifts (
    shift_id INT PRIMARY KEY AUTO_INCREMENT,
    courier_id INT NOT NULL,
    assigned_zone_id INT NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    base_pay DECIMAL(8, 2) NOT NULL DEFAULT 15.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_shift_courier_id FOREIGN KEY (courier_id) 
        REFERENCES couriers(courier_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_shift_zone_id FOREIGN KEY (assigned_zone_id) 
        REFERENCES delivery_zones(zone_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_shift_time CHECK (end_time > start_time)
) ENGINE=InnoDB;

-- ON DELETE CASCADE: If a parent record is deleted, automatically delete all related child records.
-- ON UPDATE CASCADE: If a parent primary key changes, automatically update the matching foreign key
-- in all child records..

-- 4 Table: Orders
-- Purpose: Central transaction table tracking package dispatch and fulfillment.

CREATE TABLE IF NOT EXISTS orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    delivery_address VARCHAR(255) NOT NULL,
    zone_id INT NOT NULL,
    courier_id INT NULL,
    status ENUM('PENDING', 'ASSIGNED', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED') NOT NULL DEFAULT 'PENDING',
    order_total DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    delivered_at DATETIME NULL,
    -- Prevents zone deletion while active/historic orders reference that zone.
    CONSTRAINT fk_order_zone_id FOREIGN KEY (zone_id) 
        REFERENCES delivery_zones(zone_id) ON DELETE RESTRICT ON UPDATE CASCADE,
        
    -- ON DELETE SET NULL: If a parent record is deleted, set the foreign key in all related child records to 
    -- NULL instead of deleting them.
    CONSTRAINT fk_order_courier_id FOREIGN KEY (courier_id) 
        REFERENCES couriers(courier_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 5 Table: Order Items
-- Purpose: Child line-item details for parcel inventory and payload weights.

CREATE TABLE IF NOT EXISTS order_items (
    item_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    item_description VARCHAR(150) NOT NULL,
    quantity INT DEFAULT 1 NOT NULL,
    unit_price DECIMAL(8, 2) NOT NULL,
    weight_kg DECIMAL(5, 2) DEFAULT 0.50 NOT NULL,
    CONSTRAINT fk_item_order_id FOREIGN KEY (order_id) 
        REFERENCES orders(order_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_qty CHECK (quantity > 0),
    CONSTRAINT chk_wt CHECK (weight_kg > 0.00)
) ENGINE=InnoDB;

-- 6. Performance Indexes
-- Purpose: Reduce lookup time from O(N) full table scans to O(log N) B-Tree seeks.
CREATE INDEX indx_orders_status ON orders(status);
CREATE INDEX indx_orders_zone_id ON orders(zone_id);
CREATE INDEX indx_orders_courier_status ON orders(courier_id, status);
CREATE INDEX indx_shifts_courier_schedule ON shifts(courier_id, start_time);
CREATE INDEX indx_items_order_id ON order_items(order_id);

-- 7. Audit Log Table: Stores a historical snapshot of deleted orders for compliance.
CREATE TABLE order_audit_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    order_total DECIMAL(10, 2) NOT NULL,
    status_at_deletion VARCHAR(30) NOT NULL,
    deleted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    deleted_by VARCHAR(100) DEFAULT (CURRENT_USER()),
    action_type VARCHAR(20) DEFAULT 'DELETED'
);
-- 8. Automatically insert log data in order_audit_logs before deletion
DELIMITER $$

CREATE TRIGGER triggr_after_order_delete
BEFORE DELETE ON orders
FOR EACH ROW
BEGIN
    INSERT INTO order_audit_logs (
        order_id,
        customer_name,
        order_total,
        status_at_deletion,
        deleted_at,
        deleted_by,
        action_type
    )
    VALUES (
        OLD.order_id,
        OLD.customer_name,
        OLD.order_total,
        OLD.status,
        NOW(),
        CURRENT_USER(),
        'RECORD_DELETED'
    );
END$$
DELIMITER ;

-- 9 Fleet Maintenance Records: For bulk loading from Excel/CSV
CREATE TABLE vehicle_maintenance_logs (
    maintenance_id INT AUTO_INCREMENT PRIMARY KEY,
    courier_id INT NOT NULL,
    service_date DATE NOT NULL,
    maintenance_type VARCHAR(50) NOT NULL,
    cost DECIMAL(8, 2) NOT NULL,
    workshop_name VARCHAR(100) NOT NULL,
    notes VARCHAR(255),
    CONSTRAINT fk_main_courier 
        FOREIGN KEY (courier_id) REFERENCES couriers(courier_id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- NOTE
-- ENGINE=InnoDB is specified to guarantee full ACID transactional safety,row-level locking concurrency 
-- and parent-side referential integrity enforcement