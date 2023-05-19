# This code applies corrections to the SAF datasets (permanent and seasonal). These corrections will include manual corrections which can be added each year, perhaps to the function script.
# Then, for the permanent data, it corrects invalid codes (this will need updating every year) and  splits up lines with both SFP code and Other Code. For the seasonal data, it splits up and removes those with only an Other code.
# Code corrections may need updating yearly depending on SAF data.
# This script is based on the code in B4 and B6 of the June Project (\\s0177a\datashare\seerad\ags\census\branch1\NewStructure\Surveys\June\Main\JUNE CENSUS PROJECT - 2021 Provisional Scott)
# Data used currently is from September 2021, as in the most recent version of the SAS project.
# Created by Lucy Nevard 27.01.23
# Modified by Lucy Nevard 15.05.23


# Before import -----------------------------------------------------------



# Clear environment prior

rm(list = ls())

# Load packages

library(tidyverse)
library(data.table)
library(janitor)


# Load functions

source("Functions/Functions.R")


# Datashare file path for import and export

Code_directory <- ("//s0177a/datashare/seerad/ags/census/branch1/NewStructure/Surveys/June/Codeconversion_2023")
sas_agstemp_path <- "//s0177a/sasdata1/ags/census/agstemp/"
# ADM schema for export

server <- "s0196a\\ADM"
database <- "RuralAndEnvironmentalScienceFarmingStatistics"
schema <- "juneagriculturalsurvey2023alpha"


# Import SAF data -------------------------------------------------------------


# 

list_perm_seas <- loadRData(paste0(Code_directory, "/saflist_permseas_A.rda"))

# Import new code translation table for SAF (these may need updating every year)

newcodetrans <-
  read.csv(paste0(Code_directory, "/NEW_CODE_TRANS21.csv"))

# Or import from ADM 
# 

# B6 of SAS code - Corrections ----------------------------------------------------------

#  Apply corrections to both datasets.  -----------------------------------
# Correcting area variables and slc when blank. Code corrections for sfp_code and other_code.


# Clean names again to ensure consistency

list_perm_seas<-lapply(list_perm_seas, clean_names)

# For SAF codes - this might change year to year. But those below might still be used.
# Manual corrections should also mbe included here and change from year to year. None from the 2021 SAS project.

list_perm_seas <- lapply(list_perm_seas, change_codes)


# Unlist permanent and seasonal.  ---------------------------------------


# Tidy this up in future.

#  Create separate dfs for permanent and seasonal.

names(list_perm_seas) <- c("perm", "seas")

for (i in seq(list_perm_seas)) {
  assign(paste("saf", names(list_perm_seas)[[i]], sep = "_"), list_perm_seas[[i]])
}


saf_perm$landtype <- "PERM"
saf_seas$landtype <- "SEAS"


# Remove rows of all NAS. Couldn't figure out how to do this in a list.


saf_perm <- saf_perm[rowSums(is.na(saf_perm)) != ncol(saf_perm), ]

saf_seas <- saf_seas[rowSums(is.na(saf_seas)) != ncol(saf_seas), ]


# Permanent - split up SAF datalines into claimtype other or sfp --------

# Reformat df with claimtype as "OTHER"other" or "sfp" (Single Farm Payment) and "line" variable increasing by 0.01 if OTHER.
# LLO flags also assigned

# Other claimtype df

saf_permother <- filter(saf_perm, saf_perm$other_area > 0)

# 

saf_permother <- newvarsother(saf_permother)


# SFP claimtype df

saf_permsfp <- filter(saf_perm, saf_perm$sfp_area > 0)


saf_permsfp <- newvarssfp(saf_permsfp)


# Merge Other and SFP


saf_perm<- rbind(saf_permother, saf_permsfp)


# Remove unnecessary variables


saf_perm<- saf_perm %>%
  select(-c(other_area, other_code, prefix))

# Create correct parish and holding from "slc" (Single Location Code)

saf_perm <- parishholdingslc(saf_perm)
                        

# The SAS code here has tables to see what errors are left in the permanent df - not clear what we're looking for at this point and there aren't any fixes in the code, so I've left this out for now.


