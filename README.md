# MAGYM Logistics

A database design project for a local delivery and fulfillment platform connecting customers, restaurants, pharmacies, and riders.

**Ongoing team project · September 2026–present**  
CSEN 501 · Databases I · German University in Cairo · Winter 2026

[Project walkthrough](https://Adam-Ahmed1.github.io/projects/magym-logistics/)

## Project progress

The project is developed collaboratively across **three distinct milestones** and is still under development. This repository currently contains the Milestone 1 design artifacts and Milestone 2 TSQL implementation.

| Milestone | Work | Repository status |
| --- | --- | --- |
| 1 | Enhanced Entity–Relationship Diagram (EERD) and relational schema | Done |
| 2 | TSQL Procedures, Views, and Functions for added features | Done |
| 3 | UI | Incomplete |

## Overview

Customers build carts from products offered by local businesses. At checkout, an order can split into business-specific suborders. Riders handle delivery, payments belong to the main order, and feedback is associated with individual suborders. Zones organize geographic coverage and delivery fees; vouchers support customer discounts.

The model brings together four user roles—Admin, Partner, Rider, and Customer—and two business types: Restaurant and Pharmacy.

### Design files

- [Complete EERD · PDF](milestones/ms1/eerd.pdf)
- [Relational schema · PDF](milestones/ms1/relational-schema.pdf)
- [Editable EERD · draw.io](milestones/ms1/magym-logistics.drawio)

### Open the editable diagram

Download the `.drawio` file and open it in [diagrams.net](https://app.diagrams.net/)
