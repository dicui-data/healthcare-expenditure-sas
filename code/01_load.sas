/*---------------------------------------------------------------------
  Project : MEPS 2023 Health Care Expenditure Analysis
  File    : 01_load.sas
  Author  : Di Cui
  Updated : 2026-07-23

  Data    : MEPS-HC 2023 Full Year Consolidated File (HC-251)
            Agency for Healthcare Research and Quality
            https://meps.ahrq.gov/data_stats/download_data_files_detail.jsp?cboPufNumber=HC-251
            Format used: SAS V9 (.sas7bdat). Data is not stored in this
            repository; download it from the link above before running.

  Purpose : Assign the data library, inspect the raw file, and build a
            reduced analysis file holding only the variables this project
            uses.

  Output  : meps.h251_slim   18,919 records, 55 variables

  Run once. Later programs read h251_slim and do not need this file.
---------------------------------------------------------------------*/

libname meps '/home/u64554518/MEPS/data';


/*--- Inspect the raw file ------------------------------------------*/
proc contents data = meps.h251 varnum;
  title 'Raw file: all variables in creation order';
run;


/*--- Build the reduced analysis file -------------------------------*/
data meps.h251_slim;
  set meps.h251;

  keep
    /* Identifiers and survey design.
       PERWT23F drives the point estimate. VARSTR and VARPSU drive the
       standard error and must be carried through to every procedure. */
    DUPERSID PANEL
    PERWT23F VARSTR VARPSU

    /* Person characteristics used as reporting dimensions */
    AGELAST SEX RACETHX HISPANX REGION23
    POVCAT23 INSCOV23 INSURC23
    RTHLTH53 MNHLTH53

    /* Total spending by who paid for it.
       The TOT: prefix picks up total charges, total expenditure, and
       every source of payment: self, Medicare, Medicaid, private,
       VA, TRICARE, other federal, state and local, workers comp,
       and other sources. It also picks up two combined variables
       (TOTPTR23, TOTOTH23) that overlap the detailed sources; these
       are excluded from the reconciliation in 03_prep.sas so nothing
       is double counted. */
      
    TOT:

    /* Spending by type of service.
       These ten categories are expected to add back to TOTEXP23.
       The reconciliation step in 02_explore.sas tests that. */
    OBVEXP23   /* office based, all providers   */
    OPTEXP23   /* hospital outpatient, facility and physician */
    ERTEXP23   /* emergency room, facility and physician      */
    IPTEXP23   /* inpatient, facility and physician           */
    RXEXP23    /* prescribed medicines          */
    DVTEXP23   /* dental                        */
    HHAEXP23   /* home health, agency           */
    HHNEXP23   /* home health, non agency       */
    OTHEXP23   /* other equipment and supplies  */
    VISEXP23   /* glasses and contact lenses    */

    /* Facility and professional components of the categories above.
       Hospitals bill a facility charge and physicians bill separately,
       so this split matches how hospital revenue is actually recorded.
       Do not add these to the category totals; they are already inside
       them. */
    OBDEXP23
    OPFEXP23 OPDEXP23
    ERFEXP23 ERDEXP23
    IPFEXP23 IPDEXP23

    /* Utilization counts.
       OBDRV23 is a subset of OBTOTV23, and OPDRV23 is a subset of
       OPTOTV23, so the two members of each pair are never summed. */
    OBTOTV23 OBDRV23
    OPTOTV23 OPDRV23
    ERTOT23
    IPDIS23 IPNGTD23
    DVTOT23
    RXTOT23
  ;
run;


/*--- Confirm the reduced file ---------------------------------------*/
proc contents data = meps.h251_slim varnum;
  title 'Reduced file: check the record count against the raw file';
run;

title;
