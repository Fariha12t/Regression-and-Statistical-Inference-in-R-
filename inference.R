# ------------------------------------------------------------------
# inference.R  -  bootstrap, robust SEs and multiple-testing helpers
# ------------------------------------------------------------------

# ---- Bootstrap for OLS --------------------------------------------
# Both functions return a B x p matrix of bootstrap coefficient vectors.

# Cluster (school-level) bootstrap: resample whole schools with replacement.
# Uses the identity  X'X = sum_g X_g'X_g  so each replicate is one small
# linear solve - 2,000 replicates take a couple of seconds.
cluster_boot_ols <- function(formula, data, cluster, B = 2000, seed = 1L) {
  stopifnot(!anyNA(data))
  X <- model.matrix(formula, data)
  y <- model.response(model.frame(formula, data))
  g <- factor(data[[cluster]]); G <- nlevels(g); p <- ncol(X)
  idx <- split(seq_len(nrow(X)), g)

  XtX <- t(vapply(idx, function(i) as.vector(crossprod(X[i, , drop = FALSE])), numeric(p * p)))
  Xty <- t(vapply(idx, function(i) as.vector(crossprod(X[i, , drop = FALSE], y[i])), numeric(p)))

  set.seed(seed)
  out <- matrix(NA_real_, B, p, dimnames = list(NULL, colnames(X)))
  for (b in seq_len(B)) {
    w <- tabulate(sample.int(G, G, replace = TRUE), nbins = G)   # school weights
    A <- matrix(crossprod(w, XtX), p, p)
    out[b, ] <- solve(A, as.vector(crossprod(w, Xty)))
  }
  out
}

# Naive case bootstrap: resample individual students, ignoring schools.
case_boot_ols <- function(formula, data, B = 2000, seed = 1L) {
  X <- model.matrix(formula, data)
  y <- model.response(model.frame(formula, data))
  set.seed(seed)
  out <- matrix(NA_real_, B, ncol(X), dimnames = list(NULL, colnames(X)))
  for (b in seq_len(B)) {
    i <- sample.int(nrow(X), replace = TRUE)
    out[b, ] <- .lm.fit(X[i, , drop = FALSE], y[i])$coefficients
  }
  out
}

# Percentile bootstrap summary: estimate, bootstrap SE and 95% CI
boot_summary <- function(boot_mat, estimate, level = .95) {
  a <- (1 - level) / 2
  tibble::tibble(
    term     = colnames(boot_mat),
    estimate = unname(estimate[colnames(boot_mat)]),
    boot_se  = apply(boot_mat, 2, sd),
    ci_low   = apply(boot_mat, 2, quantile, probs = a),
    ci_high  = apply(boot_mat, 2, quantile, probs = 1 - a)
  )
}

# ---- Standard errors under different assumptions ------------------
# Same OLS point estimates, four ways of quantifying uncertainty.
se_table_ols <- function(fit, cluster) {
  tibble::tibble(
    term      = names(coef(fit)),
    estimate  = unname(coef(fit)),
    se_naive  = sqrt(diag(vcov(fit))),
    se_hc3    = sqrt(diag(sandwich::vcovHC(fit, type = "HC3"))),
    se_cluster = sqrt(diag(sandwich::vcovCL(fit, cluster = cluster, type = "HC1")))
  )
}

# ---- Multiple testing ---------------------------------------------
# Adds Bonferroni, Holm (both control family-wise error) and
# Benjamini-Hochberg / Benjamini-Yekutieli (both control false discovery rate).
adjust_pvalues <- function(tbl, p_col = p_raw) {
  tbl |>
    mutate(
      p_bonferroni = p.adjust({{ p_col }}, "bonferroni"),
      p_holm       = p.adjust({{ p_col }}, "holm"),
      p_bh         = p.adjust({{ p_col }}, "BH"),
      p_by         = p.adjust({{ p_col }}, "BY")
    )
}

# Number of "discoveries" at a given error rate for each procedure
count_discoveries <- function(tbl, alpha = .05) {
  tibble::tibble(
    procedure = c("Unadjusted", "Bonferroni (FWER)", "Holm (FWER)",
                  "Benjamini-Hochberg (FDR)", "Benjamini-Yekutieli (FDR)"),
    rejected  = c(sum(tbl$p_raw < alpha), sum(tbl$p_bonferroni < alpha),
                  sum(tbl$p_holm < alpha), sum(tbl$p_bh < alpha), sum(tbl$p_by < alpha))
  ) |> mutate(of = nrow(tbl))
}

# ---- Simulation check of confidence-interval coverage -------------
# Generates new data sets from a fitted mixed model (new random school
# effects each time, so the true fixed effects are known), then asks how
# often each type of 95% CI for the OLS coefficients contains the truth.
coverage_simulation <- function(fit_lmm, formula, data, cluster,
                                n_sim = 500, B = 300, seed = 1L) {
  y_name <- all.vars(formula)[1]
  truth  <- lme4::fixef(fit_lmm)
  G      <- dplyr::n_distinct(data[[cluster]])
  rows   <- vector("list", n_sim)
  for (s in seq_len(n_sim)) {
    d <- data
    d[[y_name]] <- simulate(fit_lmm, nsim = 1, seed = seed + s)[[1]]
    fit  <- lm(formula, d)
    est  <- coef(fit)
    se_n <- sqrt(diag(vcov(fit)))
    se_c <- sqrt(diag(sandwich::vcovCL(fit, cluster = d[[cluster]], type = "HC1")))
    bt   <- cluster_boot_ols(formula, d, cluster, B = B, seed = seed + s)
    q    <- apply(bt, 2, quantile, probs = c(.025, .975))
    tn <- qt(.975, fit$df.residual); tc <- qt(.975, G - 1)
    rows[[s]] <- tibble::tibble(
      term = names(est), truth = unname(truth[names(est)]),
      naive_lo   = est - tn * se_n, naive_hi   = est + tn * se_n,
      cluster_lo = est - tc * se_c, cluster_hi = est + tc * se_c,
      boot_lo    = q[1, ],          boot_hi    = q[2, ]
    )
  }
  dplyr::bind_rows(rows, .id = "sim")
}

summarise_coverage <- function(sim) {
  sim |>
    tidyr::pivot_longer(c(naive_lo, naive_hi, cluster_lo, cluster_hi, boot_lo, boot_hi),
                        names_to = c("method", ".value"), names_sep = "_",
                        values_transform = list()) |>
    dplyr::group_by(term, method) |>
    dplyr::summarise(coverage = mean(lo <= truth & truth <= hi),
                     mean_width = mean(hi - lo), .groups = "drop")
}
