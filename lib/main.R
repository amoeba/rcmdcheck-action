library(httr)
library(jsonlite)
library(rcmdcheck)

print("main.R")

GITHUB_SHA <- Sys.getenv("GITHUB_SHA")
GITHUB_EVENT_PATH <- Sys.getenv("GITHUB_EVENT_PATH")
GITHUB_TOKEN <- Sys.getenv("GITHUB_TOKEN")

print("...>")
print(nchar(GITHUB_TOKEN))

GITHUB_WORKSPACE <- Sys.getenv("GITHUB_WORKSPACE")

EVENT <- read_json(Sys.getenv("GITHUB_EVENT_PATH"))
REPOSITORY <- EVENT$repository
OWNER <- REPOSITORY$owner$login
REPO <- REPOSITORY$name

CHECK_NAME <- "rcmdcheck"

HEADERS <- c(
  "Content-Type" = "application/json",
  "Accept" = "application/vnd.github.antiope-preview+json",
  "Authorization" = paste("Bearer", GITHUB_TOKEN),
  "User-Agent" = "rcmdcheck-action"
)

isotime <- function() {
  strftime(
    as.POSIXlt(
      Sys.time(),
      "UTC",
      "%Y-%m-%dT%H:%M:%S"),
    "%Y-%m-%dT%H:%M:%SZ"
  )
}

check_conclusion <- function(results) {
  conclusion <- "success"

  if (length(results$warnings) + length(results$errors) > 0) {
    conclusion <- "action_required"
  }

  conclusion
}

check_summary <- function(results) {
  NOTES <- ifelse(length(results$notes) == 1, "NOTE", "NOTES")
  WARNINGS <- ifelse(length(results$warnings) == 1, "WARNING", "WARNINGS")
  ERRORS <- ifelse(length(results$errors) == 1, "ERROR", "ERRORS")

  paste(
    paste(length(results$notes), NOTES),
    paste(length(results$warnings), WARNINGS),
    paste(length(results$errors), ERRORS),
    sep = ", "
  )
}

check_text <- function(result) {
  paste(
    c(
      "# R CMD CHECK RESULTS",
      "## NOTES",
      ifelse(length(result$notes) == 0, "No notes", result$notes),
      "## WARNINGS",
      ifelse(length(result$warnings) == 0, "No warnings", result$warnings),
      "## ERRORS",
      ifelse(length(result$errors) == 0, "No errors", result$errors)
    ),
    collapse = "\n\n")
}

create_check <- function() {
  print("Creating check...")

  url <- paste(
    "https://api.github.com",
    "repos",
    OWNER,
    REPO,
    "check-runs",
    sep = "/")

  body <- list(
    name = CHECK_NAME,
    head_sha = GITHUB_SHA,
    status = "in_progress",
    started_at = isotime()
  )

  req <- httr::POST(
    url,
    body = body,
    encode = "json",
    add_headers(HEADERS))

  stop_for_status(req)
  data <- content(req)

  print(paste("Created check with id of", data$id))

  data$id
}

update_check <- function(id, conclusion, output) {
  print("Updating check...")

  url <- paste(
    "https://api.github.com",
    "repos",
    OWNER,
    REPO,
    "check-runs",
    id,
    sep = "/")

  body <- list(
    "name" = CHECK_NAME,
    "status" = "completed",
    "completed_at" = isotime(),
    "conclusion" = conclusion,
    "output" = output
  )

  print(body)
  dput(body)

  req <- PATCH(
    url,
    body = body,
    encode = "json",
    add_headers(HEADERS))

  stop_for_status(req)
}

run <- function() {
  print("run()")

  id <- create_check()
  results <- rcmdcheck(args = "--no-manual")

  update_check(
    id,
    check_conclusion(result),
    list(
      title = CHECK_NAME,
      summary = check_summary(results),
      text = check_text(results)
    )
  )
}

run()
