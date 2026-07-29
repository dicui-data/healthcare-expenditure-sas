# MEPS 2023 Health Care Expenditure Analysis

Weighted national estimates of U.S. health care spending in 2023: how many
people spend nothing, how concentrated spending is, who pays for it, and
where the out-of-pocket burden falls. Built in SAS from the Medical
Expenditure Panel Survey, with the survey's complex sample design handled
throughout.

## Summary

- Spending is extremely concentrated. The highest-spending 5% of the
  population accounts for 48.6% of all spending and the highest 10% for
  65.2%, while the lower half accounts for 2.9%.

- Private insurance pays 42.1% of every dollar spent, Medicare 27.8%,
  households 13.4% out of pocket, and Medicaid 11.1%.

- The uninsured are not paying more; they receive far less care. They
  spend $1,062 per person against $7,600 for the privately insured, and
  more than half record no spending at all in the year. Of what they do
  spend, they pay 51.6% themselves.

- Charges run 2.8 times what is actually paid. Comparing the two columns
  as published gives 2.2, because one excludes prescriptions and the
  other does not.

## Data

MEPS Household Component, 2023 Full Year Consolidated File (HC-251),
published by the Agency for Healthcare Research and Quality.

- 18,919 person-level records, about 1,400 variables
- Represents 334,530,273 people, the U.S. civilian noninstitutionalized
  population in 2023
- Public use file, SAS V9 format
- Download: https://meps.ahrq.gov/data_stats/download_data_files_detail.jsp?cboPufNumber=HC-251

The data file is not in this repository. Download it and place it in the
folder named in the `LIBNAME` statement of `01_load.sas`.

## Why ordinary procedures give wrong answers

MEPS uses weighting, stratification and clustering. Three variables carry
that design.

| Variable | Role | Effect on the standard error |
|---|---|---|
| `PERWT23F` | Final person weight | none; it sets the point estimate |
| `VARSTR` | Variance estimation stratum | lowers it |
| `VARPSU` | Variance estimation PSU | raises it |

`PROC MEANS` and `PROC FREQ` ignore the weight, so the point estimate is
wrong, and they assume independent sampling, so the standard error is
understated. Clustering outweighs stratification for a national household
survey, so omitting both makes results look more precise than they are.

Three rules follow, applied everywhere in this analysis.

**Subgroups use `DOMAIN`, not `WHERE`.** A `WHERE` clause deletes records
the variance estimator needs and can leave a stratum with a single PSU.
The point estimate survives; the standard error does not, and no error is
raised.

**Shares use `RATIO`, not two separate estimates divided.** Numerator and
denominator are both estimated and their errors covary. `RATIO` handles
the covariance in one pass; dividing two totals returns a confidence
interval that is too wide.

**Person-level ratios are never averaged.** Averaging a per-person
out-of-pocket share would weight a $50 person and a $500,000 person
equally and force the exclusion of everyone who spent nothing.

## Repository structure

```
code/
  01_load.sas      Load the raw file, build the reduced analysis file
  02_explore.sas   Data quality checks before any estimate is produced
  03_prep.sas      Reserved codes, derived variables, value labels
  04_analysis.sas  Weighted national estimates
output/
  results.md       Result tables
```

Run in order. `01_load.sas` runs once. Programs after `03_prep.sas`
require `OPTIONS FMTSEARCH=(meps work)` to resolve the value labels stored
in the permanent catalog.

## Data quality checks

Each check is in the code and its result is reported, whether or not it
found a problem.

**Design variables reproduce the published figures.** The HC-251 codebook
prints weighted frequencies for each variable. Estimating them with the
design applied reproduces every category and the population total of
334,530,273, confirming the weight, stratum and cluster variables are
used correctly. Nothing downstream is meaningful if this fails.

**Service categories reconcile to the total.** The ten service-level
expenditure variables sum to `TOTEXP23` for every record, difference
exactly zero, with no double counting from the facility and physician
components already inside the category totals.

**Sources of payment reconcile to the total.** The same identity across
the ten payment sources holds to within $3, the residual expected from
whole-dollar rounding of the components against the total. MEPS also
supplies two combined variables that overlap the detailed sources; the
"other" combined variable proved to be a subset of the detailed ones,
short by about $375 per person on average, so the analysis builds its own
combined group from the detailed variables rather than reusing it.

**Charges and expenditures are not on the same basis.** `TOTTCH23`
excludes prescribed medicines while `TOTEXP23` includes them. Compared as
published, charges are 2.17 times what was paid; on a matching basis,
2.81. Prescriptions are about 23% of total expenditure, which drives the
difference. This check changed a headline number.

**Sample design is intact.** 105 strata, each holding two to five PSUs,
none with a single PSU, so a variance estimate is defined everywhere.
None of the three design variables is missing.

**Zero-weight records.** 456 records carry a weight of zero. The survey
procedures exclude them automatically, so estimates rest on 18,463
records while the design still spans 105 strata and 262 PSUs. They are
left in the file so the record count ties back to the published file.

**Reserved codes are contained.** MEPS stores inapplicable, refused and
don't-know answers as negative numbers. 282 records (1.5%) carry at least
one, and they are largely the same people rather than a scattered 1.5%:
those who left the survey before its final round. They are set to missing
on a copy. None of the four variables this analysis reports on carries a
reserved code, so every record contributes to every estimate.

**Coverage categories were read from the codebook, not assumed.**
`INSURC23` mixes age with coverage: its first three categories are under
65 and the rest 65 and over, so it is not a coverage variable on its own.
Two categories hold 21 and 59 records, too few to estimate separately,
and are combined into one group defined by what they share, no Medicare
despite being 65 or over. Results that should not read as age comparisons
use `INSCOV23`, the collapse MEPS publishes, which also resolves 59 people
`INSURC23` leaves ambiguous (57 to private, 2 to public).


## Findings

Weighted national estimates for 2023, 95% confidence intervals. Full
tables are in [`output/results.md`](output/results.md).

- **14.4%** of the population recorded no spending at all (53.2% among the
  uninsured, 3.5% among those 65 and over).

- Spending is concentrated: the highest-spending **5%** accounts for
  **48.6%** of all spending, the highest **10%** for **65.2%**, the lower
  half for **2.9%**. Mean spending is $7,487 against a median of $1,583.

- Payer mix: private insurance **42.1%**, Medicare **27.8%**, out of
  pocket **13.4%**, Medicaid **11.1%**, other **5.6%**. By coverage type
  each group is carried by its own payer, and the uninsured are the only
  group where households are the largest source.

- The out-of-pocket share of spending rises with income, from **5.3%**
  among the poor to **16.7%** among high-income households. It is a share
  of the bill, not of income, and the two run in opposite directions.

- Charges are **2.8** times payments on a comparable basis; comparing the
  columns as published understates this at 2.2, because one excludes
  prescriptions.

## Limitations

- One calendar year, so no trend.
- Person-level survey data, so no provider, claim or encounter detail.
- Annual totals only, so no seasonality or timing.
- Four census regions and no state identifier, so no state comparison.
- Expenditure is what was paid; charges are a separate concept, compared
  in Appendix A but not treated as spending.
- Small groups carry wide intervals and are reported combined rather than
  separately.

## Reference

AHRQ example code at https://github.com/HHS-AHRQ/MEPS was used as a
reference for survey procedure syntax. That code targets earlier data
years and the SAS transport format, so the loading step and the
year-suffixed variable names here differ from it.