#  Seasonal - filter out "Other" holdings, keep only SFP  --------------------------------------------------------------
# According to desk notes, the data for "other" is too messy to be reliable. The seasonal data is therefore an underestimate.


saf_seas <- filter(saf_seas, saf_seas$sfp_area > 0)

# SFP claimtype df - add variables

saf_seas<-newvarsseas(saf_seas)


# Create correct parish and holding from mlc (main location code)

saf_seas<-parishholdingmlc(saf_seas)



# Compare with SAS outputs

sas_saf_perm<-read_sas(paste0(sas_agstemp_path, "permanent_sheets21.sas7bdat"))
sas_saf_seas<-read_sas(paste0(sas_agstemp_path, "seasonal_sheets21.sas7bdat"))

sas_saf_perm<-clean_names(sas_saf_perm)
sas_saf_seas<-clean_names(sas_saf_seas)

sas_saf_perm <- sas_saf_perm %>% mutate_all(na_if,"")
sas_saf_seas <- sas_saf_seas %>% mutate_all(na_if,"")


saf_perm<-saf_perm %>% 
  mutate(
    parish=as.numeric(parish),
    holding=as.numeric(holding),
    code=as.factor(code),
    crops=as.factor(crops),
    area=round(as.numeric(area),3)
  )

sas_saf_perm<-sas_saf_perm %>% 
  mutate(
    sfp_code=as.factor(sfp_code),
    code=as.factor(code),
    crops=as.factor(crops),
    area=round(as.numeric(area),3))
  
perm_compare <- as.data.frame(compare_df_cols(saf_perm,sas_saf_perm))

compare_perm<-setdiff(saf_perm, sas_saf_perm) # 10 differences
compare_perm2<-setdiff(sas_saf_perm, saf_perm) # 12 differences...


diff1 <- mapply(setdiff, saf_perm, sas_saf_perm)

diff2<-sapply(diff1, length)   



comb_1<- compare_perm[1, ]
comb_2 <- compare_perm2[1, ]

compare <- rbind(comb_1,comb_2)


# compare seasonal. As of 19.05.23 this still needs to be checked. 

saf_seas<-saf_seas %>% 
  select(-c(other_area,other_code)) %>% 
  mutate(
    parish=as.numeric(parish),
    holding=as.numeric(holding),
    code=as.factor(code),
    crops=as.factor(crops),
    line=as.numeric(line),
    area=round(as.numeric(area),3)
  )

sas_saf_seas<-sas_saf_seas %>% 
  mutate(
    sfp_code=as.factor(sfp_code),
    code=as.factor(code),
    crops=as.factor(crops),
    line=as.numeric(line),
    area=round(as.numeric(area),3))



seas_compare <- as.data.frame(compare_df_cols(saf_seas,sas_saf_seas))



# Save separate permanent and seasonal datasets --------------------------

# Commented out currently as the datasets are saved at the end of this whole script.

# Save to datashare

# save(saf_perm_final, file = paste0(Code_directory, "/saf_perm_B6.rda"))
# 
# save(saf_seas, file = paste0(Code_directory, "/saf_seas_B6.rda"))



# Save to ADM
#
#
# write_dataframe_to_db(server=server,
#                       database=database,
#                       schema=schema,
#                       table_name="allsaf_perm_B6",
#                       dataframe=allsaf_perm,
#                       append_to_existing = FALSE,
#                       batch_size=1000,
#                       versioned_table=FALSE)






# B7 of SAS code ----------------------------------------------------------


# Limits for checking against

under_reportlimit <- 500
over_report_limit <- 5
under_report_percent <- 0.5
over_report_percent <- 1.1




# Permanent dataset - checks and error flags -----------------------------------




# Check frequency of fids (field id), whether multiple holdings are using the same fid.


fidfreqsorig<-saf_perm %>% 
  select(slc, fid) 

fidfreqs<-fidfreqsorig %>% 
  group_by(fid) %>% 
  summarise(count=n()) %>% 
  flatten() %>% 
  dplyr::rename(fid_uses_by_slc = count)

fids<-fid_index(fidfreqsorig)

