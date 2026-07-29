/*---------------------------------------------------------------------
  Project : MEPS 2023 Health Care Expenditure Analysis
  File    : 02_explore.sas
  Author  : Di Cui
  Updated : 2026-07-23

  Input   : meps.h251_slim

  Purpose : Check the data before any estimate is produced.
            1. Unweighted frequencies for every grouping variable.
            2. Reserved codes. MEPS stores refusals and non-responses as
               negative values, and these must be set to missing or they
               will be counted as real amounts.
            3. Distribution of the expenditure variables, which are
               heavily right skewed and include many zeros.

  Note    : Frequencies here are unweighted and describe the sample only.
            National estimates are produced in 04_analysis.sas.
---------------------------------------------------------------------*/

libname meps '/home/u64554518/MEPS/data';

/*--- 0. Scan every numeric variable for reserved codes -------------
  MEPS stores inapplicable, refused and don't know answers as negative
  numbers. This scans the minimum of every numeric variable so the ones
  carrying such codes are identified from the data rather than assumed.
  Only REGION23, RTHLTH53 and MNHLTH53 return a negative minimum; they
  are set to missing in 03_prep.sas. Every expenditure and count
  variable has a minimum of zero.
------------------------------------------------------------------*/
proc means data = meps.h251_slim min nolabels;
  title 'Minimum of every numeric variable, to locate reserved codes';
run;



/*--- 1. Grouping variables: look for negative reserved codes -------*/
proc freq data = meps.h251_slim;
  tables PANEL REGION23 SEX RACETHX HISPANX
         RTHLTH53 MNHLTH53 POVCAT23 INSCOV23 INSURC23
         / missing nocum;
  title 'Unweighted frequencies of grouping variables';
run;


/*--- 2. Survey design variables ------------------------------------*/
proc means data = meps.h251_slim n nmiss min max;
  var PERWT23F VARSTR VARPSU;
  title 'Design variables: no value should be missing';
run;

/* How many PSUs sit inside each stratum.
   A stratum holding only one PSU cannot support a variance estimate. */
proc sql;
  create table stratum_psu as
  select VARSTR, count(distinct VARPSU) as n_psu
  from meps.h251_slim
  group by VARSTR;
quit;

proc freq data = stratum_psu;
  tables n_psu;
  title 'Number of PSUs per stratum';
run;

/* Records carrying a zero weight contribute nothing to an estimate
   but are still needed for variance estimation, so they stay. */
proc sql;
  select count(*)              as n_total,
         sum(PERWT23F  = 0)    as n_zero_weight,
         sum(PERWT23F  > 0)    as n_positive_weight
  from meps.h251_slim;
quit;



/*--- 3. Expenditure distribution (unweighted) ----------------------*/
proc means data = meps.h251_slim
           n nmiss min p25 median p75 p90 p95 p99 max mean;
  var TOTEXP23 TOTSLF23 TOTMCR23 TOTMCD23 TOTPRV23
      TOTTCH23 RXEXP23;
  title 'Unweighted distribution of expenditure variables';
run;


/*--- 4. Share of people with no spending at all --------------------*/
data check_zero;
  set meps.h251_slim;
  zero_exp = (TOTEXP23 = 0);
run;

proc freq data = check_zero;
  tables zero_exp;
  title 'Persons with zero total expenditure (unweighted)';
run;


/*--- 5. Reconciliation: do the service categories add to the total? -*/
data recon;
  set meps.h251_slim;
  sum_parts = sum(OBVEXP23, OPTEXP23, ERTEXP23, IPTEXP23,
                  RXEXP23,  DVTEXP23, HHAEXP23, HHNEXP23,
                  OTHEXP23, VISEXP23);
  diff = TOTEXP23 - sum_parts;
run;

proc means data = recon n mean min max;
  var diff;
  title 'Total minus the sum of the service categories';
run;

proc print data = recon (obs = 20);
  where abs(diff) > 1;
  var DUPERSID TOTEXP23 sum_parts diff;
  title 'First rows that do not reconcile';
run;


/*--- 6. Charges and expenditures are not on the same basis ---------*/
/* TOTTCH23 is labelled EXCL RX, while TOTEXP23 includes prescriptions.
   Comparing them directly would overstate the gap. */
data check_tch;
  set meps.h251_slim;
  exp_excl_rx = TOTEXP23 - RXEXP23;
run;

proc means data = check_tch n mean min max;
  var TOTTCH23 TOTEXP23 exp_excl_rx;
  title 'Charges versus expenditures on a comparable basis';
run;

title;