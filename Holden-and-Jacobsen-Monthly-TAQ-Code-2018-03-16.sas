/* HOLDEN AND JACOBSEN MONTHLY TAQ CODE 2018-03-16 

   Our SAS code selects the Monthly TAQ (MTAQ) data that you want from WRDS,
   cleans the data, computes the National Best Bid and Offer (NBBO), computes  
   standard liquidity measures, and writes output files to your WRDS cloud 
   folder. It was last updated on March 16, 2018.

   It is based on: Holden, C. and S. Jacobsen, 2014, Liquidity Measurement 
   Problems in Fast, Competitive Markets: Expensive and Cheap Solutions,
   Journal of Finance 69, 1747-1785. Our original research code has been 
   adapted to work with the WRDS Cloud.

   Our code creates the nine WORK files listed below in the WRDS Cloud. In
   the last step, you can choose which files you want to write to your WRDS
   cloud folder. By default, the last three files are written there.

      (1) Raw data files containing MTAQ data downloaded from WRDS: 
          "MonthlyQuote" contains quote data
          "MonthlyTrade" contains trade data

      (2) Intermediate data files:
          "CompleteNBBO" contains the complete NBBO
          "TradesandCorrespondingNBBO" contains trades and the 
              corresponding NBBO
          "BuySellIndicators" adds buy/sell indicators based on three 
              conventions: LR = Lee & Ready (1991), EMO = Ellis, Michaely &
              O’Hara (2000), CLNV =Chakrabarty, Li, Nguyen, & Van Ness (2006)

      (3) Output files containing standard liquidity measures:
          "QuotedSpreadsandDepths" contains Quoted Spreads and Depths
          "EffectiveSpreads" contains Effective Spreads
          "RealizedSpreadsandPriceImpacts" contains Realized Spreads 
              and Price Impacts that are aggregated based three conventions:
              Ave = simple average, DW = dollar-weighted, SW = share-weighted
   
   Step-by-step instructions for running this WRDS Cloud program using PuTTY
   and WinScp are available at: www.kelley.iu.edu/cholden/instructions.pdf

   We welcome any comments or suggestions. We can be reached at:
      Craig Holden: cholden@indiana.edu
      Stacey Jacobsen: staceyj@cox.smu.edu 

   We thank Henk Berkman, Adam Booker, Charles Collver, Marco Eugster, 
   Ruslan Goyenko, Mehrdad Samadi, David Xu, and Zhong Zhang for helpful 
   suggestions and corrections. We are solely responsible for any remaining
   errors. Of course, you use this code at your own risk. */

/* Enter your WRDS institution name and your WRDS username */
libname project '/home/institution/username'; 
options errors=2;

/* STEP 1: RETRIEVE MONTHLY TRADE AND QUOTE (MTAQ) FILES  */
    libname taq '/wrds/taq/sasdata';

    /* Retrieve Quote data */
    data MonthlyQuote (drop=QSEQ);

        /* Enter Quote file names in YYYYMMDD format for the dates you want*/
        set taq.cq_20131016 taq.cq_20131017;
		by symbol date time;

		/* Enter company tickers you want;  */
        where symbol in ('AAPL','IBM')

        /* If you wish to select dual shares, preferred shares, etc., 
		   add a symbol suffix on the end of a symbol root. For example:
        where symbol in ('AAPL','IBM','BRKA','BRKB') */

        /* Quotes are retrieved prior to market open time to ensure that  
		   NBBO quotes are available for beginning of the day trades*/
        and (("9:00:00"t) <= time <= ("16:00:00"t));
        format date date9.;
    run;

    /* Retrieve Trade data */
    data MonthlyTrade (drop=G127 COND TSEQ);

        /* Enter Trade file names in YYYYMMDD format for the same dates */
        set taq.ct_20131016 taq.ct_20131017;
		by symbol date time;

		/* Enter the same company tickers as above */
        where symbol in ('AAPL','IBM') 

        /* If you wish to select dual shares, preferred shares, etc., 
		   add a symbol suffix on the end of a symbol root. For example:
        where symbol in ('AAPL','IBM','BRKA','BRKB') */

		/* Retrieve trades during normal market hours */
        and (("9:30:00"t) <= time <= ("16:00:00"t));
        type='T';
        format date date9.;
    run;

/* STEP 2: CLEAN QUOTE DATA */

