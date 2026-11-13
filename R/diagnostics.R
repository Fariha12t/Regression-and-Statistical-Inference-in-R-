# ------------------------------------------------------------------
# diagnostics.R  -  assumption-checking helpers
# ------------------------------------------------------------------

# ---- Linear model: the classic four-panel check, in ggplot2 -------
diag_plots_lm <- function(fit) {
  d <- broom::augment(fit) |>
    mutate(obs = row_number(),
           std_resid = .std.resid,
           sqrt_abs  = sqrt(abs(.std.resid)))

  p1 <- ggplot(d, aes(.fitted, .resid)) +
    geom_point(alpha = .25, size = .8) +
    geom_hline(yintercept = 0, linetype = 2) +
    geom_smooth(se = FALSE, colour = "#D55E00", linewidth = .8, method = "gam") +
    labs(title = "Residuals vs fitted", x = "Fitted", y = "Residual")

  p2 <- ggplot(d, aes(sample = std_resid)) +
    stat_qq(alpha = .25, size = .8) + stat_qq_line(colour = "#D55E00") +
    labs(title = "Normal Q-Q", x = "Theoretical quantiles", y = "Standardised residual")

  p3 <- ggplot(d, aes(.fitted, sqrt_abs)) +
    geom_point(alpha = .25, size = .8) +
    geom_smooth(se = FALSE, colour = "#D55E00", linewidth = .8, method = "gam") +
    labs(title = "Scale-location", x = "Fitted", y = expression(sqrt(abs(std.~resid))))

  thr <- 4 / nrow(d)
  p4 <- ggplot(d, aes(obs, .cooksd)) +
    geom_col(width = 1, fill = "grey40") +
    geom_hline(yintercept = thr, linetype = 2, colour = "#D55E00") +
    labs(title = "Cook's distance", subtitle = "dashed line = 4/n rule of thumb",
         x = "Observation", y = "Cook's D")

  (p1 | p2) / (p3 | p4)
}

# Compact table of numeric assumption tests for an lm
lm_assumption_tests <- function(fit) {
  bp  <- lmtest::bptest(fit)                          # heteroscedasticity
  res <- residuals(fit)
  tibble::tibble(
    check = c("Breusch-Pagan (constant variance)",
              "Skewness of residuals", "Excess kurtosis of residuals",
              "Max Cook's distance", "Max VIF"),
    value = c(sprintf("BP = %.1f, df = %d, p %s", unname(bp$statistic),
                      unname(bp$parameter), fmt_p(bp$p.value)),
              sprintf("%.2f", mean((res - mean(res))^3) / sd(res)^3),
              sprintf("%.2f", mean((res - mean(res))^4) / sd(res)^4 - 3),
              sprintf("%.4f", max(cooks.distance(fit))),
              sprintf("%.2f", max(car::vif(fit))))
  )
}

# ---- Logistic GLM -------------------------------------------------
# Binned residuals (Gelman & Hill): average residual per bin of fitted
# probability, with +/- 2 SE bands. ~95% of bins should fall inside.
binned_residuals <- function(fit, n_bins = NULL) {
  d <- tibble::tibble(p = fitted(fit),
                      r = residuals(fit, type = "response"))
  n_bins <- n_bins %||% floor(sqrt(nrow(d)))
  d |>
    mutate(bin = ntile(p, n_bins)) |>
    group_by(bin) |>
    summarise(p_mean = mean(p), r_mean = mean(r), n = n(),
              se = sqrt(mean(p) * (1 - mean(p)) / n()), .groups = "drop")
}

plot_binned_residuals <- function(fit, title = "Binned residuals") {
  b <- binned_residuals(fit)
  inside <- mean(abs(b$r_mean) <= 2 * b$se)
  ggplot(b, aes(p_mean, r_mean)) +
    geom_ribbon(aes(ymin = -2 * se, ymax = 2 * se), fill = "grey85") +
    geom_hline(yintercept = 0) +
    geom_point(aes(colour = abs(r_mean) > 2 * se), show.legend = FALSE) +
    scale_colour_manual(values = c(`FALSE` = "grey20", `TRUE` = "#D55E00")) +
    labs(title = title, subtitle = sprintf("%.0f%% of bins inside the 95%% band", 100 * inside),
         x = "Mean predicted probability", y = "Mean residual")
}

calibration_table <- function(y, p, n_bins = 10) {
  tibble::tibble(y, p) |>
    mutate(bin = ntile(p, n_bins)) |>
    group_by(bin) |>
    summarise(predicted = mean(p), observed = mean(y), n = n(), .groups = "drop")
}

