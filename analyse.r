#!/usr/bin/Rscript
library('tidyverse')
library('ggplot2')
library('tikzDevice')
library('xtable')
library('lemon')
library('knitr')
library('scales')

# Read input data
# For timeouts, "States" field is set to -1
input <- read_delim('results.csv', delim=";", col_names=FALSE, trim_ws=TRUE)
colnames(input) <- c("Model","Method", "Workers", "Time", "States")

# Derive Order (-rbs or -rf) from Model name and add as column
input_rf1 <- input %>% filter(grepl("-rf$", Model)) %>% mutate(Model = str_replace(Model, "-rf$", ""))
input_rf2 <- input %>% filter(grepl("^rf-", Method)) %>% mutate(Method = str_replace(Method, "^rf-", ""))
input_rf <- bind_rows(input_rf1, input_rf2)
input_rf$Order <- "rf"
input_rbs <- input %>% filter(!grepl("-rf$", Model)) %>% filter(!grepl("^rf-", Method))
input_rbs$Order <- "rbs"
input <- bind_rows(input_rf, input_rbs)

# Rename "ldd-par" to "ldd-bfs" (because it is parallel BFS)
input <- input %>% mutate(Method = str_replace(Method, "ldd-par", "ldd-bfs"))

# Add "Id" column
input <- input %>% mutate(Id = paste(Model, Order, Method, Workers, sep = "-"))

# Split into <times> and <timeouts> and remove timeouts for which we have times
times <- input %>% filter(States != -1) %>% select(Id, Model, Order, Method, Workers, Time)
timeouts <- input %>% filter(!Id %in% (times %>% distinct(Id))$Id) %>% select(Id, Model, Order, Method, Workers, Time)

# Compute median/mean/sd for times, and highest timeout for timeouts
times <- times %>% group_by(Id, Model, Order, Method, Workers) %>% summarize(MedianTime = median(Time), MeanTime = mean(Time), sd = sd(Time)) %>% ungroup
timeouts <- timeouts %>% group_by(Id, Model, Order, Method, Workers) %>% summarize(Timeout = max(Time)) %>% ungroup

# Compute Model-Order that are solved (or timeout) by all Method-Worker combinations
times_s <- times %>% mutate(MW = paste(Method, Workers)) %>% select(MW, Model, Order, Time=MedianTime)
timeouts_s <- timeouts %>% mutate(MW = paste(Method, Workers)) %>% select(MW, Model, Order, Time=Timeout)
MODone <- bind_rows(times_s, timeouts_s) %>% spread(MW, Time) %>% drop_na() %>% select(Model, Order) %>% mutate(MO = paste(Model, Order)) %>% pull(MO)

# Compute Model-Order that are solved before timeout by all Method-Worker combinations
MOAll <- times %>% mutate(MW = paste(Method, Workers)) %>% select(MW, Model, Order, MedianTime) %>% spread(MW, MedianTime) %>% drop_na() %>% mutate(MO = paste(Model, Order)) %>% pull(MO)
MOLong1 <- times %>% filter(MedianTime>=1) %>% mutate(MW = paste(Method, Workers)) %>% select(MW, Model, Order, MedianTime) %>% spread(MW, MedianTime) %>% drop_na() %>% mutate(MO = paste(Model, Order)) %>% pull(MO)
MOLong2 <- times %>% filter(MedianTime>=1 | Workers!=1) %>% mutate(MW = paste(Method, Workers)) %>% select(MW, Model, Order, MedianTime) %>% spread(MW, MedianTime) %>% drop_na() %>% mutate(MO = paste(Model, Order)) %>% pull(MO)

# Now only keep the times/timeouts for which we have results of all Method-Worker combinations
times <- times %>% mutate(MO = paste(Model, Order)) %>% filter(MO %in% MODone) %>% select(-MO)
timeouts <- timeouts %>% mutate(MO = paste(Model, Order)) %>% filter(MO %in% MODone) %>% select(-MO)
times_s <- times %>% mutate(MW = paste(Method, Workers)) %>% select(MW, Model, Order, Time=MedianTime)
timeouts_s <- timeouts %>% mutate(MW = paste(Method, Workers)) %>% select(MW, Model, Order, Time=Timeout)

