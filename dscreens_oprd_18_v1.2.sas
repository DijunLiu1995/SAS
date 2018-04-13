dm "clear log"; dm "clear out";
 
/****************************************************************************************/
* PROGRAM: impact_analysis_OPRD.sas
* SAS version:  SAS 9.4 in Unix 	
* BY:  Lynn Liu
* DATE: 03/23/2017
*
* PURPOSE: This program mannually applies OP dscreens to the CareDiscovery client Impact Analysis for comparing 
		   OPRD v2017 and OPRD v2018 models 
*
* INPUTS: FLAT13C CareDiscovery client data
*         cd_FY2017q1
*         cd_FY2017q2
*         cd_FY2017q3
*         cd_FY2017q4
*     
*  FILES		    :	dscreen_cpt_hcpcs_code.xls, from 	                    *
*						Utilities: cmcdt_fy&curryear, i10cdt_fy&fisyear,        *
*                       util.i10cdt_fy&curryear	                                *
*						cptcdt_01&curryear, cptcdt_07&curryear, 				*
*						hcpcs_cdt&curryear, ada_dental_cdt&curryear				*
*  OUTPUT FILES	    :	dscreen_oprd.sas                                        *
*                       opin_dscreen.sas7bdat      		                        *
*  FORMATS			:	$validDX_YN, $dx_sex, $dx_age, $invalidprindx_YN,   	*
*						$cptVal, $cpt_male_only, $cpt_female_only,				*
*						$cpt_childbearing, $cpt_sex, $cptagel, $cptageh
*                       opin_dscreen
*  MACROS			:	None	
*
*
* 
* 
* KNOWN ISSUES:	None
****************************************************************************************** ;

options symbolgen mprint;

/****************************************************************************************/
/* Define Parameters/Lib Ref															*/
/****************************************************************************************/
libname util informix server = utilities;
libname fac informix server = facilities;
libname output "/analytics/contentqa/databridge/201802_oprd_impact_analysis/analysis";
libname flat13c '/analytics/contentqa/databridge/201802_oprd_impact_analysis/data_extract/data';
libname temp "/analytics/contentqa/databridge/201802_oprd_impact_analysis/temp";
libname sasin "/analytics/contentqa/databridge/201802_oprd_impact_analysis/documents";
libname fmtlib "/analytics/aa_standards/formats/prod/ope/2016"; 

options fmtsearch=(work fmtlib);
%let icd_version=i10;
%let curryear=17;
%let fisyear=18;

/***********************************
*Look at the specific format;
;
proc format
library = work.formats fmtlib;
select $validDX_YN;
run;
***********************************/

/****************************************************************************************/
/* Import FLAT13C data																	*/	
/****************************************************************************************/
data temp.flat13c;
	set flat13c.cd_2017q1
	    flat13c.cd_2017q2
		flat13c.cd_2017q3
		flat13c.cd_2017q4;
 
run;
/*%macro create_fmt( );*/
/*%if &icd_version=i9 %then %do;*/
/*data icd;*/
/*set util.cmcdt_fy&curryear;*/
/*if rec_type='D'; */
/*and  subdiv =' '*/ 
/*D:diagnosis code*/
/*if prefix ='E' then cm='E'||cm;*/
/*run;*/
/*%end;*/
/*%else %if &icd_version=i10 %then %do;*/
data icd (rename=(i10=cm));
set
    util.i10cdt_fy&fisyear.  /*icd10 code*/
	util.i10cdt_fy&curryear. 
	;
if rec_type='D' /*and subdiv =' '*/; /*D:diagnosis code*/
run;
proc sort data=icd nodupkey; by cm; run;
/*%end;*/
/*%mend;*/

/*%create_fmt ();*/

*formats;
/*check if valid DX*/
data fmt;
set icd;
start=cm;
label='Y';
fmtname='$validDX_YN';
type='C';
run;
proc format cntlin=fmt; run;

/*check age, sex for dx*/
data fmt;
set icd;
if sex_spec_ind in ('F' 'M');
start=cm;
label=sex_spec_ind;
fmtname='$dx_sex';
type='C';
run;

data one;
start='OTHER';
type='C';
label='O';
fmtname='$dx_sex';
HLO='O';
run;

data fmt;
set fmt one;
run;

proc format cntlin=fmt; run;

