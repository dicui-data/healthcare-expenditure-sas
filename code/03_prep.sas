/*---------------------------------------------------------------------
  Project : MEPS 2023 Health Care Expenditure Analysis
  File    : 03_prep.sas
  Author  : Di Cui
  Updated : 2026-07-24

  Input   : meps.h251_slim      (created by 01_load.sas)
  Output  : meps.h251_analytic  (analysis file)
            meps.formats        (permanent format catalog)

  Purpose : Turn the reduced file into an analysis file. Three jobs:
            1. Set MEPS reserved codes to missing.
            2. Build the grouping variables the analysis reports on.
            3. Attach value labels so output reads without a codebook.

  Note    : Original variables are never overwritten. Every recode is
            written to a new variable, so any change can be checked
            against the source value.

            The FMTSEARCH option below is required. Value labels live in
            a permanent catalog in the MEPS library, and SAS does not
            look there unless it is told to.

            Top spender flags are not built here. Their cut points are
            weighted quantiles that have to be estimated from the data
            first, so they belong in 04_analysis.sas.
---------------------------------------------------------------------*/

libname meps '/home/u64554518/MEPS/data';
options fmtsearch = (meps work);


/*=====================================================================
  Value labels. Category names follow the HC-251 codebook.
=====================================================================*/
proc format library = meps;

  value agegrp_f
    1 = '0 to 17'
    2 = '18 to 44'
    3 = '45 to 64'
    4 = '65 and over';

  /* Collapsed from INSURC23. Source categories 7 and 8 hold 21 and 59
     records, too few to estimate separately. They share a defining
     feature, no Medicare despite being 65 or over, so they combine into
     one group named for that feature rather than a residual label. */
  value insgrp_f
    1 = 'Under 65, any private'
    2 = 'Under 65, public only'
    3 = 'Under 65, uninsured'
    4 = '65 and over, Medicare only'
    5 = '65 and over, Medicare and private'
    6 = '65 and over, Medicare and other public'
    7 = '65 and over, no Medicare';

  /* Insurance without the age split. This is INSCOV23, the collapse
     MEPS publishes, not a derived variable. Deriving it from INSURC23
     would strand the 59 people in source category 8, who hold coverage
     but not Medicare. INSCOV23 assigns 57 of them to private and 2 to
     public using information INSURC23 does not expose. */
  value inscov_f
    1 = 'Any private'
    2 = 'Public only'
    3 = 'Uninsured';

  value povcat_f
    1 = 'Poor or negative'
    2 = 'Near poor'
    3 = 'Low income'
    4 = 'Middle income'
    5 = 'High income';

  value yesno_f
    0 = 'No'
    1 = 'Yes';

  value sex_f
    1 = 'Male'
    2 = 'Female';

  value racethx_f
    1 = 'Hispanic'
    2 = 'Non-Hispanic White only'
    3 = 'Non-Hispanic Black only'
    4 = 'Non-Hispanic Asian only'
    5 = 'Non-Hispanic other race or multiple race';

  value health_f
    1 = 'Excellent'
    2 = 'Very good'
    3 = 'Good'
    4 = 'Fair'
    5 = 'Poor';

run;


