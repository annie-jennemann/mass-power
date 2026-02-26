.libPaths("~/Rlib")
library(httr2)
library(readr)
library(DatawRappr)

api_key <- Sys.getenv("API_KEY")
us_map <- Sys.getenv("CHART_CODE")

datawrapper_auth(api_key =  api_key, overwrite=TRUE)

url <- "http://mema.mapsonline.net/power_outage_public.csv"

resp <- request(url) |>
  req_user_agent("Mozilla/5.0 (GitHub Actions; R)") |>
  req_retry(max_tries = 8) |>
  req_timeout(120) |>
  req_perform()

dat <- read_csv(resp_body_raw(resp), show_col_types = FALSE)
print(head(dat))


