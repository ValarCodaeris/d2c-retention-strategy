-- ============================================================
-- Decoding Customer Value: A SQL-Driven Retention Strategy
-- Consulting & Analytics Club, IIT Guwahati — Summer Projects '26
-- Author: [Mahendra Gothwal]
-- Database: retail_customers (SQLite)
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- SCHEMA REFERENCE
-- ────────────────────────────────────────────────────────────
-- customer_id          TEXT    Unique customer identifier
-- age                  INT     Customer age (18–64)
-- age_band             TEXT    Age group bucket (18-24, 25-34, 35-44, 45-54, 55-64)
-- gender               TEXT    Male / Female / Non-binary
-- state                TEXT    US state
-- product_category     TEXT    Clothing / Accessories / Footwear / Outerwear
-- season               TEXT    Spring / Summer / Fall / Winter
-- previous_purchases   INT     Count of purchases made before latest
-- purchase_amount_usd  REAL    Net spend on latest order (after discount)
-- discount_applied     INT     1 = discount used, 0 = full price
-- discount_pct         INT     Discount percentage (0, 5, 10, 15, 20, 25, 30)
-- payment_method       TEXT    Credit Card / Debit Card / PayPal / Apple Pay / BNPL
-- shipping_type        TEXT    Standard / Express / Overnight / Free Shipping
-- review_rating        REAL    Customer rating 1–5
-- return_rate          REAL    Fraction of orders returned (0–1)
-- promo_dependency_score REAL  Engineered: 0 = zero promo reliance, 1 = fully promo-driven
-- clv_proxy            REAL    Engineered: purchase_amount_usd × previous_purchases
-- value_tier           TEXT    High / Mid / Low  (based on clv_proxy percentiles)
-- satisfaction_flag    INT     1 = review_rating >= 4
-- loyal_behavioural    INT     Def-A loyalty: prev_purchases >= 7 AND no discount used
-- loyal_value_weighted INT     Def-B loyalty: High tier + satisfied + low return rate
-- high_spend_flag      INT     1 = above-median purchase amount
-- discount_only_buyer  INT     1 = discount used AND Low value tier


-- ============================================================
-- QUESTION 1
-- Who are the genuinely loyal customers vs. those who only
-- buy when there is a discount?
-- ============================================================

SELECT
    CASE
        WHEN loyal_behavioural = 1               THEN 'Genuinely Loyal'
        WHEN discount_applied = 1
         AND previous_purchases < 4              THEN 'Bargain Hunter'
        WHEN discount_applied = 0
         AND previous_purchases < 4              THEN 'New Organic'
        ELSE                                          'Occasional Buyer'
    END                                              AS customer_type,

    COUNT(*)                                         AS total_customers,
    ROUND(100.0 * COUNT(*) / 3900, 1)               AS pct_of_base,
    ROUND(AVG(purchase_amount_usd), 2)              AS avg_spend_usd,
    ROUND(AVG(previous_purchases), 1)               AS avg_purchase_count,
    ROUND(AVG(promo_dependency_score), 3)           AS avg_promo_dependency,
    ROUND(AVG(review_rating), 2)                    AS avg_rating,
    ROUND(AVG(clv_proxy), 2)                        AS avg_clv_proxy,
    ROUND(SUM(purchase_amount_usd), 2)              AS total_revenue_usd

FROM customers
GROUP BY customer_type
ORDER BY avg_clv_proxy DESC;

-- Insight: Genuinely Loyal customers (670, 17%) deliver avg CLV of $2,699 vs
-- $149 for Bargain Hunters (889, 23%). Bargain Hunters represent the brand's
-- biggest margin leak — high volume, low value, discount-dependent.


-- ============================================================
-- QUESTION 2
-- What behavioral patterns today predict high customer value?
-- ============================================================

-- 2A: Value Tier Profile
SELECT
    value_tier,
    COUNT(*)                                         AS customers,
    ROUND(100.0 * COUNT(*) / 3900, 1)               AS pct_of_base,
    ROUND(AVG(previous_purchases), 1)               AS avg_prev_purchases,
    ROUND(AVG(purchase_amount_usd), 2)              AS avg_spend_usd,
    ROUND(AVG(review_rating), 2)                    AS avg_rating,
    ROUND(AVG(return_rate), 3)                      AS avg_return_rate,
    ROUND(AVG(promo_dependency_score), 3)           AS promo_dependency,
    ROUND(SUM(purchase_amount_usd), 2)              AS total_revenue_usd,
    SUM(loyal_behavioural)                          AS loyal_customers_defA,
    SUM(loyal_value_weighted)                       AS loyal_customers_defB

FROM customers
GROUP BY value_tier
ORDER BY avg_spend_usd DESC;

