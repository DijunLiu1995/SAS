
/*************************************************************************************/
/**************** W R D S   R E S E A R C H   A P P L I C A T I O N S ****************/
/*************************************************************************************/
/* Summary   : Table I: Program Listing for the DOW Loop                             */
/* Date      : November 2, 2011                                                      */
/* Use the DOW loop to read data from different datasets, clean,                     */
/* match and output it all at the same time, saving the I/O resources on the server. */
/*************************************************************************************/
%let wrds=wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon username=_prompt_;
rsubmit;
option notes;
PROC PRINTTO LOG='/home/lancaster/atimsal/DowLoop.log' NEW;
RUN;
/* Enter your WRDS institution name and your WRDS username */
libname taq '/wrds/taq/sasdata';
libname project '/home/lancaster/atimsal'; 
 

/*************************************************************************************/
/**************** W R D S   R E S E A R C H   A P P L I C A T I O N S ****************/
/*************************************************************************************/
/* Summary   : Table I: Program Listing for the DOW Loop                             */
/* Date      : November 2, 2011                                                      */
/* Use the DOW loop to read data from different datasets, clean,                     */
/* match and output it all at the same time, saving the I/O resources on the server. */
/*************************************************************************************/
%let IN_date=20141027; 
data project.matched /*Line 1*/
(drop = cqsymbol cqdate cqtime bid bidsiz ofr ofrsiz lagged_match timediff
   exact_match rbid rofr rcqdate cqtime rcqtime rcqsymbol
rename =  (mbid=BID mofr=OFR)
sortedby = symbol date time);
attrib CQSYMBOL length=$10. ; /*Line 2*/
attrib RCQSYMBOL length=$10.; /*Line 3*/
retain CQSYMBOL RCQSYMBOL CQDATE RCQDATE CQTIME RCQTIME BID RBID OFR ROFR 
end_of_quotes_file;  /*Line 4*/
 
set taq.ct_&IN_date. (where = (time >= '9:30:00'T  AND  time <= '16:00:00'T and symbol in ('AAPL','IBM'))) ;  /*Line 5*/
do until (exact_match = 1 OR lagged_match = 1 OR end_of_quotes_file = 1 ); /*Line 6*/
if symbol>cqsymbol OR (symbol = cqsymbol AND date > cqdate) then
  goto READQUOTE; /*Line 7*/
else /*Line  9-12*/
if cqsymbol > symbol OR cqdate>date then do; lagged_match=1;goto END_TIMEOKLOOP;End;
else do; TIMEDIFF = time - cqtime; TIMEDIFF = time - cqtime; /*Line 13-15*/
if timediff = 5 then exact_match = 1; /*Line 16-25*/
else if timediff < 5 then lagged_match = 1;
else do;
  READQUOTE: ;
  RCQSYMBOL = CQSYMBOL;
  RCQDATE = CQDATE;
  RCQTIME = CQTIME;
  RBID = BID;
  ROFR = OFR;
 
set taq.cq_&IN_date. (rename = (symbol=CQSYMBOL date=CQDATE time=CQTIME) /*Line 26-30*/
where=(cqtime>='9:30:00'T AND cqtime<='16:00:00'T AND ofr>0 AND cqsymbol in ('AAPL','IBM') AND (ofr-bid)/bid<= 0.1))
end = end_of_quotes_file ;end;end; END_TIMEOKLOOP: ; end; 
/*Line 31-37: Depending on the break point encountered above, select the match array*/
if exact_match then do;
   MBID = bid;  label mbid = 'Matching Bid Price';
   MOFR = ofr;  label mofr = 'Matching Offer Price' ;
   MTIME = cqtime; format mtime time. ;  label mtime = 'Time of the Matching Quote' ;
   Output;end;
else if lagged_match then do; /*Line 38-46*/
  if symbol = rcqsymbol then do;MBID = rbid;MOFR = rofr;MTIME = rcqtime;output;End;
else do; MBID = .; MOFR = .; MTIME = .; output;End;end;             /*Line 47-54*/
else if end_of_quotes_file then do;MBID=.;MOFR=.;MTIME=.;Output;end;/*Line 55-62*/
run;

proc printto;
run;

endrsubmit;