data MonthlyQuote;
    set MonthlyQuote;

    /* Quote Filter 1: Abnormal Modes. Quotes with abnormal modes (i.e.,  
	   abnormal quote conditions) are set to extreme values so that they   
	   will not enter the NBBO */
    if mode in (4,7,9,11,13,14,15,19,20,27,28) then do; 
        OFR=9999999; 
        BID=0; 
    end;

    /* Quote Filter 2: Crossed Quotes on the Same Exchange. Quotes from a 
	   given exchange with positive values in which the Bid is greater than
	   the Ask (i.e., crossed quotes) are set to extreme values so that they
	   will not enter the NBBO */
    If BID>OFR and BID>0 and OFR>0 then do; 
        OFR=9999999; 
        BID=0; 
    end;

    /* Quote Filter 3: One-Sided Bid Quotes. One-sided bid quotes (i.e., 
	   quotes in which the Bid is a positive value and the Ask is set to '0') 
	   are allowed to enter the NBB; the Ask is set to an extreme value so 
	   that it will not enter the NBO. One-sided ask quotes are also allowed 
	   to enter the NBO (i.e., quotes in which the Ask is a positive value 
	   and the Bid is set to '0'). In these cases, the bid is already the 
	   extreme value 0; as a result, no adjustment is necessary to ensure it 
	   does not enter the NBB. */
    If BID>0 and OFR=0 then OFR=9999999;

    /* Quote Filter 4: Abnormally Large Spreads. Quotes with positive values  
	   and large spreads (i.e., spreads greater than $5.00) are set to 
	   extreme values so that they will not enter the NBBO */
    spr=OFR-BID;
    If spr>5 and BID>0 and OFR>0 and OFR ne 9999999 then do; 
        BID=0; OFR=9999999; end;

    /* Quote Filter 5: Withdrawn Quotes. This is when an exchange temporarily 
		has no quote, as indicated by quotes with price or depth fields 
		containing values less than or equal to 0 or equal to '.'. See 
		discussion in Holden and Jacobsen (2013), page 11. They are set to 
		extreme values so that they will not enter the NBBO. They are NOT 
		deleted, because that would incorrectly allow the prior quote from 
		that exchange to enter the NBBO. NOTE: Quote Filter 5 must come last
	*/
    if OFR le 0 then OFR=9999999;
    if OFR =. then OFR=9999999;
    if OFRSIZ le 0 then OFR=9999999;
    if OFRSIZ =. then OFR=9999999;
    if BID le 0 then BID=0;
    if BID =. then BID=0;
    if BIDSIZ le 0 then BID=0;
    if BIDSIZ =. then BID=0;
run;

/* STEP 3: CLEAN TRADE DATA */

data MonthlyTrade;
    set MonthlyTrade;

    /* Trade Filter: Keep only trades in which the Correction field 
       contains '00' and the Price field contains a value greater than 
       zero */
    where corr eq 0 and price gt 0;
run;

/* STEP 4: CREATE INTERPOLATED TIME VARIABLES 
   Based on: Holden and Jacobsen (2013), pages 22-24 */

/* Create Interpolated Quote Time for quote dataset */
/* 'J' indexes the order of quotes within a given second */
data MonthlyQuote (drop=MODE spr);
    set MonthlyQuote;
    retain J;
    by symbol date time;
    if first.symbol or first.date or first.time then J=1; else J=J+1;
run;

/* 'N' is the total number of quotes within a given second */
proc sql;
	create table monthlyquote2
	as select a.*,  max(J) as N 
	from MonthlyQuote as a  
	group by symbol,date,time
	order by symbol,date,time,J;
quit; 

data monthlyquote2 (drop=J N);
    set monthlyquote2;
    InterpolatedTime=time+((2*J-1)/(2*N));
    format InterpolatedTime best15.;
run;

/* Create Interpolated Trade Time for trade dataset */
/* 'I' indexes the order of trades within a given second */
data MonthlyTrade;
    set MonthlyTrade;
    retain I;by symbol date time;
    if first.symbol or first.date or first.time then I=1; else I=I+1;
run;

/* 'N' is the total number of quotes within a given second */
proc sql;
	create table monthlytrade2
	as select a.*,  max(I) as N 
	from MonthlyTrade as a  
	group by symbol,date,time
	order by symbol,date,time,I;
quit; 

data monthlytrade2 (drop=I N);
    set monthlytrade2;
    InterpolatedTime=time+((2*I-1)/(2*N));
    tradetime=time;
    format InterpolatedTime best15.;
    format tradetime time.;
run;

/* STEP 5: NATIONAL BEST BID AND OFFER (NBB0) CALCULATION */

/* Assign ID to Each Unique Exchange or Market Maker and Find 
   The Maximum Number of Exchanges*/
proc sort data=monthlyquote2; 
    by ex mmid;
run;

data monthlyquote2;
    set monthlyquote2;
    retain ExchangeID;
    if _N_=1 then ExchangeID=0;
    if first.ex or first.mmid then ExchangeID=ExchangeID+1;
    by ex mmid;
run;

data _null_;
 	set monthlyquote2 end=eof;
 	retain MaxExchangeID;
 	if ExchangeID gt MaxExchangeID then MaxExchangeID=ExchangeID;
 	if eof then call symput('MaxExchangeID',MaxExchangeID);
run;

%put &MaxExchangeID;
proc sort data=monthlyquote2; 
    by symbol date time InterpolatedTime;
run;
	
%macro BBO;
/* Create Dataset that has a Column for Each Exchange ID's Bid and Offer
   Quote for All Interpolated Times and Multiply Bid Size and Offer Size
   By 100 to convert Round Lots to Shares*/
data monthlyquote2;
    set monthlyquote2;
	by symbol date;
	array exbid(&MaxExchangeID);exbid(ExchangeID)=bid;
	array exofr(&MaxExchangeID);exofr(ExchangeID)=ofr;
	array exbidsz(&MaxExchangeID);exbidsz(ExchangeID)=bidsiz*100;
	array exofrsz(&MaxExchangeID);exofrsz(ExchangeID)=ofrsiz*100;
/* For Interpolated Times with No Quote Update, Retain Previous Quote 
   Outstanding*/
