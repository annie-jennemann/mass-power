library(DatawRappr)

api_key <- Sys.getenv("API_KEY")

datawrapper_auth(api_key =  api_key, overwrite=TRUE)

dw_publish_chart("cP5ai")