MOResultByLDDandMDD <- bind_rows(times_s, timeouts_s) %>% filter(MW == "ldd-sat 1" | MW == "mdd-sat 1") %>% spread(MW, Time) %>% drop_na() %>% select(Model, Order) %>% mutate(MO = paste(Model, Order)) %>% pull(MO)
MODoneByLDDandMDD <- times_s %>% filter(MW == "ldd-sat 1" | MW == "mdd-sat 1") %>% spread(MW, Time) %>% drop_na() %>% select(Model, Order) %>% mutate(MO = paste(Model, Order)) %>% pull(MO)

# Get speedups of ALL times (using mean)
# times -> select mean -> spread -> remove rows without `1` -> compute speedups -> sort descending by speedup with 16 workers
Speedups <- times %>% select(Model,Order,Method,Workers,MeanTime) %>% spread(Workers,MeanTime) %>% filter(!is.na(`1`)) %>% mutate(s1=`1`/`1`, s2=`1`/`2`, s4=`1`/`4`, s8=`1`/`8`, s16 = `1`/`16`) %>% arrange(desc(s16))
SK <- Speedups %>% select(Method, s2, s4, s8, s16) %>% gather(Key, Speedup, -Method) %>% mutate(Key = as.integer(str_replace(Key, "^s","")))

# Compute timesAll all times in MOAll
timesDone <- times %>% mutate(MO = paste(Model, Order)) %>% filter(MO %in% MODone) %>% select(-MO)
timesResultByLDDandMDD <- times %>% mutate(MO = paste(Model, Order)) %>% filter(MO %in% MOResultByLDDandMDD) %>% select(-MO)
timesDoneByLDDandMDD <- times %>% mutate(MO = paste(Model, Order)) %>% filter(MO %in% MODoneByLDDandMDD) %>% select(-MO)
timesAll <- times %>% mutate(MO = paste(Model, Order)) %>% filter(MO %in% MOAll) %>% select(-MO)

###
# Time to print results
###

SloanModelCount <- bind_rows(times,timeouts) %>% filter(Order=="rbs") %>% summarize(ModelCount=n_distinct(Model)) %>% pull(ModelCount)
ForceModelCount <- bind_rows(times,timeouts) %>% filter(Order=="rf") %>% summarize(ModelCount=n_distinct(Model)) %>% pull(ModelCount)
sprintf("There are %d models with the Force variable ordering.", ForceModelCount)
sprintf("There are %d models with the Sloan variable ordering.", SloanModelCount)
sprintf("Given 20 minutes, Sylvan/LDD finishes %d Force models (with 1 core), Meddly finishes %d models.", times_s %>% filter(MW=="ldd-sat 1" & Order=="rf") %>% nrow(), times_s %>% filter(MW=="mdd-sat 1" & Order=="rf") %>% nrow())
sprintf("Given 20 minutes, Sylvan/LDD finishes %d Sloan models (with 1 core), Meddly finishes %d models.", times_s %>% filter(MW=="ldd-sat 1" & Order=="rbs") %>% nrow(), times_s %>% filter(MW=="mdd-sat 1" & Order=="rbs") %>% nrow())

# Print summary sums...
# timesDone %>% group_by(Method, Order, Workers) %>% summarize(SumMedianTime = sum(MedianTime), sumMeanTime = sum(MeanTime), CountSolved = n_distinct(Model)) %>% print(n=Inf)
# timesAll %>% group_by(Method, Order, Workers) %>% summarize(SumMedianTime = sum(MedianTime), SumMeanTime = sum(MeanTime), CountSolved = n_distinct(Model)) %>% print(n=Inf)
timesSummary <- timesAll %>% group_by(Method, Order, Workers) %>% summarize(SumMeanTime = sum(MeanTime)) %>% group_by(Method, Order) %>% spread(Workers, SumMeanTime) %>% mutate(s1=`1`/`1`, s2=`1`/`2`, s4=`1`/`4`, s8=`1`/`8`, s16 = `1`/`16`) %>% ungroup() %>% mutate(Order=str_replace(Order, "rbs", "Sloan")) %>% mutate(Order=str_replace(Order,"rf", "Force"))
kable(timesSummary %>% select(-s1), format="latex", booktabs=TRUE, digits=c(0,0,0,0,0,0,0,1,1,1,1))

