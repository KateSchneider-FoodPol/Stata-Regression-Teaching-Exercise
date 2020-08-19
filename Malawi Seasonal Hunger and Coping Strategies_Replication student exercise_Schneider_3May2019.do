/* Created by Kate Schneider
kate.schneider@tufts.edu
Last modified: 19 May 2019

Based on the paper by Anderson et al (2018):
	"Relating Seasonal Hunger and and Prevention and Coping Strategies: 
	A Panel Analysis of Malawian Farm Households"

Original Code can be found at: 
	https://github.com/EvansSchoolPolicyAnalysisAndResearch/337_Seasonal-Hunger-Malawi
Published Paper available at: 
	https://evans.uw.edu/sites/default/files/Relating%20Seasonal%20Hunger%20and%20Prevention%20and%20Coping%20Strategies%20A%20Panel%20Analysis%20of%20Malawian%20Farm%20Households.pdf
More info on the University of Washington EPAR website: 
	https://evans.uw.edu/policy-impact/epar/research/seasonal-hunger-and-coping-and-prevention-strategies-malawi
*/

/// PART 1: GET SET UP
* Set your working directory
cd "yourfilepath"
	* If you do not know what your working directory is or how to specify the filepath:
	pwd
	* On library computers, set the working directory to the desktop

* Download the dataset from canvas and save the file to your working directory file
* On library computers: save to the desktop

* Start a log file, especially if you don't have Stata on your own computer
	/* The log file will have a printout of all your commands and results so you can
		look back at your findings any time (like when you need to answer HW questions) */
	cap log close
	log using MalawiHunger_Replication, replace
	* Put today's date, name of the exercise, and your name at the top of your log file
	display "`c(current_time)' `c(current_date)'"
	display "Replication of Anderson (2018) Paper on Seasonal Hunger in Malawi"
	display "yourname"
	
* Load the dataset:
use Malawi_Hunger_EPAR, clear
	
* Good housekeeping
set more off
clear matrix
lab drop _all
set matsize 800 // If you get an error in the Table 4 regression below, you forgot to run this line

* We will be replicating the analysis in the Anderson et al (2018) paper
* So start by exploring the data

/// PART 2: EXPLORE THE DATA

* Essential first steps: look at all the data
describe
sum 

	* How many households are in the total analysis?
	sum hhid
		* Hmm, that didn't work?
		describe hhid
		* Ah ha! It's a string variable
		* Let's destring
		destring hhid, replace
		* Oops, we can't because the ID's aren't all numbers
		encode hhid, gen(hhid_num)
		lab var hhid_num "Numeric HHID"
		sum hhid_num
		
	* How many households have observations in both waves?
	tab wave_count

