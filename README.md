# Final Year Database Administration Project
## SCOA031 – Enterprise Database Management & Monitoring System

### Project Details
| | |
|---|---|
| **Institution** | University of Limpopo |
| **Faculty** | Science and Agriculture |
| **Department** | Computer Science |
| **Module** | SCOA031 – Introduction to Databases |
| **Group** | Group 6 |
| **Examiner** | Dr J Tlouyamma |
| **Due Date** | 04 May 2026 |
| **Total Marks** | 100 |

---

### Project Overview

This project simulates the role of a **Database Administrator (DBA)** for a company using the **AdventureWorks 2022** database. The objective was to design, implement, and manage a secure, efficient, and monitored database system using Microsoft SQL Server.

The project demonstrates competency in:
- Automating database operations using stored procedures
- Securing access through role-based access control
- Monitoring and improving query performance
- Tracking changes using triggers and an audit table
- Sending automated email alerts via SQL Server Database Mail
- Maintaining database health through scheduled jobs

---

### Repository Structure

```
SCOA031_Group_6_Assignement/
├── Complete_Asssignment/
│   ├── Report (PDF)/
│   │   └── GROUP6(SCOA031_FULL_REPORT).pdf   ← Full documentation report
│   └── SQL SCRIPTS/
│       ├── PART A.sql      ← Stored Procedures
│       ├── PART_B.sql      ← User Roles & Security
│       ├── PART_C.sql      ← Performance Optimization
│       ├── PART_D.sql      ← Backup & Recovery
│       ├── Part_E.sql      ← Triggers, Logging & Email Alerts
│       └── Part_F.sql      ← Maintenance & Server Health
└── DECLARATION FORM AND REGISTER.pdf
```

---

### Project Outline

#### Part A – Stored Procedures (20 Marks)
Automated core database operations using stored procedures with input parameters, transaction management (BEGIN TRANSACTION / COMMIT / ROLLBACK), and error handling (TRY...CATCH). Procedures were created for:
- Adding a new customer
- Updating product prices
- Deleting/archiving inactive customers
- Generating monthly sales reports, top 10 best-selling products, and employee performance summaries

#### Part B – User Roles & Security (10 Marks)
Implemented role-based access control using three roles: **SalesRole** (read/write sales data), **HRRole** (access employee data), and **DBA_Role** (full control). Users were created and assigned to roles using GRANT, DENY, and REVOKE statements. Restricted access was demonstrated and tested.

#### Part C – Performance Optimization (10 Marks)
Identified slow-running queries and created appropriate indexes to improve performance. Rewrote inefficient queries using execution plans and created stored procedures to monitor long-running queries, database size, and index fragmentation.

#### Part D – Backup & Recovery (10 Marks)
Implemented a complete backup strategy using SQL queries including full backups, differential backups, and transaction log backups. Demonstrated the restore process and provided a documented backup schedule.

#### Part E – Triggers, Logging & Email Alerts (20 Marks)
Created an **AuditTable** to log all INSERT, UPDATE, and DELETE operations on the Customer and Product tables. Triggers were implemented on both tables to automatically record changes. SQL Server Database Mail was configured to send automated email alerts when product prices change by more than 10%, records are deleted, or critical updates occur.

#### Part F – Maintenance & Server Health (10 Marks)
Developed a maintenance plan including index rebuild/reorganize operations, database integrity checks using DBCC CHECKDB, and scheduled automation jobs using SQL Server Agent.

---

### Tools & Technologies
- **Microsoft SQL Server 2022**
- **SQL Server Management Studio (SSMS)**
- **AdventureWorks 2022 Database**
- **SQL Server Agent** (job scheduling)
- **SQL Server Database Mail** (email alerts)

---

### Mark Breakdown

| Section | Marks |
|---|---|
| Part A: Stored Procedures | 20 |
| Part B: Security | 10 |
| Part C: Performance | 10 |
| Part D: Backup | 10 |
| Part E: Triggers & Alerts | 20 |
| Part F: Maintenance | 10 |
| Documentation | 10 |
| Demonstration | 10 |
| **Total** | **100** |
