# ------------------------------------------------------------------
# data.R  -  load and prepare the High School and Beyond (HSB) data
# ------------------------------------------------------------------
# The data ship with the `nlme` package (installed with every R), so the
# analysis needs no download and is fully reproducible.
#   nlme::MathAchieve   - 7,185 students: SES, minority status, sex, maths score
#   nlme::MathAchSchool - 160 schools: sector, size, discipline climate, ...
# Source: Raudenbush & Bryk (2002), Hierarchical Linear Models, Sage;
#         US National Center for Education Statistics, 1982 survey.

load_hsb <- function() {
  students <- nlme::MathAchieve |>
    as.data.frame() |>
    tibble::as_tibble() |>
    mutate(School = as.character(School))

  schools <- nlme::MathAchSchool |>
    as.data.frame() |>
    tibble::as_tibble() |>
    mutate(School = as.character(School)) |>
    select(-MEANSES)                       # recomputed below from the students

  dat <- students |>
    select(-MEANSES) |>
    left_join(schools, by = "School") |>
    group_by(School) |>
    mutate(
      n_school = n(),
      ses_mean = mean(SES),                # school-mean SES (between-school)
      ses_c    = SES - ses_mean            # student SES relative to own school (within)
    ) |>
    ungroup() |>
    mutate(
      Sector   = factor(Sector,   levels = c("Public", "Catholic")),
      Minority = factor(Minority, levels = c("No", "Yes")),
      Sex      = factor(Sex,      levels = c("Male", "Female"))
    )

  stopifnot(!anyNA(dat), nrow(dat) == 7185, n_distinct(dat$School) == 160)

  # Binary outcome used for the GLM part: "high achiever" = top quartile.
  # (Dichotomising loses information; it is done here to demonstrate
  #  logistic GLMs/GLMMs, and the linear models use the full score.)
  cutoff <- unname(quantile(dat$MathAch, 0.75))
  out <- dat |> mutate(high_ach = as.integer(MathAch >= cutoff))
  attr(out, "cutoff") <- cutoff
  out
}

# Data dictionary written to data/ for the repository
data_dictionary <- function() {
  tibble::tribble(
    ~variable,   ~level,    ~description,
    "School",    "school",  "School identifier (160 schools)",
    "MathAch",   "student", "Mathematics achievement score (outcome, continuous)",
    "SES",       "student", "Socio-economic status index (roughly centred at 0)",
    "ses_c",     "student", "SES minus own school's mean SES (within-school SES)",
    "ses_mean",  "school",  "School mean SES (between-school SES)",
    "Minority",  "student", "Ethnic minority status (No/Yes)",
    "Sex",       "student", "Male/Female",
    "Sector",    "school",  "Public or Catholic",
    "Size",      "school",  "School enrolment",
    "PRACAD",    "school",  "Proportion of students on the academic track",
    "DISCLIM",   "school",  "Disciplinary climate scale (higher = worse climate)",
    "HIMINTY",   "school",  "High-minority-enrolment school (0/1)",
    "n_school",  "school",  "Students sampled in the school",
    "high_ach",  "student", "1 if MathAch is in the top quartile (derived binary outcome)"
  )
}