* These are complex survey data, explore the geographic and survey wave variables
	* We could do a separate tab for each of these variables, or we could use a loop
	* Loops tell Stata to do the same thing over again for multiple variables
	foreach variable in stratum region district ta rural ym_int wave {
		tab `variable'
		}
	* What variable is the survey weight? Does it have any missing observations?
	misstable sum weight // No missing observations

/// PART 3: SUMMARY STATISTICS
	
* Household characteristics: Let's replicate table 1
	* Notice you need to calculate separate statistics for wave 1 and wave 2
	sum age_head educ_head male_head hhsize dist_road rain acres crop_count orgfert ///
		inorgfert simpson_previous poultry_num other_num stored_crop ///
		remittances any_wage sales_dum_perm any_perm_food rural ag_hh if wave==1
	sum age_head educ_head male_head hhsize dist_road rain acres crop_count orgfert ///
		inorgfert simpson_previous poultry_num other_num stored_crop ///
		remittances any_wage sales_dum_perm any_perm_food rural ag_hh if wave==2
	
	* But these are ugly, let's format nicely with esttab
	eststo sum1: estpost sum age_head educ_head male_head hhsize dist_road rain ///
		acres crop_count orgfert inorgfert simpson_previous poultry_num other_num stored_crop ///
		remittances any_wage sales_dum_perm any_perm_food rural ag_hh if wave==1
	eststo sum2: estpost sum age_head educ_head male_head hhsize dist_road rain ///
		acres crop_count orgfert inorgfert simpson_previous poultry_num other_num stored_crop ///
		remittances any_wage sales_dum_perm any_perm_food rural ag_hh if wave==2
	esttab sum1 sum2 using table1.rtf, label replace cells("mean(fmt(3)) sd(fmt(3) par)") ///
		mlabels("Wave 1" "Wave 2") title("Summary Statistics, Table 1 replication") ///
		collabels("Mean" "St. Dev." "Mean" "St. Dev.")
		
	* In the appendix, they provide summary statistics for agricultural households only
		* Let's create a summary table with only agricultural households 
		* Do you need to include the ag_hh variable this time? 
		eststo sum3: estpost sum age_head educ_head male_head hhsize dist_road rain ///
			acres crop_count orgfert inorgfert simpson_previous poultry_num other_num stored_crop ///
			remittances any_wage sales_dum_perm any_perm_food rural ///
				if wave==1 & ag_hh==1 
		eststo sum4: estpost sum age_head educ_head male_head hhsize dist_road rain ///
			acres crop_count orgfert inorgfert simpson_previous poultry_num other_num stored_crop ///
			remittances any_wage sales_dum_perm any_perm_food rural ///
			if wave==2 & ag_hh==1 
		esttab sum3 sum4 using table1_agonly.rtf, label replace cells("mean(fmt(3)) sd(fmt(3) par)") ///
			mlabels("Wave 1" "Wave 2") title("Summary Statistics, Agricultural Households Only") ///
			collabels("Mean" "St. Dev." "Mean" "St. Dev.")
			
/// PART 4: OUTCOME OF INTEREST

* Let's explore the outcome variable - Preharvest Hunger
	* There are several variables with hunger in them - which one should we use?
	* Let's first identify the variables
		* Pro-tip: Notice here we don't have to use the whole variable name
		sum *hunger*
		describe *hunger*
	* Let's find out what each of these variables mean using another loop
		* Pro-tip: Also notice we can assign any name to the variable list
		* We used "variable" above, but here we just use "v"
		foreach v of varlist *hunger* {
			tab `v', m
			}
	* Which variable is the outcome used in the paper? 
		* pre_harv_hunger
	* What type of variable is this? (Hint: what's the range of values it takes)
		* This is a count variable 
		tab pre_harv_hunger
		* It takes the values 0, 1, 2, 3, 4
	* Does this variable look normally distributed?
		hist pre_harv_hunger
		* Houston, we have a problem.
		* This variable is not normally distributed, but it's also not binary.
			* We can't use OLS or logit - should we despair?
			* There are models for these kind of data, like ordered logit that
			*	the authors use in the paper
			
* Since we don't know about ordered logit models, let's use a binary outcome instead

* Are any of the hunger variables binary?
	tab any_hunger
	* Hmm, the authors didn't label the any_hunger variable
	* How can we tell if this is any pre-harvest hunger or any hunger in the whole year?
		tab2 pre_harv_hunger any_hunger
		tab2 hunger any_hunger
	* Looks like any_hunger is a dummy variable of experiencing any hunger at all

* But we're interested in SEASONAL hunger, so let's create our own dummy variable
	* Generate a binary variable for any preharvest hunger (0=none, 1=any)
	tab pre_harv_hunger, m
		* Notice there are 5 missing observations
		* We don't want to assign these households a value in our new dummy variable
	gen any_preharv_hunger=.
		replace any_preharv_hunger=0 if pre_harv_hunger==0
		replace any_preharv_hunger=1 if pre_harv_hunger>0 & pre_harv_hunger!=.
	* Check - we should have 7,207 observations with a value and 5 missing
		tab any_preharv_hunger, m

	* Label the variable
	lab var any_preharv_hunger "Experience any preharvest hunger"
	* Label the values
	lab def yesno 0 "No" 1 "Yes"
	lab val any_preharv_hunger yesno

/// PART 4: REGRESSION ANALYSIS

****
* Now let's replicate Tables 3 and 4 with our binary outcome
****

***** Table 3 performs simple logit regressions for each wave separately
	* Since we don't have fixed effects here, we could use Stata's svy settings
	* But svy doesn't work well with fixed effects, so we use the survey weight manually instead
	* Remember to report odds ratios
	* Notice colums 2 and 4 includes additional control variables
* TABLE 3
	* The structure for our command is:
		* essto modelname: logit y x1 x2 ... xn [pweight=weight] if wave==#, or
	eststo logit1: logit any_preharv_hunger age_head educ_head male_head hhsize dist_road rain ///
		acres orgfert inorgfert [pweight=weight] if wave==1, or
	eststo logit2: logit any_preharv_hunger age_head educ_head male_head hhsize dist_road rain ///
		acres orgfert inorgfert simpson_previous any_perm_food poultry_num ///
		other_num stored_crop remittances any_wage sales_dum_perm [pweight=weight] if wave==1, or
	eststo logit3: logit any_preharv_hunger age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert [pweight=weight] if wave==2, vce(robust) or
	eststo logit4: logit any_preharv_hunger age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert simpson_previous any_perm_food poultry_num ///
		other_num stored_crop remittances any_wage sales_dum_perm [pweight=weight] if wave==2, vce(robust) or
	// Table 3:
	esttab logit1 logit2 logit3 logit4 using table3.rtf, cells(b(fmt(4) star) se(fmt(4) par)) replace starlevels(* 0.1 ** 0.05 *** 0.01) ///
		label stats(N, fmt(0 3)) onecell nodepvars keep(age_head educ_head male_head hhsize dist_road rain acres orgfert inorgfert ///
		simpson_previous any_perm_food poultry_num other_num stored_crop remittances any_wage sales_dum_perm) ///
		mlabels("Wave 1, Model 1" "Wave 1, Model 2" "Wave 2, Model 1" "Wave 2, Model 2") collabels("OR (se)") ///
		title("Table 3, Any Seasonal Hunger and Household Characteristics") rtf eform nonotes ///
		addnotes("The outcome variable is a binary variable equal to 1 if the household reported any hunger during the three months prior to harvest, plus the month of first harvest by that household. Coefficients are odds ratios from logit regressions. Standard errors are in parentheses. * p < 0.10 ** p < 0.05 *** p < 0.01")
		/* Pro tip: even if you did not specify the "or" option in the regression model, when you
			use the "eform" option in esttab, it will put odds ratios in your table.
		   BUT: this doesn't work the other way around, if you specify or in the regression
			and forget "eform" in esttab, the unexponentiated coefficients will appear in your table. */
			
	//////////////////////////////////////////////////////////////////////////////////////////////
		// For those who are curious
		// Compare the wave 1 regressions using survey versus the manual weights
		
		* Here are the survey settings:
		svyset ea_id [pweight=weight], strata(stratum)
		
		* Now compare table 3 model 1 using survey settings instead of the manual pweight
			* Notice that with survey settings you need to specify the wave as a subpopulation 
			eststo survey1: svy, subpop(if wave==1): logit any_preharv_hunger age_head educ_head ///
				male_head hhsize dist_road rain acres orgfert inorgfert, or
			eststo nosvy1: logit any_preharv_hunger age_head educ_head male_head hhsize dist_road ///
				rain acres orgfert inorgfert [pweight=weight] if wave==1, or
			esttab survey1 nosvy1
		* Hopefully we've convinced you all that our manual weights do the same thing as svy :)
	//////////////////////////////////////////////////////////////////////////////////////////////

***** Table 4 pools the data for both survey waves and uses fixed effects
	* As noted in the paper, the fixed effect is at the level of the primary sampling unit
	* The PSU is the enumeration area, the variable ea_wave is the fixed effects variable
	
* TABLE 4
	* The structure for our command is:
		* essto modelname: logit y i.ea_wave x1 x2 ... xn [pweight=weight] if wave==#, vce(robust) or
	* Notice that with fixed effects, we also have to specify robust standard errors
	eststo fe1: logit any_preharv_hunger i.ea_wave age_head educ_head male_head hhsize dist_road rain ///
		acres orgfert inorgfert [pweight=weight], vce(robust) or
	eststo fe2: logit any_preharv_hunger i.ea_wave age_head educ_head male_head hhsize dist_road rain ///
		acres orgfert inorgfert simpson_previous any_perm_food ///
		poultry_num other_num stored_crop remittances any_wage sales_dum_perm [pweight=weight], or
	esttab fe1 fe2 using table4.rtf, cells(b(fmt(4) star) se(fmt(4) par)) replace starlevels(* 0.1 ** 0.05 *** 0.01) ///
		label stats(N, fmt(0 3)) collabels("OR/se") onecell keep(age_head educ_head male_head hhsize ///
		dist_road rain acres orgfert inorgfert simpson_previous any_perm_food poultry_num other_num ////
		stored_crop remittances any_wage sales_dum_perm) rtf eform ///
		mlabels("EA/Wave fixed effects, Model 1" "EA/Wave fixed effects, Model 2") ///
		title("Table 4, Any Seasonal Hunger and Household Characteristics") nonotes ///
		addnotes("The outcome variable is a binary variable equal to 1 if the household reported any hunger during the three months prior to harvest, plus the month of first harvest by that household. Coefficients are odds ratios from logit regressions. Regressions include enumeration area/Wave fixed effects. * p < 0.10 ** p < 0.05 *** p < 0.01")

/// PART 5: REFLECTIONS
/*
Now compare your results to tables 3 and 4 in the paper
Are your results using the binary outcome different from those the authors found with the
	count outcome?
	* Do you arrive at the same conclusions about the statistical significance of each predictor?
		o Yes, the same variables are statistically significant in the same
			models as the authors found.
	* What do you find about the magnitude of the odds ratio comparing your binary outcome 
		to the count outcome in the paper?
		o Using the binary outcome results in only minor differences to the 
			estimates of the odds ratios
	* What would a researcher consider when choosing to use a binary or count outcome variable?
	  What are some advantages and disadvantages of using a binary outcome when you have count data?
			o The binary outcome might be easier to interpret comparing those who experience 
				any pre-harvest hunger to those who experience none	
			o But you give up information - there could be important differences between households 
				who experience only 1 month of pre-harvest hunger and those who experience 4
*/
