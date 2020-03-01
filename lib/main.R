library(httr)
library(jsonlite)

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

create_check <- function() {
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

  data$id
}

update_check <- function(id, conclusion, output) {
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

  print(req)
  print(status_code(req))
  print(content(req))

  stop_for_status(req)
}

run <- function() {
  id <- create_check()

  tryCatch({
    update_check(id, "success", list(
      title = CHECK_NAME,
      summary = "X offenses found",
      annotations = c(
        list(message = "FOO")
      )
    ))
  },
  error = function(e) {
    update_check(id, "failure", NULL)
  })
}

run()
