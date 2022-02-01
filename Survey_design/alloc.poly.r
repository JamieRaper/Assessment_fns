# This allocates tows (or anything really) for a straified random design.  
#This can be based on bottom type (or another polygon based non-continuous stratifying variable)
#####  DK August 26th, 2016
# Update history
# Commented, checked  and revised by DK August 2016 (Added in seed option to the function)


#####################################  Function Summary ########################################################
####  
##  This function is used within these files:(a.k.a "dependent files") 
# 1: source(paste(direct_fns,"Survey_design/Survey_design_test.r",sep=""))
###############################################################################################################

###############################################################################################################
## This function needs these functions to work (a.k.a. "support files")
# 1:   source(paste(direct_fns,"Survey_design/genran.r",sep=""))
# 2:   source(paste(direct_fns,"Maps/ScallopMap.r",sep=""))
###############################################################################################################



###############################################################################################################
# Arguments
# poly.lst:       The bank survey, if there is a stratified survey this includes all these data.  A second list is required with this that contains
#                 the survey information for the bank.  format required is poly.lst = list(survey_detail_polygon,survey_information)
# bounding.poly:  The boundary polygon for the bank.  
# ntows:          The number of tows on the bank.  If there are repeat tows this is total number - number of repeats.  Default is missing
# bank.plot:      Do you want to make a bank.plot.  T/F, default = F,
# mindist:        The minimum distance between points.  Default = 1, this is used in genran and if repeated tows to weed out tows too close to each other
# pool.size:      What size is the pool you are pulling from.  Essentially this is multiplier to give larger pools for random allocation.  Default = 4
# repeated.tows:  Are their repeated tows.  Default = NULL.  A dataframe with a list of the repeated tows (EID, X,Y, stratum are required columns)
# lplace:         If making a plot where to put the legend.  Default ='bottomleft'
# show.pool:      Plot the entire pool of randomly generated points.  T/F default = F
# seed:           Set a seed so that your results can be reproduced.  Default = NULL which uses R random number generation.  Any integer will result
#                 in producing a reproducable random number draw.
# repo:           Where are the functions you need for this.  Default = 'github' which points to the github repo and latest stable versions of the functions
#                 Alternative is to specify the directory the function exists, something like "D:/Github/Offshore/Assessment_fns/DK/" to get to the folders with this files in them
###############################################################################################################

