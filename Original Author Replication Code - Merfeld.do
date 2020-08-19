*Anderson et al (2017) - Relating Seasonal Hunger and and Prevention and Coping Strategies: A Panel Analysis of Malawian Farm Households
*Data Cleaning and Analysis Do-File
*********************************
*** Directories and Paths     ***
*********************************
clear
clear matrix
clear mata
drop _all
program drop _all
graph drop _all
set more off
set trace off
set mem 120m
set maxvar 15000
set matsize 11000


*Replace path name in quotation marks with location of Malawi data folder(s)
global malawi_data	"PUT DATA PATH HERE"

*These are the names of the folders when directly downloaded from World Bank LSMS page:
global MW_1	"$malawi_data/2010-11 data - updated"
global MW_2	"$malawi_data/2013 data"

****************************************************************************************************************

************************
************************
******            ******
******   WAVE 1   ******
******            ******
************************
************************

*Community (for distance variables)
use "$MW_1/Community/COM_CD.dta", clear
gen dist_dmarket = com_cd16a if com_cd16b==2				// kilometers is 2
replace dist_dmarket = com_cd16a*1.6 if com_cd16b==3		// miles is 3
replace dist_dmarket = com_cd16a/1000 if com_cd16b==1		// meters is 1
replace dist_dmarket = 0 if com_cd15==1						// equals zero if there is a market in the community
keep ea_id dist_*
tempfile mw1_comm
save `mw1_comm', replace


use "$MW_2/Household/HH_MOD_A_FILT.dta", clear
duplicates drop ea_id, force
keep ea_id region
tempfile merge
save `merge', replace


*Rainfall
use "$MW_1/Geovariables/HouseholdGeovariables_IHS3_Rerelease.dta", clear
ren case_id hhid
gen rain_ratio2009 = (h2009_tot-anntot_avg)/anntot_avg									// percent deviation
gen rain_ratio2010 = (h2010_tot-anntot_avg)/anntot_avg
keep hhid rain_ratio*
tempfile mw1_rain
save `mw1_rain', replace


*Basics (to merge with wave 1)
use "$MW_1/Household/HH_MOD_A_FILT.dta", clear
merge m:1 ea_id using `merge', nogen
ren case_id hhid
ren hh_a01 district
gen ta = hh_a02b
gen rural = reside==2
gen weight = hh_wgt
gen psu = ea_id

gen month1 = hh_a23b_1
gen month2 = hh_a23b_2
gen year1 = hh_a23c_1
gen year2 = hh_a23c_2

gen month = month1 if qx_type=="Panel A"												// Correct interview date is different for different waves
gen year = year1 if qx_type=="Panel A"
replace month = month2 if qx_type=="Panel B"
replace year = year2 if qx_type=="Panel B"

gen ym_int = ym(year,month)																// Month in Stata format
format ym_int %tm
gen wave=1
keep hhid hhid district weight ta rural stratum psu ea_id ym_int region wave month
merge 1:1 hhid using `mw1_rain'
tempfile mw1_merge
save `mw1_merge', replace


*Household demographics
use "$MW_1/Household/HH_MOD_B.dta", clear
merge 1:1 case_id PID using "$MW_1/Household/HH_MOD_C.dta", nogen assert(3)				// Merging for education
ren case_id hhid
gen personid = hh_b01
gen wave1_pid = hh_b01
gen male = hh_b03==1
gen relationship = hh_b04
gen age = hh_b05a
gen educ = hh_c08

preserve
	keep hhid personid male relationship age wave1_pid educ
	tempfile mw1_inddemog
	save `mw1_inddemog', replace														// Individual level
restore

gen hhsize = 1
gen elderly = age>=60 & age!=.
gen children = age<15
gen age_head = age if relationship==1
gen male_head = male if relationship==1
gen adult_male = male==1 & age>=15 & age!=.
gen adult_female = male==0 & age>=15 & age!=.
gen educ_head = educ if relationship==1 			// Assuming Training College follows Form 6 and is equivalent to University 1, 2, 3, 4
replace educ_head = 15 if educ_head == 20			 //TC year 1
replace educ_head = 16 if educ_head == 21			 //TC year 2
replace educ_head = 17 if educ_head == 22			 //TC year 3
replace educ_head = 18 if educ_head == 23			 //TC year 4
collapse (sum) hhsize elderly children adult_male adult_female (max) age_head male_head educ_head, by(hhid)
tempfile mw1_hhdemog
save `mw1_hhdemog', replace


*Labor variables
use "$MW_1/Household/HH_MOD_E.dta", clear
ren case_id hhid
gen any_wage = hh_e18==1 | hh_e55==1
collapse (sum) wage_count = any_wage (max) any_wage, by(hhid)							// Any wages variable
tempfile mw1_labor
save `mw1_labor', replace


*Identifying whether households have non-farm enterprises
use "$MW_1/Household/HH_MOD_N2.dta", clear
merge m:1 case_id using "$MW_1/Household/HH_MOD_N1.dta", nogen
ren case_id hhid
gen ent_count = 1
replace ent_count = 0 if hh_n0b==2														// = 0 if household did NOT operate one
gen ent_sales = hh_n32
replace ent_sales = 0 if hh_n0b==2														// = 0 if household did NOT operate one
collapse (sum) ent_count ent_sales, by(hhid)
gen nfe_any = ent_count>0 & ent_count!=.
tempfile mw1_nfe
save `mw1_nfe', replace


*Sales of Crops
use "$MW_1/Agriculture/AG_MOD_I.dta", clear
ren case_id hhid
gen sales_dum = ag_i01==1
gen sales_value = ag_i03																// "9999999" is assumed to be top-coded, not a missing value
gen stored_annual = ag_i38==1	
collapse (sum) sales_count = sales_dum sales_value (max) sales_dum stored_annual, by(hhid)
tempfile mw1_sales
save `mw1_sales', replace


*Sales of Crops - PERMANENT
use "$MW_1/Agriculture/AG_MOD_Q.dta", clear
ren case_id hhid
gen sales_dum_perm = ag_q01==1
gen sales_value_perm = ag_q03															// "9999999" is assumed to be top-coded, not a missing value
gen stored_perm = ag_q37==1
collapse (sum) sales_count_perm = sales_dum_perm sales_value_perm (max) sales_dum_perm stored_perm, by(hhid)
tempfile mw1_sales_perm
save `mw1_sales_perm', replace


*PREVIOUS rainy season (2008/2009 for wave 1)
use "$MW_1/Agriculture/AG_MOD_B.dta", clear
ren case_id hhid
gen ag2008 = ag_b0a==1																	// Those that actually planted crops in 2008/2009 = 1
gen acres = ag_b01a if ag_b01b==1
replace acres = ag_b01a/0.404686 if ag_b01b==2

*Creating a crop variable list (counting different types of same crop -- e.g. OPV maize, hybrid maize -- as same crop)
*We do not include cash crops here (crops that cannot be consumed, e.g. tobacco, cotton, and paprika)
gen new_crop = 1 if inlist(ag_b0c,1,2,3,4)						// Maize
replace new_crop = 3 if inlist(ag_b0c,11,12,13,14,15,16)		// Groundnut
replace new_crop = 4 if inlist(ag_b0c,17,18,19,20,21,23,25,26)	// Rice
replace new_crop = 5 if inlist(ag_b0c,27)						// Ground bean
replace new_crop = 6 if inlist(ag_b0c,28)						// Sweet potato
replace new_crop = 7 if inlist(ag_b0c,29)						// Irish potato
replace new_crop = 8 if inlist(ag_b0c,30)						// Wheat
replace new_crop = 9 if inlist(ag_b0c,31,33)					// Millet
replace new_crop = 10 if inlist(ag_b0c,32)						// Sorghum (note that this is counted separately from millet)
replace new_crop = 11 if inlist(ag_b0c,34)						// Beans
replace new_crop = 12 if inlist(ag_b0c,35)						// Soyabeans
replace new_crop = 13 if inlist(ag_b0c,36)						// Pigeonpeas
replace new_crop = 15 if inlist(ag_b0c,38)						// Sunflower
replace new_crop = 16 if inlist(ag_b0c,39)						// Sugarcane
replace new_crop = 17 if inlist(ag_b0c,41)						// Tanaposi
replace new_crop = 18 if inlist(ag_b0c,42)						// Nkhwani
replace new_crop = 19 if inlist(ag_b0c,43)						// Okra
replace new_crop = 20 if inlist(ag_b0c,44)						// Tomato
replace new_crop = 21 if inlist(ag_b0c,45)						// Onion
replace new_crop = 22 if inlist(ag_b0c,46)						// Pea
replace new_crop = 24 if inlist(ag_b0c,48)						// Other

