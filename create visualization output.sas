
%let library=C:\Users\WilliamKirk\Documents\My Middlegame Files\Clients\MAP\Simulator Design\Batch Simulations\Analysis;
%let batchfile=revised batch 2018.07.25.xlsx;
%let datafile=revised database 2018.07.25.xlsx;

run;

proc import datafile="&library\&batchfile" dbms=XLSX out=batch replace;
     sheet='batch';
     getnames=yes;

data batch(index=(group=(casestudy variable)));
     keep casestudy iteration observation variable change;
	 set batch;

* comment: import and merge variable definitions to exclude exogenous variables. *;

proc import datafile="&library\&datafile" dbms=XLSX out=variables replace;
     sheet='variables';
     getnames=yes;

data variables(index=(group=(casestudy variable)));
     keep casestudy variable label grouping model format0-format2;
	 set variables;

data batch(index=(group=(casestudy iteration)));
     keep casestudy iteration observation variable grouping label change;
	 merge batch(in=in1) variables(in=in2);
	 by casestudy variable;

	 if in1;

	 if lowcase(model)='exogenous' then delete;

* comment: import and merge simulation rules for iterations. *;

proc import datafile="&library\&batchfile" dbms=XLSX out=iterations replace;
     sheet='iterations';
     getnames=yes;

data iterations(index=(group=(casestudy iteration)));
     keep casestudy iteration scenario simulation source type modifier;
	 set iterations;

data batch(index=(group=(casestudy observation)));
     keep casestudy observation source type modifier variable label grouping change;
	 merge batch(in=in1) iterations(in=in2);
	 by casestudy iteration;

	 if in1;

proc datasets nolist;
     delete iterations;

* comment: import and merge simulation rules for iterations. *;

proc import datafile="&library\&datafile" dbms=XLSX out=observations replace;
     sheet='observations';
     getnames=yes;

data observations(index=(group=(casestudy observation)));
     keep casestudy observation geography segment product date;
	 set observations;

data batch(index=(group=(casestudy observation variable)));
     keep casestudy observation geography segment product date source type modifier variable label grouping change;
	 merge batch(in=in1) observations(in=in2);
	 by casestudy observation;

	 if in1;

 proc datasets nolist;
      delete observations;

* comment: import and merge history for endogenous variables. *;

proc import datafile="&library\&datafile" dbms=XLSX out=history replace;
     sheet='data';
     getnames=yes;

data history(index=(group=(casestudy observation variable)));
     keep casestudy observation variable instance value;
	 set history;

data batch(index=(group=(casestudy observation source)));
     keep casestudy observation geography segment product date source type modifier variable label grouping actual simulated change;
	 merge batch(in=in1) history(where=(instance=0) in=in2);
	 by casestudy observation variable;

	 if in1;

	 actual=value;
	 simulated=actual+change;

proc datasets nolist;
     modify batch;
	 rename variable=variable1 label=label1 grouping=grouping1 actual=actual1 simulated=simulated1 change=change1;

* comment: reorganize history for exodogenous variables. *;

data history(index=(group=(casestudy observation source)));
     keep casestudy observation source variable instance value;
	 set history;

	 source=variable;

* comment: merge history for impressions of exodogenous variables. *;

data batch(index=(group=(casestudy observation source)));
     keep casestudy observation geography segment product date variable source type modifier variable1-variable2 label1 grouping1 actual1-actual2 simulated1-simulated2 change1-change2;
	 merge batch(in=in1) history(where=(instance=1) in=in2);
	 by casestudy observation source;

	 if in1;

	 variable2=source;
	 actual2=value;
	 if type=1 then change2=modifier;
	 if type=2 then change2=modifier*actual2;
	 simulated2=actual2+change2;

* comment: merge history for spending of exodogenous variables. *;

data batch(index=(group=(casestudy variable)));
     keep casestudy geography segment product date modifier variable variable1-variable2 label1 grouping1 actual1-actual3 simulated1-simulated3 change1-change3;
	 merge batch(in=in1) history(where=(instance=2) in=in2);
	 by casestudy observation source;

	 if in1;

	 actual3=value;
	 if type=1 then change3=modifier;
	 if type=2 then change3=modifier*actual3;
	 simulated3=actual3+change3;

proc datasets nolist;
     delete history;

 * comment: finalize batch file for various outputs;

data batch;
     keep casestudy geography segment product date modifier variable1 variable label1 label grouping1 grouping actual1-actual3 simulated1-simulated3 change1-change3;
	 merge batch(in=in1) variables(in=in2);
	 by casestudy variable;

	 if in1;

proc datasets nolist;
     modify batch;
	 rename variable=variable2 label=label2 grouping=grouping2;

data batch;
     keep casestudy geography segment product date modifier variable1-variable2 label1-label2 grouping1-grouping2 actual1-actual3 simulated1-simulated3 change1-change3;
	 set batch;

* comment: remove an observation that looks probematic. *; 

     if lowcase(label1)='considering' and lowcase(label2)='competition rpm (mm)' and modifier=-1 then do;

        simulated1=actual1;
        change1=0; 

	 end;

* comment: organize batch results to produce the contribution, effectiveness, and efficiency visualization ... return on investment is currently out of scope. *;

data contribution(index=(group=(casestudy geography segment product date variable1)));
     keep casestudy geography segment product date variable1-variable2 label1-label2 grouping1-grouping2 actual1-actual3 change1;
	 set batch(where=(modifier=-1 and lowcase(grouping2) in('paid media','owned media','earned media','personal selling','consumer promotion','trade promotion','sales promotion')));

	 change1=-1*change1;