alloc.poly <- function(strata,ntows,bank.plot=F,mindist=1,pool.size=4,
         repeated.tows=NULL,lplace='bottomleft',show.pool=F,seed = NULL,repo = 'github')
{
  
  tooclose <- NA
  
  require(PBSmapping) || stop("You'll need to install PBSmapping if you wanna do this thang")
  require(sf) || stop("Install sf, it's the best")
  require(dplyr) || stop("Install dplyr, it's the best")
  if(repo != 'github')
  {
    #source(paste(repo,"Survey_design/genran.r",sep=""))
    source(paste(repo,"Maps/ScallopMap.r",sep=""))
  } # end if(repo != 'github')
  
  if(repo == 'github')
  {
    funs <- c(#"https://raw.githubusercontent.com/Mar-Scal/Assessment_fns/master/Survey_design/genran.r",
              "https://raw.githubusercontent.com/Mar-Scal/Assessment_fns/master/Maps/ScallopMap.r")
    # Now run through a quick loop to load each one, just be sure that your working directory is read/write!
    for(fun in funs) 
    {
      download.file(fun,destfile = basename(fun))
      source(paste0(getwd(),"/",basename(fun)))
      file.remove(paste0(getwd(),"/",basename(fun)))
    } # end for(un in funs)
  } # end if(repo == 'github')
  print("running alloc.poly function")
  # This ignores all warnings
  options(warn=-1)
  
  # create pool of random points, if we haven't specified the number of points the second element of the poly list needs to have an allocation table in
  # it so we can figure out the total number of tows.
  if(missing(ntows)) ntows<-sum(strata$allocation)
  # This tells use the number of pools, which is simply the total number of tows multiplied by the "pool.size", the higher we set pool.size the
  # more location that are generated by genran, later we will sample from this large number of potential sites and narrow it down to the 
  # appropriate number of locations.
  npool=ntows*pool.size

  # Now generate a large number of random points within this survey boundary polygon.
  # This retuns the tow ID, X & Y coordinates and the nearest neighbour distance.
  #source(paste(direct_fns,"Survey_design/genran.r",sep=""))
  # sf_use_s2(FALSE)
  # pool.EventData <- genran(npoints = npool,bounding.poly = st_union(st_transform(strata, 32620)),mindist=mindist,seed=seed)
  # 
  # Define a variable
  strataTows.lst<-NULL
  
  # if the allocation scheme hasn't been provided then you'll need to run this.
  if("allocation" %in% names(strata))
  {
    strata <- strata %>% 
      mutate(area=as.numeric(st_area(.)/10^6)) %>%
      st_transform(4326)
  }
  
  if(!"allocation" %in% names(strata))
  {
    strata <- strata %>% 
      st_transform(4326) %>%
      mutate(area=as.numeric(st_area(.)/10^6),
             allocation = round(as.numeric(st_area(.)/sum(st_area(.)))*ntows,0)) 
  }
  
  if(!is.null(seed)) set.seed(seed)
  
  Tows <- st_sample(st_transform(strata, 32620),size=strata$allocation, type="random", exact=T) %>%
    st_sf('EID' = seq(length(.)), 'geometry' = .) %>%
    st_intersection(., st_transform(strata, 32620)) %>%
    cbind(st_coordinates(.))
  
  # Get the nearest neighbour distances
  nearest<-st_nearest_feature(Tows)
  Tows$nndist <- as.numeric(st_distance(Tows, Tows[nearest,], by_element = TRUE))/1000
  
  if(any(Tows$nndist < mindist)){
    tooclose <- which(Tows$nndist<mindist)
    message(paste0("moving ", length(tooclose), " tows"))
    for (i in tooclose){
      repeat{
        if(nrow(strata)>1) {
          newpoint <- st_sample(st_transform(strata[strata$Strata_ID==Tows$Strata_ID[i],], 32620),
                                size=1, type="random", exact=T) %>%
            st_sf('EID' = seq(length(.)), 'geometry' = .) %>%
            st_intersection(., st_transform(strata[strata$Strata_ID==Tows$Strata_ID[i],], 32620)) %>%
            cbind(st_coordinates(.))
        }
        if(nrow(strata)==1) {
          newpoint <- st_sample(st_transform(strata, 32620),
                                size=1, type="random", exact=T) %>%
            st_sf('EID' = seq(length(.)), 'geometry' = .) %>%
            st_intersection(., st_transform(strata, 32620)) %>%
            cbind(st_coordinates(.))
        }
        Tows[i,] <- newpoint
        nearest<-st_nearest_feature(Tows)
        Tows$nndist <- as.numeric(st_distance(Tows, Tows[nearest,], by_element = TRUE))/1000
        if(Tows$nndist[i] >= mindist) break
      }
    }
  }
  
  nearest<-st_nearest_feature(Tows)
  message("Distance summary")
  print(summary(as.numeric(st_distance(Tows, Tows[nearest,], by_element = TRUE))/1000))
  
  Tows$EID <- 1:nrow(Tows)
  if("Strata_ID" %in% names(Tows) & "PName" %in% names(Tows)){
    Tows <- dplyr::select(Tows, EID, X, Y, Strata_ID, PName, label) %>%
      dplyr::rename("Poly.ID" = Strata_ID,
             "STRATA" = PName)
  }
  if(!("Strata_ID" %in% names(Tows) & "PName" %in% names(Tows))){
    Tows <- dplyr::select(Tows, EID, X, Y) %>%
      mutate(Poly.ID=1)
  }
  
  if(!st_crs(Tows)==st_crs(strata)){
    Tows <- st_transform(Tows,st_crs(strata))
    Tows[,c("X", "Y")] <- st_coordinates(Tows)
  }
  
  # If there are repeated tows this will randomly select stations from last years	survey (repeated.tows)
  if(!is.null(repeated.tows))
  {
    # if we have repeated tows (ger) rename properly
    repeat.dat <- repeated.tows[[2]]
    # Define a new variable
    repeated.lst<-NULL
    # Reset the names for the repeated tows
    names(repeated.tows[[1]])<-c("EID","X","Y","Poly.ID")
    # Give the tows from last year (repeated tows) a unique number
    repeated.tows[[1]]$EID<-repeated.tows[[1]]$EID+1000
    # flip to sf
    repeated.tows[[1]] <- st_as_sf(repeated.tows[[1]], coords=c("X", "Y"), remove=F, crs=4326)
    # Get the info for the repeats that you entered as part of strata list (repeat.dat)
    repeat.str<-repeat.dat[!is.na(repeat.dat$repeats),]
    # Combine the tows selected for this year with repeated tows and make that a PBSmapping object
    tmp <- rbind(Tows,repeated.tows[[1]][, c("EID", "X", "Y", "geometry", "Poly.ID")])
    # Calculate the nearest neighbour distance
    # The Lat/Lon's  for both the temp and bounding poly are converted to UTM coordinates
    # The nearest neighbour calculations are then made and tacked onto the tmp object
    tmp <- st_transform(tmp, 32620)
    nearest<-st_nearest_feature(tmp)
    tmp$nndist <- as.numeric(st_distance(tmp, tmp[nearest,], by_element = TRUE))/1000
    # Potential repeated tows are then selected that are > mindist from each other.
    repeated.tows[[1]]<-subset(tmp,nndist > mindist & EID>1000)
    # We now get repeats from each strata (for German Bank there is no strata so i =1)
    for(i in 1:length(repeat.str$PID))
    {
      # Get the tows that are in the correct strata
      str.tows<-subset(repeated.tows[[1]],Poly.ID==repeat.str$PID[i]) 
      nrow(str.tows)
      # Now from these repeat tows grab the appropriate number of tows. Note that if we want this sample reproducible we need to set the seed again
      #(Should be fine to just have this above in a function, but if running line by line you'll need this)
      if(!is.null(seed)) set.seed(seed)
      repeated.lst[[i]] <- str.tows[sample(x = 1:nrow(str.tows),size = repeat.str$repeats[repeat.str$PID==repeat.str$PID[i]]),]
      # Add the strata name column
      repeated.lst[[i]]$STRATA<-repeat.str$PName[repeat.str$PID==repeat.str$PID[i]]
    } # end for(i in 1:length(repeat.str$PID))
    # Unwrap the list into a dataframe
    repeated.tows<-do.call("rbind",repeated.lst)
    #back to non UTM please
    repeated.tows <- st_transform(repeated.tows, 4326)
    repeated.tows[,c("X", "Y")] <- st_coordinates(repeated.tows)
    # Combine the tows into a list with the new tows and a list with the repeats.
    Tows<-list(new.tows=Tows, repeated.tows=repeated.tows)
  } # end if(!is.null(repeated.tows))
  
  # Turn the warnings back on.
  options(warn=0)
  # Return the results to the function calling this.
  return(list(Tows=Tows, Strata=strata))
  rm(strata)
}