timesTHING1 <- times %>% filter(MeanTime > 0) %>% select(Model, Order, Method, Workers, Time=MeanTime) %>% spread(Workers, Time) %>% drop_na() %>% gather(Workers, Time, -Model, -Order, -Method) %>% group_by(Method, Order, Workers) %>% spread(Workers, Time) %>% mutate(s2=`1`/`2`, s4=`1`/`4`, s8=`1`/`8`, s16 = `1`/`16`) %>% drop_na() %>% summarize(s2=mean(s2),s4=mean(s4),s8=mean(s8),s16=mean(s16))
timesTHING2 <- times %>% filter((Workers != 1 | MeanTime >= 1) & MeanTime > 0) %>% select(Model, Order, Method, Workers, Time=MeanTime) %>% spread(Workers, Time) %>% drop_na() %>% gather(Workers, Time, -Model, -Order, -Method) %>% group_by(Method, Order, Workers) %>% spread(Workers, Time) %>% mutate(s2=`1`/`2`, s4=`1`/`4`, s8=`1`/`8`, s16 = `1`/`16`) %>% drop_na() %>% summarize(t2=mean(s2),t4=mean(s4),t8=mean(s8),t16=mean(s16))
kable(timesTHING1 %>% left_join(timesTHING2) %>% ungroup() %>% mutate(Order=str_replace(Order, "rbs", "Sloan")) %>% mutate(Order=str_replace(Order, "rf", "Force")), format="latex", booktabs=TRUE, digits=c(0,0,1,1,1,1,1,1,1,1))

# times %>% select(Model, Order, Method, Workers, Time=MeanTime) %>% spread(Workers, Time) %>% drop_na() %>% gather(Workers, Time, -Model, -Order, -Method) %>% group_by(Method, Order, Workers) %>% spread(Workers, Time) %>% mutate(s2=`1`/`2`, s4=`1`/`4`, s8=`1`/`8`, s16 = `1`/`16`) %>% summarize(`1`=sum(`1`),`2`=sum(`2`),`4`=sum(`4`),`8`=sum(`8`),`16`=sum(`16`),s2=mean(s2),s4=mean(s4),s8=mean(s8),s16=mean(s16)) %>% mutate(t2=`1`/`2`,t4=`1`/`4`,t8=`1`/`8`,t16=`1`/`16`) %>% select(Method, Order, s2, s4, s8, s16, t2, t4, t8, t16))

# kable(times %>% filter(Workers != 1 | MeanTime >= 1) %>% select(Model, Order, Method, Workers, Time=MeanTime) %>% spread(Workers, Time) %>% drop_na() %>% gather(Workers, Time, -Model, -Order, -Method) %>% group_by(Method, Order, Workers) %>% spread(Workers, Time) %>% mutate(s2=`1`/`2`, s4=`1`/`4`, s8=`1`/`8`, s16 = `1`/`16`) %>% summarize(`1`=sum(`1`),`2`=sum(`2`),`4`=sum(`4`),`8`=sum(`8`),`16`=sum(`16`),s2=mean(s2),s4=mean(s4),s8=mean(s8),s16=mean(s16),count=n_distinct(Model)) %>% mutate(t2=`1`/`2`,t4=`1`/`4`,t8=`1`/`8`,t16=`1`/`16`) %>% select(Method, Order, s2, s4, s8, s16, t2, t4, t8, t16, count), digits=c(0,0,1,1,1,1,1,1,1,1,0), format="latex", booktabs=TRUE)

# kable(times %>% filter(Workers != 1 | MeanTime >= 1) %>% select(Model, Order, Method, Workers, Time=MeanTime) %>% spread(Workers, Time) %>% drop_na() %>% gather(Workers, Time, -Model, -Order, -Method) %>% group_by(Method, Order, Workers) %>% spread(Workers, Time) %>% mutate(s2=`1`/`2`, s4=`1`/`4`, s8=`1`/`8`, s16 = `1`/`16`) %>% summarize(`1`=sum(`1`),`2`=sum(`2`),`4`=sum(`4`),`8`=sum(`8`),`16`=sum(`16`),s2=mean(s2),s4=mean(s4),s8=mean(s8),s16=mean(s16),count=n_distinct(Model)) %>% mutate(t2=`1`/`2`,t4=`1`/`4`,t8=`1`/`8`,t16=`1`/`16`) %>% select(Method, Order, s2, s4, s8, s16, t2, t4, t8, t16))

