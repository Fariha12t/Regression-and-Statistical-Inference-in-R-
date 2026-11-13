# Regression and Statistical Inference in R

A complete statistical analysis of the **High School and Beyond** survey (7,185 US students in 160 schools): what predicts mathematics achievement, and how much do the conclusions depend on handling the **students-within-schools** structure correctly?

The project covers linear regression, generalised linear models and mixed-effects models, with assumption checks at every stage, bootstrap confidence intervals, a simulation study of interval coverage, multiple-testing correction, and a written report.

**Read the report:** [`report.md`](report.md) (renders on GitHub) or regenerate `report.html` locally with `Rscript run_all.R` for the table of contents and collapsible code.

| | |
|---|---|
| **Language / tools** | R 4.3, tidyverse, `lme4`, R Markdown (also `broom`, `broom.mixed`, `car`, `lmtest`, `sandwich`, `patchwork`) |
| **Data** | `nlme::MathAchieve` + `nlme::MathAchSchool` (education, 1982 US survey; ships with R, no download) |
| **Reproducible** | Fixed seed (2026), one command (`Rscript run_all.R`), tables and figures written to `outputs/` |

---

## Key findings

1. **Schools matter.** 18% of the variance in maths scores is between schools (ICC = 0.18, 95% parametric-bootstrap CI 0.14 to 0.22).
2. **Ignoring clustering gives overconfident inference.** Classical OLS standard errors for school-level predictors are about 1.7 times too small. In a 500-replicate simulation, nominal 95% intervals for the Catholic-sector effect and for school mean SES covered the truth only about 73 to 74% of the time, versus about 93 to 95% for cluster-robust and cluster-bootstrap intervals.
3. **Effects (final mixed model).** Minority status is associated with about 2.8 points lower achievement, female sex with about 1.2 lower, a school with one unit higher mean SES with about 4 points higher, and Catholic schools with about 1.7 points higher at average SES.
4. **The Catholic-school advantage depends on student SES.** The SES gradient is flatter in Catholic schools (cross-level interaction, LRT p < 0.001); the sector gap is clearest for lower-SES students and absent for high-SES non-minority students.
5. **Multiple testing changes the story.** Of 160 per-school slope tests, 12 are significant unadjusted (about 8 expected by chance) but at most 1 survives Holm, Bonferroni or BH correction, and none survive BY.
6. **GLM checks matter too.** A school-level binomial model is overdispersed (Pearson dispersion 2.3), so quasi-likelihood standard errors are used. A logistic GLMM confirms the logistic GLM's conclusions with wider, cluster-aware intervals for school-level predictors.

<p align="center">
  <img src="outputs/figures/coverage-figure-1.png" width="48%" alt="Coverage of 95% confidence intervals by method">
  <img src="outputs/figures/interaction-plot-1.png" width="48%" alt="Predicted achievement by SES and school sector">
</p>

---

## Results

All tables below are produced by `run_all.R` and saved as CSV in [`outputs/tables/`](outputs/tables/). Figures are in [`outputs/figures/`](outputs/figures/). Numbers are from the full run (2,000 cluster-bootstrap, 500 parametric-bootstrap and 500 coverage-simulation replicates).

### 1. Data overview

| Sector | Schools | Students | Mean maths | SD maths | Mean SES | % minority | % female | % top quartile |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Public | 90 | 3,642 | 11.36 | 7.08 | -0.15 | 25.3 | 52.5 | 20.1 |
| Catholic | 70 | 3,543 | 14.17 | 6.36 | 0.15 | 29.7 | 53.1 | 30.1 |

Source: `01_descriptives_by_sector.csv`. Catholic-school students score about 2.8 points higher on average, before adjusting for anything.

<p align="center">
  <img src="outputs/figures/eda-figure-1.png" width="85%" alt="Exploratory plots of maths achievement, SES and school sector">
</p>

### 2. Linear regression (OLS) and its assumption checks

Outcome: maths achievement. Student SES is split into a within-school part and a school-mean part.

| Term | Estimate | SE | 95% CI | p |
|---|---:|---:|---:|---|
| Intercept | 13.34 | 0.13 | [13.08, 13.60] | <0.001 |
| SES, within school (per unit) | 1.92 | 0.11 | [1.71, 2.14] | <0.001 |
| School mean SES (per unit) | 3.93 | 0.20 | [3.53, 4.32] | <0.001 |
| Minority (vs not) | -2.71 | 0.18 | [-3.05, -2.36] | <0.001 |
| Female (vs male) | -1.37 | 0.15 | [-1.66, -1.09] | <0.001 |
| Catholic school (vs public) | 1.77 | 0.16 | [1.47, 2.08] | <0.001 |

