# ------------------------------------------------------------------
# run_all.R  -  reproduce the whole analysis
#
#   Rscript run_all.R                     # full run (a few minutes)
#   N_BOOT_CLUSTER=200 N_BOOT_PARAM=100 N_SIM_COVERAGE=50 Rscript run_all.R
#                                         # quick run (~1 minute)
#
# Produces report.html and report.md in the project root, figures in
# outputs/figures/ and tables in outputs/tables/ (CSV).
# ------------------------------------------------------------------
stopifnot(file.exists("report.Rmd"))   # run from the project root

rmarkdown::render("report.Rmd", output_file = "report.html",
                  envir = new.env(), quiet = TRUE)
message("Done. Open report.html (or report.md on GitHub).")
