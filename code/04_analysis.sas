/*---------------------------------------------------------------------
  Project : MEPS 2023 Health Care Expenditure Analysis
  File    : 04_analysis.sas
  Author  : Di Cui
  Updated : 2026-07-27

  Input   : meps.h251_analytic  (created by 03_prep.sas)

  Purpose : National estimates of health care spending in 2023: how many
            people spend nothing, how concentrated spending is, who pays
            for it, and how the out of pocket share falls across coverage
            and income.

  Method  : MEPS uses a complex sample design with weighting,
            stratification and clustering. SURVEY procedures are used
            throughout.

              weight  PERWT23F   final person weight
              stratum VARSTR     variance estimation stratum
              cluster VARPSU     variance estimation primary sampling unit

            Two rules hold everywhere in this program.

            Subgroups use DOMAIN, never WHERE. A WHERE clause removes
            records the variance estimator needs. The point estimate
            survives; the standard error does not, and SAS reports no
            error when this happens.

            Shares use RATIO, never a ratio of two separate estimates.
            Numerator and denominator are both estimated and their errors
            are correlated. RATIO handles that covariance in one pass.
            Dividing two separately estimated totals gives the right
            point estimate and the wrong confidence interval.

            Person level ratios are not averaged. A person who spent $50
            and a person who spent $500,000 would carry equal weight, and
            anyone who spent nothing would have to be dropped.
---------------------------------------------------------------------*/

libname meps '/home/u64554518/MEPS/data';
options fmtsearch = (meps work);


/*=====================================================================
  1. Validation against the published codebook

     The HC-251 codebook prints weighted frequencies for every variable.
     Reproducing them is a direct test that the three design variables
     were applied correctly. Every category should match, and the total
     should come to 334,530,273.
=====================================================================*/
proc surveyfreq data = meps.h251_analytic;
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  tables POVCAT23 RACETHX INSURC23;
  title 'Weighted frequencies, to be checked against the codebook';
run;


/*=====================================================================
  2. Sources of payment reconcile to the total

     The ten detailed sources should add back to TOTEXP23 exactly. The
     second check asks whether the collapsed group built in 03_prep
     matches the combined variable MEPS supplies.
=====================================================================*/
proc means data = meps.h251_analytic n mean min max;
  var src_diff;
  title 'Total expenditure minus the sum of the ten sources of payment';
run;

data _oth_check;
  set meps.h251_analytic;
  oth_gap = oth_src - TOTOTH23;
run;

proc means data = _oth_check n mean min max;
  var oth_gap;
  title 'Sources collapsed here against the combined variable MEPS supplies';
run;


/*=====================================================================
  3. Analysis one. How many people spend nothing

     Reported first because it sets up the rest. An average spend per
     person is misleading when a large group spends nothing at all.
=====================================================================*/
proc surveyfreq data = meps.h251_analytic;
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  tables zero_exp / cl;
  title 'Share of the population with no health care expenditure';
run;

proc surveyfreq data = meps.h251_analytic;
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  tables agegrp   * zero_exp
         INSCOV23 * zero_exp / row cl nototal;
  title 'No expenditure, by age and by coverage';
run;


/*=====================================================================
  4. Analysis two. How concentrated spending is

     4a reports weighted quantiles, which show the shape of the
     distribution. 4b finds the cut points that mark the top spenders
     and measures what share of national spending they account for.
=====================================================================*/

/*--- 4a. Weighted quantiles ----------------------------------------*/
proc surveymeans data = meps.h251_analytic
                 mean median quantile = (0.75 0.90 0.95 0.99);
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  var TOTEXP23 TOTSLF23;
  title 'Weighted distribution of total and out of pocket spending';
run;


/*--- 4b. Cumulative share of spending -------------------------------
  Records are ordered from the highest spender down, and weights are
  accumulated. At the point where the accumulated weight reaches five
  percent of the population, the accumulated spending is the share held
  by the top five percent.
-------------------------------------------------------------------*/
proc sql noprint;
  select sum(PERWT23F), sum(PERWT23F * TOTEXP23)
    into :tot_wt  trimmed,
         :tot_exp trimmed
  from meps.h251_analytic;
quit;

proc sort data = meps.h251_analytic out = _sorted;
  by descending TOTEXP23;
run;

data _lorenz;
  set _sorted;
  retain cum_wt 0 cum_exp 0;
  cum_wt  + PERWT23F;
  cum_exp + PERWT23F * TOTEXP23;
  pct_persons  = cum_wt  / &tot_wt;
  pct_spending = cum_exp / &tot_exp;
  keep DUPERSID TOTEXP23 PERWT23F pct_persons pct_spending;
run;

