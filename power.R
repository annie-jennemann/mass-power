library(httr2)
library(readr)
library(DatawRappr)

url <- "http://mema.mapsonline.net/power_outage_public.csv"

resp <- request(url) |>
  req_user_agent("Mozilla/5.0 (GitHub Actions; R)") |>
  req_retry(max_tries = 8) |>
  req_timeout(120) |>
  req_perform()

dat <- read_csv(resp_body_raw(resp), show_col_types = FALSE)
print(head(dat))

total <- sum(dat[["Without Power"]], na.rm = TRUE)

total <- format(total, big.mark = ",", scientific = FALSE)

api_key <- Sys.getenv("API_KEY")

et_time <- as.POSIXlt(Sys.time(), tz = "America/New_York")

formatted_time <- format(et_time, "%B %d at %I:%M %p EST")

formatted_time <- sub(" 0", " ", formatted_time)   # day
formatted_time <- sub(" at 0", " at ", formatted_time) # hour

formatted_time <- gsub("AM", "a.m.", formatted_time)
formatted_time <- gsub("PM", "p.m.", formatted_time)

datawrapper_auth(api_key =  api_key, overwrite=TRUE)

dw_edit_chart("cP5ai",
              title = paste0("<b>",total,"</b> customers are without power in Massachusetts"),
              annotate = paste("Chart updated ", formatted_time)
)

dw_publish_chart("cP5ai")

