## Set up R
setwd("~/R/TeamRoulette")

## MODE FUNCTION
getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

## DISTANCE FUNCTION
dist <- function(pool){
  p <- nrow(pool)
  dm <- data.frame(matrix(NA, p, p))
  colnames(dm) <- pool$Team.ID
  rownames(dm) <- pool$Team.ID
  
  if (p>1){
    for (i in 1:(p-1)){
      for (j in (i+1):p){
        dm[i, j] <- abs(pool$Case.Experience[i] - pool$Case.Experience[j]) +
          abs(pool$Case.Result[i] - pool$Case.Result[j])
        
        if(pool$Members.Count[i] + pool$Members.Count[j] > 4) {dm[i, j] <- NA}
      }
    }
  }
  dm
}

## GLUE FUNCTION
glue <- function(pool, dm){
  m <- min(dm, na.rm = TRUE)
  indi <- which(dm == m, arr.ind = TRUE)[1, 1]
  indj <- which(dm == m, arr.ind = TRUE)[1, 2]
  nm <- pool$Members.Count[indi]
  
  for (j in 1:pool$Members.Count[indj]){
    pool[indi, 2+nm+j] <- pool[indj, 2+j]
  }
  pool$Members.Count[indi] <- pool$Members.Count[indi] + pool$Members.Count[indj]
  pool$Members.Count[indj] <- 0
  pool$Case.Experience[indj] <- NA
  pool$Case.Result[indj] <- NA
  
  pool
}


## Import data
# source('Trim.R')
data <- read.csv('data.csv', stringsAsFactors = FALSE, encoding = 'UTF-8')
#data <- data[, -1]

## Clean up the data
data <- subset(data, Status == 'Complete')
data <- data[data$Cap.Name != '????????',]
data <- data[data$Cap.Name != '????????',]
data <- data[data$Cap.Name != 'test',]
data <- data[data$Cap.Name != 'Test',]

dpl <- unique(data$Cap.Email[duplicated(data$Cap.Email)])

for (i in 1:length(dpl)){
  d <- data$Response.ID[data$Cap.Email == dpl[i]]
    exclude <- d[d != max(d)]
    for (j in 1:length(exclude)){
      data <- subset(data, Response.ID != exclude[j])
    }
}

## Correct variables
colnames(data)[32] <- 'Team.TR'
colnames(data)[19] <- 'IP.City'
data$Team.TR <- data$Team.TR == ''

## Convert dataset into long form
ind.cap <- (1:ncol(data))[substr(colnames(data), 1, 3) == "Cap"]
ind.team <- (1:ncol(data))[substr(colnames(data), 1, 3) == "Tea"]
ind.mem1 <- (1:ncol(data))[substr(colnames(data), 1, 7) == "Member1"]
ind.mem2 <- (1:ncol(data))[substr(colnames(data), 1, 7) == "Member2"]
ind.mem3 <- (1:ncol(data))[substr(colnames(data), 1, 7) == "Member3"]
ind.mem4 <- (1:ncol(data))[substr(colnames(data), 1, 7) == "Member4"]
ind.tech <- 1:(min(ind.cap)-1)

vars <- colnames(data[,c(ind.tech, ind.cap, ind.team)])
vars <- c(vars, substr(colnames(data[,ind.mem1]), 9, max(nchar(colnames(data)))))

data.mem1 <- data[, c(ind.tech, ind.cap, ind.team, ind.mem1)]
data.mem2 <- data[, c(ind.tech, ind.cap, ind.team, ind.mem2)]
data.mem3 <- data[, c(ind.tech, ind.cap, ind.team, ind.mem3)]
data.mem4 <- data[, c(ind.tech, ind.cap, ind.team, ind.mem4)]
colnames(data.mem1) <- vars
colnames(data.mem2) <- vars
colnames(data.mem3) <- vars
colnames(data.mem4) <- vars

data.long <- rbind(data.mem1, data.mem2, data.mem3, data.mem4)

## Cleaning and oredering the long data
data.tidy <- data.long[data.long$Surname != '', ]
data.ordered <- data.tidy[order(data.tidy$Response.ID),]

## DECIDE WHAT TO DO WITH DUPLICATED PARTICIPANTS FROM ONE TEAM
dpl <- data.ordered$Email[duplicated(data.ordered$Email)]

for(i in 1:length(dpl)){
  dpl[i]
  d <- data.ordered$Response.ID[data.ordered$Email == dpl[i]]
  if (length(unique(d))>1){
    exclude <- d[d != max(d)]
    data.ordered<- data.ordered[data.ordered$Response.ID != exclude,]
  }
}