# kable(times %>% filter(MeanTime != 0) %>% select(Model, Order, Method, Workers, Time=MeanTime) %>% spread(Workers, Time) %>% drop_na() %>% gather(Workers, Time, -Model, -Order, -Method) %>% group_by(Method, Order, Workers) %>% spread(Workers, Time) %>% mutate(s2=`1`/`2`, s4=`1`/`4`, s8=`1`/`8`, s16 = `1`/`16`) %>% summarize(`1`=sum(`1`),`2`=sum(`2`),`4`=sum(`4`),`8`=sum(`8`),`16`=sum(`16`),s2=mean(s2),s4=mean(s4),s8=mean(s8),s16=mean(s16)) %>% mutate(t2=`1`/`2`,t4=`1`/`4`,t8=`1`/`8`,t16=`1`/`16`) %>% select(Method, Order, s2, s4, s8, s16, t2, t4, t8, t16))

timesSummary <- timesAll %>% group_by(Method, Order, Workers) %>% summarize(SumMeanTime = sum(MeanTime)) %>% group_by(Method, Order) %>% spread(Workers, SumMeanTime) %>% mutate(s1=`1`/`1`, s2=`1`/`2`, s4=`1`/`4`, s8=`1`/`8`, s16 = `1`/`16`)
kable(timesSummary %>% select(-s1), format="latex", booktabs=TRUE, digits=c(0,0,0,0,0,0,0,2,2,2,2))


# Print number of solved models with any / 1 worker
# a <- timesDone %>% group_by(Method, Order) %>% summarize(Count = n_distinct(Model))
# c <- timesDone %>% filter(Workers == 1) %>% group_by(Method, Order) %>% summarize(Count1 = n_distinct(Model))
# left_join(left_join(a, c), bind_rows(times_s, timeouts_s) %>% group_by(Order) %>% summarize(Max = n_distinct(Model)))
solvedSummary <- times %>% group_by(Method, Order, Workers) %>% summarize(Count = n_distinct(Model)) %>% spread(Workers, Count) %>% left_join(times %>% group_by(Method, Order) %>% summarize(Any = n_distinct(Model))) %>% left_join(bind_rows(times_s, timeouts_s) %>% group_by(Order) %>% summarize(Max = n_distinct(Model)))
kable(solvedSummary, format="latex", booktabs=TRUE)

# Now without distinguishing Order
solvedMO <- times %>% mutate(MO=paste(Model,Order)) %>% select(MO,Method,Workers)
solvedMOSummary <- solvedMO %>% group_by(Method, Workers) %>% summarize(Count = n_distinct(MO)) %>% spread(Workers, Count) %>% left_join(solvedMO %>% group_by(Method) %>% summarize(Any = n_distinct(MO)))
kable(solvedMOSummary, format="latex", booktabs=TRUE)


# The same but now only LDD-1 and MDD
timesDoneByLDDandMDD %>% group_by(Method, Order, Workers) %>% summarize(SumTime = sum(MeanTime), CountSolved = n_distinct(Model)) %>% filter(Method=="ldd-sat"|Method=="mdd-sat") %>% print(n=Inf)

# Print number of solved models with 1 worker
# b <- timesDone %>% group_by(Method) %>% summarize(Count = n_distinct(Model))
# d <- timesDone %>% filter(Workers == 1) %>% group_by(Method) %>% summarize(Count1 = n_distinct(Model))
# left_join(b, d)

# kable(head(Speedups, n=20))
# kable(Speedups)

# kable(head(Speedups %>% filter(Model == "BridgeAndVehicles-PT-V20P10N20"), n=20))
# kable(head(Speedups %>% filter(Model == "SmallOperatingSystem-PT-MT0128DC0064"), n=Inf))
# kable(head(Speedups %>% filter(Model == "CloudDeployment-PT-7a"), n=Inf))
# kable(head(Speedups %>% filter(Model == "Dekker-PT-015"), n=Inf))

plotLDDSat <- ggplot(
    Speedups %>% filter(Method == "ldd-sat") %>% select(Model,Order,`2`=s2,`4`=s4,`8`=s8,`16`=s16) %>% gather(Workers, Speedup, -Model, -Order) %>% mutate(Workers = as.numeric(Workers)),
    aes(x=factor(Workers), y=Speedup)) +
    geom_violin(alpha=0.2) +
    theme_bw() + theme(legend.position="none") +
    coord_cartesian(ylim=c(0,8)) +
    scale_y_continuous(breaks=seq(0,20,by=1), name="Speedup") + 
    scale_x_discrete(name="Number of workers")

