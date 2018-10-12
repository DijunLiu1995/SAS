%macro process_data(in_file,out_file)
proc import datafile ='/folders/myshortcuts/myfolder/3000 - 2.xlsx' 
out=work.sheet2
dbms=xlsx;
getnames=YES;
sheet="Sheet2";
run;

proc import datafile ='/folders/myshortcuts/myfolder/3000 - 2.xlsx' 
out=work.sheet3
dbms=xlsx;
getnames=YES;
sheet="Sheet3";
run;

proc sql;
create table sheet4 as 
select a.date, a.Ticker,b.cusip, a.dummy
from sheet2 a left join sheet3 b
on a.ticker=b.ticker
;
quit;

proc sql;
select distinct ticker from sheet4
;
quit;

data bcei_data;
set sheet4;
where ticker = "BCEI";
run;

data bgc_data;
set sheet4;
where ticker= 'BGC';
run;

proc sql;
select distinct dummy from bgc_data;
quit;