write.csv(data.ordered, 'ordered.csv')


## Identifing teams
teams <- data.frame(Cap.Email = unique(data.ordered$Cap.Email))
teams$Members.Count <- c(0)
teams$Member1 <- c('')
teams$Member2 <- c('')
teams$Member3 <- c('')
teams$Member4 <- c('')

for (i in 1:length(teams$Cap.Email)){
  teams$Team.ID[i] <- i
  data.ordered$Team.ID[data.ordered$Cap.Email == teams$Cap.Email[i]] <- i
  members <- data.ordered$Email[data.ordered$Cap.Email == teams$Cap.Email[i]]
  teams$Members.Count[i] <- length(members)
  data.ordered$Members.Count[data.ordered$Cap.Email == teams$Cap.Email[i]] <- length(members)
  for (j in 1:length(members)){
    teams[i, 2+j] <- members[j]
  }
}


## Identifing Team Roulette needs
data.ordered$TR.Need <- data.ordered$Team.TR
data.ordered$TR.Need[data.ordered$Members.Count == 4] <- FALSE


data.ft <- data.ordered[!data.ordered$TR.Need,]
data.tr <- data.ordered[data.ordered$TR.Need,]

teamlist.tr <- unique(data.tr$Team.ID)
teams$TR.Need <- FALSE
for (i in teamlist.tr){
  teams$TR.Need[teams$Team.ID == i] <- TRUE
}


teams.ft <- teams[!teams$TR.Need,]
teams.tr <- teams[teams$TR.Need,]
teams.init <- teams[teams$TR.Need,]

## Getting work database ready

wdb <- data.frame(Team.ID = data.tr$Team.ID, stringsAsFactors = FALSE)
wdb$Team.Section <- factor(data.tr$Team.Section,
                              levels = c(''))
wdb$Members.Count <- as.integer(data.tr$Members.Count)
wdb$Email <- as.character(data.tr$Email)
wdb$City <- as.character(data.tr$City)
wdb$City[wdb$City == '????????????'] <- data.tr$City.Other[data.tr$City == '????????????']
wdb$Uni <- as.character(data.tr$Uni)
wdb$Uni[wdb$Uni == '???????? ?????? ?? ????????????'] <- data.tr$Uni.Other[data.tr$Uni == '???????? ?????? ?? ????????????']
wdb$Case.Experience <- factor(data.tr$Case.Experience,
                              levels = c("", "???? ????????????????????", "1 ??????", "2-3 ????????", "???????????? 3 ??????"))
wdb$Case.Result <- factor(data.tr$Case.Result,
                          levels = c("", "????????????????", "High Quality 25 %", "High Quality 15 %",
                                     "????????????????????????", "????????????????", "???????????? (2-3 ??????????)", "???????????????????? (1 ??????????)"))

## TeamRoulette
### Teams Matrix
for (i in teams.tr$Team.ID){
  teams.tr$Team.Section[teams.tr$Team.ID == i] <- getmode(wdb$Team.Section[wdb$Team.ID == i])
  teams.tr$City[teams.tr$Team.ID == i] <- getmode(wdb$City[wdb$Team.ID == i])
  teams.tr$Uni[teams.tr$Team.ID == i] <- getmode(wdb$Uni[wdb$Team.ID == i])
  teams.tr$Case.Experience[teams.tr$Team.ID == i] <- mean(as.integer(wdb$Case.Experience[wdb$Team.ID == i]))
  teams.tr$Case.Result[teams.tr$Team.ID == i] <- mean(as.integer(wdb$Case.Result[wdb$Team.ID == i]))
}

teams.tr <- teams.tr[order(teams.tr$Members.Count, decreasing = TRUE),]
if (length(unique(teams.tr$Team.Section)) == 1){teams.tr$Team.Section <- "No Section"}
### Unique values
sections <- unique(teams.tr$Team.Section)
cities <- unique(teams.tr$City)
institutions <- unique(teams.tr$Uni)

