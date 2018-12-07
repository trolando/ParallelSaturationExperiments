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
input <- read_delim('results-simple.csv', delim=";", col_names=FALSE, trim_ws=TRUE)
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
# times -> select mean -> spread -> remove rows without `1` -> compute speedups -> sort descending by speedup with 4 workers
Speedups <- times %>% select(Model,Order,Method,Workers,MeanTime) %>% spread(Workers,MeanTime) %>% filter(!is.na(`1`)) %>% mutate(s1=`1`/`1`, s2=`1`/`2`, s4=`1`/`4`) %>% arrange(desc(s4))

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
cat(sprintf("There are %d models with the Force variable ordering.\n", ForceModelCount))
cat(sprintf("There are %d models with the Sloan variable ordering.\n", SloanModelCount))
cat(sprintf("Given 20 minutes, Sylvan/LDD finishes %d Force models (with 1 core), Meddly finishes %d models.\n", times_s %>% filter(MW=="ldd-sat 1" & Order=="rf") %>% nrow(), times_s %>% filter(MW=="mdd-sat 1" & Order=="rf") %>% nrow()))
cat(sprintf("Given 20 minutes, Sylvan/LDD finishes %d Sloan models (with 1 core), Meddly finishes %d models.\n", times_s %>% filter(MW=="ldd-sat 1" & Order=="rbs") %>% nrow(), times_s %>% filter(MW=="mdd-sat 1" & Order=="rbs") %>% nrow()))

# Print summary sums...
cat("Now follows the summary of times and speedups on the entire set.\n")

timesSummary <- timesAll %>% group_by(Method, Order, Workers) %>% summarize(SumMeanTime = sum(MeanTime)) %>% group_by(Method, Order) %>% spread(Workers, SumMeanTime) %>% mutate(s1=`1`/`1`, s2=`1`/`2`, s4=`1`/`4`) %>% ungroup() %>% mutate(Order=str_replace(Order, "rbs", "Sloan")) %>% mutate(Order=str_replace(Order,"rf", "Force"))
kable(timesSummary %>% select(-s1), format="latex", booktabs=TRUE, digits=c(0,0,0,0,0,0,0,1,1,1,1))

cat("Now follows the average speedup (s2/s4) and the average speedup for models taking more than 1 second (t2/t4).\n")

timesTHING1 <- times %>% filter(MeanTime > 0) %>% select(Model, Order, Method, Workers, Time=MeanTime) %>% spread(Workers, Time) %>% drop_na() %>% gather(Workers, Time, -Model, -Order, -Method) %>% group_by(Method, Order, Workers) %>% spread(Workers, Time) %>% mutate(s2=`1`/`2`, s4=`1`/`4`) %>% drop_na() %>% summarize(s2=mean(s2),s4=mean(s4))
timesTHING2 <- times %>% filter((Workers != 1 | MeanTime >= 1) & MeanTime > 0) %>% select(Model, Order, Method, Workers, Time=MeanTime) %>% spread(Workers, Time) %>% drop_na() %>% gather(Workers, Time, -Model, -Order, -Method) %>% group_by(Method, Order, Workers) %>% spread(Workers, Time) %>% mutate(s2=`1`/`2`, s4=`1`/`4`) %>% drop_na() %>% summarize(t2=mean(s2),t4=mean(s4))
kable(timesTHING1 %>% left_join(timesTHING2) %>% ungroup() %>% mutate(Order=str_replace(Order, "rbs", "Sloan")) %>% mutate(Order=str_replace(Order, "rf", "Force")), format="latex", booktabs=TRUE, digits=c(0,0,1,1,1,1,1,1,1,1))

# Print number of solved models with any / 1 worker
cat("Now follows the table that summarizes the number of solved models, for Force/Sloan seperately.\n")

solvedSummary <- times %>% group_by(Method, Order, Workers) %>% summarize(Count = n_distinct(Model)) %>% spread(Workers, Count) %>% left_join(times %>% group_by(Method, Order) %>% summarize(Any = n_distinct(Model))) %>% left_join(bind_rows(times_s, timeouts_s) %>% group_by(Order) %>% summarize(Max = n_distinct(Model)))
kable(solvedSummary, format="latex", booktabs=TRUE)