proc means data=contribution noprint;
     var actual1 change1;
	 output out=summary mean=actual1 x sum=y summary2;
	 by casestudy geography segment product date variable1;
	 id label1 grouping1;

data summary;
     keep casestudy geography segment product date variable1-variable2 label1-label2 grouping1-grouping2 actual1-actual3 change1;
	 set summary;

	 variable2=0;
	 label2='BASELINE';
	 grouping2='BASELINE';

	 change1=actual1-summary2;
	 actual2=0;
	 actual3=0;
 
data contribution(index=(group=(casestudy date)));
     keep casestudy geography segment product date grouping1 label1 grouping2 label2 contribution activity spending;
	 set contribution summary;

	 contribution=change1;
	 activity=actual2;
	 spending=actual3;
	 

proc datasets nolist;
     delete summary;

* comment: add additional dimesnionality ... just using dates for this example. *;

proc import datafile="&library\&datafile" dbms=XLSX out=dates replace;
     sheet='dates';
     getnames=yes;

data dates(index=(group=(casestudy date)));
     keep casestudy date calendar financials plan;
	 set dates;

data contribution;
     format casestudy best16. geography segment product $char128. date mmddyy8. calendar financials plan grouping1 label1 grouping2 label2 $char128. contribution activity spending best16.;
     keep casestudy geography segment product date calendar financials plan grouping1 label1 grouping2 label2 contribution activity spending;
	 merge contribution(in=in1) dates(in=in2);
	 by casestudy date;

	 if in1;

proc datasets nolist;
     delete dates;

* comment export the data to excel for example of output ... we will want to do this on the platform. *;

proc sort data=contribution force;
     by casestudy geography segment product date grouping1 label1 grouping2 label2;

proc export data=contribution outfile="&library\contribution.csv" dbms=CSV replace;

* comment: organize batch results to produce the marginal response visualization. *;

data marginal;
     keep casestudy geography segment product date label1-label2 grouping1-grouping2 modifier actual1-actual3 simulated1-simulated3;
	 set batch(where=(lowcase(grouping2) in('product','price','paid media','owned media','earned media','personal selling','consumer promotion','trade promotion','sales promotion','distribution','environment')));

data zero;
     keep casestudy geography segment product date label1-label2 grouping1-grouping2 modifier simulated1-simulated3;
	 set marginal(where=(modifier=1));

	 modifier=0;
	 simulated1=actual1;
	 simulated2=actual2;
	 simulated3=actual3;

data marginal(index=(group=(casestudy date)));
     keep casestudy geography segment product date label1-label2 grouping1-grouping2 modifier simulated1-simulated3;
	 set marginal zero;

* comment: add additional dimesnionality ... just using dates for this example. *;

proc import datafile="&library\&datafile" dbms=XLSX out=dates replace;
     sheet='dates';
     getnames=yes;

data dates(index=(group=(casestudy date)));
     keep casestudy date calendar financials plan;
	 set dates;
 
data marginal;
     format casestudy best16. geography segment product $char128. date mmddyy8. calendar financials plan grouping1 label1 grouping2 label2 $char128. modifier simulated1-simulated3 best16.;
     keep casestudy geography segment product date calendar financials plan grouping1 label1 grouping2 label2 modifier simulated1-simulated3;
	 merge marginal(in=in1) dates(in=in2);
     by casestudy date;

	 if in1;

* comment export the data to excel for example of output ... we will want to do this on the platform. *;

proc sort data=marginal force;
     by casestudy geography segment product date grouping1 label1 grouping2 label2 modifier;

proc export data=marginal outfile="&library\marginal.csv" dbms=CSV replace;

* comment: organize batch results to produce the due to visualization. *;

data dueto(index=(group=(casestudy geography segment product date variable1)));
     keep casestudy geography segment product date variable1-variable2 label1-label2 grouping1-grouping2 actual1 change1;
	 set batch(where=(modifier=-1 and lowcase(grouping2) in('product','price','paid media','owned media','earned media','personal selling','consumer promotion','trade promotion','sales promotion','distribution','environment')));

	 change1=-1*change1;

proc means data=dueto noprint;
     var actual1 change1;
	 output out=summary mean=actual1 x sum=y summary2;
	 by casestudy geography segment product date variable1;
	 id label1 grouping1;

data summary;
     keep casestudy geography segment product date variable1-variable2 label1-label2 grouping1-grouping2 actual1 change1;
	 set summary;

	 variable2=0;
	 label2='OTHER FACTORS';
	 grouping2='OTHER FACTORS';

	 change1=actual1-summary2;
 
data dueto(index=(group=(casestudy date)));
     keep casestudy geography segment product date grouping1 label1 grouping2 label2 dueto;
	 set dueto summary;

	 dueto=change1;

proc datasets nolist;
     delete summary;

* comment: add additional dimesnionality ... just using dates for this example. *;

proc import datafile="&library\&datafile" dbms=XLSX out=dates replace;
     sheet='dates';
     getnames=yes;

data dates(index=(group=(casestudy date)));
     keep casestudy date calendar financials plan;
	 set dates;

data dueto;
     format casestudy best16. geography segment product $char128. date mmddyy8. calendar financials plan grouping1 label1 grouping2 label2 $char128. dueto best16.;
     keep casestudy geography segment product date calendar financials plan grouping1 label1 grouping2 label2 dueto;
	 merge dueto(in=in1) dates(in=in2);
	 by casestudy date;

	 if in1;

proc datasets nolist;
     delete dates;

* comment export the data to excel for example of output ... we will want to do this on the platform. *;

proc sort data=dueto force;
     by casestudy geography segment product date grouping1 label1 grouping2 label2;

proc export data=dueto outfile="&library\dueto.csv" dbms=CSV replace;

run;