gen maize = inlist(ag_b0c,1,2,3,4)
tab new_crop, gen(crop)		// Generating a set of dummy variables for each crop (new)
foreach i of varlist crop*{
gen `i'_acres = `i'*acres
}
egen crop_count_previous = tag(hhid new_crop)

*Now generating harvest date
gen year_start = 2009		// This is true for first wave
gen year_end = 2009
gen month_start = ag_b05a
gen month_end = ag_b05b
gen ym_harv_prev = ym(year_start,month_start)
gen ym_harv_prev_end = ym(year_end,month_end)
gen ym_maize_prev = month_start if maize==1
gen ym_maize_prev_end = month_end if maize==1
format ym_harv_* %tm											// Stata time format

*Collapse to household level
collapse (firstnm) ag2008 (sum) crop*acres acres crop_count_previous (min) ym_*_prev month_start* (max) month_end* ym_*_end, by(hhid)
foreach i of varlist crop*acres{
gen `i'_herf = (`i'/acres)^2
}

egen herf_previous = rowtotal(*_herf)
gen log_acres = ln(acres)
ren month_start month_start_prev
ren ym_maize_prev month_start_maize_prev
ren month_end month_end_prev
ren ym_maize_prev_end month_end_maize_prev
keep hhid herf_previous ym_* crop_count_ ag2008 month_*
tempfile mw1_herf_prev
save `mw1_herf_prev', replace


*THIS PART USES PLOT MODULE INSTEAD OF CROP MODULE
use "$MW_1/Agriculture/AG_MOD_C.dta", clear
ren case_id hhid
ren ag_c00 plotid
gen acres_gps = ag_c04c
gen acres_report = ag_c04a if ag_c04b==1
gen acres = acres_gps
replace acres = acres_report if acres_gps==.		// Use gps unless missing
keep hhid plotid acres
tempfile mw1_plot
save `mw1_plot', replace

collapse (sum) acres, by(hhid)
tempfile mw1_acres
save `mw1_acres', replace


*Now the other plot info
use "$MW_1/Agriculture/AG_MOD_D.dta", clear
ren case_id hhid
ren ag_d00 plotid
ren ag_d01 personid
gen orgfert = ag_d36 ==1
gen inorgfert = ag_d38 ==1
merge m:1 personid hhid using `mw1_inddemog', keepusing(relationship male age) nogen keep(1 3)		// Not keeping unmatched from using
*Fixing a duplicate
duplicates tag hhid plotid, gen(dupe)				// there is one duplicate
drop if dupe==1 & ag_d20a==35						// this is the mistake; fixing by dropping it
merge 1:1 hhid plotid using `mw1_plot', nogen		// 1 not matched from using
tempfile mw1_plot
save `mw1_plot', replace
*And now the plot-crop level
use "$MW_1/Agriculture/AG_MOD_G.dta", clear
ren case_id hhid
gen month_start = ag_g12a
gen month_end = ag_g12b
gen maize = inlist(ag_g0d,1,2,3,4)
gen month_start_maize = month_start if maize==1
gen month_end_maize = month_end if maize==1

preserve
	keep hhid month*
	gen year_start=2010
	gen year_end=2010
	*Date format
	gen ym_harv_first = ym(year_start,month_start)
	gen ym_maize_first_date = ym(year_start,month_start_maize)
	gen ym_maize_first = month_start_maize
	format ym_harv_first %tm
	collapse (min) ym_harv_first ym_maize_first ym_maize_first_date month_start* (firstnm) year_start, by(hhid)
	tempfile mw1_plot_first
	save `mw1_plot_first', replace
restore

preserve
	keep hhid month*
	gen year_start=2010
	gen year_end=2010
	*Date format
	gen ym_harv_last = ym(year_end,month_end)
	gen ym_maize_last = month_end_maize
	format ym* %tm
	collapse (max) ym_harv_last ym_maize_last month_end* (firstnm) year_start, by(hhid)
	tempfile mw1_plot_last
	save `mw1_plot_last', replace
restore


drop maize
ren ag_g0b plotid
merge m:1 hhid plotid using `mw1_plot', keep(3) nogen		// 64 not matched from using (keeping only matched)
*Identifying crops
gen maize = inlist(ag_g0d,1,2,3,4)
gen tobacco = inlist(ag_g0d,5,6,7,8,9,10)
gen groundnut = inlist(ag_g0d,11,12,13,14,15,16)
gen rice = inlist(ag_g0d,17,18,19,20,21,22,23,24,25,26)
gen ground_bean = ag_g0d==27
gen sweet_potato = ag_g0d==28
gen irish_potato = ag_g0d==29
gen wheat = ag_g0d==30
gen millet = inlist(ag_g0d,31,33)
gen sorghum = ag_g0d==32
gen beans = ag_g0d==34
gen soya = ag_g0d==35
gen pigeon_pea = ag_g0d==36
gen cotton = ag_g0d==37
gen sunflower = ag_g0d==38
gen sugarcane = ag_g0d==39
gen tanaposi = ag_g0d==41
gen nkhwani = ag_g0d==42
gen okra = ag_g0d==43
gen tomato = ag_g0d==44
gen onion = ag_g0d==45
gen pea = ag_g0d==46
gen paprika = ag_g0d==47
gen other = ag_g0d==48
*We do count cash crops for acres planted

gen crop = "maize" if maize==1
	foreach i of varlist tobacco-other{
	replace crop = "`i'" if `i'==1
}


*Proportion variables do not always sum to one
gen proportion = 0.1 if ag_g03==1					// Assuming it is ten percent if less than 1/4
replace proportion = 0.25 if ag_g03==2
replace proportion = 0.5 if ag_g03==3
replace proportion = 0.75 if ag_g03==4
replace proportion = 0.9 if ag_g03==5				// Assuming 90 percent if more than 3/4
replace proportion = 1 if ag_g02==1 | ag_g01==1		// If planted on ENTIRE plot

bys hhid plotid: egen total_prop = sum(proportion)	// Getting TOTAL proportion, which is not always one
replace proportion = proportion/total_prop if total_prop>1			// Now they MUST sum to one IF they are over one

*Here we tag just one of each crop (e.g. one of the 10 rice varietals)
foreach i of varlist maize-other{
	gen `i'_temp = 1 if `i'==1
	egen `i'_tag = tag(`i'_temp hhid)		// This variable tags just one of each varietal
}

*Area by crop
foreach i of varlist maize-other{
	gen `i'_acres = acres*proportion if `i'==1
}

tempfile plot1
save `plot1', replace

*Now collapse
collapse (sum) *acres *_tag (max) orgfert inorgfert, by(hhid)
egen acres_planted = rowtotal(*_acres)
egen crop_count = rowtotal(maize_tag-other_tag)
keep hhid crop_count acres_planted orgfert inorgfert
gen ag_any = crop_count>0 & crop_count!=.
tempfile mw1_herf
save `mw1_herf', replace


*Livestock
use "$MW_1/Agriculture/AG_MOD_R1.dta", clear
ren case_id hhid
gen bovine = inlist(ag_r0a,301,302,303)
gen goat = ag_r0a==307
gen sheep = ag_r0a==308
gen pig = ag_r0a==309
gen poultry = inlist(ag_r0a,310,311,312,313,314,315,316)
gen ox = ag_r0a==304
gen equine = inlist(ag_r0a,305,306)
gen other = inlist(ag_r0a,317,318)
foreach i of varlist bovine-other{
	gen `i'_num = ag_r02 if `i'==1
}
recode bovine_num-equine_num (.=0)
collapse (max) bovine_num-equine_num, by(hhid)
gen livestock_any = 0
foreach i of varlist bovine_num-equine_num{
	replace livestock_any = 1 if `i'>0 & `i'!=.
}
tempfile mw1_livestock
save `mw1_livestock', replace


*Fruit/Perm Crops
use "$MW_1/Agriculture/AG_MOD_P.dta", clear
ren case_id hhid
tab ag_p0a
gen any_perm = ag_p0d!=.
recode ag_p0d (39=18) (14=13)
tab ag_p0d, gen(crop)
egen crop_count = tag(hhid ag_p0d)
replace crop_count = 0 if ag_p0d==1
ren crop1 cassava
ren crop2 mango
ren crop3 orange
ren crop4 pawpaw
ren crop5 banana
ren crop6 avocado
ren crop7 guava
ren crop8 lemon
ren crop9 naartje
ren crop10 peach
ren crop11 apple
ren crop12 masau
ren crop13 pineapple
ren crop14 other
gen start_month = ag_p06a
gen start_year = ag_p06b
gen end_month = ag_p06c
gen end_year = ag_p06d

gen any_perm_food = inlist(ag_p0d,1,4,5,6,7,8,9,10,11,12,13,14,15,16,17)
gen fruit = mango==1 | pawpaw==1 | banana==1 | avocado==1 | guava==1 | naartje==1 | peach==1 | apple==1 | masau==1 | pineapple==1
tempfile mw1_crop_perm
save `mw1_crop_perm', replace
collapse (max) cassava-other any_perm any_perm_food fruit (sum) crop_count, by(hhid)
recode cassava (.=0)
ren crop_count crop_count_perm
tempfile mw1_perm
save `mw1_perm', replace


*Consumption Aggregates
use "$MW_1/Round 1 (2010) Consumption Aggregate.dta", clear
ren case_id hhid
gen total_exp = rexpagg
gen total_exp_cap = pcrexpagg
gen food_exp = (rexp_cat011+rexp_cat012)
keep hhid total_* food_exp
tempfile mw1_cons
save `mw1_cons', replace