Source: `02_ols_coefficients.csv`.

| Check | Result |
|---|---|
| Breusch-Pagan (constant variance) | BP = 55.4, df = 5, p < 0.001 |
| Skewness of residuals | -0.17 |
| Excess kurtosis of residuals | -0.53 |
| Max Cook's distance | 0.0021 |
| Max VIF | 1.32 |

Source: `03_ols_assumption_checks.csv`. No influential points and no collinearity; mild heteroscedasticity. The independence assumption is the real problem (next section).

### 3. Clustering: classical vs robust vs mixed-model standard errors

| Term | Estimate | Classical SE | HC3 SE | Cluster-robust SE | Mixed-model SE | Cluster / classical |
|---|---:|---:|---:|---:|---:|---:|
| Intercept | 13.34 | 0.134 | 0.141 | 0.202 | 0.202 | 1.52 |
| SES, within school | 1.92 | 0.111 | 0.111 | 0.122 | 0.108 | 1.10 |
| School mean SES | 3.93 | 0.201 | 0.198 | 0.348 | 0.343 | **1.73** |
| Minority | -2.71 | 0.175 | 0.173 | 0.264 | 0.201 | 1.50 |
| Female | -1.37 | 0.145 | 0.146 | 0.199 | 0.159 | 1.37 |
| Catholic school | 1.77 | 0.158 | 0.158 | 0.273 | 0.278 | **1.73** |

Source: `04_standard_error_comparison.csv`. The inflation is largest for school-level predictors (school mean SES, sector). HC3 fixes heteroscedasticity but not clustering, so it barely changes the SEs. The residual ICC after adjustment is 0.046.

<p align="center">
  <img src="outputs/figures/se-figure-1.png" width="70%" alt="Standard errors by method">
</p>

### 4. Linear mixed-effects models

**Model comparison** (likelihood-ratio tests, boundary-corrected where the null puts a variance on the boundary):

| Question | LR statistic | df | p |
|---|---:|---|---:|
| Do SES slopes vary randomly across schools? (M1 vs M2) | 5.19 | 1 + 1 (boundary) | 0.049 |
| Do sector and school SES moderate the SES slope? (M1 vs M3a) | 40.87 | 2 | <0.001 |
| Do slopes still vary after those interactions? (M3a vs M3b) | 0.02 | 1 + 1 (boundary) | 0.947 |

Source: `05_lrt_model_comparison.csv`. A random slope looks marginally useful alone, but that variation is explained by sector and school SES. **M3a (random intercept plus the two cross-level interactions) is the final model.**

**Final model fixed effects (REML):**

| Term | Estimate | SE | 95% CI | t |
|---|---:|---:|---:|---:|
| Intercept | 13.31 | 0.20 | [12.91, 13.70] | 65.9 |
| SES, within school (per unit) | 2.58 | 0.15 | [2.29, 2.88] | 17.1 |
| Catholic school (vs public) | 1.71 | 0.28 | [1.16, 2.25] | 6.1 |
| School mean SES (per unit) | 4.05 | 0.34 | [3.38, 4.72] | 11.8 |
| Minority (vs not) | -2.77 | 0.20 | [-3.17, -2.38] | -13.8 |
| Female (vs male) | -1.22 | 0.16 | [-1.54, -0.91] | -7.7 |
| Within-school SES x Catholic | -1.44 | 0.23 | [-1.89, -0.99] | -6.2 |
| Within-school SES x School mean SES | 1.00 | 0.29 | [0.44, 1.56] | 3.5 |

Source: `06_lmm_fixed_effects.csv`. Between-school SD of intercepts = 1.34, residual SD = 5.98. Residual ICC falls from 0.18 (null model) to 0.048. Marginal R² = 0.213, conditional R² = 0.25.

**Reading the interactions:** the SES slope is steeper in public schools and weaker in Catholic schools (-1.44 per unit), and steeper in schools with higher mean SES (+1.00). Catholic schools therefore help lower-SES students most.

<p align="center">
  <img src="outputs/figures/lmm-diagnostics-1.png" width="85%" alt="Mixed-model residual and random-effect diagnostics">
</p>

### 5. Generalised linear models (top-quartile achievement)

The binary outcome is derived from the continuous score purely to demonstrate GLMs.

**Student-level logistic regression:**