%do i=1 %to &MaxExchangeID;
	retain exbidR&i exofrR&i exbidszR&i exofrszR&i;
	if first.symbol or first.date then exbidR&i=exbid&i;
    if exbid&i ge 0 then exbidR&i=exbid&i; 
        else exbidR&i=exbidR&i+0;
	if first.symbol or first.date then exofrR&i=exofr&i;
    if exofr&i ge 0 then exofrR&i=exofr&i; 
        else exofrR&i=exofrR&i+0;
	if first.symbol or first.date then exbidszR&i=exbidsz&i;
    if exbidsz&i ge 0 then exbidszR&i=exbidsz&i; 
        else exbidszR&i=exbidszR&i+0;
	if first.symbol or first.date then exofrszR&i=exofrsz&i;
    if exofrsz&i ge 0 then exofrszR&i=exofrsz&i; 
        else exofrszR&i=exofrszR&i+0;
%end;
/* Find Best Bid and Offer Across All Exchanges and Market Makers*/
%do i=&MaxExchangeID %to &MaxExchangeID;
	BestBid = max(of exbidR1-exbidR&i);
	BestOfr = min(of exofrR1-exofrR&i);
%end;
/* Find Best and Total Depth Across All Exchanges and Market Makers that
   are at the NBBO*/
%do i=1 %to &MaxExchangeID;
	if exbidR&i=BestBid then MaxBidDepth=max(MaxBidDepth,exbidszR&i);
	if exofrR&i=BestOfr then MaxOfrDepth=max(MaxOfrDepth,exofrszR&i);
	if exbidR&i=BestBid then TotalBidDepth=sum(TotalBidDepth,exbidszR&i);
	if exofrR&i=BestOfr then TotalOfrDepth=sum(TotalOfrDepth,exofrszR&i);
%end;
run;
%mend BBO;
%BBO;


data CompleteNBBO (keep=symbol date time InterpolatedTime 
    BestBid BestOfr MaxBidDepth MaxOfrDepth TotalBidDepth TotalOfrDepth);
    set monthlyquote2;
/* Only Output Changes in NBBO Records (e.g., changes in quotes or depth)*/
    if symbol eq lag(symbol) 
        and date eq lag(date) 
        and BestOfr eq lag(BestOfr) 
        and BestBid eq lag(BestBid) 
        and MaxOfrDepth eq lag(MaxOfrDepth) 
        and MaxBidDepth eq lag(MaxBidDepth)
        and TotalOfrDepth eq lag(TotalOfrDepth) 
        and TotalBidDepth eq lag(TotalBidDepth) then delete;
/* If Abnormal Quotes Enter the NBBO Then Set To ".". There Will Be 
   NO NBBO */
    if BestBid < .00001 then 
        do;
        BestBid=.;
        BestOfr=.;
        MaxOfrDepth=.;
        MaxBidDepth=.;
        TotalOfrDepth=.;
        TotalBidDepth=.;
        end;
    else if BestOfr > 9999998 then 
        do;
        BestBid=.; 
        BestOfr=.;
        MaxOfrDepth=.;
        MaxBidDepth=.;
        TotalOfrDepth=.;
        TotalBidDepth=.;
        end;
run;

/* STEP 6: INTERWEAVE TRADES WITH QUOTES: TRADES AT INTERPOLATED TIME TMMM
   ARE MATCHED WITH QUOTES IN FORCE AT INTERPOLATED TIME TMM(M-1)
   To Do This, Increase Interpolated Quote Time in Quotes Dataset by One
   Millisecond = .001*/

data CompleteNBBO;
    set CompleteNBBO;
    type='Q';
    InterpolatedTime+.001;
run;

/* Stack Quotes and Trades Datasets */
data TradesandCorrespondingNBBO;
    set monthlytrade2 CompleteNBBO;
    by symbol date InterpolatedTime type;
run;

/* For Each Trade, Identify the Outstanding NBBO, Best Depth and Total 
   Depth */
data TradesandCorrespondingNBBOv2 (drop=time BestOfr BestBid 
     MaxOfrDepth MaxBidDepth TotalOfrDepth TotalBidDepth corr);
    set TradesandCorrespondingNBBO;
    by symbol date;
    retain quotetime BestOfr2 BestBid2 MaxOfrDepth2 MaxBidDepth2 
        TotalOfrDepth2 TotalBidDepth2;
	if first.symbol or first.date and type='T' then quotetime=.;
	if first.symbol or first.date and type='T' then BestOfr2=.;
	if first.symbol or first.date and type='T' then BestBid2=.;
	if first.symbol or first.date and type='T' then MaxOfrDepth2=.;
	if first.symbol or first.date and type='T' then MaxBidDepth2=.;
	if first.symbol or first.date and type='T' then TotalOfrDepth2=.;
	if first.symbol or first.date and type='T' then TotalBidDepth2=.;
    if type='Q' then quotetime=time;else quotetime=quotetime;
    if type='Q' then BestOfr2=BestOfr;else BestOfr2=BestOfr2;
    if type='Q' then BestBid2=BestBid;else BestBid2=BestBid2;
    if type='Q' then MaxOfrDepth2=MaxOfrDepth;else MaxOfrDepth2=MaxOfrDepth2;
    if type='Q' then MaxBidDepth2=MaxBidDepth;else MaxBidDepth2=MaxBidDepth2;
    if type='Q' then TotalOfrDepth2=TotalOfrDepth;
        else TotalOfrDepth2=TotalOfrDepth2;
    if type='Q' then TotalBidDepth2=TotalBidDepth;
        else TotalBidDepth2=TotalBidDepth2;
    format quotetime time.;
