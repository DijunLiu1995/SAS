*********************************************************************************************************; 
*	Last Update: March 2016										*;
*													*;
* 	This SAS code computes discretionary accruals.							*;
*********************************************************************************************************; 


****************************************************************;
* GOAL: GET DATA					   	;
****************************************************************;
%let wrds=wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon username=_prompt_;
rsubmit;
PROC PRINTTO LOG='/home/usc/stamenov/AccrualsOut/auto.log' NEW;
RUN;
%put "In the Start";
libname out	'/home/usc/stamenov/AccrualsOut';				*or whatever directory on your personal computer you want to save the SAS datasets;
libname mine '~'; *define a home directory on WRDS;
/*options ls=72 ps=max nocenter nonumber nodate fullstimer ;*/
/*title ' ';*/
data all; set comp.funda (keep=gvkey datadate fyear CHE RECT INVT ACT LCT AT PPEGT DLTT SALE DP XINT IB DVP DLC RE MIB COGS XAD XRD TXDI CEQ TXDB SSTK DLTIS IBC XIDOC CAPX PSTK NI XSGA NP OANCF);
/*if _n_ <= 10;*/
run;
/*proc download data=all out=all;*/
/*run;*/

proc sort data=all; by gvkey datadate descending CEQ;
run;
proc sort data=all nodupkey; by gvkey datadate;
run;
%put "Getting data from crsp:";
data ind; set crsp.ind;
	rename lpermno = permno;
	keep gvkey lpermno datadate fyear GGROUP GIND GSECTOR SIC state;
run;
%put "After CRSP";
proc sort data=ind; by gvkey datadate descending GSECTOR;
run;
proc sort data=ind nodupkey; by gvkey datadate;
run;

data out.all; merge all (in=m1) ind (in=m2); by gvkey datadate;
	if m1 and m2;
run;


****************************************************************;
* GOAL: PREPARE DATA					  	;
****************************************************************;
data compu; set out.all;
	rename fyear = cyear;
	rename CHE = data1;
	rename RECT = data2;
	rename INVT = data3;
	rename ACT = data4;
	rename LCT = data5;
	rename AT = data6;
	rename PPEGT = data7;
	rename DLTT = data9;
	rename SALE = data12;
	rename DP = data14;
	rename XINT = data15;
	rename IB = data18;
	rename DVP = data19;
	rename DLC = data34;
	rename RE = data36;
	rename MIB = data38;
	rename COGS = data41;
	rename XAD = data45;
	rename XRD = data46;
	rename TXDI = data50;
	rename CEQ = data60;
	rename TXDB = data74;
	rename SSTK = data108;
	rename DLTIS = data111;
	rename IBC = data123;
	rename XIDOC = data124;
	rename CAPX = data128;
	rename PSTK = data130;
	rename NI = data172;
	rename XSGA = data189;
	rename NP = data206;
	rename OANCF = data308;
run;

