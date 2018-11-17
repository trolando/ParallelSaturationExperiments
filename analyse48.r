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
input <- read_delim('results48.csv', delim=";", col_names=FALSE, trim_ws=TRUE)
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

# Now only keep the times/timeouts for which we have results of all Method-Worker combinations
times <- times %>% mutate(MO = paste(Model, Order)) %>% filter(MO %in% MODone) %>% select(-MO)
timeouts <- timeouts %>% mutate(MO = paste(Model, Order)) %>% filter(MO %in% MODone) %>% select(-MO)
times_s <- times %>% mutate(MW = paste(Method, Workers)) %>% select(MW, Model, Order, Time=MedianTime)
timeouts_s <- timeouts %>% mutate(MW = paste(Method, Workers)) %>% select(MW, Model, Order, Time=Timeout)

kable(times %>% select(Model, Order, Method, Workers, Time=MeanTime) %>% spread(Workers, Time) %>% drop_na() %>% mutate(S8=`1`/`8`,S16=`1`/`16`,S24=`1`/`24`,S32=`1`/`32`,S40=`1`/`40`,S48=`1`/`48`) %>% arrange(Method), digits=1, format="latex", booktabs=TRUE)

kable(times %>% select(Model, Order, Method, Workers, Time=MeanTime) %>% spread(Workers, Time) %>% drop_na() %>% mutate(S8=`1`/`8`,S16=`1`/`16`,S24=`1`/`24`,S32=`1`/`32`,S40=`1`/`40`,S48=`1`/`48`) %>% arrange(Method, -S48) %>% select(Model,Order,Method,`1`,`24`,`48`,S24,S48), digits=1, format="latex", booktabs=TRUE)

lddsat <- times %>% filter(Method=="ldd-sat") %>% select(Model, Order, Method, Workers, Time=MeanTime) %>% spread(Workers, Time) %>% drop_na() %>% mutate(S1=`1`/`1`,S8=`1`/`8`,S16=`1`/`16`,S24=`1`/`24`,S32=`1`/`32`,S40=`1`/`40`,S48=`1`/`48`) %>% drop_na() %>% mutate(Id=paste(Model, Order)) %>% select(Id, `1`=S1, `8`=S8,`16`=S16,`24`=S24,`32`=S32,`40`=S40,`48`=S48) %>% gather(Workers, Speedup, -Id) %>% mutate(Workers=as.numeric(Workers))
lddsatplot <-
    ggplot(lddsat, aes(x=Workers,y=Speedup,group=Id)) +
    geom_line() +
    scale_x_continuous(breaks=c(1,8,16,24,32,40,48)) +
    scale_y_continuous(breaks=c(0,1,5,8,10,15,20,25,30)) +
    theme_bw()

tikz("lddsatspeedupplot.tex", width=6, height=3, standAlone=F)
print(lddsatplot)
graphics.off()