*Identifying non-farm households (with filter module)
use "$MW_1/Household/HH_MOD_X.dta", clear
ren case_id hhid
gen ag_hh = hh_x08==1 | (hh_x12==1 | hh_x15==1)
collapse (max) ag_hh, by(hhid)
tempfile mw1_filter
save `mw1_filter', replace


*Remittances
use "$MW_1/Household/HH_MOD_P.dta", clear
ren case_id hhid
egen total_received = rowtotal(hh_p03a hh_p03b hh_p03c)
collapse (sum) total_received, by(hhid)
tempfile remit
save `remit', replace
use "$MW_1/Household/HH_MOD_O.dta", clear
ren case_id hhid
gen remittances = hh_o14
collapse (sum) remittances, by(hhid)
merge 1:1 hhid using `remit', nogen assert(3)
replace remittances = ln(remittances + total_received + 1)
keep hhid remittances
tempfile mw1_remittances
save `mw1_remittances', replace


*Geovariables
use "$MW_1/Geovariables/HouseholdGeovariables_IHS3_Rerelease.dta", clear
ren case_id hhid
gen avg_rain = anntot_avg
gen avg_wetqtr = wetq_avg
gen rain2009_tot = h2009_tot
gen rain2009_wetqtr = h2009_wetq
gen rain2010_tot = h2010_tot
gen rain2010_wetqtr = h2010_wetq
tempfile mw1_geovars
save `mw1_geovars', replace

*Adding Fishery Production
use "$MW_1/Fisheries/FS_MOD_B_FILT.dta", clear
ren case_id hhid
gen fish = 1		// Assuming they fished if they do this module
keep hhid fish
tempfile mw1_fish
save `mw1_fish', replace



use `mw1_merge', clear
merge m:1 ea_id using `mw1_comm', nogen assert(3)
merge 1:1 hhid using `mw1_herf', nogen assert(1 3)
merge 1:1 hhid using `mw1_acres', gen(ag) assert(1 3)
merge 1:1 hhid using `mw1_hhdemog', nogen assert(3)
merge 1:1 hhid using `mw1_livestock', nogen assert(1 3)
merge 1:1 hhid using `mw1_cons', nogen keep(1 3)		// Only panels get matched
merge 1:1 hhid using `mw1_sales', nogen keep(1 3)
merge m:1 hhid using `mw1_sales_perm', nogen keep(1 3)
merge 1:1 hhid using `mw1_nfe', nogen keep(1 3)
merge 1:1 hhid using `mw1_labor', nogen keep(1 3)
merge 1:1 hhid using `mw1_herf_prev', nogen keep(1 3)
merge 1:1 hhid using `mw1_plot_first', nogen keep(1 3)
merge 1:1 hhid using `mw1_plot_last', nogen keep(1 3)
merge 1:1 hhid using `mw1_perm', nogen keep(1 3)
merge 1:1 hhid using `mw1_filter', nogen keep(3)
merge 1:1 hhid using `mw1_remittances', nogen assert(3)
merge 1:1 hhid using `mw1_geovars', nogen assert(3)
merge 1:1 hhid using `mw1_fish', nogen keep(1 3)
gen country = "Malawi"
tempfile mw1_hhid
save `mw1_hhid', replace





************************
************************
******            ******
******   WAVE 2   ******
******            ******
************************
************************
*Community (for distance variables)
use "$MW_2/Community/COM_MOD_D.dta", clear
gen dist_dmarket = com_cd16a if com_cd16b==2				// kilometers is 2
replace dist_dmarket = com_cd16a*1.6 if com_cd16b==3		// miles is 3
replace dist_dmarket = com_cd16a/1000 if com_cd16b==1		// meters is 1
replace dist_dmarket = 0 if com_cd15==1						// equals zero if there is a market in the community
keep ea_id dist_*
tempfile mw2_comm
save `mw2_comm', replace


*Rainfall
use "$MW_2/Geovariables/HouseholdGeovariables_IHPS.dta", clear
gen rain_ratio2012 = (h2012_tot-anntot_avg)/anntot_avg
gen rain_ratio2013 = (h2013_tot-anntot_avg)/anntot_avg
keep rain_ratio* y2_hhid
tempfile mw2_rain
save `mw2_rain', replace


*Basics (to merge with wave 1)
use "$MW_2/Household/HH_MOD_A_FILT.dta", clear
ren hh_a05 split
gen weight = hh_wgt
ren case_id hhid
encode hh_a10b, gen(ta)
gen rural = reside==2
gen psu = ea_id

gen month1 = hh_a23a_2
gen month2 = hh_a37a_2
gen year1 = hh_a23a_3
gen year2 = hh_a37a_3

gen month = month1 if qx_type==1
gen year = year1 if qx_type==1
replace month = month2 if qx_type==2
replace year = year2 if qx_type==2
gen ym_int = ym(year,month)			// Stata format
format ym_int %tm
gen wave = 2
keep y2_hhid hhid region district *weight split ta rural stratum panelweight ea_id ym_int wave month
merge 1:1 y2_hhid using `mw2_rain', nogen
tempfile mw2_merge
save `mw2_merge', replace

*Household demographics
use "$MW_2/Household/HH_MOD_B.dta", clear
*For education
merge 1:1 y2_hhid PID using "$MW_2/Household/HH_MOD_C.dta", nogen 					// 1 not matched from master
ren PID pid
gen wave1_pid = hh_b06_1
gen personid = occ
gen male = hh_b03==1
gen relationship = hh_b04
gen age = hh_b05a
gen educ = hh_c08

preserve
	keep y2_hhid pid personid male relationship age wave1_pid educ
	tempfile mw2_inddemog
	save `mw2_inddemog', replace
restore

drop hhsize
gen hhsize = 1
gen elderly = age>=60 & age!=.
gen children = age<15
gen age_head = age if relationship==1
gen male_head = male if relationship==1
gen adult_male = male==1 & age>=15 & age!=.
gen adult_female = male==0 & age>=15 & age!=.
gen educ_head = educ if relationship==1 												// Assuming Training College follows Form 6 and is equivalent to University 1, 2, 3, 4
replace educ_head = 15 if educ_head == 20
replace educ_head = 16 if educ_head == 21
replace educ_head = 17 if educ_head == 22
replace educ_head = 18 if educ_head == 23
collapse (sum) hhsize elderly children adult_male adult_female (max) age_head male_head educ_head, by(y2_hhid)
tempfile mw2_hhdemog
save `mw2_hhdemog', replace



*Labor variables
use "$MW_2/Household/HH_MOD_E.dta", clear
gen any_wage = hh_e18==1 | hh_e55==1
collapse (sum) wage_count = any_wage (max) any_wage, by(y2_hhid)
tempfile mw2_labor
save `mw2_labor', replace




*Identifying whether they have non-farm enterprises
use "$MW_2/Household/HH_MOD_N2.dta", clear
merge m:1 y2_hhid using "$MW_2/Household/HH_MOD_N1.dta", nogen
gen ent_count = 1
replace ent_count = 0 if hh_n0b==2														// = 0 if household did NOT operate one
gen ent_sales = hh_n32
replace ent_sales = 0 if hh_n0b==2														// = 0 if household did NOT operate one
collapse (sum) ent_count ent_sales, by(y2_hhid)
gen nfe_any = ent_count>0 & ent_count!=.
tempfile mw2_nfe
save `mw2_nfe', replace