run;

/* STEP 7: Classify Trades as "Buys" or "Sells" Using Three Conventions: 
   LR = Lee and Ready (1991), EMO = Ellis, Michaely and O’Hara (2000)
   and CLNV = Chakrabarty, Li, Nguyen, and Van Ness (2006); Determine NBBO 
   Midpoint and Locked and Crossed NBBOs */

data BuySellIndicators;
    set TradesandCorrespondingNBBOv2;
    where type='T';
    midpoint=(BestOfr2+BestBid2)/2;
    if BestOfr2=BestBid2 then lock=1;else lock=0;
    if BestOfr2<BestBid2 then cross=1;else cross=0;
run;

/* Determine Whether Trade Price is Higher or Lower than Previous Trade 
   Price, or "Trade Direction" */
data BuySellIndicators;
    set BuySellIndicators;
    by symbol date;
    direction=dif(price);
    if first.symbol then direction=.;
    if first.date then direction=.;
run;

data BuySellIndicators;
    set BuySellIndicators;
    retain direction2;
    if direction ne 0 then direction2=direction; 
    else direction2=direction2;
run;

/* First Classification Step: Classify Trades Using Tick Test */
data BuySellIndicators (drop=direction);
    set BuySellIndicators;
	length BuySellLR BuySellEMO BuySellCLNV $4.;
    if direction2>0 then BuySellLR=1;
    if direction2<0 then BuySellLR=-1;
    if direction2=. then BuySellLR=.;
    if direction2>0 then BuySellEMO=1;
    if direction2<0 then BuySellEMO=-1;
    if direction2=. then BuySellEMO=.;
    if direction2>0 then BuySellCLNV=1;
    if direction2<0 then BuySellCLNV=-1;
    if direction2=. then BuySellCLNV=.;
run;

/* Second Classification Step: Update Trade Classification When 
   Conditions are Met as Specified by LR, EMO, and CLNV */
data BuySellIndicators;
    set BuySellIndicators;
    if lock=0 and cross=0 and price gt midpoint then BuySellLR=1;
    if lock=0 and cross=0 and price lt midpoint then BuySellLR=-1;
    if lock=0 and cross=0 and price=BestOfr2 then BuySellEMO=1;
    if lock=0 and cross=0 and price=BestBid2 then BuySellEMO=-1;
    ofr30=BestOfr2-.3*(BestOfr2-BestBid2);
    bid30=BestBid2+.3*(BestOfr2-BestBid2);
    if lock=0 and cross=0 and price le BestOfr2 and price ge ofr30
        then BuySellCLNV=1;
    if lock=0 and cross=0 and price le bid30 and price ge BestBid2 
        then BuySellCLNV=-1;
run;

/* STEP 8: CALCULATE QUOTED SRPEADS AND DEPTHS */

/* Use Quotes During Normal Market Hours */
data QSpread1;
    set CompleteNBBO;
    if time lt ("9:30:00"t) then delete;
run;

/* Determine Time Each Quote is In Force Based on Interpolated Time */
proc sort data=QSpread1;
    by symbol date descending InterpolatedTime;
run;

data QSpread1;
    set QSpread1;
    by symbol date;
    inforce=abs(dif(InterpolatedTime));
run;

/* If Last Quote of Day, then Quote is Inforce Until 4:00 pm */
data QSpread1;
    set QSpread1;
    by symbol date;
    end=57600;   /* 4:00 pm = 57,600 seconds after midnight  */
    if first.symbol or first.date 
    then inforce=max((end-InterpolatedTime),0);
run;

proc sort data=QSpread1 (drop=end);
    by symbol date InterpolatedTime;
run;

/* Find Midpoint */
data QSpread1;
    set QSpread1;
    midpoint=(BestOfr+BestBid)/2;
run;

data QSpread2;
    set QSpread1;
/* Delete Locked and Crossed Quotes */
    if BestOfr=BestBid or BestOfr<BestBid then delete;
/* Multiply Dollar Quoted Spread, Percent Quoted Spread, Maximum Dollar 
   Depth, Maximum Share Depth, Total Dollar Depth, and Total Share 
   Depth by Time Inforce */
    wQuotedSpread_Dollar=(BestOfr-BestBid)*inforce;
    wQuotedSpread_Percent=(log(BestOfr)-log(BestBid))*inforce;
    wTotalOfrDepth_Dollar=BestOfr*TotalOfrDepth*inforce;
    wTotalBidDepth_Dollar=BestBid*TotalBidDepth*inforce;
    wTotalOfrDepth_Share=TotalOfrDepth*inforce;
    wTotalBidDepth_Share=TotalBidDepth*inforce;
    wMaxOfrDepth_Dollar=BestOfr*MaxOfrDepth*inforce;
    wMaxBidDepth_Dollar=BestBid*MaxBidDepth*inforce;
    wMaxOfrDepth_Share=MaxOfrDepth*inforce;
    wMaxBidDepth_Share=MaxBidDepth*inforce;
