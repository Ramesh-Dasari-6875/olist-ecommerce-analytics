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