-- 2B: Strongest predictors among High-value customers
SELECT
    'High Purchase Count (>= 7)'                    AS behavioral_signal,
    COUNT(*)                                         AS matching_customers,
    ROUND(AVG(clv_proxy), 2)                        AS avg_clv,
    ROUND(AVG(promo_dependency_score), 3)           AS promo_dep
FROM customers WHERE previous_purchases >= 7

UNION ALL

SELECT
    'High Spend + No Discount',
    COUNT(*),
    ROUND(AVG(clv_proxy), 2),
    ROUND(AVG(promo_dependency_score), 3)
FROM customers WHERE high_spend_flag = 1 AND discount_applied = 0

UNION ALL

SELECT
    'Satisfied (Rating >= 4) + High Spend',
    COUNT(*),
    ROUND(AVG(clv_proxy), 2),
    ROUND(AVG(promo_dependency_score), 3)
FROM customers WHERE satisfaction_flag = 1 AND high_spend_flag = 1

UNION ALL

SELECT
    'Low Return Rate (< 0.15) + High Spend',
    COUNT(*),
    ROUND(AVG(clv_proxy), 2),
    ROUND(AVG(promo_dependency_score), 3)
FROM customers WHERE return_rate < 0.15 AND high_spend_flag = 1

ORDER BY avg_clv DESC;

-- Insight: "High Purchase Count" is the strongest individual predictor of CLV.
-- A customer with >= 7 previous purchases and no discount usage is 18x more
-- valuable (CLV) than a bargain hunter with 1-3 purchases.


-- ============================================================
-- QUESTION 3
-- Which geographies and demographics are commercially
-- underlevered?
-- ============================================================

-- 3A: State-level opportunity matrix
SELECT
    state,
    COUNT(*)                                                  AS customers,
    ROUND(AVG(purchase_amount_usd), 2)                       AS avg_spend_usd,
    ROUND(AVG(promo_dependency_score), 3)                    AS promo_dep,
    ROUND(SUM(purchase_amount_usd), 2)                       AS total_revenue_usd,
    ROUND(100.0 * SUM(CASE WHEN discount_applied = 0
                           THEN 1 ELSE 0 END) / COUNT(*), 1) AS organic_buyer_pct,
    SUM(loyal_behavioural)                                   AS loyal_count,

    CASE
        WHEN AVG(promo_dependency_score) < 0.40
         AND AVG(purchase_amount_usd) > 95               THEN 'High Opportunity'
        WHEN AVG(promo_dependency_score) >= 0.50         THEN 'Discount Driven'
        ELSE                                                  'Moderate'
    END                                                       AS geo_segment

FROM customers
GROUP BY state
ORDER BY avg_spend_usd DESC;

-- 3B: Underlevered demographics (high CLV, not yet a large segment)
SELECT
    age_band,
    gender,
    COUNT(*)                                         AS customers,
    ROUND(AVG(clv_proxy), 2)                        AS avg_clv,
    ROUND(AVG(purchase_amount_usd), 2)              AS avg_spend,
    ROUND(AVG(promo_dependency_score), 3)           AS promo_dep,
    SUM(loyal_behavioural)                          AS loyal_count,
    ROUND(100.0 * SUM(loyal_behavioural) / COUNT(*), 1) AS loyal_pct

FROM customers
GROUP BY age_band, gender
HAVING customers >= 50
ORDER BY avg_clv DESC;

-- Insight: Virginia ($101 avg spend, 39% organic buyers) and New York
-- ($100 avg spend, 44% organic) are underserved relative to California
-- which has more customers but similar avg spend. Focus paid acquisition there.


-- ============================================================
-- QUESTION 4
-- How should the brand restructure its promotional strategy
-- to protect margins without losing volume?
-- ============================================================

-- 4A: Promo ROI analysis by tier
SELECT
    value_tier,
    CASE discount_applied WHEN 1 THEN 'With Discount' ELSE 'Full Price' END AS purchase_type,
    COUNT(*)                                                  AS customers,
    ROUND(AVG(purchase_amount_usd), 2)                       AS avg_net_spend,
    ROUND(SUM(purchase_amount_usd), 2)                       AS total_revenue,
    ROUND(SUM(purchase_amount_usd * discount_pct / 100.0), 2) AS discount_cost_usd,
    ROUND(AVG(review_rating), 2)                             AS avg_rating,
    ROUND(AVG(promo_dependency_score), 3)                    AS promo_dep

FROM customers
GROUP BY value_tier, discount_applied
ORDER BY value_tier, discount_applied;