run;

/* Find Average Across Firm-Day */
proc sql;
    create table QuotedSpreadsandDepths 
    as select symbol,date,
    sum(inforce) as sumtime,
    sum(wQuotedSpread_Dollar) as swQuotedSpread_Dollar,
    sum(wQuotedSpread_Percent) as swQuotedSpread_Percent,
    sum(wTotalOfrDepth_Dollar) as swTotalOfrDepth_Dollar,
    sum(wTotalBidDepth_Dollar) as swTotalBidDepth_Dollar,
    sum(wTotalOfrDepth_Share) as swTotalOfrDepth_Share,
    sum(wTotalBidDepth_Share) as swTotalBidDepth_Share,
    sum(wMaxOfrDepth_Dollar) as swMaxOfrDepth_Dollar,
    sum(wMaxBidDepth_Dollar) as swMaxBidDepth_Dollar,
    sum(wMaxOfrDepth_Share) as swMaxOfrDepth_Share,
    sum(wMaxBidDepth_Share) as swMaxBidDepth_Share 
    from QSpread2 
    group by symbol,date 
    order by symbol,date;
quit;

/* Calculate Time-Weighted Dollar Quoted Spread, Percent Quoted Spread, 
   Maximum Dollar Depth, Maximum Share Depth, Total Dollar Depth, and 
   Total Share Depth */
data QuotedSpreadsandDepths;
    set QuotedSpreadsandDepths;
    QuotedSpread_Dollar=swQuotedSpread_Dollar/sumtime;
    QuotedSpread_Percent=swQuotedSpread_Percent/sumtime;
    TotalOfrDepth_Dollar=swTotalOfrDepth_Dollar/sumtime;
    TotalBidDepth_Dollar=swTotalBidDepth_Dollar/sumtime;
    TotalOfrDepth_Share=swTotalOfrDepth_Share/sumtime;
    TotalBidDepth_Share=swTotalBidDepth_Share/sumtime;
    MaxOfrDepth_Dollar=swMaxOfrDepth_Dollar/sumtime;
    MaxBidDepth_Dollar=swMaxBidDepth_Dollar/sumtime;
    MaxOfrDepth_Share=swMaxOfrDepth_Share/sumtime;
    MaxBidDepth_Share=swMaxBidDepth_Share/sumtime;
	drop swQuotedSpread_Dollar swQuotedSpread_Percent 
         swTotalOfrDepth_Dollar swTotalBidDepth_Dollar
         swTotalOfrDepth_Share swTotalBidDepth_Share
         swMaxOfrDepth_Dollar swMaxBidDepth_Dollar
         swMaxOfrDepth_Share swMaxBidDepth_Share;
run;

/* STEP 9: CALCULATE EFFECTIVE SPREADS; AGGREGATE BASED ON 3 CONVENTIONS:
   Ave = SIMPLE AVERAGE, DW = DOLLAR-WEIGHTED, SW = SHARE-WEIGHTED */

data BuySellIndicators;
    set BuySellIndicators;
    wEffectiveSpread_Dollar=(abs(price-midpoint))*2;
    wEffectiveSpread_Percent=abs(log(price)-log(midpoint))*2;
    dollar=price*size;
    wEffectiveSpread_Dollar_DW=wEffectiveSpread_Dollar*dollar;
    wEffectiveSpread_Dollar_SW=wEffectiveSpread_Dollar*size;
    wEffectiveSpread_Percent_DW=wEffectiveSpread_Percent*dollar;
    wEffectiveSpread_Percent_SW=wEffectiveSpread_Percent*size;
run;

/* Delete Trades Associated with Locked or Crossed Best Bids or Best 
   Offers */
data TSpread2;
    set BuySellIndicators;
    if lock=1 or cross=1 then delete;
run;

/* Find average across firm-day */
proc sql;
    create table EffectiveSpreads 
    as select symbol,date,
    sum(dollar) as sumdollar,
    sum(size) as sumsize,
    mean(wEffectiveSpread_Dollar) as EffectiveSpread_Dollar_Ave,
    mean(wEffectiveSpread_Percent) as EffectiveSpread_Percent_Ave,
    sum(wEffectiveSpread_Dollar_DW) as waEffectiveSpread_Dollar_DW,
    sum(wEffectiveSpread_Dollar_SW) as waEffectiveSpread_Dollar_SW,
    sum(wEffectiveSpread_Percent_DW) as waEffectiveSpread_Percent_DW,
    sum(wEffectiveSpread_Percent_SW) as waEffectiveSpread_Percent_SW 
    from TSpread2 
    group by symbol,date 
    order by symbol,date;
quit;

/* Calculate Dollar-Weighted (DW) and Share-Weighted (SW) Dollar Effective 
   Spreads and Percent Effective Spreads */
data EffectiveSpreads;
    set EffectiveSpreads;
    EffectiveSpread_Dollar_DW=waEffectiveSpread_Dollar_DW/sumdollar;
    EffectiveSpread_Dollar_SW=waEffectiveSpread_Dollar_SW/sumsize;
    EffectiveSpread_Percent_DW=waEffectiveSpread_Percent_DW/sumdollar;
    EffectiveSpread_Percent_SW=waEffectiveSpread_Percent_SW/sumsize;
	drop waEffectiveSpread_Dollar_DW waEffectiveSpread_Dollar_SW
         waEffectiveSpread_Percent_DW waEffectiveSpread_Percent_SW;