*PREVIOUS rainy season (2011/2012 for wave 2)
use "$MW_2/Agriculture/AG_MOD_BA.dta", clear
gen ag2011 = ag_b0a==1					// Those that actually planted crops in 2011/2012 = 1
gen acres = ag_b01a if ag_b01b==1
replace acres = ag_b01a/0.404686 if ag_b01b==2

*Creating a crop variable
*Still using only food crops 
gen new_crop = 1 if inlist(ag_b0c,1,2,3,4)						// Maize
replace new_crop = 3 if inlist(ag_b0c,11,12,13,14,15,16)		// Groundnut
replace new_crop = 4 if inlist(ag_b0c,17,18,19,20,21,22,23,25,26)	// Rice
replace new_crop = 5 if inlist(ag_b0c,27)						// Ground bean
replace new_crop = 6 if inlist(ag_b0c,28)						// Sweet potato
replace new_crop = 7 if inlist(ag_b0c,29)						// Irish potato
replace new_crop = 8 if inlist(ag_b0c,30)						// Wheat
replace new_crop = 9 if inlist(ag_b0c,31,33)					// Millet
replace new_crop = 10 if inlist(ag_b0c,32)						// Sorghum (note that this is counted separately from millet)
replace new_crop = 11 if inlist(ag_b0c,34)						// Beans
replace new_crop = 12 if inlist(ag_b0c,35)						// Soyabeans
replace new_crop = 13 if inlist(ag_b0c,36)						// Pigeonpeas
replace new_crop = 15 if inlist(ag_b0c,38)						// Sunflower
replace new_crop = 16 if inlist(ag_b0c,39)						// Sugarcane
replace new_crop = 17 if inlist(ag_b0c,41)						// Tanaposi
replace new_crop = 18 if inlist(ag_b0c,42)						// Nkhwani
replace new_crop = 19 if inlist(ag_b0c,43)						// Okra
replace new_crop = 20 if inlist(ag_b0c,44)						// Tomato
replace new_crop = 21 if inlist(ag_b0c,45)						// Onion
replace new_crop = 22 if inlist(ag_b0c,46)						// Pea
replace new_crop = 24 if inlist(ag_b0c,48)						// Other
replace new_crop = 25 if inlist(ag_b0c,40)

tab new_crop, gen(crop)

foreach i of varlist crop*{
gen `i'_acres = `i'*acres
}
egen crop_count_previous = tag(y2_hhid new_crop)
*Crops
gen maize = inlist(ag_b0c,1,2,3,4)

*Now generating harvest date
gen year_start = 2012
gen year_end = 2012
gen month_start = ag_b05a
gen month_end = ag_b05b
gen ym_harv_prev = ym(year_start,month_start)
gen ym_harv_prev_end = ym(year_end,month_end)
gen ym_maize_prev = month_start if maize==1
gen ym_maize_prev_end = month_end if maize==1
format ym_harv_* %tm
*Collapse to household level
collapse (firstnm) ag2011 (sum) crop*acres acres crop_count_previous (min) ym_*_prev month_start* (max) month_end* ym_*_end, by(y2_hhid)
foreach i of varlist crop*acres{
gen `i'_herf = (`i'/acres)^2
}

egen herf_previous = rowtotal(*_herf)
ren month_start month_start_prev
ren ym_maize_prev month_start_maize_prev
ren month_end month_end_prev
ren ym_maize_prev_end month_end_maize_prev
keep y2_hhid herf_previous ym_* crop_count_ ag2011 month_*
tempfile mw2_herf_prev
save `mw2_herf_prev', replace

*Sales of Crops - ANNUAL
use "$MW_2/Agriculture/AG_MOD_I.dta", clear
gen sales_dum = ag_i01==1
gen sales_value = ag_i03																	// Assuming "99999999" is top-coded, not missing

gen stored_annual = ag_i38==1
collapse (sum) sales_count = sales_dum sales_value (max) sales_dum stored_annual, by(y2_hhid)
tempfile mw2_sales
save `mw2_sales', replace


*Sales of Crops - PERMANENT
use "$MW_2/Agriculture/AG_MOD_Q.dta", clear
gen sales_dum_perm = ag_q01==1
gen sales_value_perm = ag_q03																// Assuming "99999999" is top-coded, not missing

gen stored_perm = ag_q37==1
collapse (sum) sales_count_perm = sales_dum_perm sales_value_perm (max) sales_dum_perm stored_perm, by(y2_hhid)
tempfile mw2_sales_perm
save `mw2_sales_perm', replace

*THIS PART USES PLOT MODULE INSTEAD OF CROP MODULE
use "$MW_2/Agriculture/AG_MOD_C.dta", clear
ren ag_c00 plotid
gen acres_gps = ag_c04c
gen acres_report = ag_c04a if ag_c04b==1
gen acres = acres_gps
replace acres = acres_report if acres_gps==.		// Use GPS estimate unless missing
keep y2_hhid plotid acres
tempfile mw2_plot
save `mw2_plot', replace

collapse (sum) acres, by(y2_hhid)
tempfile mw2_acres
save `mw2_acres', replace

*Now the other plot info
use "$MW_2/Agriculture/AG_MOD_D.dta", clear
ren ag_d00 plotid
ren ag_d01 personid
gen orgfert = ag_d36 ==1
gen inorgfert = ag_d38 ==1
merge m:1 personid y2_hhid using `mw2_inddemog', keepusing(relationship male age) nogen keep(1 3)		// Not keeping unmatched from using
merge 1:1 y2_hhid plotid using `mw2_plot', keep(1 3) nogen												// 2 not matched from using, 3 from using
tempfile mw2_plot
save `mw2_plot', replace

*And now the plot-crop level
use "$MW_2/Agriculture/AG_MOD_G.dta", clear
gen month_start = ag_g12a
gen month_end = ag_g12b
gen maize = inlist(ag_g0b,1,2,3,4)
gen month_start_maize = month_start if maize==1
gen month_end_maize = month_end if maize==1
*This is to create summary statistics on timing
preserve
	keep y2_hhid month*
	gen year_start=2013				// This is true for wave 2
	gen year_end=2013
	*Date format
	gen ym_harv_first = ym(year_start,month_start)			// building format stata understands
	gen ym_maize_first_date = ym(year_start,month_start_maize)
	gen ym_maize_first = month_start_maize
	format ym_harv* %tm
	collapse (min) ym_* month_start* (firstnm) year_start, by(y2_hhid)
	tempfile mw2_plot_first
	save `mw2_plot_first', replace
restore

preserve
	keep y2_hhid month*
	gen year_start=2013				// This is true for wave 2
	gen year_end=2013
	*Date format
	gen ym_harv_last = ym(year_end,month_end)			// building format stata understands
	gen ym_maize_last = month_end_maize
	format ym_harv_last %tm
	collapse (max) ym_* month_end* (firstnm) year_start, by(y2_hhid)
	tempfile mw2_plot_last
	save `mw2_plot_last', replace
restore

drop maize
ren ag_g00 plotid
merge m:1 y2_hhid plotid using `mw2_plot', keep(3) nogen		// 115 not matched from master and 500 not matched from using (keeping only matched)
*Identifying crops
gen maize = inlist(ag_g0b,1,2,3,4)
gen tobacco = inlist(ag_g0b,5,6,7,8,9,10)
gen groundnut = inlist(ag_g0b,11,12,13,14,15,16)
gen rice = inlist(ag_g0b,17,18,19,20,21,22,23,24,25,26)
gen ground_bean = ag_g0b==27
gen sweet_potato = ag_g0b==28
gen irish_potato = ag_g0b==29
gen wheat = ag_g0b==30
gen millet = inlist(ag_g0b,31,33)
gen sorghum = ag_g0b==32
gen beans = ag_g0b==34
gen soya = ag_g0b==35
gen pigeon_pea = ag_g0b==36
gen cotton = ag_g0b==37
gen sunflower = ag_g0b==38
gen sugarcane = ag_g0b==39
gen cabbage = ag_g0b==40
gen tanaposi = ag_g0b==41
gen nkhwani = ag_g0b==42
gen okra = ag_g0b==43
gen tomato = ag_g0b==44
gen onion = ag_g0b==45
gen pea = ag_g0b==46
gen paprika = ag_g0b==47
gen other = ag_g0b==48

gen crop = "maize" if maize==1
	foreach i of varlist tobacco-other{
	replace crop = "`i'" if `i'==1
}