-- 4B: Identify segments to sunset discounts first
SELECT
    CASE
        WHEN value_tier = 'High' AND discount_applied = 1  THEN 'Sunset Priority 1: High-Value Discount Users'
        WHEN value_tier = 'Mid'  AND discount_applied = 1
         AND previous_purchases >= 5                        THEN 'Sunset Priority 2: Mid-Tier Repeat Buyers'
        WHEN discount_only_buyer = 1                        THEN 'No Action: Bargain Hunters (Accept Churn)'
        ELSE                                                     'Monitor'
    END                                                     AS sunset_segment,
    COUNT(*)                                                AS customers,
    ROUND(SUM(purchase_amount_usd * discount_pct/100.0), 2) AS discount_savings_if_removed,
    ROUND(AVG(clv_proxy), 2)                               AS avg_clv,
    ROUND(AVG(promo_dependency_score), 3)                  AS promo_dep

FROM customers
GROUP BY sunset_segment
ORDER BY discount_savings_if_removed DESC;

-- Insight: Removing discounts from High-Value tier saves $9,018 immediately.
-- These customers have avg CLV of $2,699 — they buy because they love the brand,
-- not because of the discount. Mid-Tier repeat buyers are the next priority.


-- ============================================================
-- QUESTION 5
-- What does the brand's ideal customer profile look like,
-- and how can it acquire more of them?
-- ============================================================

-- 5A: Ideal Customer Profile — Top attribute combinations
SELECT
    age_band,
    gender,
    product_category,
    payment_method,
    COUNT(*)                                         AS customer_count,
    ROUND(AVG(purchase_amount_usd), 2)              AS avg_spend_usd,
    ROUND(AVG(previous_purchases), 1)               AS avg_purchases,
    ROUND(AVG(review_rating), 2)                    AS avg_rating,
    ROUND(AVG(promo_dependency_score), 3)           AS promo_dep,
    ROUND(AVG(clv_proxy), 2)                        AS avg_clv

FROM customers
WHERE value_tier = 'High'
  AND loyal_behavioural = 1        -- Def-A: repeat buyer, no discount
GROUP BY age_band, gender, product_category, payment_method
HAVING customer_count >= 3
ORDER BY avg_clv DESC
LIMIT 15;

-- 5B: Ideal customer summary stats
SELECT
    'Ideal Customer (High + Loyal)'                 AS segment,
    COUNT(*)                                         AS customers,
    ROUND(AVG(age), 1)                              AS avg_age,
    ROUND(AVG(purchase_amount_usd), 2)              AS avg_spend,
    ROUND(AVG(previous_purchases), 1)               AS avg_purchases,
    ROUND(AVG(review_rating), 2)                    AS avg_rating,
    ROUND(AVG(return_rate), 3)                      AS avg_return_rate,
    ROUND(AVG(promo_dependency_score), 3)           AS promo_dep,
    ROUND(AVG(clv_proxy), 2)                        AS avg_clv,

    -- Most common attributes
    (SELECT payment_method FROM customers
     WHERE value_tier='High' AND loyal_behavioural=1
     GROUP BY payment_method ORDER BY COUNT(*) DESC LIMIT 1) AS top_payment,

    (SELECT product_category FROM customers
     WHERE value_tier='High' AND loyal_behavioural=1
     GROUP BY product_category ORDER BY COUNT(*) DESC LIMIT 1) AS top_category,

    (SELECT shipping_type FROM customers
     WHERE value_tier='High' AND loyal_behavioural=1
     GROUP BY shipping_type ORDER BY COUNT(*) DESC LIMIT 1) AS top_shipping

FROM customers
WHERE value_tier = 'High' AND loyal_behavioural = 1;

-- 5C: Category preference by loyalty tier
SELECT
    product_category,
    ROUND(AVG(CASE WHEN value_tier='High' THEN clv_proxy END), 2)   AS high_tier_clv,
    ROUND(AVG(CASE WHEN value_tier='Mid'  THEN clv_proxy END), 2)   AS mid_tier_clv,
    ROUND(AVG(CASE WHEN value_tier='Low'  THEN clv_proxy END), 2)   AS low_tier_clv,
    SUM(CASE WHEN loyal_behavioural=1 THEN 1 ELSE 0 END)            AS loyal_customers,
    ROUND(AVG(promo_dependency_score), 3)                            AS category_promo_dep

FROM customers
GROUP BY product_category
ORDER BY high_tier_clv DESC;

-- Insight: Ideal customer is a 25-44 year old (male or female), pays by
-- Credit Card, buys Clothing or Footwear, has 15+ previous purchases, avg spend
-- $175-$210, rating ~4.0, promo dependency near 0. This profile should be used
-- directly for paid acquisition targeting (Meta/Google lookalike audiences).
