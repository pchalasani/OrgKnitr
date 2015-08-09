## Placebo analysis

Here is a formulation that captures some aspects of what Jaynth  was suggesting: we want to compute the conversions estimate for the test population, using the control population to look up "instantaneous" conversation rates at each bid level $b$. We treat it as an *integration* and *curve-fitting* problem.

Notation: we use subscript $t$ to refer to *test* population, and subscript $c$ to refer to *control* population.

### Baseline conversions estimate as an integral

Say the test bid distribution is represented by the bid density $f_t(b)$, so the number of impressions in the bid-price range $[b, b+db]$ is $f_t(b)db$. To compute the *estimated* baseline conversions, we need to know  what the conversion rate is for impressions in the control group at bid level $b$ (we see below why this is not exactly what we want, but ignore that for now): we denote this by $R_c(b)$; this is an "instantaneous" conversion rate at bid $b$. Then the baseline estimated number of conversions for the test population is given by the integral:
$$\int_b f_t(b) R_c(b) db.$$

In practice the integral would be implemented by partitioning the test bid-price range into equal intervals of size $\Delta b$, and we replace $f_t(b) db$ by $N_t(b, b+\Delta b)$, the number of test impressions in bid-range $[b, b+ \Delta b]$, resulting in a baseline conversions estimate of

$$ \sum_b N_t(b, b + \Delta b) R_c(b).$$

Instead of equal intervals of size $\Delta b$ we could choose equal-frequency intervals (i.e each bid-interval has roughly same number of impressions), with the constraint that each interval has at least $m_t$ impressions.

### Estimating $R_c(b)$ using bid-price windows

To estimate $R_c(b)$ for a specific $b$, we look up in the control population a bid-price window of size $w$ centered at $b$.  Note that $w$ will in general depend on $b$:  we could stipulate that $w$ needs to be wide enough to contain a sufficient number of *conversions* to get a reliable estimate. At the same time $w$ should not be "too large."  

Once we fix a window of size $w$ around $b$, we compute the control-group conversion rate estimate as 
$$ R_c(b) = \frac{C_c(b-w/2, b+w/2)}{N_c(b-w/2, b+w/2)}$$
where $C_c(a,b)$ and $N_c(a,b)$ are the number of conversions and impressions respectively, in the bid-range $[a,b]$. 

### Estimating $R_c(b)$ using curve-fitting/regression