| Term | Odds ratio | 95% CI | p |
|---|---:|---:|---|
| SES, within school (per unit) | 1.66 | [1.52, 1.82] | <0.001 |
| School mean SES (per unit) | 2.86 | [2.42, 3.38] | <0.001 |
| Minority (vs not) | 0.38 | [0.33, 0.45] | <0.001 |
| Female (vs male) | 0.59 | [0.53, 0.66] | <0.001 |
| Catholic school (vs public) | 1.40 | [1.24, 1.59] | <0.001 |

| Check | Result |
|---|---|
| Linearity of the logit (add quadratic SES terms, LRT) | chi2(2) = 0.04, p = 0.98 |
| Max VIF | 1.22 |
| Max Cook's distance | 0.0023 |
| Share of binned residuals inside the 95% band | 94% |
| AUC (discrimination) | 0.71 |

Sources: `07_logistic_odds_ratios.csv`, `08_logistic_checks.csv`.

**Classical GLM vs cluster-robust vs GLMM (odds ratios, 95% CI):**

| Term | GLM, classical | GLM, cluster-robust | GLMM (random intercept) |
|---|---:|---:|---:|
| SES, within school | 1.66 [1.52, 1.82] | 1.66 [1.52, 1.83] | 1.69 [1.54, 1.86] |
| School mean SES | 2.86 [2.42, 3.38] | 2.86 [2.25, 3.63] | 3.05 [2.38, 3.91] |
| Minority | 0.38 [0.33, 0.45] | 0.38 [0.31, 0.48] | 0.38 [0.31, 0.45] |
| Female | 0.59 [0.53, 0.66] | 0.59 [0.51, 0.68] | 0.61 [0.54, 0.70] |
| Catholic school | 1.40 [1.24, 1.59] | 1.40 [1.18, 1.67] | 1.38 [1.14, 1.67] |

Source: `10_glm_vs_glmm_odds_ratios.csv`. Point estimates barely move, but intervals for school-level predictors are wider once clustering is respected. The GLMM's random-intercept SD is 0.41 (latent-scale ICC 0.048).

**School-level binomial GLM** (Pearson dispersion = 2.30, so binomial SEs are too small by about 1.5x):

| Term | Odds ratio | Binomial SE | Quasi SE | Binomial p | Quasi p |
|---|---:|---:|---:|---|---|
| School mean SES | 2.20 | 0.108 | 0.164 | <0.001 | <0.001 |
| Catholic (vs public) | 1.08 | 0.096 | 0.145 | 0.401 | 0.581 |
| Academic-track share | 2.62 | 0.206 | 0.312 | <0.001 | 0.002 |
| Disciplinary climate | 0.95 | 0.046 | 0.070 | 0.269 | 0.467 |
| High-minority school | 0.62 | 0.076 | 0.116 | <0.001 | <0.001 |
| Enrolment (per 1,000) | 1.31 | 0.056 | 0.085 | <0.001 | 0.002 |

Source: `09_school_level_glm.csv`. Conclusions for school mean SES, academic-track share, high-minority enrolment and size survive the quasi-binomial correction; sector and disciplinary climate do not differ from zero here.

<p align="center">
  <img src="outputs/figures/glm-diagnostics-1.png" width="48%" alt="Logistic GLM diagnostics">
  <img src="outputs/figures/glmm-1.png" width="48%" alt="GLM vs GLMM odds ratios">
</p>

### 6. Bootstrap confidence intervals

**Naive (student) vs cluster (school) bootstrap for OLS:**

| Term | Naive boot SE | Naive 95% CI | Cluster boot SE | Cluster 95% CI |
|---|---:|---:|---:|---:|
| SES, within school | 0.113 | [1.70, 2.15] | 0.121 | [1.69, 2.17] |
| School mean SES | 0.202 | [3.54, 4.33] | **0.357** | [3.24, 4.63] |
| Minority | 0.169 | [-3.04, -2.38] | 0.264 | [-3.23, -2.21] |
| Female | 0.144 | [-1.66, -1.10] | 0.200 | [-1.77, -1.00] |
| Catholic school | 0.163 | [1.45, 2.09] | **0.277** | [1.22, 2.29] |

Source: `11_bootstrap_ols.csv`. Resampling students ignores the clustering and reproduces the too-narrow classical intervals; resampling whole schools reproduces the cluster-robust ones.

**Three interval methods for the mixed model (Wald, profile likelihood, parametric bootstrap):**

