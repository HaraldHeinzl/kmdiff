*************************************************************;
**           SAS Macro KMDIFF                              **;
**           ================                              **;
**                                                         **;
**  Purpose  ... To visualize quantile survival time       **;
**               differences                               **;
**  Author   ... Harald Heinzl                             **;
**  Version  ... 2.42                                      **;
**  Date     ... 2017-July-19                              **;
*************************************************************;
**           Macro parameters                              **;
**           ================                              **;
**                                                         **;
**  data     ... input SAS data set (data set name         **;
**               must not start with two underscores,      **;
**               data set must not contain variables       **;
**               named __g, __t and __status)              **;
**  time     ... survival time variable                    **;
**  timeunit ... survival time units (default: years)      **;
**  status   ... survival status variable                  **;
**  censval  ... censoring status value(s) (default: 0)    **;
**  group    ... covariate (group variable)                **;
**  gvalue1  ... numerical value of first group            **;
**  gvalue2  ... numerical value of second group           **;
**  grouplbl ... label of group variable                   **;
**  gvallbl1 ... label of first group value                **;
**  gvallbl2 ... label of second group value               **;
**  alpha    ... 100-alpha per cent is the pointwise       **;
**               two-sided confidence level, 0<alpha<100   **;
**               (default: alpha=5)                        **;
**  boot     ... number of bootstrap replications for      **;
**               confidence bands                          **;
**               (default: 2000, minimum: 100)             **;
**  bundle   ... number of bootstrap replications shown    **;
**               in figures (default: 200)                 **;
**  seedval  ... seed value of random number generator     **;
**               for bootstrap replications (default: 0)   **;
*************************************************************;
**  Copyright 2017 Harald Heinzl (harald.heinzl@muv.ac.at) **;
**  This program is free software: you can redistribute it **;
**  and/or modify it under the terms of the GNU General    **;
**  Public License as published by the Free Software       **;
**  Foundation, either version 3 of the License, or (at    **;
**  your option) any later version.                        **;
**  This program is distributed in the hope that it will   **;
**  be useful, but WITHOUT ANY WARRANTY, without even the  **;
**  implied warranty of MERCHANTABILITY or FITNESS FOR A   **;
**  PARTICULAR PURPOSE. See the GNU General Public License **;
**  for more details.                                      **;
**  You should have received a copy of the GNU General     **;
**  Public License along with this program. If not, see    **;
**  <http://www.gnu.org/licenses/>.                        **;
*************************************************************;
**  In order to customize the figures produced by the      **;
**  macro, scroll down to "Begin of graphical output".     **;
*************************************************************;



%macro kmdiff(data=, time=, timeunit=years, status=, censval=0, group=, gvalue1=, gvalue2=, 
 grouplbl=, gvallbl1=, gvallbl2=, alpha=5, boot=2000, bundle=200, seedval=0) / minoperator;