plotLDDChaining <- ggplot(
    Speedups %>% filter(Method == "ldd-chaining") %>% select(Model,Order,`2`=s2,`4`=s4,`8`=s8,`16`=s16) %>% gather(Workers, Speedup, -Model, -Order) %>% mutate(Workers = as.numeric(Workers)),
    aes(x=factor(Workers), y=Speedup)) +
    geom_violin(alpha=0.2) +
    theme_bw() + theme(legend.position="none") +
    coord_cartesian(ylim=c(0,8)) +
    scale_y_continuous(breaks=seq(0,20,by=1), name="Speedup") + 
    scale_x_discrete(name="Number of workers")

plotLDDPar <- ggplot(
    Speedups %>% filter(Method == "ldd-bfs") %>% select(Model,Order,`2`=s2,`4`=s4,`8`=s8,`16`=s16) %>% gather(Workers, Speedup, -Model, -Order) %>% mutate(Workers = as.numeric(Workers)),
    aes(x=factor(Workers), y=Speedup)) +
    geom_violin(alpha=0.2) +
    theme_bw() + theme(legend.position="none") +
    coord_cartesian(ylim=c(0,8)) +
    scale_y_continuous(breaks=seq(0,20,by=1), name="Speedup") + 
    scale_x_discrete(name="Number of workers")


# Make the TIKZs
MakeTIKZ = function(s,t) {
    tikz(s, width=6, height=3, standAlone=F)
    print(t)
    graphics.off()
}


MakeTIKZ("plot-ldd-sat.tex", plotLDDSat)
MakeTIKZ("plot-ldd-chaining.tex", plotLDDChaining)
MakeTIKZ("plot-ldd-bfs.tex", plotLDDPar)

###
# Make a scatter plot for ldd-sat, Time1 v Speedup16
###
LDDSAT_Time1_Speedup16 <- times %>% filter(Method == "ldd-sat") %>% select(Model, Order, Workers, Time=MeanTime) %>% spread(Workers, Time) %>% mutate(Speedup=`16`/`1`) %>% select(Time=`1`,Speedup) %>% drop_na()
LDDSAT_Time1_Speedup16plot <- ggplot(LDDSAT_Time1_Speedup16, aes(Time, Speedup)) + geom_point(size=0.5) + scale_x_log10(name="Time with 1 worker (sec)", breaks = trans_breaks("log10", function(x) 10^x, n=4)) + scale_y_continuous(name="Speedup with 16 workers") + theme_bw()
MakeTIKZ("plot-ldd-sat-time1-speedup16.tex", LDDSAT_Time1_Speedup16plot)

###
# Make a scatter plot for ldd-sat Time1 v mdd-sat Time1
###
LDDSAT1_MDDSAT1 <- times %>% filter(Workers == 1) %>% filter(Method == "ldd-sat" | Method == "mdd-sat") %>% select(Model, Order, Method, Time=MeanTime) %>% spread(Method, Time) %>% select(lddsat=`ldd-sat`, mddsat=`mdd-sat`) %>% drop_na()
LDDSAT1_MDDSAT1plot <-
    ggplot(LDDSAT1_MDDSAT1, aes(y=lddsat, x=mddsat)) +
    geom_point(size=0.5) +
    geom_abline(slope=1,intercept=0,linetype="dashed") +
    geom_abline(slope=1,intercept=1,linetype="dashed") +
    geom_abline(slope=1,intercept=-1,linetype="dashed") +
    scale_x_log10(name="Time with Meddly MDDs (sec)", limits=c(0.0001,1200)) +
    scale_y_log10(name="Time with Sylvan LDDs (sec)", limits=c(0.001,1200)) + 
    theme_bw()
MakeTIKZ("plot-ldd-sat-mdd-sat.tex", LDDSAT1_MDDSAT1plot)

png("plot-ldd-sat-mdd-sat.png", width=1000, height=1000, res=100)
print(LDDSAT1_MDDSAT1plot)
graphics.off()

quit()


plotS2 <- ggplot(Speedups %>% filter(Method == "ldd-sat"), aes(x=Method, y=s2, color=Method, fill=Method)) + geom_violin(alpha=0.2) + coord_cartesian(ylim=c(0,15)) + theme(legend.position="none") + scale_y_continuous(breaks=seq(0, 16, by=1))