A better way to think of the $R_c(b)$ estimation problem is to treat it as a *curve fitting* problem: find a curve $R_c(b)$ that is most consistent with the winning-bid conversion data, subject to *smoothness and monotonicity(?)* constraints.  This is also a *probabilistic classification* problem: if we let the binary random variable $Y$ be 1 if the impression leads to conversion, and 0 otherwise, then $R_c(b)$ is the conditional probability of $Y=1$ given that the bid is $b$: $R_c(b) = P(Y = 1|b)$.
A simple special case is a *logistic regression model*:  
$$
R_c(b) = \frac{1}{1 + e^{-z}} ; \;\;
z = c + ab,
$$
where $a,c$ are the coefficients that need to be fit. Specifically, suppose we have a data-set of pairs $(b_i, y_i)$, where $b_i$ are the control-group impression bids, and $y_i$ are the conversion-indicators (0 or 1). For a given pair of coefficients $a,c$, the *predicted conversion rate* $y'(b_i)$ for the impression with bid $b_i$ is given by 
$$
y'(b_i) = \frac{1}{1 + e^{-c - ab_i}}.
$$
Note that the actual conversion indicator is $y_i \in \{0,1\}$, so the *loss* (or error) is given by
$$
L(y_i, y'_i) = -y_i \log(y'_i) - (1 - y_i) \log( 1 - y'_i )
$$
The goal in the logistic regression is to find coefficients $a,c$ such that total log-loss 
$$
\sum_i L(y_i, y'_i)
$$ 
is minimized.

This is easy to fit using R (or with Spark/MLLib on Hadoop):

```r
# simulate bids, conversions data
bids <- sort(runif(100000,0,1))  
convs <- 1*(runif(100000,0,1) < 0.5 * bids)
    
df <- data.frame(bid = bids, conv = convs)
mdl <- glm(convs ~ bids , family = binomial(link = 'logit'))
summary(mdl)
```

Besides logistic regression, other functional forms of $R_c(b)$ can be used. 

### Bias due to auction (win-bias)

In the above, when computing the baseline estimate for the number of conversions we used the quantity $R_c(b)$, which is the conversion rate of the control impressions at bid $b$. However this is not quite right: in the test population we are looking at impressions at bid $b$ *that were won by the advertiser*; so to get at the true lift, we really need to know the conversion rate of the b-bid control impressions that *would have been won* by the advertiser had they participated in the auction.

To illustrate this further, say for simplicity all impressions have identical bids B, so we don’t have to worry about the bid-distribution matching issue. Now say 10% of these are logged as control, and of the 90% that are designated for test, say only 10% of those actually win the bid, and those are the ones ultimately exposed to the ad -- this is the so-called *treated test population*. The very fact that we are only including the winning impressions in the test leads to a bias, I.e. The control population has *all* impressions at bid B, but the test population has only the winning impressions at bid B. Intuitively the winning impressions will tend to be the ones that are “less competitive” and of  lower conversion-rate. So this bias alone would very likely lead to an underestimate of lift, or even a negative lift. 

To make this a bit more precise we can borrow from the literature on estimating treatment effect in the presence of *non-compliance*, i.e. not all observations *assigned* to be treated actually *receive* treatment -- analogous to how only some of the impressions assigned to test are actually exposed to the ad.  For example  [Imbens/Rubin][1], [Balke/Pearl][2] study this issue in the statistics literature, and [Barajas et al][3] apply these ideas to campaign evaluation in the context of RTB/Display Advertising.

Following this literature,  define these binary random variables:  

- $Z_i$ = 0 if impression $i$ **assigned** to control, 1 if test.
- $D_i$ = 1 if impression $i$ **wins** the bid, 0 otherwise.
- $Y_i$ = 1 if impression $i$ leads to a **conversion** ("responded"),  0 otherwise.

For brevity we write $Z_{i1}$  to indicate $Z_i = 1$, $Z_{i0}$ to indicate $Z_i = 0$, and similarly for the other variables. We drop the subscript $i$ below, and simply use $Z_1, Z_0$, etc. Note:

- the combination $Z_1,D_1$ refers to impressions that were designated for test, *and* resulted in a winning bid, i.e. were exposed to an ad. This is observable.
- the combination $Z_0, D_1$ refers to impressions that were designated for control, *and would have been won* by the advertiser, if the impressions participated in the auction. This subset of the $Z_0$ population is *not observable* because there is no actual bidding for these impressions.

Our methodology currently looks at the difference of response-rates between *treated test* impressions and *control* impressions, which we call our *lift estimate:*
$$\hat{L} = E(Y | Z_1, D_1) - E(Y | Z_0),$$
but this is not quite the lift we would like to calculate.

Rewriting this  a bit we see that the lift estimate $\hat{L}$ is a sum of two components:
$$
\begin{align}
\hat{L} = &[ E(Y | Z_1, D_1) - E(Y | Z_0, D_1) ]  + \\
	            & [ E(Y | Z_0, D_1) - E(Y | Z_0) ] \\ 
     = & L_{true} + \text{winBias}
\end{align}    
 $$

The term $L_{true}$ is the *true lift* which we would like to measure but cannot directly measure: the difference between the expected conversions of exposed test impressions and the expected conversions of control impressions that *would have been exposed*. (I'm abusing terminology here a bit since is actual a relative measure so we need to divide by the baseline conversions, but let's ignore that for now.)

The  *win bias* is the difference between expected conversions of control impressions that *would have been exposed*, and the expected conversions of the control impressions overall. The intuition is that the control impressions that *would have been won* by the advertiser would tend to be of lower competitiveness/quality compared to the overall population of control impressions, hence the second term will typically be negative. 

We'd like a methodology which gets as close to $L_{true}$ as possible. When the win bias is severely negative, this can result in a severe under-estimate of the true lift, or even negative lift.


### Lift estimation from observational data

An entirely different way to estimate lift from purely observational data (i.e. avoiding placebos and randomized experiments) is presented in [Stitelman et al][5].

----------




[1]: http://www.biostat.jhsph.edu/~dscharf/Causal/imbens-rubin-1997.pdf  "G. W. Imbens and D. B. Rubin. Bayesian Inference for Causal Effects in Randomized Experiments with Noncompliance. The Annals of Statistics, 25(1):305–327, 1997."

[2]: http://ftp.cs.ucla.edu/pub/stat_ser/r199-jasa.pdf "A. Balke and J. Pearl. Bounds on treatment effects from studies with imperfect compliance. Journal of the American Statistical Association, 92:1171–1176, 1997."

[3]: http://wan.poly.edu/KDD2012/forms/workshop/ADKDD12/doc/a7.pdf "Barajas et al: Marketing Campaign Evaluation in Targeted Display Advertising."

[4]: http://yuan-shuai.info/paper/KDD-2014-optimal-real-time-bidding.pdf "Zhang, Yuan, Wang: Optimal Real-Time Bidding for Display Advertising"

[5]: http://dstillery.com/wp-content/uploads/2014/05/EstimatingEffect_OnlineAdvertising.pdf "Stitelman et al: Estimating the effect of Online Display Advertising on Browser Conversion"

[6]: http://www-stat.wharton.upenn.edu/~buja/PAPERS/paper-proper-scoring.pdf "Buja et al: Loss Functions for Binary Class Probability Estimation and Classification: Structure and Applications"