# Now without distinguishing Order
cat("Now follows the number of solved models where Force/Sloan are not distinguished.\n")
solvedMO <- times %>% mutate(MO=paste(Model,Order)) %>% select(MO,Method,Workers)
solvedMOSummary <- solvedMO %>% group_by(Method, Workers) %>% summarize(Count = n_distinct(MO)) %>% spread(Workers, Count) %>% left_join(solvedMO %>% group_by(Method) %>% summarize(Any = n_distinct(MO)))
kable(solvedMOSummary, format="latex", booktabs=TRUE)

cat("Now follows the top 20 speedups with ldd-sat\n")

kable(head(Speedups %>% filter(Method == "ldd-sat"), n=Inf))

# Helper function to make the TIKZs
MakeTIKZ = function(s,t) {
    tikz(s, width=6, height=3, standAlone=F)
    print(t)
    graphics.off()
}

###
# "violin" speedup plots
###

plotLDDSat <- ggplot(
    Speedups %>% filter(Method == "ldd-sat") %>% select(Model,Order,`2`=s2,`4`=s4) %>% gather(Workers, Speedup, -Model, -Order) %>% mutate(Workers = as.numeric(Workers)),
    aes(x=factor(Workers), y=Speedup)) +
    geom_violin(alpha=0.2) +
    theme_bw() + theme(legend.position="none") +
    coord_cartesian(ylim=c(0,8)) +
    scale_y_continuous(breaks=seq(0,20,by=1), name="Speedup") + 
    scale_x_discrete(name="Number of workers")

plotLDDChaining <- ggplot(
    Speedups %>% filter(Method == "ldd-chaining") %>% select(Model,Order,`2`=s2,`4`=s4) %>% gather(Workers, Speedup, -Model, -Order) %>% mutate(Workers = as.numeric(Workers)),
    aes(x=factor(Workers), y=Speedup)) +
    geom_violin(alpha=0.2) +
    theme_bw() + theme(legend.position="none") +
    coord_cartesian(ylim=c(0,8)) +
    scale_y_continuous(breaks=seq(0,20,by=1), name="Speedup") + 
    scale_x_discrete(name="Number of workers")

plotLDDPar <- ggplot(
    Speedups %>% filter(Method == "ldd-bfs") %>% select(Model,Order,`2`=s2,`4`=s4) %>% gather(Workers, Speedup, -Model, -Order) %>% mutate(Workers = as.numeric(Workers)),
    aes(x=factor(Workers), y=Speedup)) +
    geom_violin(alpha=0.2) +
    theme_bw() + theme(legend.position="none") +
    coord_cartesian(ylim=c(0,8)) +
    scale_y_continuous(breaks=seq(0,20,by=1), name="Speedup") + 
    scale_x_discrete(name="Number of workers")


MakeTIKZ("plot-ldd-sat.tex", plotLDDSat)
MakeTIKZ("plot-ldd-chaining.tex", plotLDDChaining)
MakeTIKZ("plot-ldd-bfs.tex", plotLDDPar)

###
# Make a scatter plot for ldd-sat, Time1 v Speedup4
###

LDDSAT_Time1_Speedup4 <- times %>% filter(Method == "ldd-sat") %>% select(Model, Order, Workers, Time=MeanTime) %>% spread(Workers, Time) %>% mutate(Speedup=`4`/`1`) %>% select(Time=`1`,Speedup) %>% drop_na()
LDDSAT_Time1_Speedup4plot <- ggplot(LDDSAT_Time1_Speedup4, aes(Time, Speedup)) + geom_point(size=0.5) + scale_x_log10(name="Time with 1 worker (sec)", breaks = trans_breaks("log10", function(x) 10^x, n=4)) + scale_y_continuous(name="Speedup with 4 workers") + theme_bw()
MakeTIKZ("plot-ldd-sat-time1-speedup4.tex", LDDSAT_Time1_Speedup4plot)

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
