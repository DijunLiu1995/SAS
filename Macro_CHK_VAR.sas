%macro chkvars(chkData,chkVarNames,chkDataType);

  %local chkvars;
  %local hasVar;
  %local dsid;
  %local varnum; 
  %local varCnt;
  %local chkVarName;
  %local vartype;
  %local chektype;
  %local chki;

  %* Double check to ensure the data type value is captured correctly;

  %let chektype = %upcase (%substr (&chkDataType, 1, 1));

  %* Initialize the hasvar local variable to 0;

  %let hasVar = 0;

  %* Attempt to open the dataset specified by chkData;

  %let dsid = %sysfunc (open (&chkData));

  %* If dsid is true (success) then check for the variable;

  %if &dsid %then %do;

       %* Determine the count of variables supplied to the macro;

       %let varCnt = %eval(%sysfunc(countc(&chkVarNames.,' '))+1); /* Count of variables in varChkNames list */
   %let hasvar=0;
                   %end;
                   %else %do;
                       %put WARNING: The variable (&curChkName.) was not found in the dataset (&chkData.);  
                       %let hasvar=1;
                       %goto finish_chkErr;
                   %end;
               %end;
                %else %do;
                       %put WARNING: The variable (&curChkName.) was not found in the dataset (&chkData.);  
                       %let hasvar=1;
                       %goto finish_chkErr;
                %end; 

           %end;

           %* Close the dataset;

         %let dsid = %sysfunc (close (&dsid));

  %end;
  %finish_chkErr:

  %* Set the return value chkVars to the value of hasVar;

  %let chkvars = &hasVar;

  %* Check the value of chkVars and set the _errorflag to YES if the variable was not found;

  %if %substr(&chkvars.,1,1)=0 %then %do;

     %put NOTE: %eval(&chki. - 1) total variables were found successfully in the target dataset (&chkData.);

  %end;
  %else %do;

     %put WARNING: At least one variable was not found and execution has passed back to the calling program; 

  %end;

  %* Return the value of chkVars as if the chkVars macro was a function;

  %exit: &chkVars
%mend chkvars;