proc sort data=compu; by gvkey cyear;
run;
data compu (compress=yes); set compu; by gvkey cyear;
	n+1;
	if first.gvkey then n=1;

	if data34  = . then data34  = 0;
	if data60  = . then data60  = 0;
	if data74  = . then data74  = 0;
	if data108 < 0 then data108 = 0;
	if data111 < 0 then data111 = 0;

	*create lagged values;
	lag_data2	=	lag(data2);
	lag_data3	=	lag(data3);
	lag_data6	=	lag(data6);
	lag_data128	=	lag(data128);
	lag2_data128	=	lag2(data128);
	lag3_data128	=	lag3(data128);
	if n = 1 then do; lag_data2=.; lag_data3=.; lag_data6=.; lag_data128=.; lag2_data128=.; lag3_data128=.; end;
	if n = 2 then do; lag2_data128=.; lag3_data128=.; end;
	if n = 3 then do; lag3_data128=.; end;
	data6_av	=	(data6+lag_data6)/2;
	data128_av	=	(lag_data128+lag2_data128+lag3_data128)/3;

	*create accounting data;
	BE 			= 	data60+data74;             							*Book Equity;
	E  			= 	data172;									*Earnings;
	S  			= 	data12;                    							*Sales;
	ACCR			=	data123-data308+data124;							*Cash Flow Approach;
	TA			=	data6;
	REV			=	data12;
	PPE			=	data7;
	CFO			=	data308-data124;								*Cash Flow from Operations;
	delta_AR		=	data2-lag_data2;								*Change in Receivables;
	delta_INV		=	data3-lag_data3;								*Change in Inventories;
	PROD			=	data41+delta_Inv;								*Production Costs;
	EXP			=	data45+data46+data189;								*Discr. Expenses;
	FIN			=	data130+data60+data38-data36; 							*Stock Financing;

	*create more lagged values;
	lag_S		=	lag(S);
	lag2_S		=	lag2(S);
	lag_TA		=	lag(TA);
	lag_REV		=	lag(REV);
	lag_E		=	lag(E);
	lag2_E		=	lag2(E);
	lag_FIN		=	lag(FIN);
	if n = 1 then do; lag_S=.; lag2_S=.; lag_TA=.; lag_REV=.; lag_E=.; lag2_E=.; lag_FIN=.; end;
	if n = 2 then do; lag2_S=.; lag2_E=.; end;

	if data6_av > 0  then Fin_Raised  = (data108+data111)/data6_av; else Fin_Raised = .;
	if lag_TA   > 0  then FCF		  =	(data172 - (data123-data308+data124) - data128_av)/lag_TA; else FCF = .;
	if FCF < -0.1 then Fin_Needed = 1; else Fin_Needed = 0;
		if FCF = . then Fin_Needed = .;

	*create more accounting data;
	if TA > 0 					then ROA = E/TA; 			else ROA = .;
									 ROA_sq	= ROA*ROA;
	if BE > 0 					then ROE = E/BE; 			else ROE = .;
	if S > 0 					then ROS = E/S; 			else ROS = .;
	if lag_E < 0 and lag2_E < 0			then NegNI=1; 				else NegNI=0; 			if lag_E = . then NegNI=.; if lag2_E = . then NegNI=.;
	if TA > 0 					then Debt = (data34+data9)/TA; else Debt = .;
	if TA > 0 					then LT_Debt = (data9)/TA; else LT_Debt = .;
	if TA > 0 					then Pri_Debt = data206/TA; else Pri_Debt = .;
	if S  > 0 					then RD_Sales = data46/S; 	else RD_Sales = .;
	if S  > 0 					then Mkt_Sales = data45/S; 	else Mkt_Sales = .;
	if lag_TA > 0 					then Stock_Financing = (FIN-lag_FIN)/lag_TA; else Stock_Financing = .;

	delta_S		= 	S-lag_S;
	delta2_S	= 	lag_S-lag2_S;
	delta_REV	= 	REV-lag_REV;
	lag_ROA	   	=   	lag(ROA); if first.gvkey then lag_ROA=.;
	lag_ROE	   	=   	lag(ROE); if first.gvkey then lag_ROE=.;
	lag_ROS	   	=   	lag(ROS); if first.gvkey then lag_ROS=.;

	rename datadate = fdate;

	sic2 = substr(SIC,1,2);

	keep gvkey cyear datadate Fin_Raised Fin_Needed BE E S lag_S ACCR TA lag_TA REV PPE CFO PROD EXP 
	ROA ROA_sq lag_ROA ROE lag_ROE ROS lag_ROS NegNI Debt LT_Debt Pri_Debt RD_Sales Mkt_Sales 
	delta_S delta2_S delta_AR delta_REV GSECTOR sic2 Stock_Financing;
run;