plotS2 <- ggplot(Speedups %>% filter(Method != "mdd-sat"), aes(x=Method, y=s2, color=Method, fill=Method)) + geom_violin(alpha=0.2) + coord_cartesian(ylim=c(0,15)) + theme(legend.position="none") + scale_y_continuous(breaks=seq(0, 16, by=1))
plotS4 <- ggplot(Speedups, aes(x=Method, y=s4, color=Method, fill=Method)) + geom_violin(alpha=0.2) + coord_cartesian(ylim=c(0,15)) + theme(legend.position="none") + scale_y_continuous(breaks=seq(0, 16, by=1))
plotS8 <- ggplot(Speedups, aes(x=Method, y=s8, color=Method, fill=Method)) + geom_violin(alpha=0.2) + coord_cartesian(ylim=c(0,15)) + theme(legend.position="none") + scale_y_continuous(breaks=seq(0, 16, by=1))
plotS16 <- ggplot(Speedups, aes(x=Method, y=s16, color=Method, fill=Method)) + geom_violin(alpha=0.2) + coord_cartesian(ylim=c(0,15)) + theme(legend.position="none") + scale_y_continuous(breaks=seq(0, 16, by=1))

png("speedups2.png", width=1000, height=1000, res=100)
# print(p + geom_jitter(height=0, width=0.1, color=1, size=0.5))
print(plotS2)
graphics.off()

png("speedups4.png", width=1000, height=1000, res=100)
# print(p + geom_jitter(height=0, width=0.1, color=1, size=0.5))
print(plotS4)
graphics.off()

png("speedups8.png", width=1000, height=1000, res=100)
# print(p + geom_jitter(height=0, width=0.1, color=1, size=0.5))
print(plotS8)
graphics.off()

png("speedups16.png", width=1000, height=1000, res=100)
# print(p + geom_jitter(height=0, width=0.1, color=1, size=0.5))
print(plotS16)
graphics.off()

MakeTIKZ("plotS2.tex", plotS2)
MakeTIKZ("plotS4.tex", plotS4)
MakeTIKZ("plotS8.tex", plotS8)
MakeTIKZ("plotS16.tex", plotS16)



quit()


# 
# times %>% group_by(Method, Order, Workers) %>% summarize(SumMedianTime = sum(MedianTime), CountSolved = n_distinct(Model)) %>% print(n=Inf)
# obs <- times %>% mutate(MW = paste(Method, Workers, sep="-")) %>% select(MW, Model, Order, MedianTime) %>% spread(MW, MedianTime) %>% drop_na()
# mdd_sat_solves <- times %>% filter(Method == "mdd-sat") %>% distinct(Model, Order)
# ldd_sat_solves <- times %>% filter(Method == "ldd-sat") %>% distinct(Model, Order)
                                                                                                        # timesMW <- times %>% mutate(MW = paste(Method, Workers, sep="-"))
# MOAll <- timesMW %>% select(MW, Model, Order, MedianTime) %>% spread(MW, MedianTime) %>% drop_na() %>% gather(MW, MedianTime, -Model, -Order) %>% select(Model, Order



# Remove orrtl and rrtl from input set (not optimized for performance)
# input <- filter(input, ! Solver %in% c("orrtl","rrtl"))

# Restrict to input that required actual solving
input <- filter(input, Solving != 0)

# We are only interested in solving
solving <- select(input, c("Model","Solver","Solving"))

# Compute timeouts
solvingTO <- solving
solvingTO$Timeout <- 0
solvingTO <- solvingTO %>% complete(Model, Solver, fill=list(Solving=timeout,Timeout=1))

# Create table relating models and sets
ModelSet <- input %>% count(Model, Set) %>% group_by(Model,Set) %>% slice(which.max(n)) %>% select(Model,Set)
solving <- left_join(solving, ModelSet)
solvingTO <- left_join(solvingTO, ModelSet)

# Generate tables from solvingTO
Summ <- function(df) {
    df %>% group_by(Solver) %>% summarize(Solving=sum(Solving),Timeout=sum(Timeout))
}

#summ_mc <- Summ(filter(solvingTO, Set == "modelchecking"))
#summ_eq <- Summ(filter(solvingTO, Set == "equivchecking"))
summ_r2 <- Summ(filter(solvingTO, Set == "random2"))
summ_s <- Summ(filter(solvingTO, Set == "synt"))
summ_mceq <- Summ(filter(solvingTO, Set %in% c("modelchecking","equivchecking")))
summ_all <- Summ(solvingTO)