fids<-fids %>%
  filter(line==1) %>% 
  dplyr::rename(holdings_using_fid=line)

fidfreqsfinal<-merge(fidfreqs, fids, by="fid")

fids_with_multiple_slcs<-fidfreqsfinal %>% 
  filter(holdings_using_fid>1)

# Filter out lmc () claimtype 
 
saf_perm_notlmc<-saf_perm %>% 
  filter(claimtype!="LMC")

fids_with_multiple_slcs<-merge(fids_with_multiple_slcs, saf_perm_notlmc, by=c("slc","fid"))




# LLO. Assign flags 1 and 7. 

fids_with_llo<-saf_perm %>% 
  filter(llo=="Y") %>% 
  select(slc, fid) %>% 
  unique()



# Filter out LMC claimtype from this point.

saf_perm_notlmc<-saf_perm %>% 
  filter(claimtype!="LMC")

fids_with_multiple_slcs <- fids_with_multiple_slcs[c('fid', 'slc')] # filter doesn't work on an empty df

# do the following two statements in a list

saf_perm<-plyr::join_all(list(saf_perm_notlmc, fids_with_multiple_slcs,fids_with_llo), by=c("slc","fid"), type='left')


saf_perm<-left_join(saf_perm, fids_with_llo, by=c("slc","fid"))


llo_error<-inner_join(saf_perm,fids_with_multiple_slcs,fids_with_llo, by=c("slc","fid"))


llo_error<-llo_error %>% 
  filter(llo=="Y")
# %>% 
# mutate(flag1=1,
#        flag7=0)


flag7<-inner_join(saf_perm,fids_with_multiple_slcs,by=c("slc","fid"))


flag7<-anti_join(flag7,llo_error,by=c("slc","fid"))

flag7<-flag7 %>% 
  select(slc, fid) %>% 
  mutate(flag1=0,
         flag7=1)



# merge flag7 with saf_perm if it has rows in it. Currently it is empty.


# create flag1 and flag7 in saf_perm

saf_perm<-saf_perm %>% 
  mutate(flag1=0,
         flag7=0)



# Dataframes for different error flags ------------------------------------
# Select variables, group by fid and summarise

checkareasummary <- saf_perm %>%
  select(fid, area, field_area, eligible_area, land_use_area, flag1, flag7) %>% 
  group_by(fid) %>% 
  summarycheckarea()

# Dataframe for when field area is inconsistent

inconsistentfieldareas <- checkareasummary %>%
  filter(var_field > 0)

# Check for differences between total land use and field area (over the overreportlimit or overpercent which is coded at the top of the script)

checkareamismatches <- checkareasummary %>%
  mutateareamismatches() %>% 
  filter(diff > 500 | diff < (-5) | ratio > 1.1 | ratio < 0.5 & max_field > 0 & sum_area > 0 & sum(flag1) >= 0) %>% 
  select(fid, sum_area, max_field, diff, ratio)

# Fid level dataset for fids with a mismatch between land use area total and recorded field area

checkareamismatches_fids <- merge(checkareamismatches, saf_perm, by = "fid")


# check for decimal point (dp) errors

dperror <- merge(checkareasummary, saf_perm, by = "fid")

dperror <- dperror %>%
  mutate(dp_ratio = signif(area / (field_area - sum_area + area), 3)) %>% 
  filter(dp_ratio == 0.01 | dp_ratio == 0.1 | dp_ratio == 10 | dp_ratio == 100)



# Flag duplicates where total land use is substantially greater than field area - keeps SFPS over OTHER

areaoverreported <- checkareamismatches_fids %>%
  filter(ratio > 1.1 | diff < (-5)) %>% 
  mutate(
    across(claimtype, as_factor)
  )


remove_duplicates <- areaoverreported %>%
  group_by(fid, area, code) %>%
  filter(!(claimtype == "OTHER" & n() > 1))

duplicates <- areaoverreported %>%
  group_by(fid, area, code) %>%
  filter((claimtype == "OTHER" & n() > 1))




# flag EXCL land where total crop area is too large