| Parameter | Estimate | Wald | Profile | Parametric bootstrap |
|---|---:|---|---|---|
| SD of school intercepts | 1.34 | n/a | [1.11, 1.55] | [1.11, 1.58] |
| Residual SD | 5.98 | n/a | [5.88, 6.07] | [5.88, 6.08] |
| School mean SES | 4.05 | [3.38, 4.72] | [3.38, 4.72] | [3.37, 4.71] |
| Catholic school | 1.71 | [1.16, 2.25] | [1.16, 2.25] | [1.17, 2.24] |
| Minority | -2.77 | [-3.17, -2.38] | [-3.17, -2.38] | [-3.21, -2.43] |
| Within-school SES x Catholic | -1.44 | [-1.89, -0.99] | [-1.89, -0.99] | [-1.89, -0.99] |

Source: `12_lmm_confidence_intervals.csv` (full table includes all fixed effects). The three methods agree closely, which supports the Wald intervals here.

<p align="center">
  <img src="outputs/figures/bootstrap-figure-1.png" width="70%" alt="Bootstrap distributions: naive vs cluster">
</p>

### 7. Simulation study: coverage of nominal 95% intervals

500 replicates, data simulated from the fitted model with known true effects.

| Term | Classical | Cluster-robust | Cluster bootstrap |
|---|---:|---:|---:|
| SES, within school | 96.4% | 96.4% | 96.8% |
| School mean SES | **74.0%** | 94.4% | 93.4% |
| Catholic school | **73.2%** | 95.4% | 94.2% |
| Minority | 86.2% | 95.8% | 94.8% |
| Female | 88.0% | 96.2% | 96.8% |

Source: `13_coverage_simulation.csv`. Classical intervals only achieve nominal coverage for the within-school predictor; for school-level predictors they cover about three times in four. Cluster-robust and cluster-bootstrap intervals stay close to 95% at a modest cost in width (about 1.6x wider for the school-level effects).

### 8. Multiple testing

**Family 1: 160 per-school SES-slope tests** (`14_school_slope_tests.csv`)

| Procedure | Schools rejected (of 160) |
|---|---:|
| Unadjusted (p < 0.05) | 12 |
| Bonferroni (FWER) | 1 |
| Holm (FWER) | 1 |
| Benjamini-Hochberg (FDR) | 1 |
| Benjamini-Yekutieli (FDR) | 0 |

About 8 rejections are expected by chance alone at the 5% level, so 12 unadjusted is barely more than noise, and the adjusted counts agree.

**Family 2: Catholic-vs-public gap in 12 sex x minority x SES subgroups** (`16_subgroup_sector_gap.csv`)

| Procedure | Subgroups rejected (of 12) |
|---|---:|
| Unadjusted | 8 |
| Bonferroni (FWER) | 6 |
| Holm (FWER) | 8 |
| Benjamini-Hochberg (FDR) | 8 |
| Benjamini-Yekutieli (FDR) | 8 |

Here the signal is real and survives correction. The estimated Catholic advantage (points, Holm-adjusted conclusions):

| Subgroup | Low SES | Mid SES | High SES |
|---|---:|---:|---:|
| Male, non-minority | 1.85 (sig.) | 2.38 (sig.) | 0.24 (n.s.) |
| Male, minority | 3.98 (sig.) | 1.70 (n.s.) | 4.45 (sig.) |
| Female, non-minority | 2.74 (sig.) | 1.58 (sig.) | -0.24 (n.s.) |
| Female, minority | 3.10 (sig.) | 3.15 (sig.) | 1.74 (n.s.) |

The gap is largest and most reliable for lower-SES and minority students and disappears for high-SES non-minority students. Minority subgroups have fewer students and schools, so their estimates are less precise.

<p align="center">
  <img src="outputs/figures/mt-schools-figure-1.png" width="48%" alt="Per-school slope tests and adjusted p-values">
  <img src="outputs/figures/mt-subgroups-figure-1.png" width="48%" alt="Subgroup sector gaps with adjusted significance">
</p>

---

## What the project demonstrates