*Same process as above
gen proportion = 0.1 if ag_g03==1		// Assuming it is ten percent if less than 1/4
replace proportion = 0.25 if ag_g03==2
replace proportion = 0.5 if ag_g03==3
replace proportion = 0.75 if ag_g03==4
replace proportion = 0.9 if ag_g03==5	// Another assumption here: =0.9 if more than 3/4
replace proportion = 1 if ag_g02==1 | ag_g01==1		// If planted on ENTIRE plot
bys y2_hhid plotid: egen total_prop = sum(proportion)	// Getting TOTAL proportion

replace proportion = proportion/total_prop if total_prop>1			// Now they MUST sum to one IF they are over one 

*Now we tag just one of each crop (e.g. one of the 10 rice varietals)
foreach i of varlist maize-other{
	gen `i'_temp = 1 if `i'==1
	egen `i'_tag = tag(`i'_temp y2_hhid)		// This variable tags just one of each varietal
}
*Area by crop
foreach i of varlist maize-other{
	gen `i'_acres = acres*proportion if `i'==1
}

*Now collapse
collapse (sum) *acres *_tag (max) orgfert inorgfert, by(y2_hhid)
egen acres_planted = rowtotal(*_acres)
egen crop_count = rowtotal(maize_tag-other_tag)
keep y2_hhid crop_count acres* orgfert inorgfert
gen ag_any = crop_count>0 & crop_count!=.
tempfile mw2_herf
save `mw2_herf', replace


*Livestock
use "$MW_2/Agriculture/AG_MOD_R1.dta", clear
gen bovine = inlist(ag_r0a,301,302,303,304)
gen goat = ag_r0a==307
gen sheep = ag_r0a==308
gen pig = ag_r0a==309
gen poultry = inlist(ag_r0a,311,313,315,3310,3314)
gen ox = ag_r0a==3304
gen equine = ag_r0a==3305
gen other = inlist(ag_r0a,318,319)
foreach i of varlist bovine-equine{
gen `i'_num = ag_r02 if `i'==1
}
recode bovine_num-equine_num (.=0)
collapse (max) bovine_num-equine_num, by(y2_hhid)
gen livestock_any = 0
foreach i of varlist bovine_num-equine_num{
replace livestock_any = 1 if `i'>0 & `i'!=.
}
tempfile mw2_livestock
save `mw2_livestock', replace


*Fruit/Perm Crops
use "$MW_2/Agriculture/AG_MOD_P.dta", clear
merge m:1 y2_hhid using `mw2_merge', assert(2 3)
gen any_perm = ag_p0c!=.
recode ag_p0c (39=18) (19=18) (14=13)
tab ag_p0c, gen(crop)
egen crop_count = tag(hhid ag_p0c)
replace crop_count = 0 if ag_p0c==1
ren crop1 cassava
ren crop2 tea
ren crop3 mango
ren crop4 orange
ren crop5 pawpaw
ren crop6 banana
ren crop7 avocado
ren crop8 guava
ren crop9 lemon
ren crop10 naartje
ren crop11 peach
ren crop12 apple
ren crop13 masau
ren crop14 pineapple
ren crop15 other
gen start_month = ag_p06a
gen start_year = ag_p06b
gen end_month = ag_p06c
gen end_year = ag_p06d

gen any_perm_food = inlist(ag_p0c,1,4,5,6,7,8,9,10,11,12,13,14,15,16,17)
gen fruit = mango==1 | pawpaw==1 | banana==1 | avocado==1 | guava==1 | naartje==1 | peach==1 | apple==1 | masau==1 | pineapple==1
tempfile mw2_crop_perm
save `mw2_crop_perm', replace
collapse (max) cassava-other any_perm any_perm_food fruit (sum) crop_count, by(y2_hhid)
recode cassava (.=0)
ren crop_count crop_count_perm
tempfile mw2_perm
save `mw2_perm', replace

*Consumption Aggregates
use "$MW_2/Round 2 (2013) Consumption Aggregate.dta", clear
gen total_exp = rexpagg
gen total_exp_cap = pcrexpagg
gen food_exp = rexp_cat01
keep y2_hhid *_exp*
tempfile mw2_cons
save `mw2_cons', replace

*Identifying non-farm households (using filter module)
use "$MW_2/Household/HH_MOD_X.dta", clear
gen ag_hh = hh_x11_1==1
collapse (max) ag_hh, by(y2_hhid)
tempfile mw2_filter
save `mw2_filter', replace

*Remittances
use "$MW_2/Household/HH_MOD_P.dta", clear
egen total_received = rowtotal(hh_p03a hh_p03b hh_p03c)
collapse (sum) total_received, by(y2_hhid)
tempfile remit
save `remit', replace
use "$MW_2/Household/HH_MOD_O.dta", clear
gen remittances = hh_o14
collapse (sum) remittances, by(y2_hhid)
merge 1:1 y2_hhid using `remit', nogen assert(3)
replace remittances = ln(remittances + total_received + 1)
keep y2_hhid remittances
tempfile mw2_remittances
save `mw2_remittances', replace


*Geovariables
use "$MW_2/Geovariables/HouseholdGeovariables_IHPS.dta", clear
gen avg_rain = anntot_avg
gen avg_wetqtr = wetQ_avg
gen rain2012_tot = h2012_tot
gen rain2012_wetqtr = h2012_wetQ
gen rain2013_tot = h2013_tot
gen rain2013_wetqtr = h2013_wetQ
tempfile mw2_geovars
save `mw2_geovars', replace

*Adding FISHERY PRODUCTIOn
use "$MW_2/Fisheries/FS_META.dta", clear
gen fish = 1
keep y2_hhid fish
tempfile mw2_fish
save `mw2_fish', replace



use `mw2_merge', clear
merge m:1 ea_id using `mw2_comm', nogen assert(3)
merge 1:1 y2_hhid using `mw2_herf', nogen assert(1 3)
merge 1:1 y2_hhid using `mw2_acres', gen(ag) assert(1 3)
merge 1:1 y2_hhid using `mw2_hhdemog', nogen assert(3)
merge 1:1 y2_hhid using `mw2_livestock', nogen assert(1 3)
merge 1:1 y2_hhid using `mw2_cons', nogen assert(3)
merge 1:1 y2_hhid using `mw2_sales', nogen keep(1 3)
merge m:1 y2_hhid using `mw2_sales_perm', nogen keep(1 3)
merge 1:1 y2_hhid using `mw2_nfe', nogen keep(1 3)
merge 1:1 y2_hhid using `mw2_labor', nogen keep(1 3)
merge 1:1 y2_hhid using `mw2_herf_prev', nogen keep(1 3)
merge 1:1 y2_hhid using `mw2_plot_first', nogen keep(1 3)
merge 1:1 y2_hhid using `mw2_plot_last', nogen keep(1 3)
merge 1:1 y2_hhid using `mw2_perm', nogen keep(1 3)
merge 1:1 y2_hhid using `mw2_filter', nogen assert(3)
merge 1:1 y2_hhid using `mw2_remittances', nogen assert(3)
merge 1:1 y2_hhid using `mw2_geovars', nogen assert(3)
merge m:1 y2_hhid using `mw2_fish', nogen keep(1 3)
gen country = "Malawi"
tempfile mw2_hhid
save `mw2_hhid', replace



*Appending
append using `mw1_hhid'
replace hhid = y2_hhid if split==2										// The splits now have their OWN hhid (not the original household's hhid)

*Checking for more than two observations per household
bys hhid: egen wave_count = count(wave)	
gen last = substr(y2_hhid,8,1)
drop if wave_count==3 & last!="1"
drop wave_count
bys hhid: egen wave_count = count(wave)	

*Variable creation
gen log_acres = ln(acres)

sum log_acres, d

gen bottom95 = log_acres<r(p95)

*Wave/district FE
egen wave_dist = group(wave district)
egen hhfe = group(hhid)													// hhfe will be used for household fixed effects
bys hhid wave: egen nosplit_count = count(wave) if split!=2

gen DOI = ym(year(dofm(ym_int)),month(dofm(ym_int)))
gen first_harv = ym(year(dofm(ym_harv_first)),month(dofm(ym_harv_first)))
gen last_harv = ym(year(dofm(ym_harv_last)),month(dofm(ym_harv_last)))
gen first_harv_month = month(dofm(ym_harv_first))
gen last_harv_month = month(dofm(ym_harv_last))
gen prev_first_harv = month(dofm(ym_harv_prev))
gen prev_last_harv = month(dofm(ym_harv_prev_end))

recode livestock_any (.=0)		// Assuming these households were not in the livestock module

*Recoding assuming missing are zero
recode fruit fish fish crop_count_perm (.=0)

*NOTE: Now herf is increasing in diversity - This is now a Simpson index
gen simpson = 1-herf
gen simpson_previous = 1-herf_previous



