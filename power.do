

// The following statistics were taken from Ramukov.org and support the parameter assignments in the below script for simulating power
// https://razumkov.org.ua/napriamky/sotsiologichni-doslidzhennia/identychnist-gromadian-ukrainy-tendentsii-zmin-cherven-2024r
// - 91% of Ukrainians expressed pride in citizenship in 2024 (up from 68% in 2015).
// - 53% primarily identified with Ukraine in 2024 (up from 31% in 2006).
// - 94.7% identified as Ukrainian in 2024, compared to 87.3% in 2021.
// - AEA P&P (https://www.aeaweb.org/articles?id=10.1257/pandp.20241056) data shows that the use of Ukrainian in tweets increased from 53% in January 2022 to 79% by November 2022.


clear all
set seed 12345

local reps 1000  // # monte carlo simulations per sample size
local min_obs 800  // min sample size
local max_obs 1100  // max sample size
local step 100     // sample size step

// set parameter values
local 1st_treat // the effect of the prime on social indentity index
local identity_mean 0.5 // mean of social identiy index
local identity_var 0.1 // variance of noise for social identiy index
local 2nd_treat 2 // the effect of the predicted social identity IV on prices in labor task
local price_mean 1.5 // mean of hourly wage (minimum wage in Ukraine)
local price_var 1 // variance of noise for hourly wage 
local sig 0.01 // significance value required for statistical significance

tempfile results
save `results', emptyok

forval n = `min_obs'(`step')`max_obs' {
    di "Running for sample size = `n'"

    // save pvals
    tempfile pvals
    save `pvals', emptyok

    forval i = 1/`reps' {
        drop _all
        set obs `n'  // obs for sample

        * treatment randomization of prime 50/50
        gen prime = rbinomial(1, 0.5)

        * create social identity index between 0 and 1, 
        gen identity_index_unbounded = `identity_mean' + 0.1 * prime + rnormal(0, `identity_var')  
//         gen identity_index = invlogit(identity_index_unbounded)  // btw 0 and 1

        * outcome for experimental task with prices, and then norm the price to be between 0 and 1
        gen unbounded_price = `price_mean' + `2nd_treat' * identity_index + rnormal(0, `price_var')
//         gen price = invlogit(unbounded_price) // btw 0 and 1

        * 1st stage reg, identify identity index with prime treatment 
        reg identity_index prime

        * pred identity using random prime
        predict identity_hat

        * 2nd stage reg
        reg unbounded_price identity_hat

        * 2nd stage pval
        matrix pval = r(table)
        local p_value = pval[4,1]  // pval for identity_hat

        * pval to temp
        clear
        set obs 1
        gen iter = `i'
        gen p_value = .
        replace p_value = `p_value'
        append using `pvals'
        save `pvals', replace
    }

    * p-values for this sample
    use `pvals', clear

    * proportion of significant results (p-value < 0.01)
    count if p_value < `sig'
    local prop_signif = r(N)/`reps'

    * sample size and prop of sig results
    clear
    set obs 1
    gen obs = `n'
    gen proportion_significant = `prop_signif'
    append using `results'
    save `results', replace
}


use `results', clear
list