areastilloverreported <- group_by(remove_duplicates, fid) %>%
  summarize(
    max_field = max(field_area),
    sum_area = sum(area)
  )


areastilloverreported <- merge(areastilloverreported, saf_perm, by = "fid")

areastilloverreported <- areastilloverreported %>%
  mutate(
    diff = max_field - sum_area,
    ratio = signif(sum_area / max_field, 3)) %>% 
  filter(ratio > over_report_percent | diff < (-over_report_limit))



overreportedexclerror <- areastilloverreported %>%
  filter(code == "EXCL")


areastilloverreported2 <- areastilloverreported %>%
  filter(code != "EXCL")

areastilloverreported2 <- group_by(areastilloverreported2, fid) %>%
  summarize(
    max_field = max(field_area),
    sum_area = sum(area)
  )



# Flag llo land where total land area is still greater than the field area by over_report amount (after accounting for duplicates). Land reported as seasonally let out as these are likely errors.

areastilloverreported2 <- merge(areastilloverreported2, saf_perm, by = "fid")


areastilloverreported2 <- areastilloverreported2 %>%
  mutate(
    diff = max_field - sum_area,
    ratio = signif(sum_area / max_field, 3)) %>% 
  filter(ratio > over_report_percent | diff < (-over_report_limit))



# 

overreportedlloerror <- areastilloverreported %>%
  filter(llo == "Y")


areastilloverreported3 <- areastilloverreported2 %>%
  filter(llo != "Y")

areastilloverreported3 <- group_by(areastilloverreported3, fid) %>%
  summarize(
    max_field = max(field_area),
    sum_area = sum(area)
  )



# Flag records that may be errors


# the following df has 1 more entry in SAS - 3 because of llo, what about 4th - see above comments.


areastilloverreported3 <- merge(areastilloverreported3, saf_perm, by = "fid") %>% 
  filter(llo != "Y") %>%
  mutate(
    diff = max_field - sum_area,
    ratio = signif(sum_area / max_field, 3)
  ) %>% 
  filter(ratio > over_report_percent)



# get unique llo errors

overreportedllofids <- overreportedlloerror %>%
  group_by(fid) %>%
  filter(!(n() > 1)) %>% 
  select(fid, mlc) %>%
  rename(llomlc = mlc)

overreportedothererror <- merge(overreportedllofids, areastilloverreported3, by = "fid", all = TRUE)


overreportedothererror <- overreportedothererror %>%
  filter(claimtype == "OTHER")



# Note: check all dfs are same type

saf_perm <- saf_perm %>%
  mutate(
    crops = code,
    flag6 =
      ifelse(parish <= 0 | holding <= 0, 1, 0)
  )

# Other flagged datasets

duplicates <- duplicates %>%
  select(brn, fid, line, claimtype, code, area) %>% 
  mutate(flag2=1)


# overreportedlloerror$flag3<-1 this doesn't work on an empty dataframe.

overreportedlloerror <- overreportedlloerror %>%
  select(brn, fid, line, claimtype, code, area) # include flag3 when df isn't empty

dperror <- dperror %>%
  select(brn, fid, line, claimtype, code, area, dp_ratio, sum_area) %>% 
  mutate(flag5=1)


overreportedothererror <- overreportedothererror %>%
  select(brn, fid, line, claimtype, code, area) %>% 
  mutate(flag8=1)


overreportedexclerror <- overreportedexclerror %>%
  select(brn, fid, line, claimtype, code, area) %>% 
  mutate(flag9=1)



# Create list of all dfs, including errors with their flags.

df_list <- list(saf_perm, duplicates, overreportedlloerror, dperror, overreportedothererror, overreportedexclerror)

# Merge all data frames in list, creating permanent dataset with all flags


finalsaf_perm <- df_list %>% reduce(full_join, by = c("brn", "fid", "line", "claimtype", "code", "area"))





# Seasonal dataset flagging ----------------------------------------------