data out.compu; set compu; by gvkey cyear;

	*regression variables for discr. accruals regression;
	if lag_TA  > 0 then y		=	ACCR/lag_TA;					else y = .;
	if lag_TA  > 0 then x1		=	1/lag_TA;					else x1 = .;
	if lag_TA  > 0 then x2_1	=	delta_REV/lag_TA;				else x2_1 = .;	
	if lag_TA  > 0 then x2_2	=	(delta_REV-delta_AR)/lag_TA;			else x2_2 = .;
	if lag_TA  > 0 then x3		=	PPE/lag_TA;					else x3 = .;

	*regression variables for CFO regression;
	if lag_TA  > 0 then cfo_y		=	CFO/lag_TA;				else cfo_y = .;
	if lag_TA  > 0 then cfo_x1		=	1/lag_TA;				else cfo_x1 = .;
	if lag_TA  > 0 then cfo_x2		=	S/lag_TA;				else cfo_x2 = .;	
	if lag_TA  > 0 then cfo_x3		=	delta_S/lag_TA;				else cfo_x3 = .;

	*regression variables for Production costs regression;
	if lag_TA  > 0 then pro_y		=	PROD/lag_TA;				else pro_y = .;
	if lag_TA  > 0 then pro_x1		=	1/lag_TA;				else pro_x1 = .;
	if lag_TA  > 0 then pro_x2		=	S/lag_TA;				else pro_x2 = .;	
	if lag_TA  > 0 then pro_x3		=	delta_S/lag_TA;				else pro_x3 = .;
	if lag_TA  > 0 then pro_x4		=	delta2_S/lag_TA;			else pro_x4 = .;

	*regression variables for Discr. Exp. regression;
	if lag_TA  > 0 then exp_y		=	EXP/lag_TA;				else exp_y = .;
	if lag_TA  > 0 then exp_x1		=	1/lag_TA;				else exp_x1 = .;
	if lag_TA  > 0 then exp_x2		=	lag_S/lag_TA;				else exp_x2 = .;	

	drop delta_S delta2_S delta_AR delta_REV;
run;
%put "Sorting";
proc sort data=out.compu out=outlier; by cyear;
run;
data outlier; set outlier;
	outlier1 = abs(y);
	outlier2 = abs(cfo_y);
	outlier3 = abs(pro_y);
	outlier4 = abs(exp_y);
	run;
proc means data=outlier noprint;
	var outlier1 outlier2 outlier3 outlier4;
	by cyear;
	output out=outlier p99=outlier1 outlier2 outlier3 outlier4;
	run;
data out.outlier; set outlier;
	keep cyear outlier1 outlier2 outlier3 outlier4;
run;


%put "After Means";
****************************************************************;
* GOAL: GET DISCRETIONARY ACCRUALS   				;
****************************************************************;
proc sort data=out.compu out=compu; by cyear;
run;
data compu; merge compu (in=m1) out.outlier; by cyear;
	if m1;
run;

%let dep=y;
%let ind=sic2;
proc sort data=compu nodupkey out=compu1; by gvkey cyear;
run;
data compu1; set compu1;
	if &dep ne .;													
	if x1 ne .;
	if x2_1 ne .;
	if x2_2 ne .;
	if x3 ne .;
	if abs(&dep) < outlier1;	
run;	
proc sort data=compu1; by cyear &ind; run;
proc univariate data=compu1 noprint;
	var &dep;														
	by cyear &ind;
	output out=count n=obs_int;
	run;
proc reg data=compu1 noprint outest=parms;
	model &dep = x1 x2_1 x3;								
	by cyear &ind;
	run;
data parms; merge parms count; by cyear &ind;
	if obs_int >= 8;
	alpha	=	x1;
	beta	=	x2_1;
	gamma	=	x3;
	keep &ind cyear intercept alpha beta gamma obs_int;
	run;

proc datasets; delete count; run; quit;
data compu1; merge compu1 parms (in=m1); by cyear &ind;
	if m1;
	fitted		=	intercept+(alpha*x1)+(beta*x2_2)+(gamma*x3);
	AAC_int		=	&dep-fitted;								
	abs_AAC_int	=	abs(AAC_int);
	keep gvkey cyear &ind aac_int abs_AAC_int obs_int ROA lag_ROA;
	run;
proc datasets; delete parms; run; quit;

proc sort data=compu nodupkey out=compu2; by gvkey cyear; 
run;
data compu2; set compu2;
	if &dep ne .;
	if x1 ne .;
	if x2_1 ne .;
	if x2_2 ne .;
	if x3 ne .;
	if abs(&dep) < outlier1;run;					
proc sort data=compu2; by cyear &ind;
run;
proc univariate data=compu2 noprint;
	var &dep;														
	by cyear &ind;
	output out=count n=obs_noint;
