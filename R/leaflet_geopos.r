leaflet_geopos <- function(data, ID_label, add_label=NULL, except_label=NULL, collapsedLayers=TRUE,
                           radius=1000, pal, layer_title=ID_label, cb.title="Date",cbpos="bottomright",
                           showScaleBar=TRUE, showSlideBar=FALSE){
  
  ID_labels <- c("DeployID","Serial","datetime","speed","prob_lim")
  if(!(ID_label %in% names(data))) stop(paste(ID_label,"not in geolocation data. Please revise!"))
  # if(missing(except_label)) except_label <- c()
  # except_label <- c(except_label,ID_label)
  
  cmap <- NULL
  data(cmap, package='oceanmap', envir = environment())
  if(missing(pal)){
    pal <- cmap$jet
  }else{
    if(length(pal) == 1){
      pal <- cmap[[pal]]
    }
  }
  
  cpal = colorNumeric(palette = pal, domain = data$datenm) 
  data$datenm <- as.numeric(as.Date(data$datetime))
  data <- .make_labels(data,ID_label=ID_label,add_label=add_label, except_label=except_label)
  labs <- as.list(data$X)
  
  if(showSlideBar) {
    labs <- data$X
    
    if(class(data) == "data.frame"){
      data <- SpatialPointsDataFrame(data=data,data[,c("Lon","Lat")])
      data <- sf::st_as_sf(data)
      data <- st_cast(data, "POINT")
      data$time <- data$datetime
    }else{
      data <- sf::st_as_sf(data)
      data$time <- data$datetime
    }
    
    m <- leaflet() %>%
      addTiles(group = "OSM (default)") %>%
      addProviderTiles(providers$Esri.OceanBasemap, group = "Esri.OceanBasemap") %>%
      addProviderTiles(providers$Esri.WorldImagery, group = "Esri.WorldImagery")
    m <- m %>% addTimeslider(data = data, color = ~cpal(data$datenm),
                             # opacity = opac, fillOpacity = opac,
                             # radius = sample(5:15, nrow(data), TRUE),
                             popupOptions = popupOptions(maxWidth = 1000, closeOnClick= F, closeButton = FALSE),
                             popup = labs,
                             options = timesliderOptions(
                               alwaysShowDate = TRUE,
                               sameDate = TRUE,
                               range = TRUE))
    overlayGroups <- character(0)
  }else{
    m <- leaflet(data) %>%
      addTiles(group = "OSM (default)") %>%
      addProviderTiles(providers$Esri.OceanBasemap, group = "Esri.OceanBasemap") %>%
      addProviderTiles(providers$Esri.WorldImagery, group = "Esri.WorldImagery")
    
    overlayGroups <- ids <- unique(data[[ID_label]])
    
    if(class(data) == "SpatialPolygonsDataFrame"){
      for(id in ids){
        add <- data[which(data[[ID_label]] == id),]
        # add <- add[order(add$datetime),]
        add@plotOrder <- order(-as.numeric(add$datetime))
        m <- m %>% addPolygons(data = add, color = ~cpal(datenm),label = lapply(labs, shiny::HTML), group = id) 
      }
    }
    
    if(class(data) == "data.frame"){
      for(id in ids){
        add <- data[which(data[[ID_label]] == id),]
        add <- add[order(add$datetime),]
        m <- m %>% addCircles(lng = add$Lon, lat =add$Lat, color = ~cpal(add$datenm),
                              label = lapply(labs, shiny::HTML),radius =radius, group = id)
      }
    }
    
    if(class(data) == "SpatialPointsDataFrame"){
      for(id in ids){
        add <- data[which(data[[ID_label]] == id),]
        add <- add[order(add$datetime),]
        m <- m %>% addCircles(lng = add$Lon, lat =add$Lat, color = ~cpal(add$datenm),
                              label = lapply(labs, shiny::HTML),radius =radius, group = id)
      }
    }
    
    ltitle <- "
        function() {
            $('.leaflet-control-layers-overlays').prepend('<label style=\"text-align:center\">ID_label</label>');
        }
    "
    ltitle <- gsub("ID_label",layer_title,ltitle)
    m <- m %>%
      onRender(ltitle)
  }
  
  if(showScaleBar) m <- m %>% addScaleBar('bottomright') 
  m <- m %>% 
    leaflet::addLegend(cbpos, pal = cpal, values = data$datenm, 
              title = cb.title, opacity = 1, 
              labFormat = .myLabelFormat(dates=TRUE)) %>%
    addLayersControl(
      baseGroups = c("OSM (default)", "Esri.OceanBasemap", "Esri.WorldImagery"),
      overlayGroups = overlayGroups,
      options = layersControlOptions(collapsed = collapsedLayers)
    ) 
  
  return(m)
}




.myLabelFormat = function(..., dates=FALSE){
  if(dates){
    function(type = "numeric", cuts){
      as.Date(cuts, origin="1970-01-01")
    }
  }else{
    labelFormat(...)
  }
}


.make_labels <- function(data,ID_label,add_label=NULL,except_label=NULL){
  ids <- unique(c(ID_label,"DeployID","Serial","datetime","speed","prob_lim"))
  if(!is.null(add_label)) ids <- c(ids,add_label)
  if(!is.null(except_label)) ids <- ids[which(!(ids %in% except_label))]
  if("speed" %in% names(data)){
    data$speed <- gsub("kilometers","km",data$speed)
    data$speed <- gsub("day","d",data$speed)
    data$speed <- gsub("hour","h",data$speed)
    data$speed <- gsub("meters","m",data$speed)
    data$speed <- gsub("seconds","s",data$speed)
  }
  data$X <- c()
  ids <- ids[which(ids %in% names(data))]
  for(i in ids){
    data$X <- paste0(data$X,'<strong>',i,': </strong>',data[[i]],'<br>')
  }
  return(data)
}