/*=====================================================================
  Analysis file
=====================================================================*/
data meps.h251_analytic;
  set meps.h251_slim;


  /*--- Reserved codes -----------------------------------------------
    MEPS records inapplicable, refused and don't know answers as
    negative numbers. SAS treats them as ordinary values, so they would
    be averaged in as real data if left alone. Only three variables
    carry them; every expenditure variable in this file has a minimum
    of zero.
  ------------------------------------------------------------------*/
  region_c  = REGION23;   if REGION23 < 0 then region_c  = .;
  phyhlth_c = RTHLTH53;   if RTHLTH53 < 0 then phyhlth_c = .;
  mnthlth_c = MNHLTH53;   if MNHLTH53 < 0 then mnthlth_c = .;

  recoded_flag = (REGION23 < 0 or RTHLTH53 < 0 or MNHLTH53 < 0);


  /*--- Age -----------------------------------------------------------*/
  if      0  <= AGELAST <= 17 then agegrp = 1;
  else if 18 <= AGELAST <= 44 then agegrp = 2;
  else if 45 <= AGELAST <= 64 then agegrp = 3;
  else if      AGELAST >= 65  then agegrp = 4;

  aged65 = (AGELAST >= 65);


  /*--- Insurance, keeping the age split the source variable has ------*/
  if      INSURC23 in (1,2,3,4,5,6) then insgrp = INSURC23;
  else if INSURC23 in (7,8)         then insgrp = 7;


  /*--- Spending flags ------------------------------------------------*/
  zero_exp = (TOTEXP23 = 0);
  any_exp  = (TOTEXP23 > 0);


  /*--- Sources of payment --------------------------------------------
    Ten detailed sources are expected to add back to TOTEXP23. The two
    combined variables MEPS also supplies, TOTPTR23 and TOTOTH23, are
    aggregates of some of these and would double count if added in.

    oth_src collapses the six smaller sources into one reporting group.
    It is built explicitly rather than taken from TOTOTH23 because the
    composition of TOTOTH23 is not stated in the file. 04_analysis.sas
    tests both the identity and whether the two agree.
  ------------------------------------------------------------------*/
  oth_src  = sum(TOTVA23, TOTTRI23, TOTOFD23,
                 TOTSTL23, TOTWCP23, TOTOSR23);

  src_sum  = sum(TOTSLF23, TOTMCR23, TOTMCD23, TOTPRV23, oth_src);
  src_diff = TOTEXP23 - src_sum;


  /*--- Charges and expenditures on a matching basis -------------------
    TOTTCH23 excludes prescribed medicines while TOTEXP23 includes them,
    so the two are not comparable as published.
  ------------------------------------------------------------------*/
  exp_excl_rx = TOTEXP23 - RXEXP23;


  /*--- Any use of each service ---------------------------------------*/
  used_office    = (OBTOTV23 > 0);
  used_outpat    = (OPTOTV23 > 0);
  used_er        = (ERTOT23  > 0);
  used_inpatient = (IPDIS23  > 0);
  used_rx        = (RXTOT23  > 0);
  used_dental    = (DVTOT23  > 0);

  label
    agegrp       = 'Age group'
    aged65       = 'Aged 65 and over'
    insgrp       = 'Insurance coverage, with age split'
    zero_exp     = 'No health care expenditure in 2023'
    any_exp      = 'Any health care expenditure in 2023'
    oth_src      = 'Paid by all other sources combined'
    src_sum      = 'Sum of the ten sources of payment'
    src_diff     = 'Total expenditure minus the sum of sources'
    exp_excl_rx  = 'Total expenditure excluding prescribed medicines'
    region_c     = 'Census region, reserved codes set to missing'
    phyhlth_c    = 'Perceived health status, reserved codes set to missing'
    mnthlth_c    = 'Perceived mental health, reserved codes set to missing'
    recoded_flag = 'Record held at least one reserved code'
    used_office    = 'Any office based visit'
    used_outpat    = 'Any hospital outpatient visit'
    used_er        = 'Any emergency room visit'
    used_inpatient = 'Any hospital stay'
    used_rx        = 'Any prescription fill'
    used_dental    = 'Any dental visit';

  format
    agegrp     agegrp_f.
    insgrp     insgrp_f.
    INSCOV23   inscov_f.
    POVCAT23   povcat_f.
    SEX        sex_f.
    RACETHX    racethx_f.
    phyhlth_c
    mnthlth_c  health_f.
    zero_exp any_exp aged65 recoded_flag
    used_office used_outpat used_er
    used_inpatient used_rx used_dental   yesno_f.;
run;


/*=====================================================================
  Confirm the recodes
=====================================================================*/
proc freq data = meps.h251_analytic;
  tables agegrp insgrp INSCOV23 POVCAT23 RACETHX
         zero_exp recoded_flag / missing nocum;
  title 'Derived variables after recoding';
run;

/* Every source category must land in exactly one derived category.
   The INSURC23 by INSCOV23 table also shows how MEPS resolves the 59
   people in source category 8. */
proc freq data = meps.h251_analytic;
  tables INSURC23 * insgrp
         INSURC23 * INSCOV23 / norow nocol nopercent missing;
  title 'Source category against derived category';
run;

proc sql;
  select count(*)          as n_records,
         sum(recoded_flag) as n_with_reserved_code
  from meps.h251_analytic;
quit;

title;