run;
proc reg data=compu2 noprint outest=parms;
	model &dep = x1 x2_1 x3 / noint;										
	by cyear &ind;
run;
data parms; merge parms count; by cyear &ind;
	if obs_noint >= 8;
	alpha	=	x1;
	beta	=	x2_1;
	gamma	=	x3;
	keep &ind cyear alpha beta gamma obs_noint;
run;
proc datasets; delete count; run; quit;
data compu2; merge compu2 parms (in=m1); by cyear &ind;
	if m1;
	fitted				=	(alpha*x1)+(beta*x2_2)+(gamma*x3);
	AAC_noint			=	&dep-fitted;								
	abs_AAC_noint			=	abs(AAC_noint);
	keep gvkey cyear aac_noint abs_AAC_noint obs_noint;run;
proc datasets; delete parms; run; quit;

proc sort data=compu1; by gvkey cyear;
run;
proc sort data=compu2; by gvkey cyear;
run;

data out.AAC; merge compu1 compu2; by gvkey cyear;
	rename cyear	=	fyear;
run;


****************************************************************;
* GOAL: DO PERFORMANCE ADJUSTMENT			   	;
****************************************************************;
data aac; set out.aac;
	n+1;run;
data control; set out.aac;
	rename gvkey = gvkey_match;
	rename lag_ROA = lag_ROA_match;
	rename AAC_int = AAC_int_match;
	rename AAC_noint = AAC_noint_match;
	keep gvkey fyear sic2 lag_roa aac_int aac_noint;run;
proc sort data=control; by fyear sic2;
run;


proc datasets; delete aaac;
run; quit;
%put "Before Match";
option nonotes;
/*options mprint mlogic symbolgen;*/
%macro matching;
%do i = 1 %to 123648;
data tmp1; set aac;
	if n=&i;
run;
data tmp1; merge tmp1 (in=m1) control; by fyear sic2;
	if m1;
	if gvkey ne gvkey_match;
	diff		 = abs(lag_roa-lag_roa_match);
	if diff ne .;
	adj_AAC_int	 = AAC_int - AAC_int_match;				
	label adj_AAC_int 	= 'Matched adjusted AAC_int';
	adj_AAC_noint	= AAC_noint - AAC_noint_match;				
	label adj_AAC_noint 	= 'Matched adjusted AAC_noint';
run;
proc sort data=tmp1; by gvkey diff;
run;
proc sort data=tmp1 nodupkey; by gvkey;
run;
proc append data=tmp1 base=aaac;
run;
%end;
%mend;
%matching;
option notes;

data out.aaac; set aaac;
	abs_adj_AAC_int = abs(adj_AAC_int);
	abs_adj_AAC_noint = abs(adj_AAC_noint);
	label gvkey_match = 'GVKEY of Matching Firm';
	label diff = 'Absolute Difference in lagged ROA between Sample and Matching Firm';
	drop n lag_ROA_match;
run;



****************************************************************;
* GOAL: GET CFO MANAGEMENT			   		;
****************************************************************;
proc sort data=out.compu out=compu; by cyear;
run;
data compu; merge compu (in=m1) comp.outlier; by cyear;
	if m1;
run;

%let dep=cfo_y;
proc sort data=compu nodupkey out=compu1; by gvkey cyear;
run;
data compu1; set compu1;
	if &dep ne .;													
	if cfo_x1 ne .;
	if cfo_x2 ne .;
	if cfo_x3 ne .;
	if abs(&dep) < outlier2;
run;
proc sort data=compu1; by cyear gsector;
run;
proc univariate data=compu1 noprint;
	var &dep;														
	by cyear gsector;
	output out=count n=obs_int;
run;
proc reg data=compu1 noprint outest=parms;
	model &dep = cfo_x1 cfo_x2 cfo_x3;								
	by cyear gsector;
run;
data parms; merge parms count; by cyear gsector;
	if obs_int >= 8;
	alpha	=	cfo_x1;
	beta	=	cfo_x2;
	gamma	=	cfo_x3;
	keep gsector cyear alpha beta gamma;run;