# Flag fids which look like permanent lets (slc=mlc).
# On seasonal land sheets, the main location code relates to the business that is seasonally letting in land.  Whilst the sub location code relates to the holding that has the land on a permanent basis.  Where the MLC and SLC are the same, something has gone wrong.  It is possible that these are valid rows, with the SLC detail incorrectly filled in on the SAF.  Or it is possible this has been entered on a seasonal sheet instead of a permanent sheet incorrectly.

saf_seas <- saf_seas %>%
  mutate(
    flag4 =
      ifelse(mlc == slc, 1, 0)
  )


# In the SAS code, there is a "stage 4" here (commented out) which checks if multiple holdings use the same fids - this isn't as relevant as for permanent sheets - decide if we should bring this in or not?

# Flag duplicates where land use total substantially greater than field area

checkarea_seas <- saf_seas %>%
  filter(claimtype != "LMC")

checkarea_seas <- group_by(checkarea_seas, fid) %>%
  summarize(
    sum_area = sum(area),
    sum_field = sum(field_area),
    sum_eligible = sum(eligible_area),
    max_field = max(field_area),
    var_field = var(field_area)
  )

inconsistentfieldareas_seas <- checkarea_seas %>%
  filter(var_field > 0)


checkareamismatches_seas <- checkarea_seas %>%
  filter(max_field > 0 & sum_area > 0) %>%
  mutate(
    diff = round(max_field - sum_area, 3),
    ratio = round(sum_area / max_field, 3)
  ) %>% 
  filter(diff > under_reportlimit | diff < (-over_report_limit) | ratio > over_report_percent | ratio < under_report_percent) %>% 
  select(fid, sum_area, max_field, diff, ratio)



# Create fid level dataset where land use area and field area don't match

checkareamismatches_fids_seas <- merge(checkareamismatches_seas, saf_seas, by = "fid")


checkarea_seas <- checkarea_seas %>%
  select(fid, sum_area, max_field)


# Flag decimal point (dp) errors

dperror_seas <- merge(checkarea_seas, saf_seas, by = "fid")
# Note: the SAS code outputs only 4 observations here (August 2021 dataset)

dperror_seas <- dperror_seas %>%
  mutate(dp_ratio = signif(area / (field_area - sum_area + area), 3)) %>% 
  filter(dp_ratio == 0.01 | dp_ratio == 0.1 | dp_ratio == 10 | dp_ratio == 100)



# remove duplicates where total land use greater than field area by over report amount


areaoverreported_seas <- checkareamismatches_fids_seas %>%
  filter(ratio > over_report_percent | diff < (-over_report_limit))

# order by Business Name

areaoverreported_seas <- areaoverreported_seas[order(areaoverreported_seas$business_name), ]

remove_duplicates_seas <- areaoverreported_seas[!duplicated(areaoverreported_seas[c("fid", "area", "code")]), ]

duplicates_seas <- areaoverreported_seas[duplicated(areaoverreported_seas[c("fid", "area", "code")]), ]




# Check fids where the claimed area is much larger than field area

areastilloverreported_seas <- group_by(remove_duplicates_seas, fid) %>%
  summarize(
    max_field = max(field_area),
    sum_area = sum(area)) %>% 
  select(fid, max_field, sum_area)


areastilloverreported_seas <- merge(areastilloverreported_seas, saf_seas, by = "fid")

areastilloverreported_seas <- areastilloverreported_seas %>%
  mutate(
    diff = max_field - sum_area,
    ratio = signif(sum_area / max_field, 3)) %>% 
  filter(ratio > over_report_percent | diff < (-over_report_limit))


# Flag duplicates

saf_seas <- saf_seas %>%
  mutate(
    crops = code,
    flag6 =
      ifelse(parish <= 0 | holding <= 0, 1, 0)
  )


duplicates_seas <- duplicates_seas %>%
  select(brn, fid, line, claimtype, area, code) %>%
  mutate(flag2 = 1)


dperror_seas <- dperror_seas %>%
  select(brn, fid, line, claimtype, area, code, dp_ratio, sum_area) %>%
  mutate(flag5 = 1)

# Create list of all dfs, including errors with their flags.

df_list_seas <- list(saf_seas, duplicates_seas, dperror_seas)

# Merge all dfs in list, creating seasonal dataset with flags in

