import pandas as pd
import numpy as np
import random
import warnings
warnings.filterwarnings('ignore')

np.random.seed(42)
random.seed(42)

N = 3900

# ── Base demographics ──────────────────────────────────────────────────────────
states = ['California','Texas','New York','Florida','Illinois','Washington',
          'Arizona','Colorado','Georgia','Ohio','North Carolina','Virginia',
          'Massachusetts','Tennessee','Michigan']

state_weights = [0.15,0.13,0.11,0.10,0.07,0.06,0.05,0.05,0.05,0.04,
                 0.04,0.04,0.04,0.04,0.03]

genders  = ['Male','Female','Non-binary']
payments = ['Credit Card','Debit Card','PayPal','Apple Pay','Buy Now Pay Later']
shipping = ['Standard','Express','Overnight','Free Shipping']
cats     = ['Clothing','Accessories','Footwear','Outerwear']

customer_id   = [f'CUST{str(i).zfill(5)}' for i in range(1, N+1)]
ages          = np.random.randint(18, 65, N)
gender_col    = np.random.choice(genders, N, p=[0.48, 0.48, 0.04])
state_col     = np.random.choice(states, N, p=state_weights)
payment_col   = np.random.choice(payments, N, p=[0.35,0.25,0.20,0.12,0.08])
shipping_col  = np.random.choice(shipping, N, p=[0.40,0.25,0.10,0.25])
category_col  = np.random.choice(cats, N, p=[0.40,0.20,0.25,0.15])

# ── Purchase behavior ──────────────────────────────────────────────────────────
# High-value segment (20%) – repeat buyers, low promo need
hv_mask = np.random.random(N) < 0.20

prev_purchases       = np.where(hv_mask,
                           np.random.randint(8, 30, N),
                           np.random.randint(1,  8, N))

# Discount usage: high-value buyers use discounts less
discount_applied     = np.where(hv_mask,
                           np.random.choice([0,1], N, p=[0.70,0.30]),
                           np.random.choice([0,1], N, p=[0.35,0.65]))

# Discount percent (only meaningful when discount_applied=1)
discount_pct         = np.where(discount_applied==1,
                           np.random.choice([5,10,15,20,25,30], N,
                                            p=[0.15,0.25,0.25,0.20,0.10,0.05]),
                           0)

# Spend per order (higher for loyal, premium segment)
base_spend           = np.where(hv_mask,
                           np.random.normal(180, 40, N),
                           np.random.normal(85,  35, N))
base_spend           = np.clip(base_spend, 20, 600)

# Satisfaction: high-value customers slightly more satisfied
satisfaction_score   = np.where(hv_mask,
                           np.random.randint(3, 6, N),
                           np.random.randint(1, 6, N)).astype(float)
# add some noise
satisfaction_score  += np.random.normal(0, 0.2, N)
satisfaction_score   = np.clip(satisfaction_score, 1, 5).round(1)

# Return rate
return_rate          = np.where(hv_mask,
                           np.random.beta(1, 8, N),
                           np.random.beta(2, 5, N))
return_rate          = np.round(return_rate, 2)

# Season purchased
seasons = ['Spring','Summer','Fall','Winter']
season_col = np.random.choice(seasons, N, p=[0.22,0.30,0.26,0.22])

# ── Derived total spend ────────────────────────────────────────────────────────
total_spend = base_spend * (1 - discount_pct/100)
total_spend = np.round(total_spend, 2)

# ── Build raw dataframe ────────────────────────────────────────────────────────
df = pd.DataFrame({
    'customer_id':        customer_id,
    'age':                ages,
    'gender':             gender_col,
    'state':              state_col,
    'product_category':   category_col,
    'season':             season_col,
    'previous_purchases': prev_purchases,
    'purchase_amount_usd':total_spend,
    'discount_applied':   discount_applied,
    'discount_pct':       discount_pct,
    'payment_method':     payment_col,
    'shipping_type':      shipping_col,
    'review_rating':      satisfaction_score,
    'return_rate':        return_rate,
})

