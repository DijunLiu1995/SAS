options mprint mlogic symbolgen;
%macro process_data(in_file,out_file);
proc import datafile =&in_file. 
out=work.sheet2
dbms=xlsx
replace;
getnames=YES;
sheet="Sheet2";
run;

proc import datafile =&in_file.
out=work.sheet3
dbms=xlsx
replace;
getnames=YES;
sheet="Sheet3";
run;

proc sql;
create table &out_file. as 
select a.date, a.Ticker,b.cusip, a.dummy
from sheet2 a left join sheet3 b
on a.ticker=b.ticker
;
quit;
%mend process_data;

%process_data('/folders/myshortcuts/myfolder/3000 - 1.xlsx',File1_sheet4);
%process_data('/folders/myshortcuts/myfolder/3000 - 2.xlsx',File2_sheet4);
%process_data('/folders/myshortcuts/myfolder/3000 - 3.xlsx',File3_sheet4);
%process_data('/folders/myshortcuts/myfolder/3000 - 4.xlsx',File4_sheet4);
%process_data('/folders/myshortcuts/myfolder/3000 - 5.xlsx',File5_sheet4);
%process_data('/folders/myshortcuts/myfolder/3000 - 6.xlsx',File6_sheet4);
%process_data('/folders/myshortcuts/myfolder/3000 - 7.xlsx',File7_sheet4);
%process_data('/folders/myshortcuts/myfolder/3000 - 8.xlsx',File8_sheet4);
%process_data('/folders/myshortcuts/myfolder/3000 - 9.xlsx',File9_sheet4);
%process_data('/folders/myshortcuts/myfolder/3000 - 10.xlsx',File10_sheet4);

%macro append_data;
%do i = 2 %to 10;
	proc append base=File1_sheet4 data=&&File&i.._sheet4 force;
	run;
%end;
%mend append_data;

%append_data;