finalsaf_seas <- df_list_seas %>% reduce(full_join, by = c("brn", "fid", "line", "claimtype", "code", "area"))



# Save to datashare


save(finalsaf_perm, file = paste0(Code_directory, "/allsaf_perm_B7.rda"))
save(finalsaf_seas, file = paste0(Code_directory, "/allsaf_seas_B7.rda"))





# B8 section of SAS code -------------------------------------------------

# rename dataframes

saf_permcurr<-finalsaf_perm
saf_seascurr<-finalsaf_seas


# Last year's data must be read in from a csv - R struggles with the xlsx

saf_prev <- read.csv(paste0(Code_directory, "/ALLSAF20.csv"))


# rename area in current seasonal data

saf_seascurr_fid <- saf_seascurr %>%
  rename(areacurr = area)



# Split seasonal data into different LLIs ---------------------------------

saf_seasprev_fid <- saf_prev %>%
  filter(substr(code, 1, 4) == "LLI-" & claimtype == "SFPS") %>%
  rename(areaprev = area) %>% 
  distinct(parish, holding, fid, .keep_all = TRUE) %>% 
  filter(!(is.na(parish) | is.na(holding)))


saf_seasprev_cph <- saf_prev %>%
  select(parish, holding) %>% 
  filter(!(is.na(parish) | is.na(holding)))

# remove duplicates

saf_seasprev_cph <- saf_seasprev_cph %>%
  distinct(parish, holding, .keep_all = TRUE) %>% 
  mutate(
    parish = as.numeric(parish),
    holding = as.numeric(holding)
  )

saf_seascurr_fid <- saf_seascurr_fid %>%
  select(-c("other_area", "other_code")) %>% 
  mutate(
    parish = as.numeric(parish),
    holding = as.numeric(holding)) %>% 
  filter(!(is.na(parish) | is.na(holding) | is.na(fid)))




# Different LLI types are assigned here.

# 	- LLI-SL = Land seasonally let in at same location as last year
# - LLI-DL = Land seasonally let in at a different location to last year
# - LLI-NL = Land seasonally let in but no SAF claimed last year

# The SAS code for this keeps NAs (parish and holding) in as if they are matching - I have already removed parish/holding NAS from seas21_fid

seascurr_matched <- merge(saf_seascurr_fid, saf_seasprev_cph, by = c("parish", "holding"))


onlycurr_fid <- setdiff(saf_seascurr_fid, seascurr_matched)

saf_seasprev_fid2 <- saf_seasprev_fid %>%
  select(areaprev, parish, holding, fid)

bothyears <- merge(seascurr_matched, saf_seasprev_fid2, by = c("parish", "holding", "fid"), all.x = TRUE)



bothyears <- bothyears %>%
  mutate(
    code =
      ifelse(areacurr > 0 & areaprev > 0, "LLI-SL", "LLI-DL")
  ) %>% 
  select(-areaprev)

onlycurr_fid <- onlycurr_fid %>%
  mutate(code = "LLI-NL")


split <- rbind(bothyears, onlycurr_fid)


pfdscurr_seas <- split %>%
  rename(area = areacurr) %>%
  mutate(
    llo = 0,
    landtype = "SEAS",
    claimtype = "SFPS"
  )




# Automatic corrections ---------------------------------------------------


# Remove flagged entries if required  (SAF validations also in C)


pfds_finalcurr <- rbind(saf_permcurr, pfdscurr_seas, fill = TRUE)


pfds_corrections1 <- pfds_finalcurr %>%
  filter(flag6 == 1 & !is.na(mlc) & landtype == "PERM") %>%
  mutate(
    parish = str_remove(substr(mlc, 1, 3), "^0+"),
    holding = str_remove(substr(mlc, 5, 8), "^0+"),
    flag6 = 0
  )


pfds_corrections2 <- pfds_finalcurr %>%
  filter((flag1 > 0 | flag2 > 0) & !is.na(fid))


pfds_corrections3 <- pfds_finalcurr %>%
  filter(flag5 > 0 & !is.na(fid))



# The below df doesn't completely match up with the one produced in SAS - possibly because SAS is on August 2021 data.