*Giving wave 2 observation the wave 1 value for first and last harvest
bys hhid (wave): gen first_harv_wave1 = first_harv_month[_n-1]
bys hhid (wave): gen last_harv_wave1 = last_harv_month[_n-1]

tempfile clean_TEMP
save `clean_TEMP', replace


************************************************************************************************************
*Now food security (creating a variable for months hungry between harvest and interview)
use `clean_TEMP', clear
keep if wave==1
tempfile mw1_merge
save `mw1_merge', replace
use `clean_TEMP', clear
keep if wave==2
tempfile mw2_merge
save `mw2_merge', replace

************************
************************
******            ******
******   WAVE 1   ******
******            ******
************************
************************
use "$MW_1/Household/HH_MOD_H.dta", clear
ren case_id hhid
gen hunger_any = hh_h04==1
keep hh_h05* hhid
merge m:1 hhid using `mw1_merge', nogen keepusing(rural weight ag_hh)
ren hh_h05a* y2009*
ren hh_h05b* y2010*
ren y2009_01 y2009mar
ren y2009_02 y2009apr
ren y2009_03 y2009may
ren y2009_04 y2009jun
ren y2009_05 y2009jul
ren y2009_06 y2009aug
ren y2009_07 y2009sep
ren y2009_08 y2009oct
ren y2009_09 y2009nov
ren y2009_10 y2009dec
ren y2010_01 y2010jan
ren y2010_02 y2010feb
ren y2010_03 y2010mar
ren y2010_04 y2010apr
ren y2010_05 y2010may
ren y2010_06 y2010jun
ren y2010_07 y2010jul
ren y2010_08 y2010aug
ren y2010_09 y2010sep
ren y2010_10 y2010oct
ren y2010_11 y2010nov
ren y2010_12 y2010dec
ren y2010_13 y2011jan
ren y2010_14 y2011feb
ren y2010_15 y2011mar
foreach i of varlist y2009mar-y2011mar{
replace `i' = "1" if `i'=="X"
replace `i' = "0" if `i'!="1"
destring `i', replace
}
reshape long y20, i(hhid) j(month) string
gen year = substr(month,1,2)
destring year, replace
recode year (9=2009) (10=2010) (11=2011)
ren y20 hunger
replace month = substr(month,3,.)
replace month = "1" if month=="jan"
replace month = "2" if month=="feb"
replace month = "3" if month=="mar"
replace month = "4" if month=="apr"
replace month = "5" if month=="may"
replace month = "6" if month=="jun"
replace month = "7" if month=="jul"
replace month = "8" if month=="aug"
replace month = "9" if month=="sep"
replace month = "10" if month=="oct"
replace month = "11" if month=="nov"
replace month = "12" if month=="dec"
destring month, replace
label define month 1 "Jan" 2 "Feb" 3 "Mar" 4 "Apr" 5 "May" 6 "Jun" 7 "Jul" 8 "Aug" 9 "Sep" 10 "Oct" 11 "Nov" 12 "Dec"
label val month month
gen hunger_date = ym(year,month)
format hunger_date %tm
sort hhid hunger_date

gen country = "Malawi"
gen wave = 1

tempfile mw1
save `mw1', replace


************************
************************
******            ******
******   WAVE 2   ******
******            ******
************************
************************
use "$MW_2/Household/HH_MOD_H.dta", clear
gen hunger_any = hh_h04==1
keep hh_h05* y2_hhid hunger_any
merge m:1 y2_hhid using `mw2_merge', nogen keepusing(rural weight ag_hh)
ren hh_h05a y2012apr
ren hh_h05b y2012may
ren hh_h05c y2012jun
ren hh_h05d y2012jul
ren hh_h05e y2012aug
ren hh_h05f y2012sep
ren hh_h05g y2012oct
ren hh_h05h y2012nov
ren hh_h05i y2012dec
ren hh_h05j y2013jan
ren hh_h05k y2013feb
ren hh_h05l y2013mar
ren hh_h05m y2013apr
ren hh_h05n y2013may
ren hh_h05o y2013jun
ren hh_h05p y2013jul
ren hh_h05q y2013aug
ren hh_h05r y2013sep
ren hh_h05s y2013oct
foreach i of varlist y2012apr-y2013oct{
replace `i' = "1" if `i'=="X"
replace `i' = "0" if `i'!="1"
destring `i', replace
}
reshape long y20, i(y2_hhid) j(month) string
gen year = substr(month,1,2)
destring year, replace
recode year (12=2012) (13=2013)
ren y20 hunger
replace month = substr(month,3,.)
replace month = "1" if month=="jan"
replace month = "2" if month=="feb"
replace month = "3" if month=="mar"
replace month = "4" if month=="apr"
replace month = "5" if month=="may"
replace month = "6" if month=="jun"
replace month = "7" if month=="jul"
replace month = "8" if month=="aug"
replace month = "9" if month=="sep"
replace month = "10" if month=="oct"
replace month = "11" if month=="nov"
replace month = "12" if month=="dec"
destring month, replace
label define month 1 "Jan" 2 "Feb" 3 "Mar" 4 "Apr" 5 "May" 6 "Jun" 7 "Jul" 8 "Aug" 9 "Sep" 10 "Oct" 11 "Nov" 12 "Dec"
label val month month
gen hunger_date = ym(year,month)
format hunger_date %tm
sort y2_hhid year month

gen country = "Malawi"
gen wave = 2
tempfile mw2
save `mw2', replace
*End of food security cleaning
************************************************************************************************************


use `mw1', clear
merge m:1 hhid using `mw1_merge', nogen keep(3)
tempfile mw1
save `mw1', replace
use `mw2', clear
merge m:1 y2_hhid using `mw2_merge', nogen keep(3)
tempfile mw2
save `mw2', replace
*Appending wave 1
append using `mw1'
keep hhid country wave ym* hunger_date hunger month region rural ag_hh weight district

*NOTE: Hunger should only be asked for 12 months PRIOR to interview
*ym_int is the interview variable, while hunger_date is the date of hunger question variable (H05)
gen hunger_int_diff = ym_int-hunger_date
tab hunger_int_diff
tab hunger_int_diff if hunger==1		// This should only be 0-12, which it is
keep if hunger_int_diff>0 & hunger_int_diff<=12		// Using this information, we have dropped all OTHER months


*Creating seasonal hunger variables
gen pre_harvest = hunger_date==ym_harv_first | hunger_date==(ym_harv_first-1) | hunger_date==(ym_harv_first-2) | hunger_date==(ym_harv_first-3) if hunger_date!=. & ym_harv_first!=.
gen pre_harv_hunger = pre_harvest==1 & hunger==1 if pre_harvest!=.
gen chronic_month_hunger = pre_harvest==0 & hunger==1 if pre_harvest!=.

*These define a common definition of seasonal hunger so that we can include non-farm households
gen pre_harvest_ALL = inlist(month,1,2,3,4) if month!=.
gen pre_harv_hunger_ALL = pre_harvest_ALL==1 & hunger==1 if month!=.
gen chronic_month_hunger_ALL = !pre_harvest_ALL & hunger==1 if month!=.



tempfile hunger_vars
save `hunger_vars', replace


collapse (sum) pre_harv_hunger* hunger chronic_month_hunger*, by(wave hhid)

tempfile merge
save `merge', replace



use `clean_TEMP', clear
merge 1:1 wave hhid using `merge', nogen keep(1 3)			// All matched from MASTER
															// 5 not matched from master

ren ssa_aez09 agrozone
keep *hunger* herf_previous simpson_previous month wave crop_count* weight wave hhid first_harv district ///
agrozone ta acres acres_planted sales_* ea_id stratum ag_hh ag2008 ag2011 nfe* livestock* ym_* *_num remittances crop_count_perm *fert rain_* ///
adult_* children age_head male_head ent_* *count* *harv* hhsize fruit fish fish rural ///
bovine goat sheep pig poultry month_* region educ_head dist_road rain2010_tot rain2012_tot sales_dum_perm stored_* any_wage any_perm_food sales_dum_perm split





*Some recoding
recode acres* crop_count* (.=0)			// Assuming missing values for these variables means zero (e.g. no ag module therefore missing crop count)
*Generating a few variables
gen log_acres_p = ln(acres_planted)
gen hectares = acres*2.47105
gen hectares_p = acres_planted*2.47105
replace sales_value = sales_value/100000

*Wave / Geographic FE
egen FE = group(ta wave)
egen dist = group(district wave)

*Destringing hhid to use as a factor variable
egen hhidfe = group(hhid country)

*Weights
tempvar weight2
gen `weight2' = weight if wave==2 & country=="Malawi"
*we are using the second wave's pweight for household fixed effects, as per the World Bank
bys hhid: egen panel_weight = max(`weight2')

*Simpson index should never actually be equal to zero
recode simpson_previous (1=.)

*Assuming livestock variables are zero if it is missing
recode livestock_any *_num (.=0)

*Generating enterprise AND livestock variable
egen other_num = rowtotal(bovine_num goat_num sheep_num pig_num ox_num equine_num)
gen mammal = bovine_num>0 | goat_num>0 | sheep_num>0 | pig_num>0 | equine_num>0
gen poultry = poultry_num>0
gen rain = rain2010_tot if wave==1
replace rain = rain2012_tot if wave==2

gen stored_crop = stored_annual==1 | stored_perm==1
egen ea_wave = group(ea_id wave)

*Labeling variables
la var simpson_previous "Simpson index in previous season (planted acres)"
la var adult_male "Adult males"
la var adult_female "Adult females"
la var children "Children (age<15)"
la var age_head "Age of household head"
la var male_head "Male household head"
la var log_acres "Acres (log)"
la var acres "Acres"
la var acres_planted "Acres planted"
la var crop_count "Crop count"
la var sales_count "Number of crops sold"
la var sales_value "Value of crops sold (hundred thousands)"
la var log_acres_p "Acres planted (log)"
la var ent_count "Number of non-farm enterprises operated"
la var wage_count "Number of wage workers"
la var bovine_num "Bovine (count)"
la var goat_num "Goat (count)"
la var sheep_num "Sheep (count)"
la var pig_num "Pig (count)"
la var poultry_num "Poultry (count)"
la var equine_num "Equine (count)"
la var other_num "Other (count)"
la var mammal "Household Owned Mammal"
la var poultry "Household Owned Poultry"
la var remittances "Remittances and gifts (log of total cash received - MK)"
la var hunger "Number of months hungry in previous year"
la var pre_harv_hunger "Number of months hungry in three months before first harvest"
la var other_num "Other livestock (count)"
la var hhsize "Household size"
la var crop_count_perm "Number of permanent/fruit crops (excluding cassava)"
la var pre_harv_hunger "Seasonal hunger (count)"
la var month_start_prev "Month of first harvest in previous wave"
la var month_end_prev "Month of last harvest in previous wave"
la var month_start "Month of first harvest in current wave"
la var month_end "Month of last harvest in currentwave"
la var month_start_maize_prev "Month of first maize harvest in previous wave"
la var month_end_maize "Month of last maize harvest in current wave"
la var month_start_maize "Month of first maize harvest in current wave"
la var month_end_maize_prev "Month of last maize harvest in previous wave"
la var ym_maize_first "Month of first maize harvest in current year"
la var ym_maize_last "Month of last maize harvest in current year"
la var stored_crop "Stored Annual or Permanent Crop"
la var any_wage "Household Member Worked for Wage"
la var sales_dum_perm "Sold Annual or Permanent Crop"
la var any_perm_food "Grew Off-Season or Permanent Crop"
la var orgfert "Used any organic fertilizer"
la var inorgfert "Used any inorganic fertilizer"
la var educ_head "Education of household head (years)"
la var rain "Total rainfall in reference growing season (mm)
gen hhfe = hhidfe
gen integer_weight = floor(weight)
gen any_hunger = pre_harv_hunger!=0 if pre_harv_hunger!=.
*Summary statistics
eststo sum1: estpost sum age_head educ_head male_head hhsize dist_road rain acres crop_count orgfert inorgfert simpson_previous poultry_num other_num stored_crop ///
remittances any_wage sales_dum_perm any_perm_food rural ag_hh if wave==1
eststo sum2: estpost sum age_head educ_head male_head hhsize dist_road rain acres crop_count orgfert inorgfert simpson_previous poultry_num other_num stored_crop ///
remittances any_wage sales_dum_perm any_perm_food rural ag_hh if wave==2
*****************
*    Table 1    *
* Summary Stats *
*****************
esttab sum1 sum2, label replace cells("mean(fmt(3)) sd(fmt(3) par)") mlabels("Wave 1" "Wave 2")
*Summary statistics
eststo sum1: estpost sum age_head educ_head male_head hhsize dist_road rain acres crop_count orgfert inorgfert simpson_previous poultry_num other_num stored_crop ///
remittances any_wage sales_dum_perm any_perm_food rural if wave==1 & ag_hh==1
eststo sum2: estpost sum age_head educ_head male_head hhsize dist_road rain acres crop_count orgfert inorgfert simpson_previous poultry_num other_num stored_crop ///
remittances any_wage sales_dum_perm any_perm_food rural if wave==2 & ag_hh==1
*****************
*   Table A1    *
* Summary Stats *
*****************
esttab sum1 sum2, label replace cells("mean(fmt(3)) sd(fmt(3) par)") mlabels("Wave 1" "Wave 2")
*Figure 1
hist month_start if wave==1 [fweight=integer_weight], percent xtitle("Month of First Harvest") start(-0.5) width(1) ylabel(0(10)50) title("Wave 1") name(harvw1) xlabel(0(1)12)
hist month_start if wave==2 [fweight=integer_weight], percent xtitle("Month of First Harvest") start(-0.5) width(1) ylabel(0(10)50) title("Wave 2") name(harvw2) xlabel(0(1)12)
******************
*    Figure 1    *
******************
graph combine harvw1 harvw2
*Figures
gen hunger_cat = hunger if hunger!=.
gen hunger_ag = hunger if ag_hh==1
tab rural ag_hh
bys hunger_cat rural wave: egen all_hunger_pct = count(hunger) if hunger!=.
replace all_hunger_pct = all_hunger_pct/852 if rural==0 & wave==1
replace all_hunger_pct = all_hunger_pct/1041 if rural==0 & wave==2
replace all_hunger_pct = all_hunger_pct/2375 if rural==1 & wave==1
replace all_hunger_pct = all_hunger_pct/2939 if rural==1 & wave==2
tab rural wave if ag_hh==1
bys hunger_cat rural wave: egen ag_hunger_pct = count(hunger) if hunger!=. & ag_hh==1
replace ag_hunger_pct = ag_hunger_pct/369 if rural==0 & wave==1 & ag_hh==1
replace ag_hunger_pct = ag_hunger_pct/436 if rural==0 & wave==2 & ag_hh==1
replace ag_hunger_pct = ag_hunger_pct/2285 if rural==1 & wave==1 & ag_hh==1
replace ag_hunger_pct = ag_hunger_pct/2705 if rural==1 & wave==2 & ag_hh==1
graph bar (mean) all_hunger_pct ag_hunger_pct if rural==1 & wave==1, over(hunger_cat) ytitle("Percent") title("Wave 1 - Rural Households") legend(off) b1title("Number of months hungry in previous year") name(allrw1) ylabel(0(0.1)0.8)
graph bar (mean) all_hunger_pct ag_hunger_pct if rural==1 & wave==2, over(hunger_cat) ytitle("Percent") title("Wave 2 - Rural Households") legend(off) b1title("Number of months hungry in previous year") name(allrw2) ylabel(0(0.1)0.8)
graph bar (mean) all_hunger_pct ag_hunger_pct if rural==0 & wave==1, over(hunger_cat) ytitle("Percent") title("Wave 1 - Urban Households") legend(off) b1title("Number of months hungry in previous year") name(agrw1) ylabel(0(0.1)0.8)
graph bar (mean) all_hunger_pct ag_hunger_pct if rural==0 & wave==2, over(hunger_cat) ytitle("Percent") title("Wave 2 - Urban Households") legend(off) b1title("Number of months hungry in previous year") name(agrw2) legend(order(1 "All Households" 2 "Ag Households")) ylabel(0(0.1)0.8)
******************
*    Figure 2    *
******************
graph combine allrw1 allrw2
grc1leg agrw1 agrw2
*To get figure 3, we need to call previously created data (at the month level)
preserve
use `hunger_vars', clear
gen hunger_ag = hunger if ag_hh==1
graph drop _all
graph bar (mean) hunger hunger_ag if wave==1 & rural==1 [pweight=weight], over(month, label(angle(90))) ylabel(0(0.05)0.55) ytitle("Proportion of Households Hungry") title("Wave 1 - Rural Households") name(f3rw1) legend(off)
graph bar (mean) hunger hunger_ag if wave==2 & rural==1 [pweight=weight], over(month, label(angle(90))) ylabel(0(0.05)0.55) ytitle("Proportion of Households Hungry") title("Wave 2 - Rural Households") name(f3rw2) legend(off)
graph bar (mean) hunger hunger_ag if wave==1 & rural==0 [pweight=weight], over(month, label(angle(90))) ylabel(0(0.05)0.55) ytitle("Proportion of Households Hungry") title("Wave 1 - Urban Households") name(f3uw1) legend(label(1 "All Households") label(2 "Ag Households"))
graph bar (mean) hunger hunger_ag if wave==2 & rural==0 [pweight=weight], over(month, label(angle(90))) ylabel(0(0.05)0.55) ytitle("Proportion of Households Hungry") title("Wave 2 - Urban Households") name(f3uw2) legend(label(1 "All Households") label(2 "Ag Households"))
******************
*    Figure 3    *
******************
graph combine f3rw1 f3rw2, ycommon
grc1leg f3uw1 f3uw2, ycommon
*****************
*    Table 2    *
* Harvest Stats *
*****************
*This includes January through April so that we can look at both urban and rural households
collapse (max) seasonal_hunger=pre_harv_hunger_ALL nonseasonal_hunger=chronic_month_hunger_ALL (sum) pre_harv_hunger_ALL nonseasonal_hunger_count=chronic_month_hunger_ALL (firstnm) rural weight ag_hh, by(hhid wave)
*Panel A
mean seasonal_hunger if rural==0 [pweight=weight]
mean seasonal_hunger if rural==1 [pweight=weight]
mean pre_harv_hunger if rural==0 [pweight=weight]
mean pre_harv_hunger if rural==1 [pweight=weight]
mean seasonal_hunger if rural==0 & nonseasonal_hunger==0 [pweight=weight]
mean seasonal_hunger if rural==1 & nonseasonal_hunger==0 [pweight=weight]
*Panel B
mean nonseasonal_hunger if rural==0 [pweight=weight]
mean nonseasonal_hunger if rural==1 [pweight=weight]
mean nonseasonal_hunger_count if rural==0 [pweight=weight]
mean nonseasonal_hunger_count if rural==1 [pweight=weight]
mean nonseasonal_hunger if rural==0 & seasonal_hunger==0 [pweight=weight]
mean nonseasonal_hunger if rural==1 & seasonal_hunger==0 [pweight=weight]
*****************
*   Table A2    *
* Harvest Stats *
*****************
*Panel A
mean seasonal_hunger if rural==0 & ag_hh==1 [pweight=weight]
mean seasonal_hunger if rural==1 & ag_hh==1 [pweight=weight]
mean pre_harv_hunger if rural==0 & ag_hh==1 [pweight=weight]
mean pre_harv_hunger if rural==1 & ag_hh==1 [pweight=weight]
mean seasonal_hunger if rural==0 & nonseasonal_hunger==0 & ag_hh==1 [pweight=weight]
mean seasonal_hunger if rural==1 & nonseasonal_hunger==0 & ag_hh==1 [pweight=weight]
*Panel B
mean nonseasonal_hunger if rural==0 & ag_hh==1 [pweight=weight]
mean nonseasonal_hunger if rural==1 & ag_hh==1 [pweight=weight]
mean nonseasonal_hunger_count if rural==0 & ag_hh==1 [pweight=weight]
mean nonseasonal_hunger_count if rural==1 & ag_hh==1 [pweight=weight]
mean nonseasonal_hunger if rural==0 & seasonal_hunger==0 & ag_hh==1 [pweight=weight]
mean nonseasonal_hunger if rural==1 & seasonal_hunger==0 & ag_hh==1 [pweight=weight]
restore
*Descriptive regressions
*ologit
eststo ologit1: ologit pre_harv_hunger age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert [pweight=weight] if wave==1
eststo ologit3: ologit pre_harv_hunger age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert simpson_previous any_perm_food poultry_num ///
other_num stored_crop remittances any_wage sales_dum_perm [pweight=weight] if wave==1
eststo ologit5: ologit pre_harv_hunger age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert [pweight=weight] if wave==2, vce(robust)
eststo ologit7: ologit pre_harv_hunger age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert simpson_previous any_perm_food poultry_num ///
other_num stored_crop remittances any_wage sales_dum_perm [pweight=weight] if wave==2, vce(robust)
********************
*      Table 3     *
* Descriptive Regs *
********************
*ologit only
esttab ologit1 ologit3 ologit5 ologit7, cells(b(fmt(4) star) se(fmt(4) par)) replace starlevels(* 0.1 ** 0.05 *** 0.01) label stats(N, fmt(0 3)) onecell keep(age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert simpson_previous any_perm_food poultry_num other_num stored_crop remittances any_wage sales_dum_perm) mlabels("Wave 1, Model 1" "Wave 1, Model 2" "Wave 2, Model 1" "Wave 2, Model 2") rtf eform
*ologit table 4
eststo reg1: ologit pre_harv_hunger i.ea_wave age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert [pweight=weight], vce(robust)
eststo reg2: ologit pre_harv_hunger i.ea_wave age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert simpson_previous any_perm_food ///
poultry_num other_num stored_crop remittances any_wage sales_dum_perm [pweight=weight]
*******************
*     Table 4     *
* EA/Wave FE Regs *
*******************
esttab reg1 reg2, cells(b(fmt(4) star) se(fmt(4) par)) starlevels(* 0.1 ** 0.05 *** 0.01) label stats(N, fmt(0 3)) onecell keep(age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert simpson_previous any_perm_food poultry_num other_num stored_crop remittances any_wage sales_dum_perm) rtf eform
*Hunger and date of harvest
*OLS
*Any harvest
eststo date5: areg month_start pre_harv_hunger hhsize male_head acres other_num poultry_num rain i.wave##i.region [pweight=panel_weight] if split==1 | wave==1, cluster(hhfe) absorb(hhfe)
*Maize harvest
eststo date6: areg month_start_maize pre_harv_hunger hhsize male_head acres other_num poultry_num rain i.wave##i.region [pweight=panel_weight] if split==1 | wave==1, cluster(hhfe) absorb(hhfe)
*OLOGIT
*Any harvest
eststo date7: ologit month_start i.hhfe pre_harv_hunger hhsize male_head acres other_num poultry_num rain i.wave##i.region [pweight=panel_weight] if split==1 | wave==1, cluster(hhfe) or
*margins, dydx(pre_harv_hunger hhsize male_head acres other_num poultry_num rain) atmeans
*Maize harvest
eststo date8: ologit month_start_maize i.hhfe pre_harv_hunger hhsize male_head acres other_num poultry_num rain i.wave##i.region [pweight=panel_weight] if split==1 | wave==1, cluster(hhfe) or
*margins, dydx(pre_harv_hunger hhsize male_head acres other_num poultry_num rain) atmeans
****************
*   Table 5    *
* HHID FE Regs *
****************
esttab date5 date6, b(3) se(3) par starlevels(* 0.1 ** 0.05 *** 0.01) label keep(pre_harv_hunger hhsize male_head acres other_num poultry_num rain) order(pre_harv_hunger hhsize male_head acres other_num poultry_num rain) coeflabels(rain "Rainfall") stats(N r2, fmt(0 3)) mlabels("Start of harvest" "Start of maize harvest") replace onecell rtf
esttab date7 date8, b(3) se(3) par starlevels(* 0.1 ** 0.05 *** 0.01) label keep(pre_harv_hunger hhsize male_head acres other_num poultry_num rain) order(pre_harv_hunger hhsize male_head acres other_num poultry_num rain) coeflabels(rain "Rainfall") stats(N, fmt(0)) mlabels("Start of harvest" "Start of maize harvest") replace onecell rtf eform
*Checks for multicollinearity
corr pre_harv_hunger age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert simpson_previous any_perm_food ///
poultry_num other_num stored_crop remittances any_wage sales_dum_perm					// highest: 0.3826
reg pre_harv_hunger age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert simpson_previous any_perm_food ///
poultry_num other_num stored_crop remittances any_wage sales_dum_perm
vif					// Highest: 1.24, well below commonly used cut-off of 10 (Wooldridge, 2009)
reg pre_harv_hunger age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert simpson_previous any_perm_food ///
poultry_num other_num stored_crop remittances any_wage sales_dum_perm
vce, corr
*Differences at the household level (testing for collinearity in the differences since it is fixed effects):
foreach i in pre_harv_hunger hhsize male_head log_acres other_num poultry_num rain{
	bys hhfe (wave): gen `i'_diff = `i'-`i'[_n-1]
}
corr *_diff			// highest: 0.1527
*Testing for heteroskedasticity
reg pre_harv_hunger age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert [pweight=weight]
whitetst			// p-value=0.0000