plot_calibration <- function(y, p, title = "Calibration") {
  ggplot(calibration_table(y, p), aes(predicted, observed)) +
    geom_abline(linetype = 2) +
    geom_line(colour = "grey50") + geom_point(size = 2) +
    coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
    labs(title = title, x = "Mean predicted probability (decile)", y = "Observed proportion")
}

# AUC via the Mann-Whitney identity, plus the ROC curve
auc <- function(y, p) {
  r <- rank(p); n1 <- sum(y == 1); n0 <- sum(y == 0)
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}
roc_curve <- function(y, p) {
  o <- order(p, decreasing = TRUE)
  tibble::tibble(fpr = c(0, cumsum(y[o] == 0) / sum(y == 0)),
                 tpr = c(0, cumsum(y[o] == 1) / sum(y == 1)))
}

# ---- Mixed models -------------------------------------------------
plot_lmm_diagnostics <- function(fit) {
  d <- tibble::tibble(fitted = fitted(fit), resid = resid(fit, scaled = TRUE))
  re <- ranef(fit)[[1]]                       # random effects for the grouping factor
  re_int <- tibble::tibble(u = re[["(Intercept)"]])

  p1 <- ggplot(d, aes(fitted, resid)) +
    geom_point(alpha = .2, size = .8) + geom_hline(yintercept = 0, linetype = 2) +
    geom_smooth(se = FALSE, colour = "#D55E00", linewidth = .8, method = "gam") +
    labs(title = "Level 1: residuals vs fitted", x = "Fitted", y = "Scaled residual")
  p2 <- ggplot(d, aes(sample = resid)) +
    stat_qq(alpha = .25, size = .8) + stat_qq_line(colour = "#D55E00") +
    labs(title = "Level 1: residual Q-Q", x = "Theoretical", y = "Sample")
  p3 <- ggplot(re_int, aes(sample = u)) +
    stat_qq(size = 1.4) + stat_qq_line(colour = "#D55E00") +
    labs(title = "Level 2: school-intercept Q-Q", x = "Theoretical", y = "Sample")
  p4 <- ggplot(re_int, aes(u)) +
    geom_histogram(bins = 25, fill = "grey60", colour = "white") +
    labs(title = "Level 2: distribution of school effects", x = "Random intercept", y = "Schools")
  (p1 | p2) / (p3 | p4)
}

# Intraclass correlation from a variance-components table
icc_from_vc <- function(var_between, var_within) var_between / (var_between + var_within)

# Nakagawa-Schielzeth R2 for a model with ONE grouping factor.
# Marginal = variance explained by fixed effects; conditional = fixed + random.
r2_nakagawa <- function(fit) {
  mf   <- model.frame(fit)
  X    <- model.matrix(lme4::nobars(formula(fit)), mf)
  var_f <- var(as.vector(X %*% lme4::fixef(fit)))
  vc   <- lme4::VarCorr(fit)[[1]]
  W    <- do.call(cbind, lapply(rownames(vc), function(v)
            if (v == "(Intercept)") rep(1, nrow(mf)) else mf[[v]]))
  var_r <- mean(rowSums((W %*% vc) * W))
  var_e <- if (inherits(fit, "glmerMod")) pi^2 / 3 else sigma(fit)^2
  c(marginal = var_f / (var_f + var_r + var_e),
    conditional = (var_f + var_r) / (var_f + var_r + var_e))
}

# LRT p-value for adding ONE random slope (with its covariance) to a
# random-intercept model. The null sits on the boundary of the parameter
# space, so the reference distribution is a 50:50 mixture of chi2(1) and
# chi2(2) rather than chi2(2) (Self & Liang 1987; Stram & Lee 1994).
p_boundary_lrt <- function(stat) 0.5 * pchisq(stat, 1, lower.tail = FALSE) +
                                 0.5 * pchisq(stat, 2, lower.tail = FALSE)

# ---- Formatting ---------------------------------------------------
fmt_p <- function(p, digits = 3) {
  ifelse(p < 10^-digits, paste0("< ", format(10^-digits, scientific = FALSE)),
         paste0("= ", formatC(p, digits = digits, format = "f")))
}

# p-value for display in tables
p_fmt <- function(p) ifelse(p < .001, "<0.001", sprintf("%.3f", p))

# Readable labels for model terms
pretty_term <- function(term) {
  lookup <- c(
    "(Intercept)"          = "Intercept",
    "ses_c"                = "SES, within school (per unit)",
    "ses_mean"             = "School mean SES (per unit)",
    "MinorityYes"          = "Minority (vs not)",
    "SexFemale"            = "Female (vs male)",
    "SectorCatholic"       = "Catholic school (vs public)",
    "ses_c:SectorCatholic" = "Within-school SES x Catholic",
    "ses_c:ses_mean"       = "Within-school SES x School mean SES"
  )
  out <- unname(lookup[term]); ifelse(is.na(out), term, out)
}
