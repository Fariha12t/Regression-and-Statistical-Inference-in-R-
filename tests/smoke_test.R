# ------------------------------------------------------------------
# tests/smoke_test.R  -  fast sanity checks (about 10 seconds)
#   Rscript tests/smoke_test.R        (run from the project root)
# ------------------------------------------------------------------
source("R/00_setup.R"); source("R/data.R"); source("R/diagnostics.R"); source("R/inference.R")
ok <- function(cond, msg) { stopifnot(cond); cat("PASS:", msg, "\n") }

hsb <- load_hsb()
ok(nrow(hsb) == 7185 && n_distinct(hsb$School) == 160, "data: 7,185 students in 160 schools")
ok(!anyNA(hsb), "data: no missing values")
ok(abs(mean(hsb$high_ach) - 0.25) < 0.01, "data: top-quartile outcome has ~25% prevalence")
ok(max(abs(tapply(hsb$ses_c, hsb$School, mean))) < 1e-10, "data: within-school SES is centred in every school")

# AUC against a hand-computed value
ok(abs(auc(c(0, 0, 1, 1), c(.1, .4, .35, .8)) - 0.75) < 1e-12, "auc(): matches known value 0.75")

# Multiple-testing adjustments are ordered as theory says
p <- tibble(p_raw = c(.001, .01, .02, .04, .30, .70)) |> adjust_pvalues()
ok(all(p$p_holm >= p$p_raw) && all(p$p_bonferroni >= p$p_holm) && all(p$p_bh <= p$p_holm),
   "adjust_pvalues(): Bonferroni >= Holm >= raw and BH <= Holm")

# Boundary LRT p-value is smaller than the naive chi2(2) p-value
ok(p_boundary_lrt(5) < pchisq(5, 2, lower.tail = FALSE), "p_boundary_lrt(): less conservative than chi2(2)")

# Cluster bootstrap reproduces the sandwich cluster-robust SE (within 15%)
f  <- MathAch ~ ses_c + ses_mean + Minority + Sex + Sector
m  <- lm(f, hsb)
bt <- cluster_boot_ols(f, hsb, "School", B = 400, seed = 1)
se_boot <- apply(bt, 2, sd)["ses_mean"]
se_cl   <- sqrt(diag(sandwich::vcovCL(m, cluster = hsb$School, type = "HC1")))["ses_mean"]
ok(abs(se_boot / se_cl - 1) < .15, "cluster_boot_ols(): bootstrap SE ~ cluster-robust SE")

# Bootstrap point estimates centre on the OLS estimates
ok(all(abs(colMeans(bt) - coef(m)) < 0.1), "cluster_boot_ols(): replicate means centre on OLS estimates")
cat("\nAll smoke tests passed.\n")