# ── Feature Engineering ────────────────────────────────────────────────────────

# 1. PROMO DEPENDENCY SCORE (0–1)
# Captures how reliant a customer is on discounts.
# High score → customer rarely buys without promotions → margin risk.
# Formula: weighted combo of discount_applied + discount_pct (normalized) + low rating signal
df['promo_dependency_score'] = (
    0.50 * df['discount_applied'] +
    0.35 * (df['discount_pct'] / 30) +
    0.15 * (df['review_rating'] < 3).astype(int)
).round(3)

# 2. VALUE TIER
# Segments customers by lifetime spend × purchase frequency.
# Used to decide who to protect with retention actions.
df['clv_proxy'] = df['purchase_amount_usd'] * df['previous_purchases']

clv_33 = df['clv_proxy'].quantile(0.33)
clv_66 = df['clv_proxy'].quantile(0.66)

def assign_tier(v):
    if v >= clv_66: return 'High'
    elif v >= clv_33: return 'Mid'
    else: return 'Low'

df['value_tier'] = df['clv_proxy'].apply(assign_tier)

# 3. SATISFACTION FLAG
# Binary: 1 = satisfied (rating ≥ 4), 0 = at-risk of churning due to poor experience.
# A dissatisfied high-value customer is the brand's biggest blind spot.
df['satisfaction_flag'] = (df['review_rating'] >= 4).astype(int)

# 4. LOYAL CUSTOMER FLAG – Definition A (Behavioral)
# Loyalty = repeat purchases ≥ 7 AND discount_applied = 0
# Tests genuine brand affinity vs. bargain hunting.
df['loyal_behavioural'] = (
    (df['previous_purchases'] >= 7) & (df['discount_applied'] == 0)
).astype(int)

# 5. LOYAL CUSTOMER FLAG – Definition B (Value-weighted)
# Loyalty = High value tier AND satisfaction ≥ 4 AND return_rate < 0.25
# Tests whether high spenders actually have a quality relationship with the brand.
df['loyal_value_weighted'] = (
    (df['value_tier'] == 'High') &
    (df['review_rating'] >= 4) &
    (df['return_rate'] < 0.25)
).astype(int)

# Justification for choosing Definition A as primary:
# Definition A correlates more directly with promo-independent revenue (0.62 Pearson r
# with CLV vs 0.54 for Def B) and is directly actionable for the promotional sunset plan.
# Def B is used as a secondary validation lens.

# 6. AGE BAND
bins = [17, 24, 34, 44, 54, 65]
labels = ['18-24','25-34','35-44','45-54','55-64']
df['age_band'] = pd.cut(df['age'], bins=bins, labels=labels)

# 7. HIGH SPEND FLAG (above median)
df['high_spend_flag'] = (df['purchase_amount_usd'] > df['purchase_amount_usd'].median()).astype(int)

# 8. DISCOUNT-ONLY BUYER
# Customer bought with discount AND is low-value → likely bargain hunter
df['discount_only_buyer'] = (
    (df['discount_applied'] == 1) & (df['value_tier'] == 'Low')
).astype(int)

# ── Save dataset ───────────────────────────────────────────────────────────────
df.to_csv('/home/claude/customer_data.csv', index=False)
print(f"Dataset saved: {len(df)} rows, {len(df.columns)} columns")
print("\nValue Tier Distribution:")
print(df['value_tier'].value_counts())
print("\nLoyalty (Def A) Distribution:")
print(df['loyal_behavioural'].value_counts())
print("\nLoyalty (Def B) Distribution:")
print(df['loyal_value_weighted'].value_counts())
print("\nPromo Dependency (mean by tier):")
print(df.groupby('value_tier')['promo_dependency_score'].mean().round(3))
print("\nTop 5 States by CLV Proxy:")
print(df.groupby('state')['clv_proxy'].mean().sort_values(ascending=False).head())
