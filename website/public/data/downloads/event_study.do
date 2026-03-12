* =============================================================================
* FEAR: Flood Exposure Asset Repricing
* =============================================================================
* Econ 66: Topics in Money and Finance
* Cameron Keith
* Professor Gupta
* Winter 2026
* =============================================================================

* =============================================================================
* Event Study: Effect of LOMR Flood Zone Reclassification on Home Values
* =============================================================================
*
* When FEMA issues a Letter of Map Revision (LOMR), it officially updates the
* flood risk designation for affected properties. If property markets fully
* capitalize flood risk, home values should adjust to reflect the revised risk.
* We exploit the staggered timing of LOMRs across US coastal zip codes to test
* whether — and how completely — this repricing occurs.
*
* Treatment includes ALL effective LOMRs, not just those crossing the SFHA
* boundary. This captures the broad informational effect of flood map revisions.
* SFHA-crossing LOMRs (which trigger or remove mandatory insurance requirements)
* are examined separately in section 9d as a subsample check.
*
* Regression:
*   ln(ZHVI_{z,t}) = α_z + δ_{c(z),y(t)} + Σ β_τ · 1[t − E_z = τ] + γ X_{z,t} + ε_{z,t}
*
*   where t indexes quarters, c(z) maps zip to county, y(t) maps quarter to year
*
* Identification:
*   - Zip FE (α_z) absorb time-invariant zip characteristics
*   - County×year FE (δ_{c(z),y(t)}) absorb county-level annual housing cycles
*   - β_τ: effect at τ years relative to LOMR effective date
*   - Reference period: τ = -1 (12-0 months pre-LOMR)
*   - SE clustered at county level
*
* Sample:
*   - Coastal zips, 2009-2022 (bound by NFIP policy data)
*   - Drops already-treated zips (LOMR before 2009) from event study
*   - Controls: never-treated + not-yet-treated zips
*
* Required packages (uncomment to install):
*   ssc install ftools, replace
*   ssc install reghdfe, replace
*   ssc install estout, replace
*   ssc install bacondecomp, replace
*   ssc install drdid, replace
*   ssc install csdid, replace
*   ftools, compile
*   reghdfe, compile

*
* =============================================================================

* --- PATHS ---
global root "/Users/cameronkeith/Desktop/Econ/Econ 66/Research Paper/econ66-fear"
global clean "$root/data/clean"
global output "$root/output"
global results "$output/results"
cap mkdir "$output"
cap mkdir "$results"

capture log using "$output/event_study.log", text replace
clear all
set more off
set scheme s2color

* --- SAMPLE RESTRICTION ---
* Set to 0 for full sample; >1000 = Census urban definition
global density_min 0
* Set to 0 for full sample; e.g. 10000 for thick housing markets
global pop_min 0
* Set to 0 for full time range; e.g. 2015 to restrict to post-2015
global year_min 0


* =============================================================================
* 1. IMPORT AND PREPARE DATA
* =============================================================================

import delimited "$clean/regression_panel.csv", clear stringcols(1 2 3 6 7 8 12)

* --- Generate Stata date variables ---
gen date_stata = date(date, "YMD")
format date_stata %td

di "Monthly panel loaded: " _N " zip-month observations"

* --- Collapse to quarterly panel ---
* ZHVI is a 3-month smoothed index; monthly obs are autocorrelated.
* Quarterly aggregation reduces noise without losing information.
gen yq = qofd(date_stata)
format yq %tq

* Save zip-level string attributes (collapse requires numeric)
preserve
bysort zip: keep if _n == 1
keep zip county_fips state_id state_name first_lomr_date
tempfile zip_strings
save `zip_strings'
restore

* Destring county_fips for collapse
destring county_fips, gen(county_id) force

* Drop string variables before collapse (merge back after)
drop year_month date county_fips state_id state_name first_lomr_date date_stata

collapse (mean) zhvi real_zhvi ln_real_zhvi ln_zhvi event_time ///
    unemployment_rate n_policies total_premium avg_premium sfha_share ///
    n_claims total_paid ///
    (max) treated ///
    (first) county_id ever_treated treated_in_window already_treated ///
    n_lomrs treatment_intensity population density, ///
    by(zip yq)

* Merge back string attributes
merge m:1 zip using `zip_strings', assert(match) nogenerate

di "Quarterly panel: " _N " zip-quarter observations"

* --- Reconstruct date and FE variables ---
gen date_stata = dofq(yq)
format date_stata %td
encode zip, gen(zip_id)
gen yr = year(date_stata)
egen county_yr = group(county_id yr)   // county × year FE identifier

* --- Label variables ---
label var real_zhvi    "Home Value Index (Dec 2022 $)"
label var ln_real_zhvi "ln(Real ZHVI)"
label var zhvi         "Home Value Index (nominal $)"
label var ln_zhvi      "ln(Nominal ZHVI)"
label var treated      "Post-LOMR"
label var ever_treated "Ever Treated"
label var event_time   "Months Since LOMR (qtr avg)"
label var n_lomrs      "Num. LOMRs in Zip"
label var unemployment_rate "County Unemp. Rate (%)"
label var n_policies   "NFIP Policies (qtr avg)"
label var avg_premium  "NFIP Avg Premium ($)"
label var sfha_share   "SFHA Zone Share"
label var n_claims     "NFIP Claims (qtr avg)"
label var total_paid   "NFIP Claims Paid ($)"
label var population   "Zip Population"
label var density      "Zip Pop. Density"
label var treatment_intensity "Treatment Intensity (LOMR/ZCTA)"

qui tab zip_id
di "Unique zips: " r(r)
qui tab yq
di "Unique quarters: " r(r)


* =============================================================================
* 1b. MERGE ELECTION DATA (needed for summary stats + section 9c)
* =============================================================================

preserve
import delimited "$clean/election_county_year.csv", clear stringcols(1)
collapse (mean) rep_share, by(county_fips)
rename rep_share mean_rep_share
tempfile election
save `election'
restore

merge m:1 county_fips using `election', keep(master match) nogenerate

* Binary split: above-median Republican two-party vote share
* Note: zips with missing election data are coded as republican = . (not 0)
* and excluded from the republican interaction analysis via Stata's missing rules
qui sum mean_rep_share, detail
local rep_median = r(p50)
gen republican = (mean_rep_share >= `rep_median') if !missing(mean_rep_share)

label var republican "Republican County"
label var mean_rep_share "R Two-Party Vote Share"


* =============================================================================
* 1c. MERGE DISCLOSURE LAWS (needed for summary stats + section 9b)
* =============================================================================

gen state_fips2 = substr(county_fips, 1, 2)

preserve
import delimited "$root/data/raw/state-disclosure-laws/disclosure_laws.csv", clear stringcols(1)
keep state_fips has_mandatory_disclosure
rename state_fips state_fips2
tempfile disc_laws
save `disc_laws'
restore

merge m:1 state_fips2 using `disc_laws', keep(master match) nogenerate
replace has_mandatory_disclosure = 0 if has_mandatory_disclosure == .
gen disc = has_mandatory_disclosure

* Broad disclosure: strict 9 states + FL, VA, NC, NY
* FL: common-law duty (Johnson v. Davis, 1985) + federal mortgage flood determination
* VA: Residential Property Disclosure Act flood question (2017 amendments)
* NC: Residential Property Disclosure Statement floodplain question
* NY: attorney-standard transactions with routine flood zone due diligence
gen disc_broad = disc
replace disc_broad = 1 if inlist(state_id, "FL", "VA", "NC", "NY")
drop state_fips2

label var disc "Disclosure: Strict (9 states)"
label var disc_broad "Disclosure: Broad (13 states)"

* =============================================================================
* 1d. MERGE RISK DIRECTION (needed for summary stats + section 9)
* =============================================================================

preserve
import delimited "$clean/nfip_lomr_deltas.csv", clear stringcols(1)
keep zip risk_direction zone_risk_direction delta_policies delta_sfha_share
tempfile deltas
save `deltas'
restore

merge m:1 zip using `deltas', keep(master match) nogenerate

gen upzoned   = (zone_risk_direction == "up")
gen downzoned = (zone_risk_direction == "down")

label var upzoned   "Upzoned (into SFHA)"
label var downzoned "Downzoned (out of SFHA)"

* =============================================================================
* 2. EVENT STUDY SAMPLE
* =============================================================================

* Drop already-treated zips (LOMR before analysis window — no clean pre-period)
* Keep: treated_in_window (treatment group) + never-treated (control)
drop if already_treated == 1

* Drop multi-LOMR zips (noisy treatment timing from overlapping revisions)
drop if n_lomrs > 1
di "Dropped multi-LOMR zips (n_lomrs > 1)"

* Drop zips with zero population (no analytic weight, pollute summary stats)
drop if population == 0 | population == .
di "Dropped zero-population zips"

* Winsorize ln(Real ZHVI) at 1st/99th percentile to reduce outlier noise
qui sum ln_real_zhvi, detail
replace ln_real_zhvi = r(p1)  if ln_real_zhvi < r(p1)
replace ln_real_zhvi = r(p99) if ln_real_zhvi > r(p99) & ln_real_zhvi != .
di "Winsorized ln_real_zhvi at 1st/99th percentiles"

* Restrict to urban zips (if density_min > 0)
if $density_min > 0 {
    drop if density < $density_min
    di "Restricted to zips with density >= $density_min per sq mi"
}

* Restrict to minimum population (if pop_min > 0)
if $pop_min > 0 {
    drop if population < $pop_min
    di "Restricted to zips with population >= $pop_min"
}

* Restrict to recent years (if year_min > 0)
if $year_min > 0 {
    drop if year(date_stata) < $year_min
    di "Restricted to observations from $year_min onward"
}

di "Event study sample: " _N " zip-quarter observations"
tab ever_treated

* --- Balance table: treated vs control pre-treatment characteristics ---
* Compares pre-LOMR means for treated zips vs all-period means for controls.
preserve

gen pre_treatment = (event_time < 0) | (ever_treated == 0)
keep if pre_treatment == 1

collapse (mean) real_zhvi unemployment_rate n_policies ///
    avg_premium sfha_share n_claims ///
    (first) ever_treated population density, ///
    by(zip)

label var real_zhvi         "Home Value (Dec 2022 $)"
label var population        "Population"
label var density           "Pop. Density (per sq mi)"
label var unemployment_rate "County Unemp. Rate (%)"
label var n_policies        "NFIP Policies (qtr avg)"
label var avg_premium       "NFIP Avg Premium ($)"
label var sfha_share        "SFHA Zone Share"
label var n_claims          "NFIP Claims (qtr avg)"

estpost ttest real_zhvi population density unemployment_rate ///
    n_policies avg_premium sfha_share n_claims, by(ever_treated) unequal

esttab using "$results/s03_balance_table.tex", replace ///
    cells("mu_1(fmt(%12.2fc)) mu_2(fmt(%12.2fc)) b(fmt(%12.2fc) star)") ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    collabels("Control" "Treated" "Difference") ///
    noobs nonumber nomtitle label ///
    title("Balance Table: Pre-Treatment Characteristics") ///
    addnotes("Treated: zips with single LOMR during 2009-2022." ///
             "Control: zips with no LOMR." ///
             "Pre-treatment means reported for treated zips." ///
             "Difference = Treated - Control. Welch t-test.")

esttab using "$results/s03_balance_table.csv", replace ///
    cells("mu_1(fmt(%12.2f)) mu_2(fmt(%12.2f)) b(fmt(%12.2f) star)") ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    collabels("Control" "Treated" "Difference") ///
    noobs nonumber nomtitle label plain

di _n "Balance table saved to $results/s03_balance_table.tex/csv"

restore

* =============================================================================
* 2b. DERIVED VARIABLES (needed for summary stats)
* =============================================================================

* --- Policy intensity: pre-LOMR avg policies / population ---
bysort zip: egen _pre_policies = mean(cond(event_time < 0 | ever_treated == 0, n_policies, .))
gen policy_intensity = _pre_policies / population
replace policy_intensity = 0 if missing(policy_intensity)
drop _pre_policies
label var policy_intensity "Policy Intensity"
sum policy_intensity, detail

* Drop zips with implausible policy intensity (> 1 = corrupted population data)
di _n "=== Dropping zips with policy_intensity > 1 (data errors) ==="
levelsof zip if policy_intensity > 1, local(bad_zips)
foreach z of local bad_zips {
    di "  Dropping zip `z': intensity = " policy_intensity[1] " (pop corrupted)"
}
drop if policy_intensity > 1

* --- Log outcomes for insurance mechanism tests ---
gen ln_policies = ln(n_policies + 1)
gen ln_claims   = ln(n_claims + 1)
label var ln_policies "ln(NFIP Policies + 1)"
label var ln_claims   "ln(NFIP Claims + 1)"

* --- SFHA-crossing indicator (upzoned or downzoned) ---
gen sfha_crossing = (zone_risk_direction == "up" | zone_risk_direction == "down")
replace sfha_crossing = 0 if ever_treated == 0
label var sfha_crossing "SFHA-Crossing LOMR"

* =============================================================================
* 3. SUMMARY STATISTICS TABLE (on estimation sample)
* =============================================================================

* Panel A: Outcomes
* Panel B: Treatment
* Panel C: Controls
* Panel D: Heterogeneity

