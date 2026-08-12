# Decoding Customer Value: A SQL-Driven Retention Strategy

> **Summer Projects '26** — Consulting & Analytics Club, IIT Guwahati
> **Author:** Mahendra Gothwal | IIT Guwahati
> **Date:** May 23, 2026

---

## Project Overview

A D2C fashion brand selling Clothing, Accessories, Footwear, and Outerwear across the United States has behavioral data on ~3,900 customers but no intelligence built on top of it. The brand runs a discount program and wants to know:

> *"Is the business building a loyal customer base — or is it just attracting bargain hunters?"*

This project uses Python for feature engineering, SQL for segmentation, and an interactive dashboard to answer that question and deliver an actionable retention strategy.

---

## Key Findings

| Metric | Value |
|---|---|
| Genuinely Loyal Customers | 670 (17.2% of base) |
| Avg CLV — Loyal Segment | $2,699 |
| Avg CLV — Bargain Hunters | $149 |
| Unnecessary Discount Cost | $26,078 / period |
| Recoverable Margin (90 days) | **$18,433** |

---

## Dashboard Preview

> Open `dashboard/founder_dashboard.html` in any browser — no server needed.

**4 Panels:**
- Customer Pyramid — value distribution across the base
- Promo Dependency vs CLV — who needs discounts to buy
- Geographic Opportunity Map — organic vs discount-driven states
- Category Funnel — entry-point vs retention categories

---

## Folder Structure

```
d2c-retention-strategy/
├── README.md
├── requirements.txt
├── data/
│   └── customer_data.csv          # 3,900-row synthetic dataset
├── python/
│   └── generate_dataset.py        # Data generation + feature engineering
├── sql/
│   └── segmentation_queries.sql   # All 5 key segmentation queries
├── dashboard/
│   └── founder_dashboard.html     # Interactive 4-panel dashboard
└── docs/
    ├── retention_playbook.docx     # Full strategy playbook
    └── executive_summary.docx     # 1-page executive summary
```

---

## How to Run

### 1. Generate the Dataset
```bash
pip install -r requirements.txt
python python/generate_dataset.py
```
This creates `customer_data.csv` with all engineered features.

### 2. Run SQL Queries
Load `data/customer_data.csv` into any SQL tool:

**SQLite (command line):**
```bash
sqlite3 retail.db
.mode csv
.import data/customer_data.csv customers
.read sql/segmentation_queries.sql
```

**Or use:** DB Browser for SQLite (free GUI) — just drag in the CSV and run the SQL file.

### 3. View the Dashboard
```bash
# Just open in browser — no server needed
open dashboard/founder_dashboard.html
```

---

## Engineered Features

| Feature | Description |
|---|---|
| `promo_dependency_score` | 0–1 score: how reliant a customer is on discounts |
| `value_tier` | High / Mid / Low based on CLV proxy percentiles |
| `clv_proxy` | purchase_amount × previous_purchases |
| `satisfaction_flag` | 1 if review_rating ≥ 4 |
| `loyal_behavioural` | Def-A: purchases ≥ 7 AND no discount used |
| `loyal_value_weighted` | Def-B: High tier + satisfied + low return rate |
| `discount_only_buyer` | Discount used AND Low value tier |

---

## SQL Queries — 5 Key Questions

| Query | Business Question |
|---|---|
| Q1 | Loyal vs Bargain Hunters — who actually is who? |
| Q2 | What behavioral patterns predict high customer value? |
| Q3 | Which geographies are underlevered? |
| Q4 | How to restructure the promo strategy? |
| Q5 | What does the ideal customer look like? |

---

## Retention Strategy (Summary)

**Sunset Priority 1** — Remove discounts from 523 High-tier customers. Replace with free express shipping. Expected margin recovery: **$9,018**.

**Sunset Priority 2** — Shift 420 Mid-tier repeat buyers from discounts to a points loyalty program. Expected margin recovery: **$9,415** over 90 days.

**No Action** — Accept churn of 879 Bargain Hunters (avg CLV $149). Reallocate their promo budget to lookalike acquisition.

---

## Ideal Customer Profile

| Attribute | Value |
|---|---|
| Age | 25–44 |
| Payment | Credit Card |
| Category | Footwear / Clothing |
| Avg Order Value | $175–$215 |
| Avg CLV | $3,500–$5,600 |
| Promo Dependency | ~0.00 |
| Best States | Virginia, Ohio, North Carolina |

---

## Tools Used

- **Python** — pandas, numpy (data generation + feature engineering)
- **SQL** — SQLite compatible (segmentation queries)
- **HTML / Chart.js** — Interactive dashboard
- **Microsoft Word / docx** — Strategy documents

---

## Contact

**Mahendra Gothwal**
IIT Guwahati
Summer Projects '26 — Consulting & Analytics Club