| Skill | Where |
|---|---|
| Linear regression with full diagnostics (residual plots, Q-Q, scale-location, Cook's distance, VIF, Breusch-Pagan) | Report section 4 |
| Detecting and quantifying a violated independence assumption (residual ICC, design effect, robust vs classical SEs) | Section 5 |
| Linear mixed-effects models in `lme4`: random intercepts and slopes, cross-level interactions, ML vs REML, boundary-corrected LRTs, R², level-1 and level-2 diagnostics | Section 6 |
| GLMs: logistic regression (calibration, binned residuals, ROC/AUC, linearity of the logit), overdispersion and quasi-binomial, logistic GLMM, marginal vs conditional odds ratios | Section 7 |
| Bootstrap confidence intervals: cluster vs naive case bootstrap, parametric bootstrap for mixed models, bootstrap CI for the ICC, profile and Wald comparison | Section 8 |
| Simulation study of CI coverage | Section 8.4 |
| Multiple-testing correction: Bonferroni, Holm (FWER), Benjamini-Hochberg, Benjamini-Yekutieli (FDR) on two families of tests | Section 9 |
| Clear interpretation, limitations and non-causal framing | Sections 6, 10 |

## Repository structure

```
Regression-and-Statistical-Inference-in-R-/
├── report.Rmd              # the analysis and written report (source)
├── report.md / report.html # rendered report
├── run_all.R               # reproduces everything
├── install_packages.R      # installs the CRAN packages used
├── R/
│   ├── 00_setup.R          # packages, seed, bootstrap sizes, plotting theme
│   ├── data.R              # data loading and preparation, data dictionary
│   ├── diagnostics.R       # lm / glm / mixed-model diagnostic helpers
│   └── inference.R         # cluster bootstrap, robust SEs, coverage simulation, p-value adjustment
├── data/                   # analysis data set and data dictionary (CSV)
├── outputs/
│   ├── figures/            # all figures (PNG)
│   └── tables/             # all result tables (CSV, files 01 to 17)
└── tests/smoke_test.R      # quick sanity checks for the helper functions
```

## How to run

```bash
git clone https://github.com/Fariha12t/Regression-and-Statistical-Inference-in-R-.git
cd Regression-and-Statistical-Inference-in-R-
Rscript install_packages.R        # once
Rscript run_all.R                 # full run, a few minutes
Rscript tests/smoke_test.R        # optional sanity checks (about 10 seconds)
```

Run all commands from the project root, because the scripts use relative paths.

A quick run with smaller bootstrap sizes (numbers will differ slightly from the tables above):

```bash
N_BOOT_CLUSTER=200 N_BOOT_PARAM=100 N_SIM_COVERAGE=50 Rscript run_all.R
```

Rendering to HTML needs [Pandoc](https://pandoc.org/) (bundled with RStudio). The project was developed with R 4.3.3; the report ends with a full `sessionInfo()`.

**GitHub Codespaces / Ubuntu:** install R and the packages from apt for a fast setup:

```bash
sudo apt-get update
sudo apt-get install -y r-base r-base-dev pandoc \
  r-cran-tidyverse r-cran-lme4 r-cran-broom r-cran-broom.mixed r-cran-car \
  r-cran-lmtest r-cran-sandwich r-cran-patchwork r-cran-scales \
  r-cran-knitr r-cran-rmarkdown
```

## Data dictionary

| Variable | Level | Description |
|---|---|---|
| `School` | school | School identifier (160 schools) |
| `MathAch` | student | Mathematics achievement score (outcome, continuous) |
| `SES` | student | Socio-economic status index (roughly centred at 0) |
| `ses_c` | student | SES minus own school's mean SES (within-school SES) |
| `ses_mean` | school | School mean SES (between-school SES) |
| `Minority` | student | Ethnic minority status (No/Yes) |
| `Sex` | student | Male/Female |
| `Sector` | school | Public or Catholic |
| `Size` | school | School enrolment |
| `PRACAD` | school | Proportion of students on the academic track |
| `DISCLIM` | school | Disciplinary climate scale (higher = worse climate) |
| `HIMINTY` | school | High-minority-enrolment school (0/1) |
| `n_school` | school | Students sampled in the school |
| `high_ach` | student | 1 if `MathAch` is in the top quartile (derived binary outcome) |

## Notes on the data and design choices

* **Data:** the High School and Beyond survey as distributed in `nlme` (Raudenbush & Bryk, 2002, *Hierarchical Linear Models*). Student SES is split into within-school and between-school parts so each effect is estimated separately.
* **Binary outcome:** "top-quartile achiever" is derived from the continuous score purely to demonstrate GLMs. The linear mixed models are the primary analysis.
* **Limitations:** observational, 1982 data, no survey weights, and no causal interpretation of the sector effect. See report section 10.

## Optional: publish the HTML report with GitHub Pages

In the repository, go to Settings, then Pages, choose "Deploy from a branch", select `main` and `/ (root)`. The report will then be available at `https://<your-username>.github.io/Regression-and-Statistical-Inference-in-R-/report.html`.


