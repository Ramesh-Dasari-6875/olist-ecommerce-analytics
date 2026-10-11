# olist-ecommerce-analytics

Olist E-commerce Sales \& Customer Analysis




















\## Data Quality Findings



Dataset: Olist Brazilian E-Commerce (about 99k orders, Sep 2016 to Oct 2018).

The data is largely clean. Issues found and how they were handled:



| Issue | Count | Handling |

|---|---|---|

| Orders not delivered (canceled, unavailable, in transit) | 2,963 | Excluded from revenue analysis |

| Delivered orders missing delivery date | 8 | Excluded from delivery metrics |

| Orders with no items | 775 | Excluded (no revenue) |

| Duplicate review IDs | 789 | Reduced to one review per order |

| Orders with multiple reviews | 547 | Latest review used |

| Products with no category | 610 | Labelled "unknown" |

| Orphan order items | 0 | Referential integrity intact |



Checks are in `sql/02\_data\_quality\_checks.sql`.

## Key Findings: Revenue

- Revenue grew about 2.4x year over year (Jan to Aug 2018 vs. the same months of 2017), driven by order volume; average order value stayed flat at about R$130 to R$150.
- Growth plateaued from March 2018 at roughly R$0.85M to R$1.0M per month.
- Nov 2017 was the peak month (R$1.0M, 7,421 orders).
- health_beauty, watches_gifts and bed_bath_table lead on revenue. watches_gifts earns about R$214 per order vs. about R$110 for bed_bath_table.
- Analysis window: Jan 2017 to Aug 2018 (other months have too few orders).

- Revenue is geographically concentrated: São Paulo contributes 38.3% of revenue, and SP + RJ + MG together 63.4%. Top 5 states account for 73.9%.
- Revenue is diversified across categories: the top 10 categories make up 62.4% and none exceeds 9.3%.
- Recommendation: growth outside the southeast is the largest untapped opportunity, so test regional marketing and faster logistics for the North and Northeast.

## Key Findings: Customers (RFM)

- Only 3.0% of customers (2,888 of 94,990) purchased more than once.
- The top 40% of customers by spend (avg about R$268) generate 71.2% of revenue; repeat buyers generate only 5.6%.
- The largest segment by revenue is high-value one-time buyers who have not returned (22.2% of customers, 42.0% of revenue).
- Recommendation: test a second-purchase campaign (e.g. post-delivery coupons) aimed at high-value one-time buyers, since a small lift in repeat rate would affect a large share of revenue.