together <- summ_mceq %>% 
                left_join(.,summ_s,by="Solver") %>% 
                left_join(.,summ_r2,by="Solver") %>% 
                left_join(.,summ_all,by="Solver")

colnames(together) <- c("Solver", "MC&EQ", "MC&EQ T/O", "Synt", "Synt T/O", "Rnd", "Rnd T/O", "Total", "Total T/O")

# PRINT TIBBLE TO STDOUT
options(width=150)
together %>% arrange(`Total`) %>% print(., width=Inf)

# WRITE SUMMARY (sorted by MC&EQ)
print(xtable(together %>% arrange(`MC&EQ`), digits=c(0)), tabular.environment="tabu", file="summary.tex", booktabs=TRUE, only.contents=TRUE, include.rownames = FALSE, include.colnames=FALSE, hline.after=NULL)

# WRITE SUMMARY (sorted by Total)
print(xtable(together %>% arrange(`Total`), digits=c(0)), tabular.environment="tabu", file="summary_total.tex", booktabs=TRUE, only.contents=TRUE,include.rownames = FALSE,include.colnames=FALSE,hline.after=NULL)




# Helper function to make a cactus plot
# Results in fields Model, Solver, Solving, Sort
Cactify <- function(s, slvr) {
    s <- select(filter(s, Solver == slvr), c("Model","Solver","Solving"))
    s <- arrange(s, Solving)
    s$Sort <- 1:nrow(s)
    s
}

# Helper function that creates the plots...
CactusPlot <- function(s) {
    slvrs <- unique(s$Solver)
    data <- s %>% group_by(Solver) %>% do(Cactify(.,.$Solver))
    ggplot(data, aes(y=Solving,x=Sort,color=Solver,shape=Solver)) +
        geom_point(size=3) + geom_line() +
        scale_shape_manual(values=1:length(slvrs)) + 
        scale_y_continuous(name="Time (sec)") +
        scale_x_continuous(name="Number of games") +
        theme_bw(base_size=16)
}

# Create the cactus plots
cac_all <- CactusPlot(solving) + coord_cartesian(ylim=c(0,750),xlim=c(400,700))
cac_mceq <- CactusPlot(solving %>% filter(Set %in% c("modelchecking","equivchecking"))) + coord_cartesian(ylim=c(0,500),xlim=c(180,320))
cac_s <- CactusPlot(solving %>% filter(Set == "synt")) + coord_cartesian(ylim=c(0,500),xlim=c(120,220))
cac_rn2 <- CactusPlot(solving %>% filter(Set == "random2")) + coord_cartesian(ylim=c(0,500))

# Make the PNGs
MakePNG <- function(s,t) {
    png(s, width=2000, height=1000, res=100)
    print(t)
    graphics.off()
}

if (TRUE) {
    MakePNG("oink_mceq.png", cac_mceq)
    MakePNG("oink_rn2.png", cac_rn2)
    MakePNG("oink_s.png", cac_s)
    MakePNG("oink_all.png", cac_all)
}

# Make the TIKZs
MakeTIKZ = function(s,t) {
    tikz(s, width=8, height=3, standAlone=F)
    print(t)
    graphics.off()
}

MakeTIKZ("oink_all.tex", cac_all)
MakeTIKZ("oink_mceq.tex", cac_mceq)
MakeTIKZ("oink_s.tex", cac_s)
MakeTIKZ("oink_rn2.tex", cac_rn2)

# Now some special magic to merge mc_eq and rn2 in one plot
library("gtable")
library("grid")
g1 <- ggplotGrob(cac_mceq + scale_x_continuous(name="Number of MC\\&EC games"))
g2 <- ggplotGrob(cac_rn2 + scale_x_continuous(name="Number of large random games"))
g <- rbind(g1, g2, size="first") # stack the two plots
g$widths <- unit.pmax(g1$widths, g2$widths) # use the largest widths
# find legends
idxs <- which(grepl("guide", g$layout$name))
# remove legend of top graph
g$grobs[idxs[1]][[1]] <- zeroGrob()
# center the other legend vertically
g$layout[idxs[2],c("t","b")] <- c(1,nrow(g))

png("oink_both.png", width=2000, height=2000, res=100)
grid.draw(g)
graphics.off()

tikz("oink_both.tex", width=8, height=6, standAlone=F)
grid.draw(g)
graphics.off()

