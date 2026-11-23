# MAGYM Logistics

A database design project for a local delivery and fulfillment platform connecting customers, restaurants, pharmacies, and riders.

**Ongoing team project · September 2026–present**  
CSEN 501 · Databases I · German University in Cairo · Winter 2026

[Project walkthrough](https://Adam-Ahmed1.github.io/projects/magym-logistics/)

## Project progress

The project is developed collaboratively across **three distinct milestones** and is still under development. This repository currently contains the Milestone 1 design artifacts.

| Milestone | Work | Repository status |
| --- | --- | --- |
| 1 | Enhanced Entity–Relationship Diagram (EERD) and relational schema | Available |
| 2 | Further course project development | To be documented |
| 3 | Final course project milestone | To be documented |

## The system

Customers build carts from products offered by local businesses. At checkout, an order can split into business-specific suborders. Riders handle delivery, payments belong to the main order, and feedback is associated with individual suborders. Zones organize geographic coverage and delivery fees; vouchers support customer discounts.

The model brings together four user roles—Admin, Partner, Rider, and Customer—and two business types: Restaurant and Pharmacy.

## Milestone 1 · Design

The conceptual model captures entities, specializations, relationships, and constraints. Its relational mapping contains **25 relations**, with primary keys, foreign keys, and composite identifiers.

- **Specialization:** shared account and business attributes stay in parent relations, with distinct subtype relations.
- **Multiple phone numbers:** separate user and business phone relations preserve multivalued contact information.
- **Cart contents:** a junction relation stores the selected product, quantity, and customer notes.
- **Suborder identity:** `(sub_order_number, order_id)` identifies a suborder and is referenced by delivery and feedback records.

[![Overview of the MAGYM Logistics EER diagram](docs/eerd-preview.webp)](milestones/ms1/eerd.pdf)

### Design files

- [Complete EERD · PDF](milestones/ms1/eerd.pdf)
- [Relational schema · PDF](milestones/ms1/relational-schema.pdf)
- [Editable EERD · draw.io](milestones/ms1/magym-logistics.drawio)

### Open the editable diagram

Download the `.drawio` file and open it in [diagrams.net](https://app.diagrams.net/)
