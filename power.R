library(DatawRappr)

api_key <- Sys.getenv("API_KEY")
us_map <- Sys.getenv("CHART_CODE")

datawrapper_auth(api_key =  api_key, overwrite=TRUE)

dw_publish_chart("cP5ai")
