*****************************************************
* Candidate Name: Nikhil Kumar			    *
* Date: 7/12/2020				    *
* Stata Version Used: Stata 16 SE					*
*****************************************************

/*
Using microdata from the basic monthly Current Population Survey (CPS), I calculate the following statistics for the civilian noninstitutionalized population age (16+):
Employment to Population Ratio, Labor Force Participation Rate, and Unemployment rate for each of the first seven months of 2020.
*/

clear all

* How can you run this file?
* Just change the path of the working folder in the next line
global projdir "C:\Users\nikhi\Downloads\Stata"

* raw data folder
global raw "$projdir\Raw Data"

* folder where clean data is saved
global final "$projdir\Clean Data"

* folder where ouptut graphs and tables are saved
global output "$projdir\Output"

cd "$raw\cps_data\data"

* global macro for all months
global month feb mar apr may jun jul

* first, I append all the monthly data into one file
use jan20 
tempfile mydata
save `mydata'
foreach mon of global month{
	use `mydata', clear
	append using `mon'20
	save `mydata', replace	
}

* Find the relevant labels from BLS codebook

label define pemlr1 1	"EMPLOYED-AT WORK" ///
					2	"EMPLOYED-ABSENT" ///
					3	"UNEMPLOYED-ON LAYOFF" ///
					4	"UNEMPLOYED-LOOKING" ///
					5	"NOT IN LABOR FORCE-RETIRED" ///
					6	"NOT IN LABOR FORCE-DISABLED" ///
					7	"NOT IN LABOR FORCE-OTHER" 
					
label define prpertyp1 	1	"CHILD HOUSEHOLD MEMBER" ///
						2	"ADULT CIVILIAN HOUSEHOLD MEMBER" ///
						3	"ADULT ARMED FORCES HOUSEHOLD MEMBER"

label define prtage1	80		"80-84 Years Old" ///
						85		"85+ Years Old"
						
label values pemlr pemlr1 
label values prpertyp prpertyp1 
label values prtage prtage1

save "$final\data_append", replace

* restrict the dataset to civilian noninstitutionalized population age (16+):
drop if prtage < 16 //drop observations with age < 16
drop if prpertyp == 3 // drop military observations

* encoding month doesn't assign the numbers to months in the intuitive order
* So,m generate a numeric variable for each month in the correct order
gen mon = 4 if month == "apr" 
replace mon = 2 if month == "feb" 
replace mon = 1 if month == "jan" 
replace mon = 7 if month == "jul" 
replace mon = 6 if month == "jun" 
replace mon = 3 if month == "mar" 
replace mon = 5 if month == "may"

* generate labels for the month variable
label define m 4 "apr" 2 "feb" 1 "jan" 7 "jul" 6 "jun" 3 "mar" 5 "may"
label values mon m

gen emp = pemlr <= 2 // dummy for whether employed or not
gen in_labfor = pemlr < = 4 // dummy for whether participating in labor force or not

* find the total population for each month
preserve 
collapse (sum) pwcmpwgt, by(mon)
rename pwcmpwgt population 
save "$final/mon_pop", replace
restore

* find the total employment for each month
preserve 
collapse (sum) pwcmpwgt, by(mon emp)
reshape wide pwcmpwgt, i(mon) j(emp)
rename pwcmpwgt1 employed
keep employed mon
save "$final/mon_emp", replace
restore

* find the total number of people participating in labor market for each month
preserve 
collapse (sum) pwcmpwgt, by(mon in_labfor)
reshape wide pwcmpwgt, i(mon) j(in_labfor)
rename pwcmpwgt1 part
keep part mon
save "$final/mon_part", replace
restore

* merge the above three monthly statistics and generate the required 3 estimates 
use "$final/mon_pop", replace
merge 1:1 mon using "$final/mon_emp"
drop _merge
merge 1:1 mon using "$final/mon_part" 
drop _merge

gen epop = (employed/population)*100 // employment to population ratio
format epop %9.1f
label var epop "employment to population ratio"

gen lfpr = (part/population)*100 // labor force participation rate
format lfpr %9.1f
label var lfpr "labor force participation rate"

gen unemp = 100 - 100*(employed/part) // unemployment rate
format unemp %9.1f
label var unemp "unemployment rate"

* My estimates match the not seasonally adjusted Bureau of Labor Statistics (BLS) estimates exactly

drop population employed part // drop irrelevant variables

save "$output/task2_summary", replace

* import seasonally adjusted estimates from BLS and mereg with this data
clear 
import excel "$raw\Seasonally Adjusted Rates BLS.xlsx", sheet("Sheet1") firstrow
merge 1:1 mon using "$output/task2_summary"
drop _merge

label var epop_s "employment to population ratio - seasonally adjusted"
label var lfpr_s "labor force participation rate - seasonally adjusted"
label var unemp_s "unemployment rate - seasonally adjusted"

save "$output/task2_summary", replace

line epop epop_s mon, xla(1 "Jan" 2 "Feb" 3 "Mar" 4 "Apr" 5 "May" 6 "Jun" 7 "Jul") ytitle(" ") xtitle(" ") ylabel(,format(%9.0f)) title("Civilian Employment to Population Ratio (2020)") note("BLS and author's calculation using Current Population Survey (CPS)'" "SA = Seasonally Adjusted" "NSA = Not Seasonally Adjusted") legend(label(1 "NSA") label(2 "SA"))
graph export "$output/task2_epop.png", replace

line lfpr lfpr_s mon, xla(1 "Jan" 2 "Feb" 3 "Mar" 4 "Apr" 5 "May" 6 "Jun" 7 "Jul")  ytitle(" ") xtitle(" ") ylabel(,format(%9.0f)) title("Civilian Labor Force Participation Rate (2020)") note("BLS and author's calculation using Current Population Survey (CPS)'" "SA = Seasonally Adjusted" "NSA = Not Seasonally Adjusted") legend(label(1 "NSA") label(2 "SA"))
graph export "$output/task2_lfpr.png", replace

line unemp unemp_s mon, xla(1 "Jan" 2 "Feb" 3 "Mar" 4 "Apr" 5 "May" 6 "Jun" 7 "Jul") ytitle(" ") xtitle(" ") ylabel(,format(%9.0f)) title("Civilian Unemployment Rate (2020)") note("BLS and author's calculation using Current Population Survey (CPS)'" "SA = Seasonally Adjusted" "NSA = Not Seasonally Adjusted") legend(label(1 "NSA") label(2 "SA"))
graph export "$output/task2_unemp.png", replace