run;

/* STEP 10: CALCULATE REALIZED SPREADS AND PRICE IMPACTS BASED ON THREE:
   CONVENTIONS: LR = LEE AND READY (1991), EMO = ELLIS, MICHAELY, AND O'HARA 
   (2000) AND CLNV = CHAKRABARTY, LI, NGUYEN, AND VAN NESS (2006);  
   FIND THE NBBO MIDPOINT 5 MINUTES SUBSEQUENT TO THE TRADE */

/* Redefine the InterpolatedTime variable as 5 minutes earlier (e.g., quotes
   at 10:00:00 are redefined as occurring at 9:55:00 in order to match to 
   trades occurring at 9:55:00. This way we match trades occurring at time T 
   to NBBO quotes outstanding at T+5). */
data MidQ (keep=symbol date type midpointnew InterpolatedTime 
     BestOfrnew BestBidnew);
    set QSpread1;
    midpointnew=midpoint;
    InterpolatedTime=InterpolatedTime-300;
    BestOfrnew=BestOfr;
    BestBidnew=BestBid;
run;

data MidT (keep=symbol date tradetime InterpolatedTime type midpoint price
     BuySellLR BuySellEMO BuySellCLNV wEffectiveSpread_Dollar size dollar);
    set BuySellIndicators;
run;

proc sort data=MidQ;
    by symbol date InterpolatedTime type;
run;

proc sort data=MidT;
    by symbol date InterpolatedTime type;
run;

/* Stack Trades at Time T with NBBO Quotes at Time T+5 */
data Mid1;
    set MidT MidQ;
    by symbol date InterpolatedTime type;
run;

/* For Each Trade at Time T, Identify the Outstanding NBBO at Time T+5 */
data Mid1;
    set Mid1;
    by symbol date;
    retain midpoint5 BestOfr5 BestBid5;
    if type='Q' then midpoint5=midpointnew;
    else midpoint5=midpoint5;
    if type='Q' then BestOfr5=BestOfrnew;else BestOfr5=BestOfr5;
    if type='Q' then BestBid5=BestBidnew;else BestBid5=BestBid5;
run;

/* Delete Trades at T Associated with Locked or Crossed Best Bids or Best 
   Offers at T+5 */
data Mid2 (drop=midpointnew BestOfrnew BestBidnew);
    set Mid1;
    if BestOfr5=BestBid5 or BestOfr5<BestBid5 then delete;
run;

/* Create Indicator Variable "D" equal to "1" if Trade is a Buy and "-1" if 
   Trade is a Sell for LR, EMO, and CLNV */
data Mid2; 
    set Mid2; 
    where type='T';

    /* Compute Dollar and Percent Realized Spread for LR, EMO, and CLNV */
    wDollarRealizedSpread_LR=BuySellLR*(price-midpoint5)*2;
    wDollarRealizedSpread_EMO=BuySellEMO*(price-midpoint5)*2;
    wDollarRealizedSpread_CLNV=BuySellCLNV*(price-midpoint5)*2;
    wPercentRealizedSpread_LR=BuySellLR*(log(price)-log(midpoint5))*2;
    wPercentRealizedSpread_EMO=BuySellEMO*(log(price)-log(midpoint5))*2;
    wPercentRealizedSpread_CLNV=BuySellCLNV*(log(price)-log(midpoint5))*2;

    /* Compute Dollar and Percent Price Impact for LR, EMO, and CLNV */
    wDollarPriceImpact_LR=BuySellLR*(midpoint5-midpoint)*2;
    wDollarPriceImpact_EMO=BuySellEMO*(midpoint5-midpoint)*2;
    wDollarPriceImpact_CLNV=BuySellCLNV*(midpoint5-midpoint)*2;
    wPercentPriceImpact_LR=BuySellLR*(log(midpoint5)-log(midpoint))*2;
    wPercentPriceImpact_EMO=BuySellEMO*(log(midpoint5)-log(midpoint))*2;
    wPercentPriceImpact_CLNV=BuySellCLNV*(log(midpoint5)-log(midpoint))*2;

    /* Multiply Realized Spreads and Price Impact by Dollar and Share Size of 
	   Trade for LR, EMO, and CLNV */
    wDollarRealizedSpread_LR_SW=wDollarRealizedSpread_LR*size;
    wDollarRealizedSpread_LR_DW=wDollarRealizedSpread_LR*dollar;
    wPercentRealizedSpread_LR_SW=wPercentRealizedSpread_LR*size;
    wPercentRealizedSpread_LR_DW=wPercentRealizedSpread_LR*dollar;
    wDollarPriceImpact_LR_SW=wDollarPriceImpact_LR*size;
    wDollarPriceImpact_LR_DW=wDollarPriceImpact_LR*dollar;
    wPercentPriceImpact_LR_SW=wPercentPriceImpact_LR*size;
    wPercentPriceImpact_LR_DW=wPercentPriceImpact_LR*dollar;
    wDollarRealizedSpread_EMO_SW=wDollarRealizedSpread_EMO*size;
    wDollarRealizedSpread_EMO_DW=wDollarRealizedSpread_EMO*dollar;
    wPercentRealizedSpread_EMO_SW=wPercentRealizedSpread_EMO*size;
    wPercentRealizedSpread_EMO_DW=wPercentRealizedSpread_EMO*dollar;
    wDollarPriceImpact_EMO_SW=wDollarPriceImpact_EMO*size;
    wDollarPriceImpact_EMO_DW=wDollarPriceImpact_EMO*dollar;
    wPercentPriceImpact_EMO_SW=wPercentPriceImpact_EMO*size;
    wPercentPriceImpact_EMO_DW=wPercentPriceImpact_EMO*dollar;
	wDollarRealizedSpread_CLNV_SW=wDollarRealizedSpread_CLNV*size;
    wDollarRealizedSpread_CLNV_DW=wDollarRealizedSpread_CLNV*dollar;
    wPercentRealizedSpread_CLNV_SW=wPercentRealizedSpread_CLNV*size;
    wPercentRealizedSpread_CLNV_DW=wPercentRealizedSpread_CLNV*dollar;
    wDollarPriceImpact_CLNV_SW=wDollarPriceImpact_CLNV*size;
    wDollarPriceImpact_CLNV_DW=wDollarPriceImpact_CLNV*dollar;
    wPercentPriceImpact_CLNV_SW=wPercentPriceImpact_CLNV*size;
    wPercentPriceImpact_CLNV_DW=wPercentPriceImpact_CLNV*dollar;
