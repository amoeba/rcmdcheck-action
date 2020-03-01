FROM rocker/r-ver:3.6.2

LABEL com.github.actions.name="rcmdcheck-action"
LABEL com.github.actions.description="rcmdcheck"
LABEL com.github.actions.icon="code"
LABEL com.github.actions.color="blue"
LABEL maintainer="Bryce Mecum <petridish@gmail.com>"

RUN apt-get update && \
  apt-get install -y libssl-dev libcurl4-openssl-dev

RUN Rscript -e "install.packages(c(\"httr\", \"jsonlite\", \"rcmdcheck\"))"

COPY lib /action/lib
ENTRYPOINT ["/action/lib/entrypoint.sh"]

