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

CHECK_NAME = "rcmdcheck"

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

check_text <- function(result) {
  out <- c()

  if (length(result$notes) > 0) {
    out <- c(out, "notes")
    out <- c(out, result$notes)
  }

  if (length(result$warnings) > 0) {
    out <- c(out, "warnings")
    out <- c(out, result$warnings)
  }

  if (length(result$errors) > 0) {
    out <- c(out, "errors")
    out <- c(out, result$errors)
  }

  paste(out, collapse = "\n\n")
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
    "head_sha" = GITHUB_SHA,
    "status" = "completed",
    "completed_at" = isotime(),
    "conclusion" = conclusion,
    "output" = output
  )

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

  tryCatch({
    print("Running rcmdcheck...")

    results <- rcmdcheck()


    conclusion <- ifelse(results$status == 0, "success", "failure")
    print(paste("Done. Status is", results$status, "(", conclusion, ")"))

    update_check(
      id,
      "conclusion",
      list(
        title = CHECK_NAME,
        summary = "X offenses found",
        text = check_text(results)
      ))
  },
  error = function(e) {
    print("ERROR")
    print(e)
    print(e$message)

    update_check(id, "failure", list(
      title = CHECK_NAME,
      summary = "The check error'd out",
      text = as.character(e)
    ))
  })
}

run()
