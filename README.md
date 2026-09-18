# Logistics Fleet & Delivery Optimization Engine (M605 Advanced Databases)

- **GitHub Repository:** https://github.com/Ankitpatel008/Logistics-Fleet-Database-System
- **Video Demonstration URL:** https://youtu.be/m605-logistics-fleet-walkthrough (3-5 min technical walkthrough)

---

## Project Overview
This repository contains the database architecture, procedural seeder pipelines, performance-optimized queries, compliance auditing triggers, and concurrency control scripts for the **Logistics Fleet & Delivery Optimization Engine**. Developed for the M605 Advanced Databases individual project at Gisma University of Applied Sciences, the system runs on **MySQL 8.0 / InnoDB** to manage structured urban parcel logistics, courier shifts, vehicle maintenance logs, and real-time fleet balancing under strict ACID compliance.

---

## Repository Structure & SQL Script Breakdown

The implementation is structured across three sequential script files:

### 1. `01_schema.sql` (Database & Schema Architecture)
* **Description:** Provisions the relational database schema under strict Third Normal Form (3NF) normalization rules.
* **Key Components:**
  * Creates 7 normalized tables: `delivery_zones`, `couriers`, `shifts`, `orders`, `order_items`, `vehicle_maintenance_logs`, and `order_audit_logs`.
  * Enforces primary keys, foreign key constraints, referential cascades (`ON DELETE CASCADE`, `SET NULL`), and domain constraints (`ENUM` delivery states, positive weights/quantities, valid rating bounds).
  * Establishes composite B-Tree indexes (e.g., `indx_orders_courier_status`) to optimize high-frequency dispatch lookups.

### 2. `02_data_ingestion_and_process.sql` (ETL Pipeline & Procedural Seeder)
* **Description:** Handles automated synthetic data generation and bulk external file ingestion.
* **Key Components:**
  * Features the custom stored procedure `PopulateFleetData()` to generate over 1,000 realistic German logistics records mapped to Berlin postal sectors.
  * Implements a native MySQL bulk data loader (`LOAD DATA INFILE`) to ingest external CSV workshop repair histories into `vehicle_maintenance_logs`.
  * Executes correlated aggregate updates to synchronize parent order totals with child line-item valuations.

### 3. `03_query_and_transaction.sql` (Business Queries, Triggers & Concurrency)
* **Description:** Contains analytical business queries, automated compliance triggers, and transaction safety controls.
* **Key Components:**
  * **Functional Queries (Q1-Q4):** Multi-table aggregations for driver revenue, left-join congestion mapping for Berlin delivery sectors, heavy cargo payload audits, and conditional `CASE` priority dispatching.
  * **Compliance Trigger:** Implements a `BEFORE DELETE` trigger on the `orders` table capturing complete financial snapshots, session metadata (`CURRENT_USER()`, `NOW()`), and user identifiers into `order_audit_logs` prior to cascade deletions.
  * **ACID Rollback Testing:** Demonstrates explicit transaction handling (`START TRANSACTION`, `ROLLBACK`) to guarantee safe recovery states.
  * **Pessimistic Concurrency Control:** Implements exclusive row-level locking via `SELECT ... FOR UPDATE` and finalizes actions with `COMMIT;` to prevent race conditions under multi-dispatcher workloads.

---

## Execution Instructions
1. Clone or download this repository to your local machine.
2. Open **MySQL Workbench** connected to your local MySQL 8.0 instance.
3. Execute the scripts in numerical order:
   - **Step 1:** Run `01_schema.sql` to build the database schema and indexes.
   - **Step 2:** Run `02_data_ingestion_and_process.sql` to populate synthetic data and ingest CSV metrics.
   - **Step 3:** Run `03_query_and_transaction.sql` to execute analytical queries, test triggers, and run concurrency transaction blocks.