library(RSQLite)

opp.to.db.opp <- function(opp, cruise.name, file.name) {
  check.cruise.id(cruise.name)

  #First, the function checks that OPP data is transformed before uploading it into the database. if not, tranform it.
  id <- which(colnames(opp) == "pulse_width" | colnames(opp) == "time" | colnames(opp) =="pop")
    if(!any(max(opp[,-c(id)]) < 10^3.5)){
      opp <- .transformData(opp)
      print("data was transformed to be consistent with popcycle.sql databse")
    }

  n <- dim(opp)[1]
  new.columns = cbind(cruise = rep(cruise.name, n), file = rep(file.name, n), particle = 1:n)
  return (cbind(new.columns, opp))
}

upload.opp <- function(db.opp, db = db.name) {
  con <- dbConnect(SQLite(), dbname = db)
  dbWriteTable(conn = con, name = opp.table.name, value = db.opp, row.names=FALSE, append=TRUE)
  dbDisconnect(con)
}

# these delete functions should only be called when re-running analyses
.delete.opp.by.file <- function(file.name, db = db.name) {
  file.name <- clean.file.name(file.name)
  sql <- paste0("DELETE FROM ", opp.table.name, " WHERE file == '",
                file.name, "'")
  con <- dbConnect(SQLite(), dbname = db)
  dbGetQuery(con, sql)
  dbDisconnect(con)
}

.delete.vct.by.file <- function(file.name, db = db.name) {
  file.name <- clean.file.name(file.name)
  sql <- paste0("DELETE FROM ", vct.table.name, " WHERE file == '",
                file.name, "'")
  con <- dbConnect(SQLite(), dbname = db)
  dbGetQuery(con, sql)
  dbDisconnect(con)
}

.delete.opp.evt.ratio.by.file <- function(file.name, db = db.name) {
  file.name <- clean.file.name(file.name)
  sql <- paste0("DELETE FROM ", opp.evt.ratio.table.name, " WHERE file == '",
                file.name, "'")
  con <- dbConnect(SQLite(), dbname = db)
  dbGetQuery(con, sql)
  dbDisconnect(con)
}

.delete.cytdiv.by.file <- function(file.name, db = db.name) {
  file.name <- clean.file.name(file.name)
  sql <- paste0("DELETE FROM ", cytdiv.table.name, " WHERE file == '",
                file.name, "'")
  con <- dbConnect(SQLite(), dbname = db)
  dbGetQuery(con, sql)
  dbDisconnect(con)
}

.delete.sfl <- function(db = db.name) {
  sql <- paste0("DELETE FROM ", sfl.table.name)
  con <- dbConnect(SQLite(), dbname = db)
  dbGetQuery(con, sql)
  dbDisconnect(con)
}

.delete.stats <- function(db = db.name) {
  sql <- paste0("DELETE FROM ", stats.table.name)
  con <- dbConnect(SQLite(), dbname = db)
  dbGetQuery(con, sql)
  dbDisconnect(con)
}


vct.to.db.vct <- function(vct, cruise.name, file.name, method.name) {
  check.cruise.id(cruise.name)

  n <- length(vct)
  cruise = rep(cruise.name, n)
  file = rep(file.name, n)
  particle = 1:n
  pop <- vct
  method <- rep(method.name, n)

  return (data.frame(cruise = cruise, file = file, particle = particle, pop = pop, method = method))
}

upload.vct <- function(db.vct, db = db.name) {
  con <- dbConnect(SQLite(), dbname = db)
  dbWriteTable(conn = con, name = vct.table.name, value = db.vct, row.names=FALSE, append=TRUE)
  dbDisconnect(con)
}

get.opp.by.file <- function(file.name, db = db.name) {
  file.name <- clean.file.name(file.name)
  sql <- paste0("SELECT * FROM ", opp.table.name, " WHERE file == '",
                file.name, "' ORDER BY particle")
  con <- dbConnect(SQLite(), dbname = db)
  opp <- dbGetQuery(con, sql)
  dbDisconnect(con)
  # drop cruise, file, particle columns
  return (opp[,-c(1:4)])
}

