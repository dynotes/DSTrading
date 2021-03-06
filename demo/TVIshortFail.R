require(DSTrading)
require(IKTrading)
require(quantstrat)

initDate="1990-01-01"
from="2003-01-01"
to="2010-12-31"

#to rerun the strategy, rerun everything below this line
source("demoData.R") #contains all of the data-related boilerplate.

#trade sizing and initial equity settings
tradeSize <- -10000
initEq <- -tradeSize*length(symbols)

strategy.st <- portfolio.st <- account.st <- "TVI_short"
rm.strat(portfolio.st)
rm.strat(strategy.st)
initPortf(portfolio.st, symbols=symbols, initDate=initDate, currency='USD')
initAcct(account.st, portfolios=portfolio.st, initDate=initDate, currency='USD',initEq=initEq)
initOrders(portfolio.st, initDate=initDate)
strategy(strategy.st, store=TRUE)

#parameters (trigger lag unchanged, defaulted at 1)
delta=0
period=20
pctATR=.02 #control risk with this parameter

#indicators
add.indicator(strategy.st, name="TVI", arguments=list(x=quote(Cl(mktdata)), period=period, delta=delta), label="TVI")
add.indicator(strategy.st, name="lagATR", arguments=list(HLC=quote(HLC(mktdata)), n=period), label="atrX")

#signals
add.signal(strategy.st, name="sigThreshold", 
           arguments=list(threshold=-1, column="vigor.TVI", relationship="lte", cross=FALSE),
           label="TVIltThresh")
add.signal(strategy.st, name="sigComparison",
           arguments=list(columns=c("vigor.TVI","trigger.TVI"), relationship="lt"),
           label="TVIltLag")
add.signal(strategy.st, name="sigAND",
           arguments=list(columns=c("TVIltThresh","TVIltLag"), cross=TRUE),
           label="shortEntry")
add.signal(strategy.st, name="sigCrossover",
           arguments=list(columns=c("vigor.TVI","trigger.TVI"), relationship="gt"),
           label="shortExit")

#rules
add.rule(strategy.st, name="ruleSignal", 
         arguments=list(sigcol="shortEntry", sigval=TRUE, ordertype="market", 
                        orderside="short", replace=FALSE, prefer="Open", osFUN=osDollarATR,
                        tradeSize=tradeSize, pctATR=pctATR, atrMod="X"), 
         type="enter", path.dep=TRUE)
add.rule(strategy.st, name="ruleSignal", 
         arguments=list(sigcol="shortExit", sigval=TRUE, orderqty="all", ordertype="market", 
                        orderside="short", replace=FALSE, prefer="Open"), 
         type="exit", path.dep=TRUE)


#apply strategy
t1 <- Sys.time()
out <- applyStrategy(strategy=strategy.st,portfolios=portfolio.st)
t2 <- Sys.time()
print(t2-t1)


#set up analytics
updatePortf(portfolio.st)
dateRange <- time(getPortfolio(portfolio.st)$summary)[-1]
updateAcct(portfolio.st,dateRange)
updateEndEq(account.st)

#tradeStats
tStats <- tradeStats(Portfolios = portfolio.st, use="trades", inclZeroDays=FALSE)
tStats[,4:ncol(tStats)] <- round(tStats[,4:ncol(tStats)], 2)
print(data.frame(t(tStats[,-c(1,2)])))
(aggPF <- sum(tStats$Gross.Profits)/-sum(tStats$Gross.Losses))
(numTrades <- sum(tStats$Num.Trades))
(aggCorrect <- sum(tStats$Num.Trades*tStats$Percent.Positive/100)/numTrades)
(meanAvgWLR <- mean(tStats$Avg.WinLoss.Ratio))

#dailyStats
dStats <- dailyStats(Portfolios = portfolio.st, use="Equity")
rownames(dStats) <- gsub(".DailyEndEq","", rownames(dStats))
print(data.frame(t(dStats)))

#portfolio cash PL
portPL <- .blotter$portfolio.TVI_short$summary$Net.Trading.PL

#Cash Sharpe
(SharpeRatio.annualized(portPL, geometric=FALSE))

#Portfolio comparisons to SPY
instRets <- PortfReturns(account.st)

#Correlations
instCors <- cor(instRets)
diag(instRets) <- NA
corMeans <- rowMeans(instCors, na.rm=TRUE)
names(corMeans) <- gsub(".DailyEndEq", "", names(corMeans))
print(round(corMeans,3))
mean(corMeans)

portfRets <- xts(rowMeans(instRets)*ncol(instRets), order.by=index(instRets))
portfRets <- portfRets[!is.na(portfRets)]
cumPortfRets <- cumprod(1+portfRets)
firstNonZeroDay <- as.character(index(portfRets)[min(which(portfRets!=0))])
getSymbols("SPY", from=firstNonZeroDay, to=to)
SPYrets <- diff(log(Cl(SPY)))[-1]
cumSPYrets <- cumprod(1+SPYrets)
comparison <- cbind(cumPortfRets, cumSPYrets)
colnames(comparison)  <- c("strategy", "SPY")
chart.TimeSeries(comparison, legend.loc = "topleft", 
                 main=paste0("Period=", period, ", Delta=",delta), colors=c("green","red"))

SharpeRatio.annualized(portfRets)
Return.annualized(portfRets)
maxDrawdown(portfRets)

#Sharpe, Returns, max DD
SharpeRatio.annualized(portfRets)
Return.annualized(portfRets)
maxDrawdown(portfRets)

#Individual instrument equity curve
chart.Posn(portfolio.st, "XLB")
#The triggerLag is NOT 30 for the strategy, just amplified in this case to illustrate exit logic.
#The actual trigger lag is defaulted at 1.
tmp <- TVI(Cl(XLB), period=period, delta=delta, triggerLag=1)
add_TA(tmp$vigor, lwd=3)
add_TA(tmp$trigger, on=5, col="red", lwd=1.5)
tmp2 <- lagATR(HLC=HLC(XLB), n=period)
add_TA(tmp2$atr, col="blue", lwd=2)