## Optimal distribution: Educational institution and Homesity match
for (s in 1:length(sections)){
  for (c in 1:length(cities)){
    for (i in 1:length(institutions)){
      pool <- subset(teams.tr, (City == cities[c])&(Uni == institutions[i])&(Team.Section == sections[s]))
      if (nrow(pool) > 1){
        n <- nrow(pool)*2
        for (j in 1:n){
          dm <- dist(pool)
          if (sum(!is.na(dm)) != 0){
            pool <- glue(pool, dm)
          } else {
              j <- n*2
          }
        }
        for (m in pool$Team.ID){
          teams.tr$Member1[teams.tr$Team.ID == m] <- pool$Member1[pool$Team.ID == m]
          teams.tr$Member2[teams.tr$Team.ID == m] <- pool$Member2[pool$Team.ID == m]
          teams.tr$Member3[teams.tr$Team.ID == m] <- pool$Member3[pool$Team.ID == m]
          teams.tr$Member4[teams.tr$Team.ID == m] <- pool$Member4[pool$Team.ID == m]
          
          teams.tr$Members.Count[teams.tr$Team.ID == m] <- pool$Members.Count[pool$Team.ID == m]
          teams.tr$Case.Experience[teams.tr$Team.ID == m] <- pool$Case.Experience[pool$Team.ID == m]
          teams.tr$Case.Result[teams.tr$Team.ID == m] <- pool$Case.Result[pool$Team.ID == m]
        }
      }
    }
  }
}
teams.tr <- teams.tr[teams.tr$Members.Count > 0,]

## Less quality: Homecity match
for (s in 1:length(sections)){
  for (c in 1:length(cities)){
    pool <- subset(teams.tr, (City == cities[c])&(Team.Section == sections[s]), Members.Count < 4)
    if (nrow(pool) > 1){
      n <- nrow(pool)*2
      for (j in 1:n){
        dm <- dist(pool)
        if (sum(!is.na(dm)) != 0){
          pool <- glue(pool, dm)
        } else {
          j <- n*2
        }
      }
      for (m in pool$Team.ID){
        teams.tr$Member1[teams.tr$Team.ID == m] <- pool$Member1[pool$Team.ID == m]
        teams.tr$Member2[teams.tr$Team.ID == m] <- pool$Member2[pool$Team.ID == m]
        teams.tr$Member3[teams.tr$Team.ID == m] <- pool$Member3[pool$Team.ID == m]
        teams.tr$Member4[teams.tr$Team.ID == m] <- pool$Member4[pool$Team.ID == m]
        
        teams.tr$Members.Count[teams.tr$Team.ID == m] <- pool$Members.Count[pool$Team.ID == m]
        teams.tr$Case.Experience[teams.tr$Team.ID == m] <- pool$Case.Experience[pool$Team.ID == m]
        teams.tr$Case.Result[teams.tr$Team.ID == m] <- pool$Case.Result[pool$Team.ID == m]
      }
    }
  }
}

teams.tr <- teams.tr[teams.tr$Members.Count > 0,]

# Lowest Quality: Different cities, different unies
for (s in 1:length(sections)){
  pool <- subset(teams.tr, Team.Section == sections[s], Members.Count < 4)
  if (nrow(pool) > 1){
    n <- nrow(pool)*2
    for (j in 1:n){
      dm <- dist(pool)
      if (sum(!is.na(dm)) != 0){
        pool <- glue(pool, dm)
      } else {
        j <- n*2
      }
    }
    for (m in pool$Team.ID){
      teams.tr$Member1[teams.tr$Team.ID == m] <- pool$Member1[pool$Team.ID == m]
      teams.tr$Member2[teams.tr$Team.ID == m] <- pool$Member2[pool$Team.ID == m]
      teams.tr$Member3[teams.tr$Team.ID == m] <- pool$Member3[pool$Team.ID == m]
      teams.tr$Member4[teams.tr$Team.ID == m] <- pool$Member4[pool$Team.ID == m]
      
      teams.tr$Members.Count[teams.tr$Team.ID == m] <- pool$Members.Count[pool$Team.ID == m]
      teams.tr$Case.Experience[teams.tr$Team.ID == m] <- pool$Case.Experience[pool$Team.ID == m]
      teams.tr$Case.Result[teams.tr$Team.ID == m] <- pool$Case.Result[pool$Team.ID == m]
    }
  }
}

teams.tr <- teams.tr[teams.tr$Members.Count > 0,]


## Rewriting members' teams
for (i in 1:nrow(teams.tr)){
  id <- teams.tr$Team.ID[i]
  for (j in 3:6){
    e <- teams.tr[i,j]
    mc <- teams.tr$Members.Count[i]
    data.tr$Team.ID[data.tr$Email == e] <- id
    data.tr$Members.Count[data.tr$Email == e] <- mc
  }
}

data.tr <- data.tr[order(data.tr$Team.ID),]

## Write Rouletted Data
data.rouletted <- rbind(data.ft, data.tr)
data.rouletted <- data.rouletted[order(data.rouletted$Team.ID),]

write.csv(data.rouletted, 'rouletted.csv')