data fmt;
set icd;
if age_ind in ('B' 'P' 'A' 'M');
start=cm;
label=age_ind;
fmtname='$dx_age';
type='C';
run;
data one;
start='OTHER';
type='C';
label='O';
fmtname='$dx_age';
HLO='O';
run;
data fmt;
set fmt one;
run;

proc format cntlin=fmt; run; 	

Data noprindx (rename=(i10=dx));
set util.i10cdt_fy16;
where spec_edit="M" or spec_edit="U";
run;
proc sort data=noprindx nodupkey; by dx; run;

/*check valid primary dx code*/
data fmt;
set noprindx;
start=dx;
label='Y';
fmtname='$invalidprindx_YN';
type='C';
run;

proc format cntlin=fmt; run;

/*check cpt*/
data fmt (keep=cpt);
set util.cptcdt_01&curryear.
	util.cptcdt_07&curryear.
	util.hcpcs_cdt&curryear.(rename=(hcpcs=cpt))
	util.ada_dental_cdt&curryear. (rename=(dental=cpt))
	;
run;
proc sort data=fmt nodupkey; by cpt; run;

data fmt;
set fmt;
start=cpt;
label='Y';
type='C';
fmtname='$cptVal';
run;

proc format cntlin=fmt; run;

/*check cpt age, gender appropriate*/
proc import out=Male_Only  datafile="/analytics/contentqa/databridge/201802_oprd_impact_analysis/documents/dscreen_cpt_hcpcs_code.xls"
	DBMS=xls REPLACE;
	Sheet="cpt_hcpcs_male_only";
	GETNAMES=yes;
run;

data fmt;
set male_only;
start=cpt;
label='Y';
fmtname='$cpt_male_only';
type='C';
run;

%put "Displaying from Male";
proc sql;
select * from fmt where start in ("73560","G0463");
quit;

proc format cntlin=fmt; run;

proc import out=Female_Only datafile="/analytics/contentqa/databridge/201802_oprd_impact_analysis/documents/dscreen_cpt_hcpcs_code.xls"
	DBMS=xls REPLACE;
	Sheet="cpt_hcpcs_female_only";
	GETNAMES=yes;
run;

data fmt;
set female_only;
start=cpt;
label='Y';
fmtname='$cpt_female_only';
type='C';
run;
%put "Displaying from Female";
proc sql;
select * from fmt where start in ("73560","G0463");
quit;
proc format cntlin=fmt; run;

proc import out=childbearing datafile="/analytics/contentqa/databridge/201802_oprd_impact_analysis/documents/dscreen_cpt_hcpcs_code.xls"
	DBMS=xls REPLACE;
	Sheet="cpt_women_childbearing_age";
	GETNAMES=yes;
run;

data fmt;
set childbearing;
start=cpt;
label='Y';
fmtname='$cpt_childbearing';
type='C';
run;
proc format cntlin=fmt; run;


data flat_work;
set temp.flat13c;
where dkey=3669406603;
run;

/***************************************************************
Set dscreen flags
****************************************************************/
%macro set_dscreens ( );

