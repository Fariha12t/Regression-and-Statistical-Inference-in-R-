# ------------------------------------------------------------------
# 00_setup.R  -  packages, global options, shared constants
# ------------------------------------------------------------------
suppressPackageStartupMessages({
  library(tidyverse)   # dplyr, ggplot2, tidyr, purrr, readr, tibble
  library(lme4)        # linear and generalised linear mixed models
  library(patchwork)   # multi-panel figures
})
# Other packages are called with pkg::fun() so it is always clear where
# a function comes from: broom, broom.mixed, car, lmtest, sandwich, nlme.

SEED <- 2026L
set.seed(SEED)

# Bootstrap sizes. Override with environment variables for a quick run:
#   N_BOOT_CLUSTER=200 N_BOOT_PARAM=100 N_SIM_COVERAGE=50 Rscript run_all.R
N_BOOT_CLUSTER <- as.integer(Sys.getenv("N_BOOT_CLUSTER", "2000"))
N_BOOT_PARAM   <- as.integer(Sys.getenv("N_BOOT_PARAM",   "500"))
N_SIM_COVERAGE <- as.integer(Sys.getenv("N_SIM_COVERAGE", "500"))

# Optimiser settings that avoid spurious convergence warnings in lme4
LMER_CTRL  <- lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
GLMER_CTRL <- glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))

# Colour-blind-safe palette (Okabe-Ito) used for school sector everywhere
SECTOR_COLS <- c(Public = "#0072B2", Catholic = "#D55E00")

theme_set(
  theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = "bold"),
          panel.grid.minor = element_blank())
)

for (d in c("outputs/figures", "outputs/tables", "data"))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

# Save a table to outputs/tables; returns it invisibly so it is not echoed
save_table <- function(x, name) {
  readr::write_csv(x, file.path("outputs", "tables", paste0(name, ".csv")))
  invisible(x)
}