# Return data frame of OPP data that covers the provided time range.
#
# If the time range specified does not fall exactly on a 3 minute boundary
# stored in the database then the time range will be expanded to fall on a
# 3 minute  boundary.
#
# Args:
#   start.day: Start date, formatted as YYYY-MM-DD HH[:MM]
#   end.day: End date, formatted as YYYY-MM-DD HH[:MM]
#   pop: Only return data for this population. Should be a population name
#     found in the VCT table. If not specified return particle data for all
#     populations.
#   channel: Only return data for this measurement channel. Should be a
#     column name from OPP table. If not specified return data for all
#     channels.
get.opp.by.date <- function(start.time, end.time,
                            pop=NULL, channel=NULL,
                            db=db.name) {
  date.bounds <- c(date.to.db.date(start.time), date.to.db.date(end.time))

  con <- dbConnect(SQLite(), dbname = db)
  if (is.null(channel)) {
    sql <- "SELECT
      opp.*, "
  } else {
    sql <- paste0("SELECT
      opp.", channel, ", ")
  }
  sql <- paste0(sql,
    "sfl.date as time, vct.pop
    FROM
      sfl, opp, vct
    WHERE
      sfl.date >= '", date.bounds[1], "'
      AND
      sfl.date < '", date.bounds[2], "'
      AND
      opp.cruise == sfl.cruise
      AND
      opp.file == sfl.file
      AND
      opp.cruise = vct.cruise
      AND
      opp.file = vct.file
      AND
      opp.particle == vct.particle"
  )
  if (! is.null(pop)) {
    sql <- paste0(sql, "
      AND
      vct.pop == '", pop, "'"
    )
  }
  opp <- dbGetQuery(con, sql)
  dbDisconnect(con)
  return (opp)
}

# Return a list of min and max values for each of opp channels:
# "fsc_small", pe", "chl_small"
# The list contains a named member for each channel (e.g. x$fsc_small),
# and each member is a two item vector of min and max values (e.g. c(1, 1000))
#
# To retrieve the min value for fsc_small from the list:
# x$fsc_small[1]
# To retriev ethe max value for fsc_small from the list:
# x$ fsc_small[2]
get.opp.channel.ranges <- function(db=db.name) {
  con <- dbConnect(SQLite(), dbname=db)
  # It would be nice to do all the MIN MAX calls in one query, but
  # due to some sqlite quirks this bypasses any indexes.
  # http://www.sqlite.org/optoverview.html#minmax
  minmaxes = list()
  #channels <- c("fsc_small", "fsc_big", "fsc_perp", "pe", "chl_small", "chl_big")
  channels <- c("fsc_small", "pe", "chl_small")
  for (channel in channels) {
    sql <- paste0("SELECT MIN(", channel, ") FROM ", opp.table.name)
    min.answer <- dbGetQuery(con, sql)
    sql <- paste0("SELECT MAX(", channel, ") FROM ", opp.table.name)
    max.answer <- dbGetQuery(con, sql)
    minmaxes[[channel]] = c(min.answer[1,1], max.answer[1,1])
  }
  dbDisconnect(con)
  return(minmaxes)
}

# Get SFL rows >= start.date and < end.date
#
# Args:
#   start.date: start date in format YYYY-MM-DD HH:MM
#   end.date:   end date in format YYYY-MM-DD HH:MM
get.sfl.by.date <- function(start.date, end.date, db=db.name) {
  date.bounds <- c(date.to.db.date(start.date), date.to.db.date(end.date))

  con <- dbConnect(SQLite(), dbname = db)
  sql <- paste0("SELECT * FROM ", sfl.table.name,
                " WHERE date >= '", date.bounds[1], "'",
                " AND", " date < '", date.bounds[2], "'")
  sfl <- dbGetQuery(con, sql)
  return(sfl)
}

get.vct.by.file <- function(file.name, db = db.name) {
  file.name <- clean.file.name(file.name)
  sql <- paste0("SELECT * FROM ", vct.table.name, " WHERE file == '",
                file.name, "' ORDER BY particle")
  con <- dbConnect(SQLite(), dbname = db)
  vct <- dbGetQuery(con, sql)
  dbDisconnect(con)
  # drop cruise, file, particle, method columns
  return (vct[,-c(1,2,3,5)])
}

upload.opp.evt.ratio <- function(opp.evt.ratio, cruise.name, file.name, db = db.name) {
  check.cruise.id(cruise.name)

  con <- dbConnect(SQLite(), dbname = db)
  dbWriteTable(conn = con, name = opp.evt.ratio.table.name,
               value = data.frame(cruise = cruise.name, file = file.name, ratio = opp.evt.ratio),
               row.names=FALSE, append=TRUE)
  dbDisconnect(con)
}

# Return a vector of distinct file values in opp table
#
# Args:
#   db = sqlite3 db
get.opp.files <- function(db = db.name) {
  sql <- paste0("SELECT DISTINCT file from ", opp.evt.ratio.table.name)
  con <- dbConnect(SQLite(), dbname = db)
  files <- dbGetQuery(con, sql)
  dbDisconnect(con)
  print(paste(length(files$file), "opp files found"))
  return(files$file)
}

# Return a vector of distinct file values in vct.table.name
#
# Args:
#   db = sqlite3 db
get.vct.files <- function(db = db.name) {
  sql <- paste0("SELECT DISTINCT file from ", vct.table.name)
  con <- dbConnect(SQLite(), dbname = db)
  files <- dbGetQuery(con, sql)
  dbDisconnect(con)
  return(files$file)
}

# Return a vector of distinct file values in opp.evt.ratio.table.name
#
# Args:
#   db = sqlite3 db
get.opp.evt.ratio.files <- function(db = db.name) {
  sql <- paste0("SELECT DISTINCT file from ", opp.evt.ratio.table.name)
  con <- dbConnect(SQLite(), dbname = db)
  files <- dbGetQuery(con, sql)
  dbDisconnect(con)
  return(files$file)
}

get.opp.evt.ratio.by.file <- function(file.name, db = db.name) {
  file.name <- clean.file.name(file.name)
  sql <- paste0("SELECT * FROM ", opp.evt.ratio.table.name, " WHERE file == '",
                file.name)
  con <- dbConnect(SQLite(), dbname = db)
  file <- dbGetQuery(con, sql)
  dbDisconnect(con)
  return(file$ratio)
}

get.opp.evt.ratio.by.date <- function(start.date, end.date, db = db.name) {
  date.bounds <- c(date.to.db.date(start.date), date.to.db.date(end.date))
  sql <- paste0("SELECT
    opp_evt_ratio.file, opp_evt_ratio.ratio
  FROM
    sfl, opp_evt_ratio
  WHERE
    sfl.date >= '", date.bounds[1], "'
    AND
    sfl.date < '", date.bounds[2], "'
    AND
    sfl.cruise == opp_evt_ratio.cruise
    AND
    sfl.file == opp_evt_ratio.file")
  con <- dbConnect(SQLite(), dbname = db)
  files <- dbGetQuery(con, sql)
  dbDisconnect(con)
  return(files)
}

# Return a list of EVT files for which there is no OPP data in the database
#
# Args:
#   evt.list = list of EVT file paths, e.g. get.evt.list(evt.location)
#   db = sqlite3 db
get.empty.evt.files <- function(evt.list, db = db.name) {
  opp.files <- get.opp.files(db)
  # Make sure user provided file list has folder removed for new style file
  # names and kept for old style names
  clean.evt.list <- unlist(lapply(evt.list, clean.file.name))
  return(setdiff(clean.evt.list, opp.files))
}

get.stat.table <- function(db = db.name) {
  sql <- paste('SELECT * FROM ', stats.table.name, 'ORDER BY time ASC')
  con <- dbConnect(SQLite(), dbname = db)
  stats <- dbGetQuery(con, sql)
  dbDisconnect(con)
  return (stats)
}

insert.stats.for.file <- function(file.name, db = db.name) {
  file.name <- clean.file.name(file.name)
  # [TODO Francois] Name of OPP, vct, sfl, opp_evt_ratio tables should be a variable too.
  sql <- "INSERT INTO stats
SELECT
  opp.cruise as cruise,
  opp.file as file,
  sfl.date as time,
  sfl.lat as lat,
  sfl.lon as lon,
  opp_evt_ratio.ratio as opp_evt_ratio,
  sfl.flow_rate as flow_rate,
  sfl.file_duration as file_duration,
  vct.pop as pop,
  count(vct.pop) as n_count,
  count(vct.pop) / (sfl.flow_rate * (sfl.file_duration/60) * opp_evt_ratio.ratio) as abundance,
  avg(opp.fsc_small) as fsc_small,
  avg(opp.chl_small) as chl_small,
  avg(pe) as pe
FROM
  opp, vct, sfl, opp_evt_ratio
WHERE
  opp.cruise == vct.cruise
  AND
  opp.file == vct.file
  AND
  opp.particle == vct.particle
  AND
  opp.cruise == sfl.cruise
  AND
  opp.file == sfl.file
  AND
  opp.cruise == opp_evt_ratio.cruise
  AND
  opp.file == opp_evt_ratio.file
  AND
  opp.file == 'FILE_NAME'
GROUP BY
  opp.cruise, opp.file, vct.pop;"

  #in case there's stats in there already
  sql.delete <- gsub('FILE_NAME', file.name, paste('DELETE FROM', stats.table.name, 'WHERE file == "FILE_NAME"'))
  con <- dbConnect(SQLite(), dbname = db)
  response <- dbGetQuery(con, sql.delete)

  sql <- gsub('FILE_NAME', file.name, sql)
  response <- dbGetQuery(con, sql)
  dbDisconnect(con)
}


run.stats <- function(opp.list, db=db.name){

  # delete old stats entries if they exist so we keep cruise/file distinct
  .delete.stats()

  i <- 0
  for (opp.file in opp.list) {

     message(round(100*i/length(opp.list)), "% completed \r", appendLF=FALSE)

    tryCatch({
    #   print('Updating stat')
      insert.stats.for.file(opp.file, db=db.name)
    }, error = function(e) {print(paste("Encountered error with file", opp.file))})

    i <-  i + 1
    flush.console()

  }
}



upload.cytdiv <- function(indices, cruise.name, file.name, db = db.name) {
  check.cruise.id(cruise.name)

  file.name <- clean.file.name(file.name)
  con <- dbConnect(SQLite(), dbname = db)
  dbWriteTable(conn = con, name = cytdiv.table.name,
               value = data.frame(cruise = cruise.name, file = file.name, N0 = indices[1], N1= indices[2], H=indices[3], J=indices[4], opp_red=indices[5]),
               row.names=FALSE, append=TRUE)
  dbDisconnect(con)
}


get.cytdiv.table <- function(db = db.name) {
  sql <- "SELECT
            sfl.cruise as cruise,
            sfl.file as file,
            sfl.date as time,
            sfl.lat as lat,
            sfl.lon as lon,
            cytdiv.N0 as N0,
            cytdiv.N1 as N1,
            cytdiv.H as H,
            cytdiv.J as J,
            cytdiv.opp_red as opp_red,
            sfl.bulk_red as bulk_red
           FROM sfl, cytdiv
           WHERE
            sfl.cruise == cytdiv.cruise
            AND
            sfl.file == cytdiv.file
            ORDER BY time ASC ;"

  con <- dbConnect(SQLite(), dbname = db)
  cytdiv <- dbGetQuery(con, sql)
  dbDisconnect(con)
  return (cytdiv)
}


get.sfl.table <- function(db = db.name) {
  sql <- paste('SELECT * FROM ', sfl.table.name, 'ORDER BY date ASC')
  con <- dbConnect(SQLite(), dbname = db)
  sfl <- dbGetQuery(con, sql)
  dbDisconnect(con)
  return (sfl)
}

# Create a new, empty sqlite3 database using schema from original db
#
# Args:
#   new.db.path = path to a new sqlite3 database
make.sqlite.db <- function(new.db.path) {
  sql.file <- paste(system.file("sql", package="popcycle"), "popcycle.sql", sep="/")
  cmd <- sprintf("sqlite3 %s < %s", new.db.path, sql.file)
  status <- system(cmd)
  if (status > 0) {
    stop(paste("Db creation command '", cmd, "' failed with exit status ", status))
  }
}

# Merge opp, opp.evt.ratio, vct tables from multiple sqlite dbs into target.db.
# Erase files in src.dbs once merged.
#
# Args:
#   src.dbs: paths of sqlite3 dbs to merge into target.db
#   target.db: path of sqlite3 db to be merged into
merge.dbs <- function(src.dbs, target.db=db.name) {
  for (src in src.dbs) {
    # First erase existing opp, opp.evt.ratio, and vct entries in main db for
    # files about to be merged. Otherwise we'll get sqlite3 errors about
    # "UNIQUE constraint failed" if filtering is being rerun for some files.
    for (f in get.opp.files(src)) {
      .delete.opp.by.file(f, db=db.name)
    }
    for (f in get.vct.files(src)) {
      .delete.vct.by.file(f, db=db.name)
    }
    for (f in get.opp.evt.ratio.files(src)) {
      .delete.opp.evt.ratio.by.file(f, db=db.name)
    }

    # Now merge src db into main db
    merge.sql <- paste(sprintf("attach \"%s\" as incoming", src),
                       "BEGIN",
                       sprintf("insert into %s select * from incoming.%s",
                               opp.table.name, opp.table.name),
                       sprintf("insert into %s select * from incoming.%s",
                               vct.table.name, vct.table.name),
                       sprintf("insert into %s select * from incoming.%s",
                               opp.evt.ratio.table.name, opp.evt.ratio.table.name),
                       "COMMIT;", sep="; ")
    cmd <- sprintf("sqlite3 %s '%s'", target.db, merge.sql)
    status <- system(cmd)
    if (status > 0) {
      stop(paste("Db merge command '", cmd, "' failed with exit status ", status))
    }
    file.remove(src)
  }
}

# Create empty sqlite db for this project. If one already exists it will be
# overwritten. Also erase any numbered sqlite3 dbs used for parallel filtering.
#
# Args:
#   db.loc: directory containing sqlite3 database(s)
#   parts.only: only erase numbered databases (e.g. popcycle.db5) and leave
#     main db untouched
reset.db <- function(db.loc=db.location, parts.only=FALSE) {
  if (parts.only) {
    db.files <- list.files(db.loc, pattern="^popcycle\\.db[0-9]+$", full.names=TRUE)
  } else {
    db.files <- list.files(db.loc, pattern="^popcycle\\.db[0-9]*$", full.names=TRUE)
  }
  for (db in db.files) {
      file.remove(db)
  }
  # Create empty sqlite database
  if (! parts.only) {
    make.sqlite.db(paste(db.loc, "popcycle.db", sep="/"))
  }
}

# Ensure that there is an sfl.date index in sqlite3 db
#
# Args:
#   db: path to sqlite3 db file
ensure.sfl.date.index <- function(db=db.name) {
  system(paste0("sqlite3 ", db, " 'CREATE INDEX IF NOT EXISTS sflDateIndex ON sfl (date)'"))
}

# Ensure that there is are per channel indexes on opp in sqlite3 db
#
# Args:
#   db: path to sqlite3 db file
ensure.opp.channel.indexes <- function(db=db.name) {
  system(paste0("sqlite3 ", db, " 'CREATE INDEX IF NOT EXISTS oppFsc_smallIndex ON opp (fsc_small)'"))
  #system(paste0("sqlite3 ", db, " 'CREATE INDEX IF NOT EXISTS oppFsc_perpIndex ON opp (fsc_perp)'"))
  #system(paste0("sqlite3 ", db, " 'CREATE INDEX IF NOT EXISTS oppFsc_bigIndex ON opp (fsc_big)'"))
  system(paste0("sqlite3 ", db, " 'CREATE INDEX IF NOT EXISTS oppPeIndex ON opp (pe)'"))
  system(paste0("sqlite3 ", db, " 'CREATE INDEX IF NOT EXISTS oppChl_smallIndex ON opp (chl_small)'"))
  #system(paste0("sqlite3 ", db, " 'CREATE INDEX IF NOT EXISTS oppChl_bigIndex ON opp (chl_big)'"))
}

# Convert a date string in format YYYY-MM-DD HH:MM to format suitable for db
# date field comparison.
#
# Args:
#   date.string: In format YYYY-MM-DD HH:MM
date.to.db.date <- function(date.string) {
  return(POSIXct.to.db.date(string.to.POSIXct(date.string)))
}

# Returns a POSIXct object for a human readable date string
#
# Args:
#   date.string: In format YYYY-MM-DD HH:MM
string.to.POSIXct <- function(date.string) {
  # Make POSIXct objects in GMT time zone
  date.ct <- as.POSIXct(strptime(date.string, format="%Y-%m-%d %H:%M", tz="GMT"))
  if (is.na(date.ct)) {
    stop(paste("wrong format for date.string parameter : ", date.string, "instead of ", "%Y-%m-%d %H:%M"))
  }
  return(date.ct)
}

# Convert a POSIXct date into a string suitable for comparisons in db date
# fields comparison.
POSIXct.to.db.date <- function(date.ct) {
  return(format(date.ct, "%Y-%m-%dT%H:%M:00"))
}