run;

/* Find average across firm-day */
proc sql; 
    create table RealizedSpreadsandPriceImpacts 
    as select symbol,date,
    sum(dollar) as sumdollar,
    sum(size) as sumsize,
    mean(wDollarRealizedSpread_LR) as DollarRealizedSpread_LR_Ave,
    mean(wDollarRealizedSpread_EMO) as DollarRealizedSpread_EMO_Ave,
    mean(wDollarRealizedSpread_CLNV) as DollarRealizedSpread_CLNV_Ave,
    mean(wPercentRealizedSpread_LR) as PercentRealizedSpread_LR_Ave,
    mean(wPercentRealizedSpread_EMO) as PercentRealizedSpread_EMO_Ave,
    mean(wPercentRealizedSpread_CLNV) as PercentRealizedSpread_CLNV_Ave,
    mean(wDollarPriceImpact_LR) as DollarPriceImpact_LR_Ave,
    mean(wDollarPriceImpact_EMO) as DollarPriceImpact_EMO_Ave,
    mean(wDollarPriceImpact_CLNV) as DollarPriceImpact_CLNV_Ave,
    mean(wPercentPriceImpact_LR) as PercentPriceImpact_LR_Ave,
    mean(wPercentPriceImpact_EMO) as PercentPriceImpact_EMO_Ave,
    mean(wPercentPriceImpact_CLNV) as PercentPriceImpact_CLNV_Ave,
	sum(wDollarRealizedSpread_LR_SW) as waDollarRealizedSpread_LR_SW,
    sum(wDollarRealizedSpread_LR_DW) as waDollarRealizedSpread_LR_DW,
    sum(wPercentRealizedSpread_LR_SW) as waPercentRealizedSpread_LR_SW,
    sum(wPercentRealizedSpread_LR_DW) as waPercentRealizedSpread_LR_DW,
    sum(wDollarPriceImpact_LR_SW) as waDollarPriceImpact_LR_SW,
    sum(wDollarPriceImpact_LR_DW) as waDollarPriceImpact_LR_DW,
    sum(wPercentPriceImpact_LR_SW) as waPercentPriceImpact_LR_SW,
    sum(wPercentPriceImpact_LR_DW) as waPercentPriceImpact_LR_DW, 
	sum(wDollarRealizedSpread_EMO_SW) as waDollarRealizedSpread_EMO_SW,
    sum(wDollarRealizedSpread_EMO_DW) as waDollarRealizedSpread_EMO_DW,
    sum(wPercentRealizedSpread_EMO_SW) as waPercentRealizedSpread_EMO_SW,
    sum(wPercentRealizedSpread_EMO_DW) as waPercentRealizedSpread_EMO_DW,
    sum(wDollarPriceImpact_EMO_SW) as waDollarPriceImpact_EMO_SW,
    sum(wDollarPriceImpact_EMO_DW) as waDollarPriceImpact_EMO_DW,
    sum(wPercentPriceImpact_EMO_SW) as waPercentPriceImpact_EMO_SW,
    sum(wPercentPriceImpact_EMO_DW) as waPercentPriceImpact_EMO_DW, 
	sum(wDollarRealizedSpread_CLNV_SW) as waDollarRealizedSpread_CLNV_SW,
    sum(wDollarRealizedSpread_CLNV_DW) as waDollarRealizedSpread_CLNV_DW,
    sum(wPercentRealizedSpread_CLNV_SW) as waPercentRealizedSpread_CLNV_SW,
    sum(wPercentRealizedSpread_CLNV_DW) as waPercentRealizedSpread_CLNV_DW,
    sum(wDollarPriceImpact_CLNV_SW) as waDollarPriceImpact_CLNV_SW,
    sum(wDollarPriceImpact_CLNV_DW) as waDollarPriceImpact_CLNV_DW,
    sum(wPercentPriceImpact_CLNV_SW) as waPercentPriceImpact_CLNV_SW,
    sum(wPercentPriceImpact_CLNV_DW) as waPercentPriceImpact_CLNV_DW 
	from Mid2 
    group by symbol,date 
    order by symbol,date; 
