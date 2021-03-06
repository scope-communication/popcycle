get.evt.list <- function(evt.loc=evt.location) {
  file.list <- list.files(evt.loc, recursive=T)
  if (length(file.list) == 0) {
    print(paste("no evt files found in", evt.loc))
    return (file.list)
  }
  # regexp to match both types of EVT files
  #   - 37.evt (old style)
  #   - 2014-05-15T17-07-08+0000 or 2014-07-04T00-03-02+00-00 (new style)
  # In the new style the final timezone offset may not always be UTC (00-00)
  # so be sure to correctly parse it in all code.
  regexp <- '/?[0-9]+\\.evt$|/?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}[+-][0-9]{2}-?[0-9]{2}$'
  id <- grep(regexp,file.list)
  file.list <- file.list[id]
  print(paste(length(file.list), "evt files found"))
  return (sort(file.list))
}

get.latest.evt.with.day <- function(evt.loc=evt.location) {
  file.list <- get.evt.list(evt.loc)
  n <- length(file.list)
  return (file.list[n])
}

get.latest.evt <- function(evt.loc=evt.location) {
  return (basename(get.latest.evt.with.day(evt.loc)))
}

files.in.range <- function(start.day, start.timestamp, end.day, end.timestamp, evt.loc=evt.location) {
  file.list <- get.evt.list(evt.loc)
  start.file = paste(start.day, start.timestamp, sep='/')
  end.file = paste(end.day, end.timestamp, sep='/')

  if(!any(file.list == start.file)) {
    stop(paste("Could not find file", start.file))
  }

  if(!any(file.list == end.file)) {
    stop(paste("Could not find file", end.file))
  }

  start.index = which(file.list == start.file)
  end.index = which(file.list == end.file)

  return(file.list[start.index:end.index])
}


file.transfer <- function(evt.loc=evt.location, instrument.loc=instrument.location){

  last.evt <- get.latest.evt.with.day(evt.loc)
  file.list <- list.files(instrument.loc, recursive=T)
  sfl.list <- file.list[grepl('.sfl', file.list)]
  file.list <- file.list[-length(file.list)] # remove the last file (opened file)
  file.list <- sort(file.list[!grepl('.sfl', file.list)])

  id <- match(last.evt, file.list)

  if(length(id) == 0){
    day <- unique(dirname(file.list))
      for(d in day) system(paste0("mkdir ",evt.loc,"/",d))
    print(paste0("scp ",instrument.loc,"/",file.list," ", evt.loc,"/",file.list))
    system(paste0("scp ",instrument.loc,"/",file.list," ", evt.loc,"/",file.list, collapse=";"))
    system(paste0("scp ",instrument.loc,"/",sfl.list," ", evt.loc,"/",sfl.list, collapse=";"))
  }
  else{
    file.list <- file.list[id:length(file.list)]
    day <- unique(dirname(file.list))
      for(d in day) system(paste0("mkdir ",evt.loc,"/",d))
    print(paste0("scp ",instrument.loc,"/",file.list," ", evt.loc,"/",file.list))
    system(paste0("scp ",instrument.loc,"/",file.list," ", evt.loc,"/",file.list, collapse=";"))
    system(paste0("scp ",instrument.loc,"/",sfl.list," ", evt.loc,"/",sfl.list, collapse=";"))
  }
 }

is.new.style.file <- function(file.name) {
  # regexp to new style EVT file names
  #   - 2014-05-15T17-07-08+0000 or 2014-07-04T00-03-02+00-00 (new style)
  regexp.new <- '/?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}\\+[0-9]{2}-?[0-9]{2}$'
  return(length(grep(regexp.new, file.name)) == 1)
}

# For old style EVT file names, don't remove folder if it exists
# For new style EVT file names, remove folder
clean.file.name <- function(file.name) {
  if (is.new.style.file(file.name)) {
    return(basename(file.name))
  } else {
    return(file.name)
  }
}