%if %length(&data)>1 %then %do;
  %if %substr(&data,1,2) EQ __ %then %do;
    %put;
    %put %str(The name of the input data set must not start with two underscores);
    %put %str(################  The macro has therefore stopped  ################);
    %put;
    %goto exit;      
  %end;
%end;

%if  %upcase(&group)  in (__G __T __STATUS) 
  or %upcase(&time)   in (__G __T __STATUS) 
  or %upcase(&status) in (__G __T __STATUS) %then %do;
  %put;
  %put %str(The variable names __g, __t and __status are reserved for internal purposes);
  %put %str(and cannot be used in the group, time or status statement                  );
  %put %str(####################  The macro has therefore stopped  ####################);
  %put;
  %goto exit;      
%end;

%if %eval(%sysfunc(verify(&gvalue1,-0123456789.))) 
 or %eval(%sysfunc(verify(&gvalue2,-0123456789.))) 
%then %do;
  %put;
  %put %str(At least one of the values specified in gvalue1 and gvalue2 is not numeric);
  %put %str(####################  The macro has therefore stopped  ####################);
  %put;
  %goto exit;      
%end;

%if &grouplbl EQ %then %let grouplbl=&group; 
%if &gvallbl1 EQ %then %let gvallbl1=&gvalue1; 
%if &gvallbl2 EQ %then %let gvallbl2=&gvalue2; 

%if %eval(not %sysfunc(verify(&alpha,-0123456789.))) %then %do;
  %if %sysevalf(&alpha<=0)   %then %do; 
    %let alpha=5; 
    %put;
    %put %str(## Condition alpha>0 is not fulfilled);
    %put %str(## alpha is therefore set to a value of 5);
    %put;
  %end;
  %if %sysevalf(&alpha>=100) %then %do; 
    %let alpha=5; 
    %put;
    %put %str(## Condition alpha<100 is not fulfilled);
    %put %str(## alpha is therefore set to a value of 5);
    %put;
  %end;
%end;
%else %do;
  %let alpha=5;
  %put;
  %put %str(## The value specified in alpha is not numeric);
  %put %str(## alpha is therefore set to a value of 5);
  %put;
%end;

%if %eval(not %sysfunc(verify(&boot,-0123456789))) %then %do;
  %if &boot<100 %then %do;
    %let boot=100;
    %put;
    %put %str(## Condition boot>=100 is not fulfilled);
    %put %str(## boot is therefore set to a value of 100);
    %put;
  %end;
%end;
%else %do;
  %let boot=2000;
  %put;
  %put %str(## The value specified in boot is not an integer);
  %put %str(## boot is therefore set to a value of 2000);
  %put;
%end;

%if %eval(not %sysfunc(verify(&bundle,0123456789))) %then %do;
  %if &bundle>&boot %then %do;
    %let bundle=&boot;
    %put;
    %put %str(## Condition bundle<=boot is not fulfilled);
    %put %str(## bundle is therefore set to a value of &boot);
    %put;
  %end;
%end;
%else %do;
  %let bundle=0;
  %put;
  %put %str(## The value specified in bundle is not a non-negative integer);
  %put %str(## bundle is therefore set to a value of 0);
  %put;
%end;

option nonotes;
ods graphics on / groupmax=%eval(&bundle+10);

data __original;
set &data;
keep __g __t __status;
__g=&group;
__t=&time;
__status=&status;
if __g in (&gvalue1, &gvalue2);
if __t>.z;
if __status>.z;
run; 

proc sort data=__original;
by __g;
run;

proc surveyselect data=__original  out=__abc(keep=__g __t __status replicate)
     seed=&seedval method=urs samprate=1 rep=&boot outhits noprint;
     strata __g;
run;

data __original;
set __original;
replicate=0;
run;

data __abc;
set __original __abc;
run;

proc sort data=__abc;
by replicate;
run;

proc lifetest data=__abc notable outsurv=__out noprint plots=none;
  time __t*__status(&censval);
  strata __g;
  by replicate;
run;

data __out;
set __out;
survival=round(survival,0.000000000001);
run;

data __out1(keep=__t survival replicate) __out2(keep=__t survival replicate) __h(keep=survival replicate);
set __out;
if __g=&gvalue1 and _censor_<1 then output __out1 __h;
if __g=&gvalue2 and _censor_<1 then output __out2 __h;
run;

data __out1;
set __out1;
rename __t=t1;
run;

data __out2;
set __out2;
rename __t=t2;
run;

proc sort data=__h;
by replicate descending survival;
run;

data __erg;
merge __out1 __out2 __h;
by  replicate descending survival;
run;

data __erg;
set __erg;
by replicate;
s2=lag(survival);
if first.replicate then s2=.; 
run;

proc sort data=__erg;
by  replicate survival s2;
run;

data __erg;
set __erg;
by replicate;
retain h1 h2;
drop h1 h2;
if first.replicate then do;
  h1=.;
  h2=.;
end;
if t1=. then t1=h1;
        else h1=t1;
if t2=. then t2=h2;
        else h2=t2;
run;

data __erg;
set __erg;
rename survival=s1;
if t2=0 and s2=. then delete;
if t1=. or  t2=. then delete;
run;

data __erg;
set __erg;
keep survival time_difference replicate;
time_difference=t2-t1;
survival=s1; output;
survival=s2; output;
run;
 
*** Duplicates are removed ***;

data __erg;
set __erg;
drop h:;
retain hrep hdiff hsurv;
if hrep=replicate and hdiff=time_difference and hsurv=survival then delete;
else do;
  hrep=replicate; 
  hdiff=time_difference;
  hsurv=survival;
end;
run;

*******************************;
*** Begin of CI-computation ***;
*******************************;

data __erg10;
set __erg;
if replicate>0;
run;

data __erg20;
set __erg;
drop replicate;
rename i=replicate;
rename time_difference=time_diff_original;
if replicate=0 then do i=1 to &boot;
  output;
end;
run;

proc sort data=__erg20;
by replicate survival;
run;

data __neu;
merge __erg10 __erg20;
by replicate survival;
run;

data __neu;
set __neu;
by replicate;
retain h;
drop h;
if first.replicate then h=.;
if time_difference=. then time_difference=h;
                     else h=time_difference;
run;

data __neu;
set __neu;
if time_diff_original=. then delete;
run;

proc means data=__neu noprint;
var time_difference;
output out=__max min=min max=max;
run;

data __max;
set __max;
drop _:;
max=ceil(max);
min=floor(min);
call symput('max',max);
call symput('min',min);
run;

data __neu;
set __neu;
if time_difference=. then do;
   time_difference=&min-(&max-&min+1)*10; weight=0.5; output;
   time_difference=&max+(&max-&min+1)*10; weight=0.5; output;
end;
   else do; weight=1; output; 
end;
run;

proc univariate data=__neu noprint;
class survival(order=data) time_diff_original(order=data);
var time_difference;
output out=__percentiles pctlpts=%sysevalf(&alpha/2) %sysevalf(100-(&alpha/2)) pctlpre=p_ pctlname=unten oben;
weight weight;
run;

data __percentiles;
set __percentiles;
if p_unten <&min then p_unten =.;
if p_oben  >&max then p_oben  =.;
run;

data __perc_u (keep=replicate survival time_difference p_oben) 
     __perc_o (keep=replicate survival time_difference);
set __percentiles;
replicate=-1; time_difference=p_unten; output __perc_u;
replicate=-2; time_difference=p_oben;  output __perc_o;
run;

************************************;
*** End of CI-computation        ***;
************************************;
*** Begin of graphical output    ***;
*** (customize figures here)     ***;
**********************************************************************; 
*** The main variables in the data set __erg are survival          ***;
*** (survival probability), time_difference (quantile difference), ***;
*** and replicate whose values mean the following:                 ***;
***       -2 ... upper confidence band                             ***;
***       -1 ... lower confidence band                             ***;
***        0 ... quantile difference                               ***;
***   1-boot ... bootstrap replications of quantile difference     ***;
*** 1-bundle ... bootstrap replications shown in figures           ***;
*** All other variables are ancillary variables required in SGPLOT ***;
**********************************************************************;  

data __erg;
set __perc_o __perc_u __erg;
label time_difference="Time difference in &timeunit (&grouplbl=&gvallbl2 minus &grouplbl=&gvallbl1)";  
label survival="Survival probability";
if time_difference=0 and survival=1 then delete;
if replicate<=&bundle; ** Remaining replicates are not shown in figures **;
if replicate>0  then rep_bundle=replicate;
if replicate=0  then rep_diff=replicate;
if replicate<0  then rep_conf=replicate;
if replicate=-1 then rep_band=replicate;
run;

title;

proc format;
value __gfmt &gvalue1="&gvallbl1" &gvalue2="&gvallbl2";
run; 

proc lifetest data=__original notable noprint;
  time __t*__status(&censval);
  strata __g;
  *****************************;
  label __t="Time in &timeunit";
  label __g=&grouplbl;
  format __g __gfmt.;
run;

title "Quantile survival time differences";

%if &bundle>0 %then %do; 
title2 "Bootstrap bundle";
proc sgplot data=__erg noautolegend;
  series x=time_difference y=survival / group=rep_bundle nomissinggroup lineattrs=(pattern=solid color=greydd thickness=1);
  series x=time_difference y=survival / group=rep_diff nomissinggroup lineattrs=(pattern=solid color=green  thickness=2);
  refline 0 / axis=x;
run;
%end;

title2 "Pointwise %sysevalf(100-&alpha)% confidence band";
proc sgplot data=__erg noautolegend;
  band lower=time_difference upper=p_oben y=survival / group=rep_band nomissinggroup fillattrs=(color=green transparency=0.8) type=step;
  series x=time_difference y=survival / group=rep_diff nomissinggroup lineattrs=(pattern=solid color=green  thickness=2);
  refline 0 / axis=x;
run;

%if &bundle>0 %then %do; 
title2 "Bootstrap bundle and pointwise %sysevalf(100-&alpha)% confidence band";
proc sgplot data=__erg noautolegend;
  series x=time_difference y=survival / group=rep_bundle nomissinggroup lineattrs=(pattern=solid color=greydd thickness=1);
  step x=time_difference y=survival / group=rep_conf nomissinggroup lineattrs=(pattern=solid color=black  thickness=2);
  series x=time_difference y=survival / group=rep_diff nomissinggroup lineattrs=(pattern=solid color=green  thickness=2);
  refline 0 / axis=x;
run;
%end;

ods graphics off;
title; 
option notes;
run;

*** End of graphical output ***;

%exit:
%mend kmdiff;
***********************************************************;
** End of SAS-Macro KMDIFF                               **;
***********************************************************;