proc datasets; delete count; run; quit;
data compu1; merge compu1 parms (in=m1); by cyear gsector;
	if m1;
	fitted		=	(alpha*cfo_x1)+(beta*cfo_x2)+(gamma*cfo_x3);
	ACFO_int	=	&dep-fitted;								
	abs_ACFO_int	=	abs(ACFO_int);
	keep gvkey cyear gsector ACFO_int abs_ACFO_int;run;
proc datasets; delete parms; run; quit;
proc sort data=compu1; by gvkey cyear;
run;
data comp.ACFO; set compu1;
	rename cyear	=	year;
	keep gvkey cyear ACFO_int abs_ACFO_int;
run;



****************************************************************;
* GOAL: GET PROD. COSTS MANAGEMENT			   	;
****************************************************************;
proc sort data=comp.compu out=compu; by cyear;
run;
data compu; merge compu (in=m1) out.outlier; by cyear;
	if m1;
run;

%let dep=pro_y;
proc sort data=compu nodupkey out=compu1; by gvkey cyear;
run;
data compu1; set compu1;
	if &dep ne .;													
	if pro_x1 ne .;
	if pro_x2 ne .;
	if pro_x3 ne .;
	if pro_x4 ne .;
	if abs(&dep) < outlier3;
run;
proc sort data=compu1; by cyear gsector;
run;
proc univariate data=compu1 noprint;
	var &dep;														
	by cyear gsector;
	output out=count n=obs_int;
run;
proc reg data=compu1 noprint outest=parms;
	model &dep = pro_x1 pro_x2 pro_x3 pro_x4;								
	by cyear gsector;
run;
data parms; merge parms count; by cyear gsector;
	if obs_int >= 8;
	alpha	=	pro_x1;
	beta	=	pro_x2;
	gamma	=	pro_x3;
	theta	=	pro_x4;
	keep gsector cyear alpha beta gamma theta;
run;
proc datasets; delete count; run; quit;
data compu1; merge compu1 parms (in=m1); by cyear gsector;
	if m1;
	fitted		=	(alpha*pro_x1)+(beta*pro_x2)+(gamma*pro_x3)+(theta*pro_x4);
	APRO_int	=	&dep-fitted;								
	abs_APRO_int=	abs(APRO_int);
	keep gvkey cyear gsector APRO_int abs_APRO_int;
run;
proc datasets; delete parms; run; quit;
proc sort data=compu1; by gvkey cyear;
run;
data out.APRO; set compu1;
	rename cyear	=	year;
	keep gvkey cyear APRO_int abs_APRO_int;
run;



****************************************************************;
* GOAL: GET DISCR. EXPENSES MANAGEMENT			   	;
****************************************************************;
proc sort data=out.compu out=compu; by cyear;
run;
data compu; merge compu (in=m1) out.outlier; by cyear;
	if m1;
run;

%let dep=exp_y;
proc sort data=compu nodupkey out=compu1; by gvkey cyear;
run;
data compu1; set compu1;
	if &dep ne .;													
	if exp_x1 ne .;
	if exp_x2 ne .;
	if abs(&dep) < outlier4;
run;
proc sort data=compu1; by cyear gsector;
run;
proc univariate data=compu1 noprint;
	var &dep;														
	by cyear gsector;
	output out=count n=obs_int;
run;
proc reg data=compu1 noprint outest=parms;
	model &dep = exp_x1 exp_x2;								
	by cyear gsector;
run;
data parms; merge parms count; by cyear gsector;
	if obs_int >= 8;
	alpha	=	exp_x1;
	beta	=	exp_x2;
	keep gsector cyear alpha beta;
run;
proc datasets; delete count; run; quit;
data compu1; merge compu1 parms (in=m1);
by cyear gsector;
	if m1;
	fitted		=	(alpha*exp_x1)+(beta*exp_x2);
	AEXP_int	=	&dep-fitted;								
	abs_AEXP_int=	abs(AEXP_int);
	keep gvkey cyear gsector AEXP_int abs_AEXP_int;
run;
proc datasets; delete parms; run; quit;

proc sort data=compu1; by gvkey cyear;
run;
data out.AEXP; set compu1;
	rename cyear	=	year;
	keep gvkey cyear AEXP_int abs_AEXP_int;
run;
proc printto;
run;
endrsubmit;