* Rescale intensities for display (per 1,000 residents)
gen policy_intensity_k = policy_intensity * 1000
gen treatment_intensity_k = treatment_intensity * 1000
label var policy_intensity_k "Policy Intensity (per 1,000)"
label var treatment_intensity_k "Treatment Intensity (per 1,000)"

estpost tabstat ///
    real_zhvi ln_real_zhvi ln_policies ln_claims ///
    treated ever_treated policy_intensity_k treatment_intensity_k ///
    upzoned downzoned sfha_crossing ///
    unemployment_rate n_policies avg_premium n_claims ///
    republican mean_rep_share disc disc_broad ///
    population density sfha_share, ///
    statistics(count mean sd min p25 p50 p75 max) columns(statistics)

esttab using "$results/s02_summary_stats.tex", replace ///
    cells("count(fmt(%12.0fc)) mean(fmt(%12.2fc)) sd(fmt(%12.2fc)) min(fmt(%12.2fc)) p25(fmt(%12.2fc)) p50(fmt(%12.2fc)) p75(fmt(%12.2fc)) max(fmt(%12.2fc))") ///
    noobs nonumber nomtitle label ///
    refcat(real_zhvi "\textit{Panel A: Outcomes}" ///
           treated "\textit{Panel B: Treatment Variables}" ///
           unemployment_rate "\textit{Panel C: Controls}" ///
           republican "\textit{Panel D: Heterogeneity Measures}" ///
           population "\textit{Panel E: Sample Characteristics}", nolabel) ///
    title("Summary Statistics — Estimation Sample (2009-2022)")

esttab using "$results/s02_summary_stats.csv", replace ///
    cells("count mean(fmt(%12.2f)) sd(fmt(%12.2f)) min(fmt(%12.2f)) p25(fmt(%12.2f)) p50(fmt(%12.2f)) p75(fmt(%12.2f)) max(fmt(%12.2f))") ///
    noobs nonumber nomtitle label plain


* --- Create annual event-time bins ---
* ±4 years around LOMR (τ = -1 is reference)
* τ = -4: [-∞, -36) months before LOMR (endpoint bin)
* τ = -3: [-36, -24)
* τ = -2: [-24, -12)
* τ = -1: [-12,   0)  ← REFERENCE (omitted)
* τ =  0: [  0,  12)  ← First year post-LOMR
* τ = +1: [ 12,  24)
* τ = +2: [ 24,  36)
* τ = +3: [ 36,  48)
* τ = +4: [ 48,   ∞) (endpoint bin)

gen event_bin = .
replace event_bin = -4 if event_time < -36 & event_time != .
replace event_bin = -3 if event_time >= -36 & event_time < -24
replace event_bin = -2 if event_time >= -24 & event_time < -12
replace event_bin = -1 if event_time >= -12 & event_time < 0
replace event_bin =  0 if event_time >=   0 & event_time < 12
replace event_bin =  1 if event_time >=  12 & event_time < 24
replace event_bin =  2 if event_time >=  24 & event_time < 36
replace event_bin =  3 if event_time >=  36 & event_time < 48
replace event_bin =  4 if event_time >=  48 & event_time != .

tab event_bin, missing

* --- Create manual event-time dummies ---
* (Never-treated zips have event_bin = . → all dummies = 0, which is correct)
foreach t in m4 m3 m2 p0 p1 p2 p3 p4 {
    gen ebin_`t' = 0
}
replace ebin_m4 = 1 if event_bin == -4
replace ebin_m3 = 1 if event_bin == -3
replace ebin_m2 = 1 if event_bin == -2
* τ = -1 is OMITTED (reference)
replace ebin_p0 = 1 if event_bin == 0
replace ebin_p1 = 1 if event_bin == 1
replace ebin_p2 = 1 if event_bin == 2
replace ebin_p3 = 1 if event_bin == 3
replace ebin_p4 = 1 if event_bin == 4

label var ebin_m4 "τ = -4 (3+ yrs pre)"
label var ebin_m3 "τ = -3 (2-3 yrs pre)"
label var ebin_m2 "τ = -2 (1-2 yrs pre)"
label var ebin_p0 "τ = 0 (0-1 yr post)"
label var ebin_p1 "τ = +1 (1-2 yrs post)"
label var ebin_p2 "τ = +2 (2-3 yrs post)"
label var ebin_p3 "τ = +3 (3-4 yrs post)"
label var ebin_p4 "τ = +4 (4+ yrs post)"

* policy_intensity already computed and bad zips dropped in section 2b

* --- Create intensity-weighted event-time dummies ---
* Scales binary dummies by flood insurance penetration.
* Coefficient = effect at full policy penetration (intensity = 1).
foreach t in m4 m3 m2 p0 p1 p2 p3 p4 {
    gen ibin_`t' = ebin_`t' * policy_intensity
}
label var ibin_m4 "τ = -4 × intensity"
label var ibin_m3 "τ = -3 × intensity"
label var ibin_m2 "τ = -2 × intensity"
label var ibin_p0 "τ = 0 × intensity"
label var ibin_p1 "τ = +1 × intensity"
label var ibin_p2 "τ = +2 × intensity"
label var ibin_p3 "τ = +3 × intensity"
label var ibin_p4 "τ = +4 × intensity"


* =============================================================================
* 4. MAIN REGRESSION: EVENT STUDY
* =============================================================================