proc sql;
  title 'Share of national spending held by the highest spenders';
  select 'Top 1 percent'  as spenders length = 16,
         max(pct_spending) as share format = percent9.1
    from _lorenz where pct_persons <= 0.01
  union all
  select 'Top 5 percent',  max(pct_spending)
    from _lorenz where pct_persons <= 0.05
  union all
  select 'Top 10 percent', max(pct_spending)
    from _lorenz where pct_persons <= 0.10
  union all
  select 'Top 25 percent', max(pct_spending)
    from _lorenz where pct_persons <= 0.25
  union all
  select 'Top 50 percent', max(pct_spending)
    from _lorenz where pct_persons <= 0.50;
quit;

/*--- 4c. The same shares with standard errors ------------------------
  The table above describes the weighted population but carries no
  measure of sampling error. Flagging the top spenders and expressing
  their spending as a ratio gives the same figure with a confidence
  interval. Because many people share the same expenditure value at the
  cut point, the flagged group is slightly larger than the nominal
  share; the printed group size shows by how much.
-------------------------------------------------------------------*/
proc sql noprint;
  select min(TOTEXP23) into :cut5  trimmed
    from _lorenz where pct_persons <= 0.05;
  select min(TOTEXP23) into :cut10 trimmed
    from _lorenz where pct_persons <= 0.10;
quit;

%put NOTE: cut point for the top 5 percent is &cut5;
%put NOTE: cut point for the top 10 percent is &cut10;

data _conc;
  set meps.h251_analytic;
  top5      = (TOTEXP23 >= &cut5);
  top10     = (TOTEXP23 >= &cut10);
  exp_top5  = TOTEXP23 * top5;
  exp_top10 = TOTEXP23 * top10;
  format top5 top10 yesno_f.;
run;

proc surveyfreq data = _conc;
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  tables top5 top10;
  title 'Size of the flagged top spender groups';
run;

proc surveymeans data = _conc;
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  ratio exp_top5 exp_top10 / TOTEXP23;
  title 'Share of national spending held by the top spenders, with error';
run;


/*=====================================================================
  5. Analysis three. Who pays

     Payer mix means the share of each dollar spent, not the share of
     people. RATIO gives that directly. People with no spending at all
     contribute zero to both numerator and denominator and are kept in.
=====================================================================*/
proc surveymeans data = meps.h251_analytic;
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  ratio TOTSLF23 TOTMCR23 TOTMCD23 TOTPRV23 oth_src / TOTEXP23;
  title 'National payer mix';
run;

proc surveymeans data = meps.h251_analytic;
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  ratio TOTSLF23 TOTMCR23 TOTMCD23 TOTPRV23 oth_src / TOTEXP23;
  domain insgrp;
  title 'Payer mix by insurance coverage';
run;

/* Spending per person alongside the mix, so the shares can be read
   against the amounts they divide. */
proc surveymeans data = meps.h251_analytic mean sum;
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  var TOTEXP23 TOTSLF23 TOTMCR23 TOTMCD23 TOTPRV23 oth_src;
  domain insgrp;
  title 'Spending per person and national totals, by insurance coverage';
run;


/*=====================================================================
  6. Analysis four. Who carries the out of pocket burden

     The crossed domain finds people who hold coverage and still pay a
     high share themselves.
=====================================================================*/
proc surveymeans data = meps.h251_analytic;
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  ratio TOTSLF23 / TOTEXP23;
  domain INSCOV23 POVCAT23 INSCOV23 * POVCAT23;
  title 'Out of pocket share of spending, by coverage and by income';
run;

proc surveymeans data = meps.h251_analytic mean;
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  var TOTSLF23;
  domain INSCOV23 * POVCAT23;
  title 'Out of pocket dollars per person, by coverage and income';
run;


/*=====================================================================
  Appendix A. Charges against expenditures

     TOTTCH23 excludes prescribed medicines. Comparing it against
     TOTEXP23 as published overstates what was paid and understates the
     gap. exp_excl_rx puts both sides on the same basis.
=====================================================================*/
proc surveymeans data = meps.h251_analytic;
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  ratio TOTTCH23 / TOTEXP23;
  title 'Charges against expenditures, as published and not comparable';
run;

proc surveymeans data = meps.h251_analytic;
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  ratio TOTTCH23 / exp_excl_rx;
  domain INSCOV23;
  title 'Charges against expenditures on a comparable basis';
run;


/*=====================================================================
  Appendix B. Cost and use per unit of service

     Each figure is a ratio of two totals, not an average of person
     level ratios, so people with no visits are kept in and contribute
     zero to both sides.
=====================================================================*/
proc surveymeans data = meps.h251_analytic;
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  ratio IPNGTD23 / IPDIS23;
  title 'Average length of stay, nights per hospital discharge';
run;

proc surveymeans data = meps.h251_analytic;
  stratum VARSTR;
  cluster VARPSU;
  weight  PERWT23F;
  ratio OBVEXP23 / OBTOTV23;
  ratio IPTEXP23 / IPDIS23;
  ratio ERTEXP23 / ERTOT23;
  ratio RXEXP23  / RXTOT23;
  title 'Expenditure per unit of service';
run;

title;