quit;

/* Calculate Dollar-Weighted (DW) and Share-Weighted (SW) Realized Spreads 
   and Price Impact */
data RealizedSpreadsandPriceImpacts;
    set RealizedSpreadsandPriceImpacts;
    DollarRealizedSpread_LR_SW=waDollarRealizedSpread_LR_SW/sumsize;
    DollarRealizedSpread_LR_DW=waDollarRealizedSpread_LR_DW/sumdollar;
    PercentRealizedSpread_LR_SW=waPercentRealizedSpread_LR_SW/sumsize;
    PercentRealizedSpread_LR_DW=waPercentRealizedSpread_LR_DW/sumdollar;
    DollarPriceImpact_LR_SW=waDollarPriceImpact_LR_SW/sumsize;
    DollarPriceImpact_LR_DW=waDollarPriceImpact_LR_DW/sumdollar;
    PercentPriceImpact_LR_SW=waPercentPriceImpact_LR_SW/sumsize;
    PercentPriceImpact_LR_DW=waPercentPriceImpact_LR_DW/sumdollar;
    DollarRealizedSpread_EMO_SW=waDollarRealizedSpread_EMO_SW/sumsize;
    DollarRealizedSpread_EMO_DW=waDollarRealizedSpread_EMO_DW/sumdollar;
    PercentRealizedSpread_EMO_SW=waPercentRealizedSpread_EMO_SW/sumsize;
    PercentRealizedSpread_EMO_DW=waPercentRealizedSpread_EMO_DW/sumdollar;
    DollarPriceImpact_EMO_SW=waDollarPriceImpact_EMO_SW/sumsize;
    DollarPriceImpact_EMO_DW=waDollarPriceImpact_EMO_DW/sumdollar;
    PercentPriceImpact_EMO_SW=waPercentPriceImpact_EMO_SW/sumsize;
    PercentPriceImpact_EMO_DW=waPercentPriceImpact_EMO_DW/sumdollar;
	DollarRealizedSpread_CLNV_SW=waDollarRealizedSpread_CLNV_SW/sumsize;
    DollarRealizedSpread_CLNV_DW=waDollarRealizedSpread_CLNV_DW/sumdollar;
    PercentRealizedSpread_CLNV_SW=waPercentRealizedSpread_CLNV_SW/sumsize;
    PercentRealizedSpread_CLNV_DW=waPercentRealizedSpread_CLNV_DW/sumdollar;
    DollarPriceImpact_CLNV_SW=waDollarPriceImpact_CLNV_SW/sumsize;
    DollarPriceImpact_CLNV_DW=waDollarPriceImpact_CLNV_DW/sumdollar;
    PercentPriceImpact_CLNV_SW=waPercentPriceImpact_CLNV_SW/sumsize;
    PercentPriceImpact_CLNV_DW=waPercentPriceImpact_CLNV_DW/sumdollar;
	drop waDollarRealizedSpread_LR_SW waDollarRealizedSpread_LR_DW
	     waPercentRealizedSpread_LR_SW waPercentRealizedSpread_LR_DW
		 waDollarPriceImpact_LR_SW waDollarPriceImpact_LR_DW
         waPercentPriceImpact_LR_SW waPercentPriceImpact_LR_DW
         waDollarRealizedSpread_EMO_SW waDollarRealizedSpread_EMO_DW
	     waPercentRealizedSpread_EMO_SW waPercentRealizedSpread_EMO_DW
		 waDollarPriceImpact_EMO_SW waDollarPriceImpact_EMO_DW
         waPercentPriceImpact_EMO_SW waPercentPriceImpact_EMO_DW
	     waDollarRealizedSpread_CLNV_SW waDollarRealizedSpread_CLNV_DW
	     waPercentRealizedSpread_CLNV_SW waPercentRealizedSpread_CLNV_DW
		 waDollarPriceImpact_CLNV_SW waDollarPriceImpact_CLNV_DW
         waPercentPriceImpact_CLNV_SW waPercentPriceImpact_CLNV_DW;
run;

/* STEP 11: DOWNLOAD THE FILES YOU WANT TO YOUR PROJECT FOLDER 

   By default, only the last three output files are downloaded to the 
   "project" folder. You can download all eight of the files by 
   removing the "comment outs" in the statements below */

/*data project.MonthlyQuote;set MonthlyQuote;run;*/

/*data project.MonthlyTrade;set MonthlyTrade;run;*/

/*data project.CompleteNBBO;set CompleteNBBO;run; */

/*data project.TradesandCorrespondingNBBO;
  set TradesandCorrespondingNBBO;run;*/

/*data project.BuySellIndicators;set BuySellIndicators;run; */

data project.QuotedSpreadsandDepths;set QuotedSpreadsandDepths;run;

data project.EffectiveSpreads;set EffectiveSpreads;run;

data project.RealizedSpreadsandPriceImpacts;
set RealizedSpreadsandPriceImpacts;run;