* --- Specification 1: No controls ---
reghdfe ln_real_zhvi ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
    [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_nocontrols

* --- Specification 2: With controls (main) ---
reghdfe ln_real_zhvi ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
    unemployment_rate n_policies [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_main

* --- Pre-period joint F-test (parallel trends) ---
di _n "=== Joint F-test: all pre-treatment coefficients = 0 ==="
testparm ebin_m4 ebin_m3 ebin_m2

* --- Specification 3: With full controls ---
reghdfe ln_real_zhvi ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
    unemployment_rate n_policies avg_premium n_claims [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_full

* --- Display regression table ---
esttab es_nocontrols es_main es_full using "$results/s04_regression_table.tex", replace ///
    keep(ebin_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("No Controls" "Main Controls" "Full Controls") ///
    title("ln(Real ZHVI) on LOMR Treatment") ///
    addnotes("Zip and county×year fixed effects." ///
             "Standard errors clustered at county level." ///
             "Reference period: 12-0 months before LOMR (τ = -1)." ///
             "Already-treated zips (LOMR before 2009) excluded." ///
             "(1) No controls. (2) Unemployment rate, NFIP policies. (3) Adds avg premium, claims.")

esttab es_nocontrols es_main es_full using "$results/s04_regression_table.csv", replace ///
    keep(ebin_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("No Controls" "Main Controls" "Full Controls") plain


* =============================================================================
* 5. EVENT STUDY COEFFICIENT PLOT
* =============================================================================

* Use main specification
estimates restore es_main

* --- Extract coefficients into plotting dataset ---
preserve
clear
set obs 9

gen tau = _n - 5              // -4, -3, -2, -1, 0, 1, 2, 3, 4
gen coef = .
gen se = .
gen ci_lo = .
gen ci_hi = .

* Reference period (τ = -1): normalized to zero
replace coef  = 0 if tau == -1
replace se    = 0 if tau == -1
replace ci_lo = 0 if tau == -1
replace ci_hi = 0 if tau == -1

* Fill from stored estimates
estimates restore es_main

local varlist "ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4"
local taulist "-4 -3 -2 0 1 2 3 4"
local i = 1
foreach v of local varlist {
    local t : word `i' of `taulist'
    replace coef  = _b[`v']                       if tau == `t'
    replace se    = _se[`v']                       if tau == `t'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v']     if tau == `t'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v']     if tau == `t'
    local i = `i' + 1
}

* Labels for x-axis
label define tau_lbl -4 "-4" -3 "-3" -2 "-2" -1 "-1" 0 "0" 1 "+1" 2 "+2" 3 "+3" 4 "+4"
label values tau tau_lbl

* --- Plot ---
twoway (rcap ci_hi ci_lo tau, lcolor(navy%50) lwidth(medthin)) ///
       (scatter coef tau, mcolor(navy) msymbol(circle) msize(medlarge)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(medium)) ///
    ytitle("Effect on ln(Real ZHVI)", size(medium)) ///
    title("Event Study: LOMR Effect on Home Values", size(large)) ///
    subtitle("Staggered DiD with zip and county-by-year fixed effects", size(medsmall)) ///
    xlabel(-4(1)4, labsize(medsmall)) ///
    ylabel(, labsize(medsmall) angle(horizontal) grid glcolor(gs14)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    note("Reference period: τ = -1 (12-0 months before LOMR). 95% CIs shown." ///
         "Controls: county unemployment, NFIP policies." ///
         "SE clustered at county level. Already-treated zips excluded.", ///
         size(vsmall) color(gs6))

graph export "$results/s05_event_study_main.png", replace width(1400)
graph export "$results/s05_event_study_main.pdf", replace

* Save coefficient data
export delimited using "$results/s05_event_study_coefficients.csv", replace

restore


* =============================================================================
* 6. TREATMENT INTENSITY SPECIFICATION
* =============================================================================
* Replaces binary event dummies with intensity-weighted dummies:
*   ibin_τ = ebin_τ × (pre-LOMR NFIP policies / population)
* Intensity = flood insurance penetration, proxy for share of
* housing stock in flood zone. Addresses attenuation bias.

reghdfe ln_real_zhvi ibin_m4 ibin_m3 ibin_m2 ibin_p0 ibin_p1 ibin_p2 ibin_p3 ibin_p4 ///
    unemployment_rate [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_intensity

* --- Pre-period joint F-test (intensity parallel trends) ---
di _n "=== Joint F-test: intensity pre-treatment coefficients = 0 ==="
testparm ibin_m4 ibin_m3 ibin_m2

* --- Regression table: Binary vs Intensity ---
esttab es_main es_intensity using "$results/s06_regression_intensity.tex", replace ///
    keep(ebin_* ibin_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Binary Treatment" "Intensity-Weighted") ///
    title("ln(Real ZHVI) on LOMR × Policy Intensity") ///
    addnotes("Zip and county×year FE. SE clustered at county level." ///
             "Intensity = pre-LOMR NFIP policies / population." ///
             "Proxy for share of housing stock in flood zone.")

esttab es_main es_intensity using "$results/s06_regression_intensity.csv", replace ///
    keep(ebin_* ibin_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Binary Treatment" "Intensity-Weighted") plain

* --- Coefficient plot: Intensity specification ---
preserve
clear
set obs 9

gen tau = _n - 5
gen coef = .
gen se = .
gen ci_lo = .
gen ci_hi = .

replace coef  = 0 if tau == -1
replace se    = 0 if tau == -1
replace ci_lo = 0 if tau == -1
replace ci_hi = 0 if tau == -1

estimates restore es_intensity

local varlist "ibin_m4 ibin_m3 ibin_m2 ibin_p0 ibin_p1 ibin_p2 ibin_p3 ibin_p4"
local taulist "-4 -3 -2 0 1 2 3 4"
local i = 1
foreach v of local varlist {
    local t : word `i' of `taulist'
    replace coef  = _b[`v']                       if tau == `t'
    replace se    = _se[`v']                       if tau == `t'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v']     if tau == `t'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v']     if tau == `t'
    local i = `i' + 1
}

label define tau_int -4 "-4" -3 "-3" -2 "-2" -1 "-1" 0 "0" 1 "+1" 2 "+2" 3 "+3" 4 "+4"
label values tau tau_int

twoway (rcap ci_hi ci_lo tau, lcolor(dkgreen%50) lwidth(medthin)) ///
       (scatter coef tau, mcolor(dkgreen) msymbol(circle) msize(medlarge)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(medium)) ///
    ytitle("Effect on ln(Real ZHVI) per Unit Policy Penetration", size(medium)) ///
    title("Treatment Intensity Event Study", size(large)) ///
    subtitle("Intensity = NFIP policy penetration (policies / population)", size(medsmall)) ///
    xlabel(-4(1)4, labsize(medsmall)) ///
    ylabel(, labsize(medsmall) angle(horizontal) grid glcolor(gs14)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    note("Intensity = pre-LOMR NFIP policies / population. Zip and county×year FE." ///
         "Controls: county unemployment." ///
         "SE clustered at county level.", ///
         size(vsmall) color(gs6))

graph export "$results/s06_event_study_intensity.png", replace width(1400)
graph export "$results/s06_event_study_intensity.pdf", replace

export delimited using "$results/s06_event_study_intensity_coefficients.csv", replace
restore


* =============================================================================
* 6b. INTENSITY QUARTILE EVENT STUDY
* =============================================================================
* Non-parametric dose-response: bucket treated zips into quartiles of
* pre-LOMR policy penetration and estimate separate event-study coefficients.
* Shows whether high-exposure zips decline more than low-exposure zips.
* All quartiles in one regression → shared control group and fixed effects.

* --- Compute intensity quartiles among treated zips ---
* Control zips get quartile = 0; treated zips get 1-4.
tempvar _tr_intensity
gen `_tr_intensity' = policy_intensity if ever_treated == 1 & policy_intensity > 0
xtile intensity_quartile = `_tr_intensity', nquantiles(4)
replace intensity_quartile = 0 if missing(intensity_quartile)
label var intensity_quartile "Intensity quartile (1=low … 4=high, 0=control)"

di _n "=== Intensity Quartile Summary ==="
tab intensity_quartile ever_treated
sum policy_intensity if intensity_quartile == 1, detail
sum policy_intensity if intensity_quartile == 2, detail
sum policy_intensity if intensity_quartile == 3, detail
sum policy_intensity if intensity_quartile == 4, detail

* --- Create quartile × event-time interaction dummies (32 total) ---
foreach t in m4 m3 m2 p0 p1 p2 p3 p4 {
    forvalues q = 1/4 {
        gen ebin_`t'_q`q' = ebin_`t' * (intensity_quartile == `q')
        label var ebin_`t'_q`q' "τ = `t' × Q`q'"
    }
}

* --- Pooled regression: all 4 quartiles in one equation ---
reghdfe ln_real_zhvi ///
    ebin_m4_q1 ebin_m3_q1 ebin_m2_q1 ebin_p0_q1 ebin_p1_q1 ebin_p2_q1 ebin_p3_q1 ebin_p4_q1 ///
    ebin_m4_q2 ebin_m3_q2 ebin_m2_q2 ebin_p0_q2 ebin_p1_q2 ebin_p2_q2 ebin_p3_q2 ebin_p4_q2 ///
    ebin_m4_q3 ebin_m3_q3 ebin_m2_q3 ebin_p0_q3 ebin_p1_q3 ebin_p2_q3 ebin_p3_q3 ebin_p4_q3 ///
    ebin_m4_q4 ebin_m3_q4 ebin_m2_q4 ebin_p0_q4 ebin_p1_q4 ebin_p2_q4 ebin_p3_q4 ebin_p4_q4 ///
    unemployment_rate [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_quartiles

* --- Pre-period joint F-test per quartile ---
di _n "=== Pre-trend F-tests by quartile ==="
di "Q1 (low):"
testparm ebin_m4_q1 ebin_m3_q1 ebin_m2_q1
di "Q2 (low-med):"
testparm ebin_m4_q2 ebin_m3_q2 ebin_m2_q2
di "Q3 (med-high):"
testparm ebin_m4_q3 ebin_m3_q3 ebin_m2_q3
di "Q4 (high):"
testparm ebin_m4_q4 ebin_m3_q4 ebin_m2_q4

* --- Regression table: 4 columns (one per quartile) ---
* Present as a single regression with grouped coefficients
esttab es_quartiles using "$results/s06b_regression_intensity_quartiles.tex", replace ///
    keep(ebin_*_q1 ebin_*_q2 ebin_*_q3 ebin_*_q4) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Intensity Quartiles") ///
    title("ln(Real ZHVI) by Policy Intensity Quartile") ///
    addnotes("Zip and county×year FE. SE clustered at county level." ///
             "Quartiles of pre-LOMR NFIP policy penetration among treated zips." ///
             "Q1 = lowest exposure, Q4 = highest exposure.")

esttab es_quartiles using "$results/s06b_regression_intensity_quartiles.csv", replace ///
    keep(ebin_*_q1 ebin_*_q2 ebin_*_q3 ebin_*_q4) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Intensity Quartiles") plain

* --- Overlaid event study plot: 4 quartiles ---
preserve
clear
set obs 36

* 4 groups × 9 tau values = 36 rows
gen tau = .
gen coef = .
gen ci_lo = .
gen ci_hi = .
gen str20 group = ""

* Fill tau and group labels
forvalues i = 1/9 {
    local t = `i' - 5
    replace tau = `t' if _n == `i'
    replace tau = `t' if _n == `i' + 9
    replace tau = `t' if _n == `i' + 18
    replace tau = `t' if _n == `i' + 27
    replace group = "Q1 (low)" if _n == `i'
    replace group = "Q2 (low-med)" if _n == `i' + 9
    replace group = "Q3 (med-high)" if _n == `i' + 18
    replace group = "Q4 (high)" if _n == `i' + 27
}

* Reference periods = 0
replace coef  = 0 if tau == -1
replace ci_lo = 0 if tau == -1
replace ci_hi = 0 if tau == -1

* Fill coefficients from stored estimates
estimates restore es_quartiles

local taulist "-4 -3 -2 0 1 2 3 4"

* Q1 (rows 1-9)
local q1vars "ebin_m4_q1 ebin_m3_q1 ebin_m2_q1 ebin_p0_q1 ebin_p1_q1 ebin_p2_q1 ebin_p3_q1 ebin_p4_q1"
local i = 1
foreach v of local q1vars {
    local t : word `i' of `taulist'
    local row = `t' + 5
    replace coef  = _b[`v']                   if _n == `row'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v'] if _n == `row'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v'] if _n == `row'
    local i = `i' + 1
}

* Q2 (rows 10-18)
local q2vars "ebin_m4_q2 ebin_m3_q2 ebin_m2_q2 ebin_p0_q2 ebin_p1_q2 ebin_p2_q2 ebin_p3_q2 ebin_p4_q2"
local i = 1
foreach v of local q2vars {
    local t : word `i' of `taulist'
    local row = `t' + 14
    replace coef  = _b[`v']                   if _n == `row'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v'] if _n == `row'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v'] if _n == `row'
    local i = `i' + 1
}

* Q3 (rows 19-27)
local q3vars "ebin_m4_q3 ebin_m3_q3 ebin_m2_q3 ebin_p0_q3 ebin_p1_q3 ebin_p2_q3 ebin_p3_q3 ebin_p4_q3"
local i = 1
foreach v of local q3vars {
    local t : word `i' of `taulist'
    local row = `t' + 23
    replace coef  = _b[`v']                   if _n == `row'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v'] if _n == `row'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v'] if _n == `row'
    local i = `i' + 1
}

* Q4 (rows 28-36)
local q4vars "ebin_m4_q4 ebin_m3_q4 ebin_m2_q4 ebin_p0_q4 ebin_p1_q4 ebin_p2_q4 ebin_p3_q4 ebin_p4_q4"
local i = 1
foreach v of local q4vars {
    local t : word `i' of `taulist'
    local row = `t' + 32
    replace coef  = _b[`v']                   if _n == `row'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v'] if _n == `row'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v'] if _n == `row'
    local i = `i' + 1
}

* Split into separate variables for individual panels (no jitter needed)
gen coef_q1 = coef if group == "Q1 (low)"
gen coef_q2 = coef if group == "Q2 (low-med)"
gen coef_q3 = coef if group == "Q3 (med-high)"
gen coef_q4 = coef if group == "Q4 (high)"
gen ci_lo_q1 = ci_lo if group == "Q1 (low)"
gen ci_hi_q1 = ci_hi if group == "Q1 (low)"
gen ci_lo_q2 = ci_lo if group == "Q2 (low-med)"
gen ci_hi_q2 = ci_hi if group == "Q2 (low-med)"
gen ci_lo_q3 = ci_lo if group == "Q3 (med-high)"
gen ci_hi_q3 = ci_hi if group == "Q3 (med-high)"
gen ci_lo_q4 = ci_lo if group == "Q4 (high)"
gen ci_hi_q4 = ci_hi if group == "Q4 (high)"
gen tau_q1 = tau if group == "Q1 (low)"
gen tau_q2 = tau if group == "Q2 (low-med)"
gen tau_q3 = tau if group == "Q3 (med-high)"
gen tau_q4 = tau if group == "Q4 (high)"

* Reference point marker (hollow circle at τ = -1)
gen ref_q1 = 0 if group == "Q1 (low)" & tau == -1
gen ref_q2 = 0 if group == "Q2 (low-med)" & tau == -1
gen ref_q3 = 0 if group == "Q3 (med-high)" & tau == -1
gen ref_q4 = 0 if group == "Q4 (high)" & tau == -1

* --- Individual quartile panels (2×2) ---
twoway (rcap ci_hi_q1 ci_lo_q1 tau_q1, lcolor(midblue%60) lwidth(medthin)) ///
       (connected coef_q1 tau_q1, lcolor(midblue) mcolor(midblue) msymbol(circle) msize(small) lwidth(medthin)) ///
       (scatter ref_q1 tau_q1, mcolor(white) msymbol(circle) msize(small) mlcolor(gs6) mlwidth(medium)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(small)) ///
    ytitle("Effect on ln(Real ZHVI)", size(small)) ///
    title("Q1 (low)", size(medlarge)) ///
    xlabel(-4(1)4, labsize(small)) ///
    ylabel(, labsize(small) angle(horizontal) grid glcolor(gs14)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    name(g_q1, replace)

twoway (rcap ci_hi_q2 ci_lo_q2 tau_q2, lcolor(midblue%60) lwidth(medthin)) ///
       (connected coef_q2 tau_q2, lcolor(midblue) mcolor(midblue) msymbol(circle) msize(small) lwidth(medthin)) ///
       (scatter ref_q2 tau_q2, mcolor(white) msymbol(circle) msize(small) mlcolor(gs6) mlwidth(medium)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(small)) ///
    ytitle("Effect on ln(Real ZHVI)", size(small)) ///
    title("Q2 (med-low)", size(medlarge)) ///
    xlabel(-4(1)4, labsize(small)) ///
    ylabel(, labsize(small) angle(horizontal) grid glcolor(gs14)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    name(g_q2, replace)

twoway (rcap ci_hi_q3 ci_lo_q3 tau_q3, lcolor(midblue%60) lwidth(medthin)) ///
       (connected coef_q3 tau_q3, lcolor(midblue) mcolor(midblue) msymbol(circle) msize(small) lwidth(medthin)) ///
       (scatter ref_q3 tau_q3, mcolor(white) msymbol(circle) msize(small) mlcolor(gs6) mlwidth(medium)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(small)) ///
    ytitle("Effect on ln(Real ZHVI)", size(small)) ///
    title("Q3 (med-high)", size(medlarge)) ///
    xlabel(-4(1)4, labsize(small)) ///
    ylabel(, labsize(small) angle(horizontal) grid glcolor(gs14)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    name(g_q3, replace)

twoway (rcap ci_hi_q4 ci_lo_q4 tau_q4, lcolor(midblue%60) lwidth(medthin)) ///
       (connected coef_q4 tau_q4, lcolor(midblue) mcolor(midblue) msymbol(circle) msize(small) lwidth(medthin)) ///
       (scatter ref_q4 tau_q4, mcolor(white) msymbol(circle) msize(small) mlcolor(gs6) mlwidth(medium)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(small)) ///
    ytitle("Effect on ln(Real ZHVI)", size(small)) ///
    title("Q4 (high)", size(medlarge)) ///
    xlabel(-4(1)4, labsize(small)) ///
    ylabel(, labsize(small) angle(horizontal) grid glcolor(gs14)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    name(g_q4, replace)

* --- Combine into 2×2 panel ---
graph combine g_q1 g_q2 g_q3 g_q4, rows(2) cols(2) ///
    title("Event Study by Intensity Quartile", size(large)) ///
    subtitle("Quartiles of pre-LOMR NFIP policy penetration", size(medsmall)) ///
    note("Zip and county×year FE. Controls: county unemployment." ///
         "SE clustered at county level. Reference: τ = -1.", ///
         size(vsmall) color(gs6)) ///
    graphregion(color(white)) ///
    imargin(small)

graph export "$results/s06b_event_study_intensity_quartiles.png", replace width(1800)
graph export "$results/s06b_event_study_intensity_quartiles.pdf", replace

graph drop g_q1 g_q2 g_q3 g_q4

export delimited using "$results/s06b_event_study_intensity_quartiles_coefficients.csv", replace
restore


* =============================================================================
* 7. SIMPLE DiD (TWO-PERIOD) FOR COMPARISON
* =============================================================================

* Basic two-way FE DiD: treated = 1 if post-LOMR
reghdfe ln_real_zhvi treated unemployment_rate n_policies ///
    [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store did_twfe

esttab did_twfe using "$results/s07_did_twfe.tex", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("TWFE DiD") ///
    title("ln(Real ZHVI) on LOMR (TWFE DiD)") ///
    addnotes("Zip and county×year FE. SE clustered at county level.")


* =============================================================================
* 8. MECHANISM: INSURANCE MARKET OUTCOMES
* =============================================================================
* Does the LOMR actually change insurance behavior?
* Policies = "first stage" (LOMRs → insurance take-up)
* Claims = falsification (LOMRs don't cause floods)
*
* NOTE: Pooled spec here; Section 8b splits by zone-based risk direction
*       (SFHA share Δ), which is independent of policy counts → no circularity.

* ln_policies, ln_claims already generated in section 2b

* --- Spec A: Policies as outcome ---
* Controls: unemployment (exclude n_policies — it's the outcome)
reghdfe ln_policies ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
    unemployment_rate [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_policies

* --- Spec B: Claims as outcome (falsification) ---
reghdfe ln_claims ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
    unemployment_rate [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_claims

* --- Regression table: Insurance outcomes ---
esttab es_policies es_claims using "$results/s08_regression_insurance.tex", replace ///
    keep(ebin_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("ln(Policies)" "ln(Claims)") ///
    title("ln(NFIP Policies) on LOMR Treatment") ///
    addnotes("Zip and county×year FE. SE clustered at county level." ///
             "Policies: NFIP policy count (mechanism). Claims: falsification." ///
             "Reference period: τ = -1 (12-0 months before LOMR).")

esttab es_policies es_claims using "$results/s08_regression_insurance.csv", replace ///
    keep(ebin_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("ln(Policies)" "ln(Claims)") plain

* --- Coefficient plot: Policies outcome ---
preserve
clear
set obs 9

gen tau = _n - 5
gen coef = .
gen se = .
gen ci_lo = .
gen ci_hi = .

replace coef  = 0 if tau == -1
replace se    = 0 if tau == -1
replace ci_lo = 0 if tau == -1
replace ci_hi = 0 if tau == -1

estimates restore es_policies

local varlist "ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4"
local taulist "-4 -3 -2 0 1 2 3 4"
local i = 1
foreach v of local varlist {
    local t : word `i' of `taulist'
    replace coef  = _b[`v']                       if tau == `t'
    replace se    = _se[`v']                       if tau == `t'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v']     if tau == `t'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v']     if tau == `t'
    local i = `i' + 1
}

label define tau_pol -4 "-4" -3 "-3" -2 "-2" -1 "-1" 0 "0" 1 "+1" 2 "+2" 3 "+3" 4 "+4"
label values tau tau_pol

twoway (rcap ci_hi ci_lo tau, lcolor(dkorange%50) lwidth(medthin)) ///
       (scatter coef tau, mcolor(dkorange) msymbol(circle) msize(medlarge)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(medium)) ///
    ytitle("Effect on ln(NFIP Policies + 1)", size(medium)) ///
    title("Mechanism: LOMR Effect on Insurance Take-Up", size(large)) ///
    subtitle("Staggered DiD with zip and county-by-year fixed effects", size(medsmall)) ///
    xlabel(-4(1)4, labsize(medsmall)) ///
    ylabel(, labsize(medsmall) angle(horizontal) grid glcolor(gs14)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    note("Reference period: τ = -1. 95% CIs shown." ///
         "Controls: county unemployment." ///
         "SE clustered at county level.", ///
         size(vsmall) color(gs6))

graph export "$results/s08_event_study_policies.png", replace width(1400)
graph export "$results/s08_event_study_policies.pdf", replace

export delimited using "$results/s08_event_study_policies_coefficients.csv", replace
restore


* =============================================================================
* 8b. CREATE UP/DOWN EVENT DUMMIES
* =============================================================================
* Risk direction + upzoned/downzoned already merged in section 1d.

di _n "Zone-based risk direction (SFHA share Δ, ±1pp threshold):"
tab zone_risk_direction if ever_treated == 1 & event_bin != ., missing

* --- Create subsample-specific event dummies ---
* Upzoned dummies: only = 1 for upzoned treated zips
foreach t in m4 m3 m2 p0 p1 p2 p3 p4 {
    gen up_`t'   = ebin_`t' * upzoned
    gen down_`t' = ebin_`t' * downzoned
}


* =============================================================================
* 8c. INSURANCE TAKE-UP BY RISK DIRECTION
* =============================================================================
* Split the insurance mechanism test by zone-based risk direction.
* Upzoned (into flood zone) → expect MORE insurance take-up.
* Downzoned (out of flood zone) → expect LESS take-up / policy drop.
* Classification uses SFHA zone share Δ — independent of policy counts.

* --- Spec A: Policies — upzoned subsample ---
reghdfe ln_policies up_m4 up_m3 up_m2 up_p0 up_p1 up_p2 up_p3 up_p4 ///
    unemployment_rate [aweight=population] ///
    if (upzoned == 1 | ever_treated == 0), ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_pol_up

* --- Spec B: Policies — downzoned subsample ---
reghdfe ln_policies down_m4 down_m3 down_m2 down_p0 down_p1 down_p2 down_p3 down_p4 ///
    unemployment_rate [aweight=population] ///
    if (downzoned == 1 | ever_treated == 0), ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_pol_down

* --- Spec C: Claims — upzoned subsample (falsification) ---
reghdfe ln_claims up_m4 up_m3 up_m2 up_p0 up_p1 up_p2 up_p3 up_p4 ///
    unemployment_rate [aweight=population] ///
    if (upzoned == 1 | ever_treated == 0), ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_clm_up

* --- Spec D: Claims — downzoned subsample (falsification) ---
reghdfe ln_claims down_m4 down_m3 down_m2 down_p0 down_p1 down_p2 down_p3 down_p4 ///
    unemployment_rate [aweight=population] ///
    if (downzoned == 1 | ever_treated == 0), ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_clm_down

* --- Regression table: Insurance by risk direction ---
esttab es_pol_up es_pol_down es_clm_up es_clm_down ///
    using "$results/s08b_regression_insurance_updown.tex", replace ///
    keep(up_* down_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Policies (Up)" "Policies (Down)" "Claims (Up)" "Claims (Down)") ///
    title("ln(NFIP Policies) on Upzoning vs Downzoning") ///
    addnotes("Zip and county×year FE. SE clustered at county level." ///
             "Each spec uses its treated subsample + all never-treated controls." ///
             "Risk direction: SFHA zone share Δ (±1pp threshold)." ///
             "Reference period: τ = -1 (12-0 months before LOMR).")

esttab es_pol_up es_pol_down es_clm_up es_clm_down ///
    using "$results/s08b_regression_insurance_updown.csv", replace ///
    keep(up_* down_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Policies (Up)" "Policies (Down)" "Claims (Up)" "Claims (Down)") plain

* --- Coefficient plot: Insurance take-up by risk direction ---
preserve
clear
set obs 18

gen tau = .
gen coef = .
gen ci_lo = .
gen ci_hi = .
gen group = ""

* Row indices: 1-9 = upzoned, 10-18 = downzoned
forvalues i = 1/9 {
    replace tau = `i' - 5 if _n == `i'
    replace tau = `i' - 5 if _n == `i' + 9
    replace group = "Upzoned (risk ↑)" if _n == `i'
    replace group = "Downzoned (risk ↓)" if _n == `i' + 9
}

* Reference periods = 0
replace coef  = 0 if tau == -1
replace ci_lo = 0 if tau == -1
replace ci_hi = 0 if tau == -1

* Fill upzoned coefficients
estimates restore es_pol_up
local upvars "up_m4 up_m3 up_m2 up_p0 up_p1 up_p2 up_p3 up_p4"
local taulist "-4 -3 -2 0 1 2 3 4"
local i = 1
foreach v of local upvars {
    local t : word `i' of `taulist'
    local row = `t' + 5
    replace coef  = _b[`v']                   if _n == `row'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v'] if _n == `row'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v'] if _n == `row'
    local i = `i' + 1
}

* Fill downzoned coefficients
estimates restore es_pol_down
local downvars "down_m4 down_m3 down_m2 down_p0 down_p1 down_p2 down_p3 down_p4"
local i = 1
foreach v of local downvars {
    local t : word `i' of `taulist'
    local row = `t' + 14
    replace coef  = _b[`v']                   if _n == `row'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v'] if _n == `row'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v'] if _n == `row'
    local i = `i' + 1
}

* Offset tau slightly for visual separation
gen tau_plot = tau - 0.12 if group == "Upzoned (risk ↑)"
replace tau_plot = tau + 0.12 if group == "Downzoned (risk ↓)"

* Split into two variables for twoway
gen coef_up = coef if group == "Upzoned (risk ↑)"
gen coef_down = coef if group == "Downzoned (risk ↓)"
gen ci_lo_up = ci_lo if group == "Upzoned (risk ↑)"
gen ci_hi_up = ci_hi if group == "Upzoned (risk ↑)"
gen ci_lo_down = ci_lo if group == "Downzoned (risk ↓)"
gen ci_hi_down = ci_hi if group == "Downzoned (risk ↓)"
gen tau_up = tau_plot if group == "Upzoned (risk ↑)"
gen tau_down = tau_plot if group == "Downzoned (risk ↓)"

twoway (rcap ci_hi_up ci_lo_up tau_up, lcolor(cranberry%50) lwidth(medthin)) ///
       (scatter coef_up tau_up, mcolor(cranberry) msymbol(circle) msize(medlarge)) ///
       (rcap ci_hi_down ci_lo_down tau_down, lcolor(navy%50) lwidth(medthin)) ///
       (scatter coef_down tau_down, mcolor(navy) msymbol(square) msize(medlarge)), ///
    xline(-0.5, lcolor(gs8) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(medium)) ///
    ytitle("Effect on ln(NFIP Policies + 1)", size(medium)) ///
    title("Insurance Take-Up by Risk Direction", size(large)) ///
    subtitle("Upzoned (risk increased) vs Downzoned (risk decreased)", size(medsmall)) ///
    xlabel(-4(1)4, labsize(medsmall)) ///
    ylabel(, labsize(medsmall) angle(horizontal) grid glcolor(gs14)) ///
    legend(order(2 "Upzoned (risk ↑)" 4 "Downzoned (risk ↓)") ///
           ring(0) pos(11) cols(1) size(small) region(lcolor(gs12))) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    note("Reference: τ = -1. 95% CIs shown. Controls: unemployment." ///
         "SE clustered at county level. Risk direction: SFHA zone share Δ (±1pp threshold).", ///
         size(vsmall) color(gs6))

graph export "$results/s08b_event_study_policies_updown.png", replace width(1400)
graph export "$results/s08b_event_study_policies_updown.pdf", replace

export delimited using "$results/s08b_event_study_policies_updown_coefficients.csv", replace
restore


* =============================================================================
* 9. HETEROGENEITY: UPZONED vs DOWNZONED LOMRs (HOME VALUES)
* =============================================================================
* Not all LOMRs are equivalent. Those that cross the SFHA boundary impose or
* remove a mandatory flood insurance requirement for federally backed mortgages,
* creating a direct, unavoidable cost channel. Upzoning (into SFHA) imposes new
* mandatory insurance costs; downzoning (out of SFHA) eliminates them. We
* decompose the main estimate into upzoned and downzoned LOMRs to test whether
* the mandatory purchase requirement drives the repricing effect, or whether
* informational updating alone is sufficient.
*
* Risk direction and up/down event dummies already created in Section 8b.

label var up_m4   "τ = -4 (3+ yrs pre)"
label var up_m3   "τ = -3 (2-3 yrs pre)"
label var up_m2   "τ = -2 (1-2 yrs pre)"
label var up_p0   "τ = 0 (0-1 yr post)"
label var up_p1   "τ = +1 (1-2 yrs post)"
label var up_p2   "τ = +2 (2-3 yrs post)"
label var up_p3   "τ = +3 (3-4 yrs post)"
label var up_p4   "τ = +4 (4+ yrs post)"

label var down_m4 "τ = -4 (3+ yrs pre)"
label var down_m3 "τ = -3 (2-3 yrs pre)"
label var down_m2 "τ = -2 (1-2 yrs pre)"
label var down_p0 "τ = 0 (0-1 yr post)"
label var down_p1 "τ = +1 (1-2 yrs post)"
label var down_p2 "τ = +2 (2-3 yrs post)"
label var down_p3 "τ = +3 (3-4 yrs post)"
label var down_p4 "τ = +4 (4+ yrs post)"

* --- Spec A: Upzoned only (risk increased → expect negative β) ---
reghdfe ln_real_zhvi up_m4 up_m3 up_m2 up_p0 up_p1 up_p2 up_p3 up_p4 ///
    unemployment_rate n_policies ///
    [aweight=population] if (upzoned == 1 | ever_treated == 0), ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_up

* --- Spec B: Downzoned only (risk decreased → expect positive β) ---
reghdfe ln_real_zhvi down_m4 down_m3 down_m2 down_p0 down_p1 down_p2 down_p3 down_p4 ///
    unemployment_rate n_policies ///
    [aweight=population] if (downzoned == 1 | ever_treated == 0), ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_down

* --- Regression table: Up vs Down ---
esttab es_up es_down using "$results/s09_regression_updown.tex", replace ///
    keep(up_* down_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Upzoned (Risk ↑)" "Downzoned (Risk ↓)") ///
    title("ln(Real ZHVI) on Upzoning vs Downzoning") ///
    addnotes("Zip and county×year FE. SE clustered at county level." ///
             "Each spec uses its treated subsample + all never-treated controls." ///
             "Risk direction classified by SFHA zone share change (±1pp) around LOMR.")

esttab es_up es_down using "$results/s09_regression_updown.csv", replace ///
    keep(up_* down_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Upzoned (Risk Up)" "Downzoned (Risk Down)") plain

* --- Build combined coefficient plot ---
preserve
clear
set obs 18

gen tau = .
gen coef = .
gen ci_lo = .
gen ci_hi = .
gen group = ""

* Row indices: 1-9 = upzoned, 10-18 = downzoned
forvalues i = 1/9 {
    replace tau = `i' - 5 if _n == `i'
    replace tau = `i' - 5 if _n == `i' + 9
    replace group = "Upzoned (risk ↑)" if _n == `i'
    replace group = "Downzoned (risk ↓)" if _n == `i' + 9
}

* Reference periods = 0
replace coef  = 0 if tau == -1
replace ci_lo = 0 if tau == -1
replace ci_hi = 0 if tau == -1

* Fill upzoned coefficients
estimates restore es_up
local upvars "up_m4 up_m3 up_m2 up_p0 up_p1 up_p2 up_p3 up_p4"
local taulist "-4 -3 -2 0 1 2 3 4"
local i = 1
foreach v of local upvars {
    local t : word `i' of `taulist'
    * Find the row for this tau in the upzoned group (rows 1-9)
    local row = `t' + 5
    replace coef  = _b[`v']                   if _n == `row'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v'] if _n == `row'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v'] if _n == `row'
    local i = `i' + 1
}

* Fill downzoned coefficients
estimates restore es_down
local downvars "down_m4 down_m3 down_m2 down_p0 down_p1 down_p2 down_p3 down_p4"
local i = 1
foreach v of local downvars {
    local t : word `i' of `taulist'
    * Find the row for this tau in the downzoned group (rows 10-18)
    local row = `t' + 14
    replace coef  = _b[`v']                   if _n == `row'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v'] if _n == `row'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v'] if _n == `row'
    local i = `i' + 1
}

* Offset tau slightly for visual separation
gen tau_plot = tau - 0.12 if group == "Upzoned (risk ↑)"
replace tau_plot = tau + 0.12 if group == "Downzoned (risk ↓)"

* Split into two variables for twoway
gen coef_up = coef if group == "Upzoned (risk ↑)"
gen coef_down = coef if group == "Downzoned (risk ↓)"
gen ci_lo_up = ci_lo if group == "Upzoned (risk ↑)"
gen ci_hi_up = ci_hi if group == "Upzoned (risk ↑)"
gen ci_lo_down = ci_lo if group == "Downzoned (risk ↓)"
gen ci_hi_down = ci_hi if group == "Downzoned (risk ↓)"
gen tau_up = tau_plot if group == "Upzoned (risk ↑)"
gen tau_down = tau_plot if group == "Downzoned (risk ↓)"

twoway (rcap ci_hi_up ci_lo_up tau_up, lcolor(cranberry%50) lwidth(medthin)) ///
       (scatter coef_up tau_up, mcolor(cranberry) msymbol(circle) msize(medlarge)) ///
       (rcap ci_hi_down ci_lo_down tau_down, lcolor(navy%50) lwidth(medthin)) ///
       (scatter coef_down tau_down, mcolor(navy) msymbol(square) msize(medlarge)), ///
    xline(-0.5, lcolor(gs8) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(medium)) ///
    ytitle("Effect on ln(Real ZHVI)", size(medium)) ///
    title("Event Study by Risk Direction", size(large)) ///
    subtitle("Upzoned (risk increased) vs Downzoned (risk decreased)", size(medsmall)) ///
    xlabel(-4(1)4, labsize(medsmall)) ///
    ylabel(, labsize(medsmall) angle(horizontal) grid glcolor(gs14)) ///
    legend(order(2 "Upzoned (risk ↑)" 4 "Downzoned (risk ↓)") ///
           ring(0) pos(11) cols(1) size(small) region(lcolor(gs12))) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    note("Reference: τ = -1. 95% CIs shown. Controls: unemployment, NFIP policies." ///
         "SE clustered at county level. Risk direction: SFHA zone share Δ (±1pp threshold).", ///
         size(vsmall) color(gs6))

graph export "$results/s09_event_study_updown.png", replace width(1400)
graph export "$results/s09_event_study_updown.pdf", replace

export delimited using "$results/s09_event_study_updown_coefficients.csv", replace

restore


* --- Create signed intensity dummies ---
* Signs policy_intensity by risk direction: +1 for upzoned, -1 for downzoned.
* Directly comparable to pooled ibin_τ — same intensity measure, same sample.
* β < 0 means markets respond rationally to direction of risk change.
gen signed_intensity = policy_intensity * upzoned - policy_intensity * downzoned
replace signed_intensity = 0 if missing(signed_intensity)
label var signed_intensity "Signed Policy Penetration (+up, -down)"
sum signed_intensity if ever_treated == 1, detail

foreach t in m4 m3 m2 p0 p1 p2 p3 p4 {
    gen sibin_`t' = ebin_`t' * signed_intensity
}
label var sibin_m4 "τ = -4 × signed intensity"
label var sibin_m3 "τ = -3 × signed intensity"
label var sibin_m2 "τ = -2 × signed intensity"
label var sibin_p0 "τ = 0 × signed intensity"
label var sibin_p1 "τ = +1 × signed intensity"
label var sibin_p2 "τ = +2 × signed intensity"
label var sibin_p3 "τ = +3 × signed intensity"
label var sibin_p4 "τ = +4 × signed intensity"

* Also keep iup/idown for the two-series plot
foreach t in m4 m3 m2 p0 p1 p2 p3 p4 {
    gen iup_`t'   = ibin_`t' * upzoned
    gen idown_`t' = ibin_`t' * downzoned
}

* --- Spec C: Signed intensity (one set of coefficients) ---
reghdfe ln_real_zhvi sibin_m4 sibin_m3 sibin_m2 sibin_p0 sibin_p1 sibin_p2 sibin_p3 sibin_p4 ///
    unemployment_rate [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_signed

* --- Spec D: Decomposed iup + idown (full sample, for comparison plot) ---
reghdfe ln_real_zhvi iup_m4 iup_m3 iup_m2 iup_p0 iup_p1 iup_p2 iup_p3 iup_p4 ///
    idown_m4 idown_m3 idown_m2 idown_p0 idown_p1 idown_p2 idown_p3 idown_p4 ///
    unemployment_rate [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_iupdown

* --- Regression table: Pooled vs Signed vs Decomposed ---
esttab es_intensity es_signed es_iupdown ///
    using "$results/s09_regression_updown_intensity.tex", replace ///
    keep(ibin_* sibin_* iup_* idown_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Pooled Intensity" "Signed Intensity" "Up + Down") ///
    title("Treatment Intensity: Pooled vs Risk Direction") ///
    addnotes("Zip and county×year FE. SE clustered at county level." ///
             "Intensity = pre-LOMR NFIP policies / population." ///
             "Signed intensity: +intensity for upzoned, −intensity for downzoned." ///
             "β < 0 in (2): markets respond rationally to direction of risk change.")

esttab es_intensity es_signed es_iupdown ///
    using "$results/s09_regression_updown_intensity.csv", replace ///
    keep(ibin_* sibin_* iup_* idown_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Pooled Intensity" "Signed Intensity" "Up + Down") plain

* --- Build signed intensity coefficient plot (single series) ---
preserve
clear
set obs 9

gen tau = _n - 5
gen coef = .
gen se = .
gen ci_lo = .
gen ci_hi = .

replace coef  = 0 if tau == -1
replace se    = 0 if tau == -1
replace ci_lo = 0 if tau == -1
replace ci_hi = 0 if tau == -1

estimates restore es_signed

local varlist "sibin_m4 sibin_m3 sibin_m2 sibin_p0 sibin_p1 sibin_p2 sibin_p3 sibin_p4"
local taulist "-4 -3 -2 0 1 2 3 4"
local i = 1
foreach v of local varlist {
    local t : word `i' of `taulist'
    replace coef  = _b[`v']                       if tau == `t'
    replace se    = _se[`v']                       if tau == `t'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v']     if tau == `t'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v']     if tau == `t'
    local i = `i' + 1
}

label define tau_si -4 "-4" -3 "-3" -2 "-2" -1 "-1" 0 "0" 1 "+1" 2 "+2" 3 "+3" 4 "+4"
label values tau tau_si

twoway (rcap ci_hi ci_lo tau, lcolor(dkorange%50) lwidth(medthin)) ///
       (scatter coef tau, mcolor(dkorange) msymbol(circle) msize(medlarge)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(medium)) ///
    ytitle("Effect on ln(Real ZHVI) per Unit Signed Intensity", size(medium)) ///
    title("Signed Treatment Intensity Event Study", size(large)) ///
    subtitle("Signed intensity: +policy penetration (upzoned), -policy penetration (downzoned)", size(medsmall)) ///
    xlabel(-4(1)4, labsize(medsmall)) ///
    ylabel(, labsize(medsmall) angle(horizontal) grid glcolor(gs14)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    note("B < 0: markets respond rationally to direction of risk change." ///
         "Intensity = pre-LOMR NFIP policies / pop. SE clustered at county.", ///
         size(vsmall) color(gs6))

graph export "$results/s09_event_study_updown_intensity.png", replace width(1400)
graph export "$results/s09_event_study_updown_intensity.pdf", replace

export delimited using "$results/s09_event_study_updown_intensity_coefficients.csv", replace
restore


* =============================================================================
* 9b. HETEROGENEITY: DISCLOSURE LAW × LOMR INTENSITY
* =============================================================================
* Do mandatory flood disclosure laws amplify the LOMR effect on home values?
* Hypothesis: disclosure forces sellers/agents to reveal flood zone status,
* making buyers more responsive to reclassification in disclosure states.
*
* 9 states with verified mandatory flood zone disclosure during sample period:
*   CA (1998), IL (1994), IN (1994), LA (2003), MS (1993),
*   OR (1993), SC (2002), TX (1994), WI (1992).
* Inclusion criterion: state law requires seller to disclose FEMA flood zone
*   designation (or floodplain status) in residential real estate transactions.
* Excluded: FL (no flood disclosure until Oct 2024), VA (caveat emptor; seller
*   makes no representations re flood zones), NY (PCDS had no flood questions
*   until Mar 2024; $500 opt-out), MI (asks about flood damage history only,
*   not flood zone designation), NC (seller may answer "No Representation").
* Sources verified against state statutes; citations in disclosure_laws.csv.

* disc already merged in section 1c

di _n "=== Disclosure law coverage (9 states with verified flood zone disclosure) ==="
di "Treated zips by disclosure status:"
tab disc ever_treated if event_bin != ., missing
di _n "Disclosure × risk direction cross-tab:"
tab disc downzoned if ever_treated == 1 & event_bin != ., missing

* --- Binary disclosure interaction: ebin_τ × disc ---
* Simpler double-interaction: does LOMR effect differ in disclosure states?
foreach t in m4 m3 m2 p0 p1 p2 p3 p4 {
    gen dbin_`t' = ebin_`t' * disc
}

label var dbin_m4 "τ = -4 × Disclosure"
label var dbin_m3 "τ = -3 × Disclosure"
label var dbin_m2 "τ = -2 × Disclosure"
label var dbin_p0 "τ = 0 × Disclosure"
label var dbin_p1 "τ = +1 × Disclosure"
label var dbin_p2 "τ = +2 × Disclosure"
label var dbin_p3 "τ = +3 × Disclosure"
label var dbin_p4 "τ = +4 × Disclosure"

* --- Binary × strict disclosure regression ---
* β_τ (ebin_*) = baseline LOMR effect (non-disclosure states)
* γ_τ (dbin_*) = additional effect in mandatory disclosure states
* Disclosure implied effect = β_τ + γ_τ (recovered via lincom)
reghdfe ln_real_zhvi ///
    ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
    dbin_m4 dbin_m3 dbin_m2 dbin_p0 dbin_p1 dbin_p2 dbin_p3 dbin_p4 ///
    unemployment_rate n_policies ///
    [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_disc_bin

di _n "=== Joint F-test: post-treatment binary strict disclosure interactions ==="
testparm dbin_p0 dbin_p1 dbin_p2 dbin_p3 dbin_p4

* --- Binary × broad disclosure regression ---
foreach t in m4 m3 m2 p0 p1 p2 p3 p4 {
    gen dbinb_`t' = ebin_`t' * disc_broad
}

label var dbinb_m4 "τ = -4 × Broad Disc."
label var dbinb_m3 "τ = -3 × Broad Disc."
label var dbinb_m2 "τ = -2 × Broad Disc."
label var dbinb_p0 "τ = 0 × Broad Disc."
label var dbinb_p1 "τ = +1 × Broad Disc."
label var dbinb_p2 "τ = +2 × Broad Disc."
label var dbinb_p3 "τ = +3 × Broad Disc."
label var dbinb_p4 "τ = +4 × Broad Disc."

reghdfe ln_real_zhvi ///
    ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
    dbinb_m4 dbinb_m3 dbinb_m2 dbinb_p0 dbinb_p1 dbinb_p2 dbinb_p3 dbinb_p4 ///
    unemployment_rate n_policies ///
    [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_disc_bin_broad

di _n "=== Joint F-test: post-treatment binary broad disclosure interactions ==="
testparm dbinb_p0 dbinb_p1 dbinb_p2 dbinb_p3 dbinb_p4

* --- Binary disclosure regression table ---
esttab es_main es_disc_bin es_disc_bin_broad ///
    using "$results/s09b_regression_disclosure.tex", replace ///
    keep(ebin_* dbin_* dbinb_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    order(ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
          dbin_m4 dbin_m3 dbin_m2 dbin_p0 dbin_p1 dbin_p2 dbin_p3 dbin_p4 ///
          dbinb_m4 dbinb_m3 dbinb_m2 dbinb_p0 dbinb_p1 dbinb_p2 dbinb_p3 dbinb_p4) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Binary" "× Strict Disclosure" "× Broad Disclosure") ///
    title("ln(Real ZHVI) on LOMR × Disclosure") ///
    addnotes("Sample: all treated zips + never-treated controls (full event study sample)." ///
             "ebin = baseline LOMR effect (non-disclosure). dbin/dbinb = differential disclosure effect." ///
             "Zip and county×year FE. SE clustered at county level." ///
             "Strict: CA, IL, IN, LA, MS, OR, SC, TX, WI (9 states)." ///
             "Broad adds FL, VA, NC, NY (13 states).")

esttab es_main es_disc_bin es_disc_bin_broad ///
    using "$results/s09b_regression_disclosure.csv", replace ///
    keep(ebin_* dbin_* dbinb_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    order(ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
          dbin_m4 dbin_m3 dbin_m2 dbin_p0 dbin_p1 dbin_p2 dbin_p3 dbin_p4 ///
          dbinb_m4 dbinb_m3 dbinb_m2 dbinb_p0 dbinb_p1 dbinb_p2 dbinb_p3 dbinb_p4) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Binary" "× Strict Disclosure" "× Broad Disclosure") plain

drop dbinb_m4 dbinb_m3 dbinb_m2 dbinb_p0 dbinb_p1 dbinb_p2 dbinb_p3 dbinb_p4

* --- Intensity disclosure interaction (robustness) ---
* Triple interaction: ibin_τ × disc = ebin_τ × policy_intensity × disc
foreach t in m4 m3 m2 p0 p1 p2 p3 p4 {
    gen disc_`t' = ibin_`t' * disc
}

label var disc_m4 "τ = -4 × intensity × Disclosure"
label var disc_m3 "τ = -3 × intensity × Disclosure"
label var disc_m2 "τ = -2 × intensity × Disclosure"
label var disc_p0 "τ = 0 × intensity × Disclosure"
label var disc_p1 "τ = +1 × intensity × Disclosure"
label var disc_p2 "τ = +2 × intensity × Disclosure"
label var disc_p3 "τ = +3 × intensity × Disclosure"
label var disc_p4 "τ = +4 × intensity × Disclosure"

reghdfe ln_real_zhvi ///
    ibin_m4 ibin_m3 ibin_m2 ibin_p0 ibin_p1 ibin_p2 ibin_p3 ibin_p4 ///
    disc_m4 disc_m3 disc_m2 disc_p0 disc_p1 disc_p2 disc_p3 disc_p4 ///
    unemployment_rate ///
    [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_disc_int

di _n "=== Joint F-test: post-treatment intensity disclosure interactions ==="
testparm disc_p0 disc_p1 disc_p2 disc_p3 disc_p4

* --- Coefficient plot: implied series for disclosure vs non-disclosure ---
* Non-disclosure = β_τ directly
* Disclosure = β_τ + γ_τ via lincom (correct SE from variance-covariance matrix)
preserve
clear
set obs 18

gen tau = .
gen coef = .
gen ci_lo = .
gen ci_hi = .
gen group = ""

* Row indices: 1-9 = disclosure, 10-18 = non-disclosure
forvalues i = 1/9 {
    replace tau = `i' - 5 if _n == `i'
    replace tau = `i' - 5 if _n == `i' + 9
    replace group = "Disclosure" if _n == `i'
    replace group = "Non-Disclosure" if _n == `i' + 9
}

* Reference periods = 0
replace coef  = 0 if tau == -1
replace ci_lo = 0 if tau == -1
replace ci_hi = 0 if tau == -1

estimates restore es_disc_bin

* Fill non-disclosure coefficients (baseline β_τ)
local basevars "ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4"
local taulist "-4 -3 -2 0 1 2 3 4"
local i = 1
foreach v of local basevars {
    local t : word `i' of `taulist'
    local row = `t' + 14
    replace coef  = _b[`v']                   if _n == `row'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v'] if _n == `row'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v'] if _n == `row'
    local i = `i' + 1
}

* Fill disclosure coefficients (β_τ + γ_τ via lincom for correct SE)
local intvars "dbin_m4 dbin_m3 dbin_m2 dbin_p0 dbin_p1 dbin_p2 dbin_p3 dbin_p4"
local i = 1
foreach v of local basevars {
    local t : word `i' of `taulist'
    local row = `t' + 5
    local intv : word `i' of `intvars'
    qui lincom `v' + `intv'
    replace coef  = r(estimate)                   if _n == `row'
    replace ci_lo = r(estimate) - 1.96 * r(se)    if _n == `row'
    replace ci_hi = r(estimate) + 1.96 * r(se)    if _n == `row'
    local i = `i' + 1
}

* Offset tau for visual separation
gen tau_plot = tau - 0.12 if group == "Disclosure"
replace tau_plot = tau + 0.12 if group == "Non-Disclosure"

* Split into group-specific variables for twoway
gen coef_disc    = coef  if group == "Disclosure"
gen coef_nodisc  = coef  if group == "Non-Disclosure"
gen ci_lo_disc   = ci_lo if group == "Disclosure"
gen ci_hi_disc   = ci_hi if group == "Disclosure"
gen ci_lo_nodisc = ci_lo if group == "Non-Disclosure"
gen ci_hi_nodisc = ci_hi if group == "Non-Disclosure"
gen tau_disc     = tau_plot if group == "Disclosure"
gen tau_nodisc   = tau_plot if group == "Non-Disclosure"

twoway (rcap ci_hi_disc ci_lo_disc tau_disc, lcolor(cranberry%50) lwidth(medthin)) ///
       (scatter coef_disc tau_disc, mcolor(cranberry) msymbol(circle) msize(medlarge)) ///
       (rcap ci_hi_nodisc ci_lo_nodisc tau_nodisc, lcolor(navy%50) lwidth(medthin)) ///
       (scatter coef_nodisc tau_nodisc, mcolor(navy) msymbol(square) msize(medlarge)), ///
    xline(-0.5, lcolor(gs8) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(medium)) ///
    ytitle("Effect on ln(Real ZHVI)", size(medium)) ///
    title("LOMR Effect: Disclosure Law Heterogeneity", size(large)) ///
    subtitle("Binary LOMR × disclosure interaction: mandatory vs non-disclosure states", size(medsmall)) ///
    xlabel(-4(1)4, labsize(medsmall)) ///
    ylabel(, labsize(medsmall) angle(horizontal) grid glcolor(gs14)) ///
    legend(order(2 "Disclosure states (β+γ)" 4 "Non-disclosure states (β)") ///
           ring(0) pos(11) cols(1) size(small) region(lcolor(gs12))) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    note("Reference: τ = -1. Full sample. Binary interaction: ebin_τ + ebin_τ × disclosure." ///
         "SE clustered at county. Disclosure CI via lincom.", ///
         size(vsmall) color(gs6))

graph export "$results/s09b_event_study_disclosure.png", replace width(1400)
graph export "$results/s09b_event_study_disclosure.pdf", replace

export delimited using "$results/s09b_event_study_disclosure_coefficients.csv", replace

restore

drop dbin_m4 dbin_m3 dbin_m2 dbin_p0 dbin_p1 dbin_p2 dbin_p3 dbin_p4
drop disc_m4 disc_m3 disc_m2 disc_p0 disc_p1 disc_p2 disc_p3 disc_p4


* =============================================================================
* 9c. HETEROGENEITY: REPUBLICAN VOTE SHARE × LOMR INTENSITY
* =============================================================================
* Do politically conservative counties respond differently to FEMA flood zone
* reclassifications? Hypothesis: Republican-leaning areas may discount
* government risk information, attenuating the LOMR effect on home values.
* Uses same intensity-interaction design as Section 9b (disclosure).

* republican and mean_rep_share already merged in section 1b

di _n "=== Political lean distribution ==="
tab republican ever_treated if event_bin != ., missing
qui count if missing(republican) & event_bin != .
di "Observations with missing election data (excluded from s09c): " r(N)

* --- Create interaction dummies: ibin_τ × republican ---
foreach t in m4 m3 m2 p0 p1 p2 p3 p4 {
    gen rep_`t' = ibin_`t' * republican
}

label var rep_m4 "τ = -4 × intensity × Republican"
label var rep_m3 "τ = -3 × intensity × Republican"
label var rep_m2 "τ = -2 × intensity × Republican"
label var rep_p0 "τ = 0 × intensity × Republican"
label var rep_p1 "τ = +1 × intensity × Republican"
label var rep_p2 "τ = +2 × intensity × Republican"
label var rep_p3 "τ = +3 × intensity × Republican"
label var rep_p4 "τ = +4 × intensity × Republican"

* --- Pooled interaction regression ---
* β_τ (ibin_*) = baseline intensity LOMR effect (Democratic-leaning counties)
* γ_τ (rep_*)  = additional intensity effect in Republican-leaning counties
* Republican implied effect = β_τ + γ_τ (recovered via lincom)
reghdfe ln_real_zhvi ///
    ibin_m4 ibin_m3 ibin_m2 ibin_p0 ibin_p1 ibin_p2 ibin_p3 ibin_p4 ///
    rep_m4 rep_m3 rep_m2 rep_p0 rep_p1 rep_p2 rep_p3 rep_p4 ///
    unemployment_rate ///
    [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_rep_int

* --- Joint F-test: pre-treatment Republican interactions = 0 (parallel trends) ---
di _n "=== Joint F-test: pre-treatment Republican interactions ==="
testparm rep_m4 rep_m3 rep_m2

* --- Joint F-test: all post-treatment Republican interactions = 0 ---
di _n "=== Joint F-test: post-treatment Republican interactions ==="
testparm rep_p0 rep_p1 rep_p2 rep_p3 rep_p4

* --- Regression table ---
esttab es_rep_int using "$results/s09c_regression_republican.tex", replace ///
    keep(ibin_* rep_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    order(ibin_m4 ibin_m3 ibin_m2 ibin_p0 ibin_p1 ibin_p2 ibin_p3 ibin_p4 ///
          rep_m4 rep_m3 rep_m2 rep_p0 rep_p1 rep_p2 rep_p3 rep_p4) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Intensity × Republican Interaction") ///
    title("ln(Real ZHVI) on Policy Intensity × Political Lean") ///
    addnotes("Sample: all treated zips + never-treated controls (full event study sample)." ///
             "ibin = intensity LOMR effect (Dem-leaning counties). rep = differential Republican effect." ///
             "Republican = above-median county Republican two-party vote share." ///
             "Intensity = pre-LOMR NFIP policies / population." ///
             "Zip and county×year FE. SE clustered at county level.")

esttab es_rep_int using "$results/s09c_regression_republican.csv", replace ///
    keep(ibin_* rep_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    order(ibin_m4 ibin_m3 ibin_m2 ibin_p0 ibin_p1 ibin_p2 ibin_p3 ibin_p4 ///
          rep_m4 rep_m3 rep_m2 rep_p0 rep_p1 rep_p2 rep_p3 rep_p4) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Intensity × Republican Interaction") plain

* --- Coefficient plot: implied series for Republican vs Democratic counties ---
* Democratic = β_τ directly (baseline)
* Republican = β_τ + γ_τ via lincom (correct SE from variance-covariance matrix)
preserve
clear
set obs 18

gen tau = .
gen coef = .
gen ci_lo = .
gen ci_hi = .
gen group = ""

* Row indices: 1-9 = Republican, 10-18 = Democratic
forvalues i = 1/9 {
    replace tau = `i' - 5 if _n == `i'
    replace tau = `i' - 5 if _n == `i' + 9
    replace group = "Republican" if _n == `i'
    replace group = "Democratic" if _n == `i' + 9
}

* Reference periods = 0
replace coef  = 0 if tau == -1
replace ci_lo = 0 if tau == -1
replace ci_hi = 0 if tau == -1

estimates restore es_rep_int

* Fill Democratic coefficients (baseline β_τ)
local basevars "ibin_m4 ibin_m3 ibin_m2 ibin_p0 ibin_p1 ibin_p2 ibin_p3 ibin_p4"
local taulist "-4 -3 -2 0 1 2 3 4"
local i = 1
foreach v of local basevars {
    local t : word `i' of `taulist'
    local row = `t' + 14
    replace coef  = _b[`v']                   if _n == `row'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v'] if _n == `row'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v'] if _n == `row'
    local i = `i' + 1
}

* Fill Republican coefficients (β_τ + γ_τ via lincom for correct SE)
local intvars "rep_m4 rep_m3 rep_m2 rep_p0 rep_p1 rep_p2 rep_p3 rep_p4"
local i = 1
foreach v of local basevars {
    local t : word `i' of `taulist'
    local row = `t' + 5
    local intv : word `i' of `intvars'
    qui lincom `v' + `intv'
    replace coef  = r(estimate)                   if _n == `row'
    replace ci_lo = r(estimate) - 1.96 * r(se)    if _n == `row'
    replace ci_hi = r(estimate) + 1.96 * r(se)    if _n == `row'
    local i = `i' + 1
}

* Offset tau for visual separation
gen tau_plot = tau - 0.12 if group == "Republican"
replace tau_plot = tau + 0.12 if group == "Democratic"

* Split into group-specific variables for twoway
gen coef_rep    = coef  if group == "Republican"
gen coef_dem    = coef  if group == "Democratic"
gen ci_lo_rep   = ci_lo if group == "Republican"
gen ci_hi_rep   = ci_hi if group == "Republican"
gen ci_lo_dem   = ci_lo if group == "Democratic"
gen ci_hi_dem   = ci_hi if group == "Democratic"
gen tau_rep     = tau_plot if group == "Republican"
gen tau_dem     = tau_plot if group == "Democratic"

twoway (rcap ci_hi_rep ci_lo_rep tau_rep, lcolor(cranberry%50) lwidth(medthin)) ///
       (scatter coef_rep tau_rep, mcolor(cranberry) msymbol(circle) msize(medlarge)) ///
       (rcap ci_hi_dem ci_lo_dem tau_dem, lcolor(navy%50) lwidth(medthin)) ///
       (scatter coef_dem tau_dem, mcolor(navy) msymbol(square) msize(medlarge)), ///
    xline(-0.5, lcolor(gs8) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(medium)) ///
    ytitle("Effect on ln(Real ZHVI) per Unit Intensity", size(medium)) ///
    title("LOMR Intensity: Political Heterogeneity", size(large)) ///
    subtitle("Republican vs Democratic-leaning counties (median split)", size(medsmall)) ///
    xlabel(-4(1)4, labsize(medsmall)) ///
    ylabel(, labsize(medsmall) angle(horizontal) grid glcolor(gs14)) ///
    legend(order(2 "Republican counties (β+γ)" 4 "Democratic counties (β)") ///
           ring(0) pos(11) cols(1) size(small) region(lcolor(gs12))) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    note("Reference: τ = -1. Full sample. Republican = above-median county R two-party share." ///
         "Intensity = pre-LOMR NFIP policies / pop. SE clustered at county. Republican CI via lincom.", ///
         size(vsmall) color(gs6))

graph export "$results/s09c_event_study_republican.png", replace width(1400)
graph export "$results/s09c_event_study_republican.pdf", replace

export delimited using "$results/s09c_event_study_republican_coefficients.csv", replace

restore

drop rep_m4 rep_m3 rep_m2 rep_p0 rep_p1 rep_p2 rep_p3 rep_p4


* =============================================================================
* 9d. ROBUSTNESS: SFHA-CROSSING LOMRs ONLY
* =============================================================================
* The main specification includes ALL effective LOMRs — informational shocks
* to flood risk designation regardless of whether the SFHA boundary moves.
* Here we restrict to the subset that actually shift the SFHA boundary
* (zone_risk_direction == "up" or "down"), which trigger or remove the
* mandatory flood insurance purchase requirement for federally backed mortgages.
*
* ~34% of treated zips have "stable" LOMRs (BFE updates or sub-zone changes
* that don't move the SFHA boundary). Dropping them isolates the insurance
* mandate channel. If the mandate drives capitalization, this restriction
* should sharpen the effect; if informational updating is the primary channel,
* the effect should be similar to the full-sample estimate.

di _n "=== SFHA-crossing sample restriction ==="
di "Zone risk direction among treated zips:"
tab zone_risk_direction if ever_treated == 1 & event_bin != ., missing

* sfha_crossing already generated in section 2b

di "SFHA-crossing treated zips:"
tab sfha_crossing if ever_treated == 1 & event_bin != ., missing

* --- Spec A: All LOMRs (baseline for comparison) ---
reghdfe ln_real_zhvi ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
    unemployment_rate n_policies ///
    [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_sfha_all

* --- Spec B: SFHA-crossing only ---
* Keep: all never-treated controls + treated zips with SFHA-crossing LOMRs
reghdfe ln_real_zhvi ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
    unemployment_rate n_policies ///
    [aweight=population] if (sfha_crossing == 1 | ever_treated == 0), ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_sfha_cross

* --- Regression table ---
esttab es_sfha_all es_sfha_cross ///
    using "$results/s09d_regression_sfha_crossing.tex", replace ///
    keep(ebin_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("All LOMRs" "SFHA-Crossing Only") ///
    title("ln(Real ZHVI) on SFHA-Crossing LOMRs") ///
    addnotes("Zip and county×year FE. SE clustered at county level." ///
             "SFHA-crossing = zone_risk_direction is 'up' or 'down' (not 'stable')." ///
             "Reference period: τ = -1 (12-0 months before LOMR).")

esttab es_sfha_all es_sfha_cross ///
    using "$results/s09d_regression_sfha_crossing.csv", replace ///
    keep(ebin_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("All LOMRs" "SFHA-Crossing Only") plain

* --- Event study coefficient plot (SFHA-crossing subsample) ---
preserve
clear
set obs 9

gen tau = _n - 5
gen coef = .
gen se = .
gen ci_lo = .
gen ci_hi = .

replace coef  = 0 if tau == -1
replace se    = 0 if tau == -1
replace ci_lo = 0 if tau == -1
replace ci_hi = 0 if tau == -1

estimates restore es_sfha_cross

local varlist "ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4"
local taulist "-4 -3 -2 0 1 2 3 4"
local i = 1
foreach v of local varlist {
    local t : word `i' of `taulist'
    replace coef  = _b[`v']                       if tau == `t'
    replace se    = _se[`v']                       if tau == `t'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v']     if tau == `t'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v']     if tau == `t'
    local i = `i' + 1
}

label define tau_sfha -4 "-4" -3 "-3" -2 "-2" -1 "-1" 0 "0" 1 "+1" 2 "+2" 3 "+3" 4 "+4"
label values tau tau_sfha

twoway (rcap ci_hi ci_lo tau, lcolor(dkgreen%50) lwidth(medthin)) ///
       (scatter coef tau, mcolor(dkgreen) msymbol(circle) msize(medlarge)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(medium)) ///
    ytitle("Effect on ln(Real ZHVI)", size(medium)) ///
    title("Event Study: SFHA-Crossing LOMRs Only", size(large)) ///
    subtitle("Restricted to LOMRs that shift parcels across the SFHA boundary", size(medsmall)) ///
    xlabel(-4(1)4, labsize(medsmall)) ///
    ylabel(, labsize(medsmall) angle(horizontal) grid glcolor(gs14)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    note("Reference: τ = -1. 95% CIs shown. Controls: unemployment, NFIP policies." ///
         "SE clustered at county level. SFHA-crossing: zone risk direction ≠ 'stable'.", ///
         size(vsmall) color(gs6))

graph export "$results/s09d_event_study_sfha_crossing.png", replace width(1400)
graph export "$results/s09d_event_study_sfha_crossing.pdf", replace

export delimited using "$results/s09d_event_study_sfha_crossing_coefficients.csv", replace
restore

drop sfha_crossing


* =============================================================================
* 9.5 ROBUSTNESS: UNWEIGHTED + GEOGRAPHIC INTENSITY
* =============================================================================

* --- 9.5a: Unweighted main specification ---
di _n "=== Robustness: Unweighted main specification ==="
reghdfe ln_real_zhvi ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
    unemployment_rate n_policies, ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_unweighted

* --- 9.5b: Geographic intensity (LOMR area / ZCTA area) ---
di _n "=== Robustness: Geographic treatment intensity ==="
cap drop geo_m4 geo_m3 geo_m2 geo_p0 geo_p1 geo_p2 geo_p3 geo_p4
forvalues k = 4(-1)2 {
    gen geo_m`k' = ebin_m`k' * treatment_intensity
}
forvalues k = 0/4 {
    gen geo_p`k' = ebin_p`k' * treatment_intensity
}

reghdfe ln_real_zhvi geo_m4 geo_m3 geo_m2 geo_p0 geo_p1 geo_p2 geo_p3 geo_p4 ///
    unemployment_rate n_policies [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_geointensity

* --- Robustness comparison table ---
esttab es_main es_unweighted es_geointensity ///
    using "$results/s095_robustness_table.tex", replace ///
    keep(ebin_* geo_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f)) ///
    mtitles("Main (weighted)" "Unweighted" "Geographic Intensity") ///
    title("ln(Real ZHVI) on LOMR (Robustness)") ///
    addnotes("Zip and county×year fixed effects." ///
             "Standard errors clustered at county level." ///
             "Geographic intensity = LOMR polygon area / ZCTA area.")

esttab es_main es_unweighted es_geointensity ///
    using "$results/s095_robustness_table.csv", replace ///
    keep(ebin_* geo_*) se star(* 0.10 ** 0.05 *** 0.01) ///
    label stats(N r2_within, labels("Observations" "Within R²") fmt(%12.0fc %9.4f))

drop geo_m4 geo_m3 geo_m2 geo_p0 geo_p1 geo_p2 geo_p3 geo_p4


* =============================================================================
* 10. MULTI-PANEL FIGURE: SUMMARY + EVENT STUDY
* =============================================================================

* --- Panel (a): Distribution of treatment timing ---
preserve
keep if treated_in_window == 1
collapse (first) first_lomr_date, by(zip)
gen lomr_date = date(first_lomr_date, "YMD")
format lomr_date %td
gen lomr_year = year(lomr_date)

histogram lomr_year, discrete frequency ///
    fcolor(navy%70) lcolor(navy) lwidth(vthin) ///
    xtitle("Year of First LOMR", size(medium)) ///
    ytitle("Number of Zip Codes", size(medium)) ///
    title("Treatment Timing Distribution", size(large)) ///
    xlabel(2009(1)2022, labsize(small) angle(45)) ///
    ylabel(, labsize(medsmall) grid glcolor(gs14)) ///
    graphregion(color(white)) plotregion(margin(medium))

graph export "$results/s10_treatment_timing_hist.png", replace width(1200)
graph save "$results/s10_treatment_timing_hist.gph", replace
restore

* --- Panel (b): Pre-treatment event-time coefficients (parallel trends test) ---
* Shows the pre-treatment coefficients from the main event study (es_main)
* with 95% CIs. A proper parallel trends figure: all coefficients should be
* indistinguishable from zero before treatment.
estimates restore es_main
testparm ebin_m4 ebin_m3 ebin_m2
local pretrend_p : di %5.3f r(p)

preserve
clear
set obs 9
gen tau = _n - 5              // -4, -3, -2, -1, 0, 1, 2, 3, 4
gen coef = .
gen se = .
gen ci_lo = .
gen ci_hi = .

* Reference period (τ = -1): normalized to zero
replace coef  = 0 if tau == -1
replace se    = 0 if tau == -1
replace ci_lo = 0 if tau == -1
replace ci_hi = 0 if tau == -1

* Fill from stored estimates
local varlist "ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4"
local taulist "-4 -3 -2 0 1 2 3 4"
local i = 1
foreach v of local varlist {
    local t : word `i' of `taulist'
    replace coef  = _b[`v']                       if tau == `t'
    replace se    = _se[`v']                       if tau == `t'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v']     if tau == `t'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v']     if tau == `t'
    local i = `i' + 1
}

label define tau_lbl2 -4 "-4" -3 "-3" -2 "-2" -1 "-1" 0 "0" 1 "+1" 2 "+2" 3 "+3" 4 "+4"
label values tau tau_lbl2

twoway (rcap ci_hi ci_lo tau, lcolor(navy%50) lwidth(medthin)) ///
       (scatter coef tau, mcolor(navy) msymbol(circle) msize(medlarge)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(medium)) ///
    ytitle("Effect on ln(Real ZHVI)", size(medium)) ///
    title("Parallel Trends: Pre-Treatment Event-Time Coefficients", size(large)) ///
    subtitle("Pre-treatment joint F-test: p = `pretrend_p'", size(medsmall)) ///
    xlabel(-4(1)4, labsize(medsmall)) ///
    ylabel(, labsize(medsmall) angle(horizontal) grid glcolor(gs14)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    note("Reference period: τ = -1. 95% CIs shown. Zip and county×year FE." ///
         "SE clustered at county level.", ///
         size(vsmall) color(gs6))

graph export "$results/s10_parallel_trends.png", replace width(1200)
graph save "$results/s10_parallel_trends.gph", replace
restore


* Section 11 removed — panels exported as standalone figures above.


* =============================================================================
* 12. BACON DECOMPOSITION (TWFE DIAGNOSTIC)
* =============================================================================
* Goodman-Bacon (2021): the TWFE DiD estimator is a weighted average of all
* 2×2 DiD comparisons. With staggered treatment, some comparisons use
* already-treated units as controls, which can bias estimates.
* This section decomposes the TWFE estimate to show the weight on each type.
*
* Requires: ssc install bacondecomp, replace

preserve

* Collapse to annual panel (bacondecomp works best with annual data)
collapse (mean) ln_real_zhvi (max) treated, by(zip_id yr)

* Balance the panel: keep only zips observed in all years
bysort zip_id: gen _ny = _N
qui tab yr
local total_years = r(r)
di "Total years: `total_years'"
di "Zips before balancing: " _N / `total_years'
keep if _ny == `total_years'
drop _ny
qui tab zip_id
di "Zips after balancing: " r(r)

* Set panel and run decomposition
xtset zip_id yr
bacondecomp ln_real_zhvi treated, ddetail

graph export "$results/s12_bacon_decomposition.png", replace width(1400)
graph export "$results/s12_bacon_decomposition.pdf", replace

* Export Bacon decomposition scatter data to CSV
* bacondecomp stores results in r() matrices after ddetail
capture {
    preserve
    clear
    svmat double e(dd), names(col)
    * Columns: dd_estimate, weight, type (1=timing, 2=always vs timing, 3=never vs timing)
    export delimited using "$results/s12_bacon_decomposition_data.csv", replace
    restore
}

restore


* =============================================================================
* 13. CALLAWAY & SANT'ANNA ROBUST ESTIMATOR
* =============================================================================
* Callaway & Sant'Anna (2021): heterogeneity-robust DiD estimator that avoids
* problematic comparisons identified by Goodman-Bacon. Estimates group-time
* ATTs separately, then aggregates to event study.
*
* Requires: ssc install csdid, replace
*           ssc install drdid, replace

preserve

* Create cohort variable: year of first LOMR (0 = never-treated)
gen lomr_date_stata = date(first_lomr_date, "YMD") if first_lomr_date != ""
gen cohort_yr = year(lomr_date_stata) if lomr_date_stata != .
replace cohort_yr = 0 if ever_treated == 0

* Drop cohorts outside the panel window (2009-2022) — LOMRs with effective
* dates after the panel ends cannot have valid post-treatment observations
replace cohort_yr = . if cohort_yr > 2022
drop if cohort_yr == .
di _n "=== Dropped cohorts after 2022 for C&S estimation ==="

* Collapse to annual panel (csdid is slow on large panels; annual is standard)
collapse (mean) ln_real_zhvi (first) cohort_yr, by(zip_id yr)

* Balance the panel: keep only zips observed in all years
bysort zip_id: gen _ny = _N
qui tab yr
local total_years = r(r)
keep if _ny == `total_years'
drop _ny

di _n "--- CS Estimator: balanced annual panel ---"
qui tab zip_id
di "Zips after balancing: " r(r)
qui tab yr
di "Years in panel: " r(r)
tab cohort_yr if cohort_yr > 0, sort
di "Never-treated zips: " _N - r(N) " (cohort_yr == 0)"

* Set panel
xtset zip_id yr

* CS estimator: not-yet-treated + never-treated as controls
csdid ln_real_zhvi, ivar(zip_id) time(yr) gvar(cohort_yr) notyet

* Event study aggregation
csdid_estat event, window(-3 5) estore(cs_event)

* Plot
csdid_plot, ///
    title("Callaway & Sant'Anna Event Study", size(large)) ///
    subtitle("Heterogeneity-robust DiD estimator", size(medsmall)) ///
    xtitle("Years Relative to LOMR Effective Date", size(medium)) ///
    ytitle("ATT on ln(Real ZHVI)", size(medium)) ///
    graphregion(color(white)) plotregion(margin(medium))

graph export "$results/s13_event_study_cs.png", replace width(1400)
graph export "$results/s13_event_study_cs.pdf", replace

* Export C&S event study coefficients to CSV
estimates restore cs_event
matrix b = e(b)
matrix V = e(V)
local k = colsof(b)
tempname fh
file open `fh' using "$results/s13_event_study_cs_coefficients.csv", write replace
file write `fh' "tau,coef,se,ci_lo,ci_hi" _n
local names : colnames b
local i = 1
foreach name of local names {
    local coef = b[1,`i']
    local se = sqrt(V[`i',`i'])
    local ci_lo = `coef' - 1.96 * `se'
    local ci_hi = `coef' + 1.96 * `se'
    * Extract tau from column name (e.g., "Tp3" -> 3, "Tm2" -> -2)
    local tau = subinstr("`name'", "Tp", "", .)
    local tau = subinstr("`tau'", "Tm", "-", .)
    local tau = subinstr("`tau'", "Pre_avg", "pre", .)
    local tau = subinstr("`tau'", "Post_avg", "post", .)
    file write `fh' "`tau',`coef',`se',`ci_lo',`ci_hi'" _n
    local ++i
}
file close `fh'

restore



* =============================================================================
* 14. PLACEBO TEST: UNEMPLOYMENT AS OUTCOME
* =============================================================================

di _n "=== s14: Placebo test — unemployment rate as outcome ==="

reghdfe unemployment_rate ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
    n_policies [aweight=population], ///
    absorb(zip_id county_yr) cluster(county_id)
estimates store es_placebo

* --- Pre-period joint F-test (placebo parallel trends) ---
di _n "=== Placebo F-test: all pre-treatment coefficients = 0 ==="
testparm ebin_m4 ebin_m3 ebin_m2

* --- Extract coefficients ---
preserve
clear
set obs 9

gen tau = _n - 5
gen coef = .
gen se = .
gen ci_lo = .
gen ci_hi = .

replace coef  = 0 if tau == -1
replace se    = 0 if tau == -1
replace ci_lo = 0 if tau == -1
replace ci_hi = 0 if tau == -1

estimates restore es_placebo

local varlist "ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4"
local taulist "-4 -3 -2 0 1 2 3 4"
local i = 1
foreach v of local varlist {
    local t : word `i' of `taulist'
    replace coef  = _b[`v']                       if tau == `t'
    replace se    = _se[`v']                       if tau == `t'
    replace ci_lo = _b[`v'] - 1.96 * _se[`v']     if tau == `t'
    replace ci_hi = _b[`v'] + 1.96 * _se[`v']     if tau == `t'
    local i = `i' + 1
}

label define tau_lbl14 -4 "-4" -3 "-3" -2 "-2" -1 "-1" 0 "0" 1 "+1" 2 "+2" 3 "+3" 4 "+4"
label values tau tau_lbl14

* --- Plot ---
twoway (rcap ci_hi ci_lo tau, lcolor(navy%50) lwidth(medthin)) ///
       (scatter coef tau, mcolor(navy) msymbol(circle) msize(medlarge)), ///
    xline(-0.5, lcolor(cranberry) lpattern(dash) lwidth(thin)) ///
    yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    xtitle("Years Relative to LOMR Effective Date", size(medium)) ///
    ytitle("Effect on Unemployment Rate", size(medium)) ///
    title("Placebo: LOMR Effect on County Unemployment", size(large)) ///
    subtitle("Should be null if LOMR effect is specific to housing", size(medsmall)) ///
    xlabel(-4(1)4, labsize(medsmall)) ///
    ylabel(, labsize(medsmall) angle(horizontal) grid glcolor(gs14)) ///
    legend(off) ///
    graphregion(color(white) margin(small)) ///
    plotregion(margin(medium)) ///
    note("Reference period: τ = -1. 95% CIs shown." ///
         "SE clustered at county level.", ///
         size(vsmall) color(gs6))

graph export "$results/s14_event_study_placebo.png", replace width(1400)
graph export "$results/s14_event_study_placebo.pdf", replace

export delimited using "$results/s14_event_study_placebo_coefficients.csv", replace

restore


* =============================================================================
* 15. LEAVE-ONE-OUT BY STATE
* =============================================================================

di _n "=== s15: Leave-one-out by state ==="

* Derive state FIPS from county_id (first 2 digits of 5-digit FIPS)
gen state_fips = floor(county_id / 1000)

* Get the full-sample τ=+4 coefficient for reference
estimates restore es_main
local full_coef = _b[ebin_p4]
local full_se = _se[ebin_p4]

* Count states
qui levelsof state_fips, local(states)
local n_states : word count `states'
di "Looping over `n_states' states..."

* Collect results
preserve
clear
set obs `n_states'
gen excluded_state = .
gen coef_p4 = .
gen se_p4 = .
gen ci_lo_p4 = .
gen ci_hi_p4 = .
gen n_obs = .

tempfile loo_results
save `loo_results'
restore

local row = 1
foreach s of local states {
    di "  Excluding state `s' (`row'/`n_states')..."
    qui reghdfe ln_real_zhvi ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
        unemployment_rate n_policies [aweight=population] if state_fips != `s', ///
        absorb(zip_id county_yr) cluster(county_id)

    preserve
    use `loo_results', clear
    replace excluded_state = `s' in `row'
    replace coef_p4 = _b[ebin_p4] in `row'
    replace se_p4 = _se[ebin_p4] in `row'
    replace ci_lo_p4 = _b[ebin_p4] - 1.96 * _se[ebin_p4] in `row'
    replace ci_hi_p4 = _b[ebin_p4] + 1.96 * _se[ebin_p4] in `row'
    replace n_obs = e(N) in `row'
    save `loo_results', replace
    restore

    local row = `row' + 1
}

* Export results
preserve
use `loo_results', clear
export delimited using "$results/s15_leave_one_out_state.csv", replace
restore

* Clean up
drop state_fips


* =============================================================================
* 16. ALTERNATIVE CLUSTERING: STATE-LEVEL
* =============================================================================

di _n "=== s16: Alternative clustering — state vs county ==="

* Derive state FIPS and encode for clustering
gen state_fips_str = string(floor(county_id / 1000), "%02.0f")
encode state_fips_str, gen(state_fips_id)

* Run main spec with state-level clustering
reghdfe ln_real_zhvi ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4 ///
    unemployment_rate n_policies [aweight=population], ///
    absorb(zip_id county_yr) cluster(state_fips_id)
estimates store es_state_cluster

* --- Extract coefficients for both county and state clustering ---
preserve
clear
set obs 18

gen str10 series = ""
gen tau = .
gen coef = .
gen se = .
gen ci_lo = .
gen ci_hi = .

* County clustering series (from es_main)
estimates restore es_main
local varlist "ebin_m4 ebin_m3 ebin_m2 ebin_p0 ebin_p1 ebin_p2 ebin_p3 ebin_p4"
local taulist "-4 -3 -2 0 1 2 3 4"
local row = 1
foreach v of local varlist {
    local t : word `row' of `taulist'
    replace series = "County"                      in `row'
    replace tau    = `t'                          in `row'
    replace coef   = _b[`v']                      in `row'
    replace se     = _se[`v']                     in `row'
    replace ci_lo  = _b[`v'] - 1.96 * _se[`v']   in `row'
    replace ci_hi  = _b[`v'] + 1.96 * _se[`v']   in `row'
    local row = `row' + 1
}
* Reference point τ = -1 for county
replace series = "County" in `row'
replace tau = -1 in `row'
replace coef = 0 in `row'
replace se = 0 in `row'
replace ci_lo = 0 in `row'
replace ci_hi = 0 in `row'
local row = `row' + 1

* State clustering series
estimates restore es_state_cluster
local wix = 1
foreach v of local varlist {
    local t : word `wix' of `taulist'
    replace series = "State"                      in `row'
    replace tau    = `t'                          in `row'
    replace coef   = _b[`v']                      in `row'
    replace se     = _se[`v']                     in `row'
    replace ci_lo  = _b[`v'] - 1.96 * _se[`v']   in `row'
    replace ci_hi  = _b[`v'] + 1.96 * _se[`v']   in `row'
    local row = `row' + 1
    local wix = `wix' + 1
}
* Reference point τ = -1 for state
replace series = "State" in `row'
replace tau = -1 in `row'
replace coef = 0 in `row'
replace se = 0 in `row'
replace ci_lo = 0 in `row'
replace ci_hi = 0 in `row'

sort series tau

export delimited using "$results/s16_event_study_alt_clustering_coefficients.csv", replace
restore

* Clean up
drop state_fips_str state_fips_id


* =============================================================================
* DONE
* =============================================================================

di _n "============================================="
di    "  All outputs saved to: $results/"
di    "============================================="
di    "  s02_summary_stats.tex/csv              — Summary statistics"
di    "  s03_balance_table.tex/csv              — Balance table"
di    "  s04_regression_table.tex/csv           — Regression results (3 specs)"
di    "  s05_event_study_main.png/pdf           — Event study coefficient plot"
di    "  s06_regression_intensity.tex/csv       — Treatment intensity regression"
di    "  s06_event_study_intensity.png/pdf      — Treatment intensity plot"
di    "  s06b_regression_intensity_quartiles.tex/csv — Intensity quartile regression"
di    "  s06b_event_study_intensity_quartiles.png/pdf — Intensity quartile plot"
di    "  s07_did_twfe.tex                       — Simple TWFE DiD"
di    "  s08_regression_insurance.tex/csv       — Insurance market outcomes"
di    "  s08_event_study_policies.png/pdf       — Mechanism: insurance take-up"
di    "  s08b_regression_insurance_updown.tex/csv — Insurance by risk direction"
di    "  s08b_event_study_policies_updown.png/pdf — Insurance take-up: up vs down"
di    "  s09_regression_updown.tex/csv          — Regression: up vs down risk"
di    "  s09_event_study_updown.png/pdf         — Event study: upzoned vs downzoned"
di    "  s09b_regression_disclosure.tex/csv     — Disclosure interaction"
di    "  s09b_event_study_disclosure.png/pdf    — Disclosure heterogeneity plot"
di    "  s09c_regression_republican.tex/csv     — Republican interaction"
di    "  s09c_event_study_republican.png/pdf    — Political heterogeneity plot"
di    "  s10_treatment_timing_hist.png          — Treatment year distribution"
di    "  s10_parallel_trends.png                — Treated vs control trends"
di    "  s12_bacon_decomposition.png/pdf        — Bacon decomposition"
di    "  s13_event_study_cs.png/pdf             — Callaway & Sant'Anna"
di    "  s14_event_study_placebo.png/pdf/csv    — Placebo: unemployment outcome"
di    "  s15_leave_one_out_state.csv            — Leave-one-out by state"
di    "  s16_alt_clustering_coefficients.csv    — State vs county clustering"
di    "============================================="

capture log close
