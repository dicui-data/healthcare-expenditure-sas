# MEPS 2023 Healthcare Expenditure Analysis — SAS

National estimates of US healthcare spending in 2023: how many people spend
nothing, how concentrated spending is, who pays, and who carries the
out-of-pocket burden.

**Data:** MEPS-HC 2023 Full Year Consolidated File (HC-251) — Medical
Expenditure Panel Survey, Agency for Healthcare Research and Quality.
18,919 person records representing a population of 334 million. The data is
not stored in this repository; download it from
[AHRQ](https://meps.ahrq.gov/data_stats/download_data_files_detail.jsp?cboPufNumber=HC-251)
before running.

**Design:** weight `PERWT23F`, stratum `VARSTR`, cluster `VARPSU`. SURVEY
procedures throughout — the ordinary procedures run without complaint on this
file and return wrong numbers. Two rules hold everywhere:

- Subgroups use `DOMAIN`, never `WHERE`. A WHERE clause removes records the
  variance estimator needs; the point estimate survives, the standard error
  does not, and no error is raised.
- Shares use `RATIO`, never two separate estimates divided — numerator and
  denominator errors are correlated, so the division has to happen inside the
  estimation. Person-level ratios are never averaged, which would weight a
  $50 spender the same as a $500,000 one and drop everyone at zero.

## Findings

- Spending is extremely concentrated: the top 5% of the population accounts
  for 48.6% of all spending, the lower half for 2.9%. Mean $7,487 per person,
  median $1,583.
- Private insurance pays 42 cents of every dollar, Medicare 28, households 13
  out of pocket, Medicaid 11. The uninsured are the only group where
  households themselves are the largest payer, at 52%.
- The uninsured are not paying more — they are getting far less care:
  $1,062 a year against $7,600 for the privately insured, and more than half
  record no spending at all.
- Charges run 2.8× what is actually paid. Compared as published the ratio is
  2.2×, because total charges excludes prescriptions while total expenditure
  includes them.
- The out-of-pocket *share of the bill* rises with income (17% for the
  highest income group vs 5% for the poorest). As a share of income the
  direction would reverse, but this file does not carry income in a form that
  allows that.

## Checks before any estimate

1. **Design validation** — reproduced the codebook's published weighted
   frequencies. Every category matches, including the population total of
   334,530,273. Nothing downstream is meaningful if this fails.
2. **Parts against the whole** — the ten service categories sum back to total
   expenditure on all 18,919 records; same test across the ten sources of
   payment. Two supplied variables are aggregates of others and would double
   count if added in.
3. **Reserved codes** — refusals and non-responses are stored as negative
   numbers, which arithmetic treats as real amounts. 282 records carry at
   least one; they turn out to be largely the same people — those who left
   the survey before its final round. Recoded to missing on copies, source
   columns untouched.
4. **Columns that look comparable but are not** — total charges excludes
   prescribed medicines, total expenditure includes them. Prescriptions are
   ~23% of the total, which is what moves the ratio from 2.2× to 2.8×.
5. **Categories that do not mean what their name suggests** — the main
   insurance variable mixes age with coverage; two of its categories hold 21
   and 59 people, too few to estimate, and are collapsed by their defining
   feature rather than into a residual bucket.

## Files

| File | Purpose |
|---|---|
| `01_load.sas` | assign library, build the reduced analysis file (55 → 29 variables kept) |
| `02_explore.sas` | unweighted checks: reserved codes, PSUs per stratum, reconciliation |
| `03_prep.sas` | recodes, derived groups, permanent format catalog |
| `04_analysis.sas` | weighted estimates: zero-expenditure, concentration, payer mix, OOP burden |

## Notes and limits

- One calendar year, so no trend. Person-level survey data, so no provider or
  claim detail. Four census regions, no states.
- Expenditure means what was paid, a different quantity from what was billed.
- Small groups carry wide intervals and are reported combined.

**Tools:** SAS (Base, PROC SQL, PROC SURVEYMEANS, PROC SURVEYFREQ)