pfdscorrections <- rbind(pfds_corrections1, pfds_corrections2, pfds_corrections3)

# Following chunk only works when flag3 is present - see B7 script.

# pfds_finalcurr<-pfds_finalcurr %>%
#   filter(!flag3>0)


pfds_finalcurr <- setdiff(pfds_finalcurr, pfds_corrections2)


pfds_finalcurr <- pfds_finalcurr %>%
  mutate(
    area =
      ifelse(flag5 > 0 & !is.na(flag5), (area / dp_ratio), area),
    flag5 = 0,
    flag6 = 0
  )



# create permanent and seasonal datasets if necessary

saf_permcurr <- pfds_finalcurr %>%
  filter(landtype == "PERM")


saf_seascurr <- pfds_finalcurr %>%
  filter(landtype == "SEAS")


saf_permseas<-rbind(saf_permcurr,allsaf_seascurr)

# Keep necessary variables of combined dataset

saf_curr <- pfds_finalcurr %>%
  select(-c(business_name, land_use, land_use_area, bps_claimed_area, application_status, is_perm_flag, sfp_area, sfp_code, dp_ratio, sum_area))

# Save corrections and combined allsaf flagged dataset to datashare

save(saf_curr, file = paste0(Code_directory, "/allsaf_B8.rda"))

save(pfds_finalcurr, file = paste0(Code_directory, "/allsaf_B8flags.rda"))

save(saf_permseas, file = paste0(Code_directory, "/allsaf_B8permseas.rda"))

save(pfdscorrections, file = paste0(Code_directory, "/allsaf_B8corrections.rda"))




# B9 Section of SAS code --------------------------------------------------



# Rename SAF df

allsaf <- saf_curr

# Aggregate data 

check.llo <- allsaf %>%
  filter(!(llo == "N" | llo == "Y"))


allsaf_fids <- allsaf %>%
  filter(!claimtype == "LMC") %>%
  mutatellolfass()%>% 
  group_by (parish, holding, fid, code) %>%
  summaryfids()



aggregate1 <- allsaf_fids %>%
  group_by(parish, holding, code) %>%
  aggregatefids()

allsaf_reduced <- allsaf %>%
  select(parish, holding, mlc, brn, area)

rm(allsaf, allsaf_fids)



# Map SAF code to JAC item numbers ----------------------------------------


# Translate codes to June items based on translation table (this will probably be updated every year)

aggregate1$code <- as.factor(aggregate1$code)
newcodetrans21$code <- as.factor(newcodetrans21$code)

cens_coded <- merge(aggregate1, newcodetrans, by = "code", all.x = TRUE)

unmatched_codes <-
  cens_coded [!aggregate1$code %in% cens_coded$code, ]

rm(newcodetrans, aggregate1)

allsaf <- as_tibble(allsaf)



# Produces item185 for item 41 (item41 is Unspecified Crops Total Area). Item185 will specify the crops.


extra_ncode <- cens_coded %>%
  select(parish, holding, cens_code, code)

extra_ncode$item185 <- ""

extra_ncode <- extra_ncode %>%
  group_by(parish, holding) %>%
  mutate(
    item185 =
      ifelse(row_number() == 1, "a", "")
  )


# Some of these will probably change yearly - if so, update othercropscodes in Functions script.

extra_ncode <- extra_ncode %>%
  group_by(parish, holding) %>%
  othercropscodes()

extra_ncode <- extra_ncode %>%
  group_by(parish, holding) %>%
  ncode()

extra_ncode$item185 [is.na(extra_ncode$item185)] <- ""



# Group by parish and holding. item185 consists of multiple strings concatenated - should change this to include semicolon (if collapse=";" it ends up with lots of unwanted semicolons!)

extra_item185 <- extra_ncode %>%
  group_by(parish, holding) %>%
  summarise(item185 = paste(item185, collapse = "")) %>% 
  mutate(
    parish = as.numeric(parish),
    holding = as.numeric(holding)
  )




# Group by SLC

census_format <- cens_coded %>%
  group_by(parish, holding, cens_code) %>%
  censusformat()