data flags_work;
	flag02=0;
	flag05=0;
	flag07=0;
	flag09=0;
	flag10=0;
	flag11=0;
	flag12=0;
	flag13=0;
	flag14=0;
	flag15=0;
	flag17=0;
	flag18=0;
	flag19=0;
	flag20=0;
	flag24=0;
	flag25=0;
	flag27=0;
	flag28=0;
	flag29=0;
	flag30=0;
	flag31=0;
	flag32=0;
	set flat_work;
	if sex=' ' then gender='U';
	else if sex='1' then gender='M';
	else if sex='2' then gender='F';
	if years=. and months=. and days=. then flag02=1;
	if gender not in ('F', 'M', 'U')  then flag05=1;
	if years> 124 then flag07=1;
	if dx_code1=' ' or put(dx_code1,$validdx_yn.) ne 'Y' then flag09=1;
	
	%do i=1 %to 50;
		if dx_code1='O80' and px_code&i in ('01961','01968','59510','59514','59515','59618','59620','59622') then flag10=1;
		if years>0 and put(dx_code&i,$dx_age.) = 'B' then flag11=1;
		if years>17 and put(dx_code&i, $dx_age.)='P' then flag12=1;
		if (0=<years<12 or years>55)and put(dx_code&i,$dx_age.)='M' then flag13=1;
		if 0=<years<15 and put(dx_code&i,$dx_age.)='A' then  flag14=1;
		if years ne . and (years<12 or years>55) and put(px_code&i,$cpt_childbearing.)='Y' then flag15=1;
		if put(dx_code&i, $dx_sex.)='F' and gender='M' then flag17=1;
		else if put(dx_code&i, $dx_sex.)='M' and gender='F' then flag17=1;
		if ((gender ne 'F') and (put(px_code&i,$cpt_female_only.)='Y')) then  
		do;
		a11=px_code&i.;
		a12=put(px_code&i.,$cpt_female_only.);
		%put "Writing into log: " &a11.;
		%put "Writing into log: " &a12.;
		flag18=1;
		end;
		else if ((gender ne 'M') and (put(px_code&i., $cpt_male_only.)='Y')) then 
		do;
		a11=px_code&i.;
		a12=put(px_code&i.,$cpt_male_only.);
		%put "Writing into log: " &a11;
		%put "Writing into log: " &a12;
		flag18=1;
		end;
		if px_code&i ne ' ' and put(px_code&i,$cptVal.) ne 'Y' then flag20=1; 
		if &i>1 and dx_code&i ne ' ' and put(dx_code&i,$validDX_YN.) ne 'Y' then flag19=1;
		if (put(px_code&i, $cptagel.)) ne 0 then if (years<put(px_code&i, $cptagel.)) then flag32=1; 
		if (put(px_code&i, $cptageh.)) ne 999 then if (years>put(px_code&i, $cptageh.)) then flag32=1; 
	%end;
	if total_chrg=. or total_chrg<0 or total_chrg>150000 then flag24=1;
	if disch_dt=. and adm_dt=. then flag31=1;
run;
%mend set_dscreens;
%set_dscreens ( );

data dscreen02 dscreen05 dscreen07 dscreen09 dscreen10 dscreen11 dscreen12 dscreen13 dscreen14 dscreen15 dscreen17 
    dscreen18 dscreen19 dscreen20 dscreen24 dscreen31 dscreen32 output.opin_dscreen;
	set flags_work;
	if flag02=1 then output dscreen02;
	if flag05=1 then output dscreen05;
	if flag07=1 then output dscreen07;
	if flag09=1 then output dscreen09;
	if flag10=1 then output dscreen10;
	if flag11=1 then output dscreen11;
	if flag12=1 then output dscreen12;
	if flag13=1 then output dscreen13;
	if flag14=1 then output dscreen14;
	if flag15=1 then output dscreen15;
	if flag17=1 then output dscreen17;
	if flag18=1 then output dscreen18;
	if flag19=1 then output dscreen19;
	if flag20=1 then output dscreen20;
	if flag24=1 then output dscreen24;
	if flag31=1 then output dscreen31;
	if flag32=1 then output dscreen32;
	if flag02=0 and flag05=0 and flag07=0 and flag09=0 and flag10=0 and flag11=0 and flag12=0 and flag13=0
	   and flag14=0 and flag15=0 and flag17=0 and flag18=0 and flag19=0 and flag20=0 and flag24=0
	   and flag31=0 and flag32=0 then output output.opin_dscreen;
run;

title "dscreen02";
proc print data=dscreen02(obs=10); run;

title "dscreen05";
proc print data=dscreen05 (obs=10); run;
title "dscreen07";
proc print data=dscreen07 (obs=10); run;
title "dscreen09";
proc print data=dscreen09 (obs=10); run;
title "dscreen10";
proc print data=dscreen10 (obs=10); run;
title "dscreen11";
proc print data=dscreen11 (obs=10); run;
title "dscreen12";
proc print data=dscreen12 (obs=10); run;
title "dscreen13";
proc print data=dscreen13 (obs=10); run;
title "dscreen15";
proc print data=dscreen15 (obs=10); run;
title "dscreen17";
proc print data=dscreen17 (obs=10); run;
title "dscreen18";
proc print data=dscreen18 (obs=100); run;
title "dscreen19";
proc print data=dscreen19 (obs=10); run;
title "dscreen20";
proc print data=dscreen20 (obs=100); run;
title "dscreen24";
proc print data=dscreen24 (obs=100); run;
title "dscreen31";
proc print data=dscreen31 (obs=10); run;
title "dscreen32";
proc print data=dscreen32 (obs=10); run;




