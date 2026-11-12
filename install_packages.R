# Install the CRAN packages the project needs (skips ones already installed).
# `nlme`, `MASS` and `mgcv` are "recommended" packages that ship with R itself.
pkgs <- c("tidyverse", "lme4", "broom", "broom.mixed", "car", "lmtest",
          "sandwich", "patchwork", "scales", "knitr", "rmarkdown")
todo <- setdiff(pkgs, rownames(installed.packages()))
if (length(todo)) install.packages(todo, repos = "https://cloud.r-project.org")
message("All packages available.")