# Extra fields to fold in later

extra_fields <- census_format %>%
  group_by(parish, holding) %>%
  extrafields()


#brns dataset


brns <- allsaf %>%
  select(parish, holding, brn, mlc, area) %>%
  brnmutate() %>%  
  group_by(parish, holding, brn) %>%
  brnsummary() %>% 
  group_by(parish, holding) %>% 
  summarise_all(unique) # distinct doesn't work here, why?



# Reformat dataset --------------------------------------------------------


# Change dataset from long to wide

cens_wide <- census_format %>%
  select(parish, holding, cens_code, area) %>% 
  group_by(parish, holding) %>%
  pivot_wider(names_from = cens_code, values_from = area)



# Check where these items are in the JAC

order <-
  c(
    "parish",
    "holding",
    "item2321",
    "item2322",
    "item2828",
    "item9999",
    "item2469",
    "item2470",
    "item3156",
    "item47",
    "item20",
    "item16",
    "item14",
    "item19",
    "item41",
    "item70",
    "item48",
    "item18",
    "item2320",
    "item66",
    "item17",
    "item24",
    "item2827",
    "item34",
    "item29",
    "item32",
    "item49",
    "item31",
    "item30",
    "item28",
    "item52",
    "item1710",
    "item83",
    "item53",
    "item63",
    "item75",
    "item27",
    "item56",
    "item2858",
    "item82",
    "item80",
    "item2879",
    "item21",
    "item23",
    "item15",
    "item36",
    "item2059",
    "item2323",
    "item64",
    "item71",
    "item72",
    "item2859",
    "item2324",
    "item1709",
    "item2860",
    "item65",
    "item60",
    "item59",
    "item2832",
    "item61",
    "item2034",
    "item2861",
    "item55",
    "item81",
    "item2707",
    "item22",
    "item2863",
    "item2864",
    "item2865"
  )





orderdf <- order[order %in% colnames(cens_wide)]

cens_wide <- setDT(cens_wide)
cens_wide <- setcolorder(cens_wide, as.character(orderdf))



# add column not in dataset and reorder to include

addtodf <- order[!order %in% colnames(cens_wide)]

cens_wide[, addtodf] <- NA

cens_wide <- setcolorder(cens_wide, as.character(order))

# Convert any missing values, NULL, NA, to zeroes

cens_wide[cens_wide == "NULL"] <- 0

cens_wide[is.na(cens_wide)] <- 0



# Rename column created from unmatched codes (NA)

cens_wide <- cens_wide %>%
  rename_at("NA", ~"unmatched")


cens_wide<-data.frame(cens_wide) %>% 
  mutate_all(
    unlist(as.character)
  ) %>% 
  mutate_if(is.character, as.numeric) %>% 
  filter(!parish < 1 | !holding < 1)



# Prepare dfs for creating final SAF dataset

extra_fields <- extra_fields %>%
  select(parish, holding, lfass_area, llo_area) %>% 
  mutate(
    parish=as.numeric(parish),
    holding=as.numeric(holding)
  )

# remove leading zeroes

brns <- brns %>%
  select(parish, holding, brn, mlc) %>% 
  mutate(
    parish= as.numeric(sub("^0+", "", parish)),
    holding= as.numeric(sub("^0+", "", holding)),
  )


list<-list(cens_wide,extra_fields,extra_item185,brns)

cens_wide_final<-list %>% reduce(left_join, by = c("parish","holding"))



cens_wide_final <- cens_wide_final %>%
  newitemssaf()  # check this function works.




# Check what order the variables should be in - does it matter.

cens_wide_final[cens_wide_final == "NULL"] <- 0
cens_wide_final[is.na(cens_wide_final)] <- 0

# Remove any stray duplicates.

cens_wide_dups <- cens_wide_final[!duplicated(cens_wide_final[, 1:2]), ]



# Note: decide what checks to add here. e.g. SAS code checks if item50 exists (total land) and is > 0 in any cases. Item50 is not in the dataset.

# Save to datashare

save(cens_wide_final, file = paste0(Code_directory, "/allsaf_final_B1.rda"))

# Save to ADM server