library(popcycle)

context("EVT filtering")

test_that("Successfully filter two files with filter.evt", {
  newdir <- tempdir()
  projdir <- file.path(newdir, "project")

  set.project.location(projdir)
  set.evt.location("../../inst/extdata")
  set.cruise.id("test")

  evt.path <- c(file.path("SeaFlow", "datafiles", "evt",
                          "2014_185", "2014-07-04T00-00-02+00-00"),
                file.path("SeaFlow", "datafiles", "evt",
                          "2014_185", "2014-07-04T00-03-02+00-00"))

  offset <- 0.0
  width <- 0.5

  evt1 <- readSeaflow(evt.path[1])
  opp1 <- filter.evt(evt1, filter.notch, offset=offset, width=width)
  opp1.count <- nrow(opp1)

  evt2 <- readSeaflow(evt.path[2])
  opp2 <- filter.evt(evt2, filter.notch, offset=offset, width=width)
  opp2.count <- nrow(opp2)

  print(paste0("opp1.count = ", opp1.count))
  print(paste0("opp2.count = ", opp2.count))
  expect_equal(opp1.count, 345)
  expect_equal(opp2.count, 404)

  # Erase temp dir
  unlink(projdir, recursive=T)
})

test_that("Successfully filter five files, one core", {
  newdir <- tempdir()
  projdir <- file.path(newdir, "project")

  set.project.location(projdir)
  set.evt.location("../../inst/extdata")
  set.cruise.id("test")

  evt.path <- c(file.path("SeaFlow", "datafiles", "evt",
                          "2014_185", "2014-07-04T00-00-02+00-00"), # good file
                file.path("SeaFlow", "datafiles", "evt",
                          "2014_185", "2014-07-04T00-03-02+00-00"), # good file
                file.path("SeaFlow", "datafiles", "evt",
                          "2014_185", "2014-07-04T00-06-02+00-00"), # empty file
                file.path("SeaFlow", "datafiles", "evt",
                          "2014_185", "2014-07-04T00-09-02+00-00"), # corrupt file
                file.path("SeaFlow", "datafiles", "evt",
                          "2014_185", "2014-07-04T00-12-02+00-00")) # good file

  setFilterParams(offset=0.0, width=0.5)

  bad.evt.files <- filter.evt.files(evt.path, cores=1)
  opp.count <- nrow(get.opp.by.file(evt.path[1]))
  opp.count <- opp.count + nrow(get.opp.by.file(evt.path[2]))
  opp.count <- opp.count + nrow(get.opp.by.file(evt.path[3]))
  opp.count <- opp.count + nrow(get.opp.by.file(evt.path[4]))
  opp.count <- opp.count + nrow(get.opp.by.file(evt.path[5]))

  print(paste0("opp.count = ", opp.count))
  expect_equal(opp.count, 1114)

  print(paste0("bad.evt.files = ", paste(bad.evt.files, collapse=" ")))
  print(paste0("evt.path[3:4] = ", paste(unlist(lapply(evt.path[3:4], clean.file.name)), collapse=" ")))
  expect_equal(bad.evt.files, unlist(lapply(evt.path[3:4], clean.file.name)))

  # Erase temp dir
  unlink(projdir, recursive=T)
})

# [TODO Chris]: configure travis to use two cores
# Does not work in our current Travis setup so use env var INTRAVIS
# (set to 1 in .travis.yml) to determine if the test is run locally
# or in Travis.
test_that("Successfully filter five files, two cores", {
  if (Sys.getenv("INTRAVIS") != 1) {
    newdir <- tempdir()
    projdir <- file.path(newdir, "project")

    set.project.location(projdir)
    set.evt.location("../../inst/extdata")
    set.cruise.id("test")

    evt.path <- c(file.path("SeaFlow", "datafiles", "evt",
                          "2014_185", "2014-07-04T00-00-02+00-00"), # good file
                file.path("SeaFlow", "datafiles", "evt",
                          "2014_185", "2014-07-04T00-03-02+00-00"), # good file
                file.path("SeaFlow", "datafiles", "evt",
                          "2014_185", "2014-07-04T00-06-02+00-00"), # empty file
                file.path("SeaFlow", "datafiles", "evt",
                          "2014_185", "2014-07-04T00-09-02+00-00"), # corrupt file
                file.path("SeaFlow", "datafiles", "evt",
                          "2014_185", "2014-07-04T00-12-02+00-00")) # good file

    setFilterParams(offset=0.0, width=0.5)

    # Filter the second file without SNOW multicore parallelism so there
    # is some duplicate opp/opp.evt.ratio data in the database.  This way
    # we can test potential UNIQUE key sqlite3 errors when re-filtering the second
    # file.
    filter.evt.files(evt.path[2], cores=1)

    filter.evt.files(evt.path, cores=2)
    opp.count <- nrow(get.opp.by.file(evt.path[1]))
    opp.count <- opp.count + nrow(get.opp.by.file(evt.path[2]))
    opp.count <- opp.count + nrow(get.opp.by.file(evt.path[3]))
    opp.count <- opp.count + nrow(get.opp.by.file(evt.path[4]))
    opp.count <- opp.count + nrow(get.opp.by.file(evt.path[5]))

    print(paste0("opp.count = ", opp.count))
    expect_equal(opp.count, 1114)

    # Erase temp dir
    unlink(projdir, recursive=T)
  }
})
