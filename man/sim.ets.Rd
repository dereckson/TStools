\name{sim.ets}
\alias{sim.ets}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Simulate Exponential Smoothing
}
\description{
Function generates data using ETS with Single Source of Error as a data generating process.
}
\usage{
sim.ets(model="ANN",seas.freq=1,
             persistence=NULL, phi=1,
             initial=NULL, initial.season=NULL,
             bounds=c("both","usual","admissible"),
             obs=10, nseries=1,
             randomizer=c("rnorm","runif","rbeta","rt"),
             ...)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{model}{
  type of ETS model according to [Hyndman et. al., 2008] taxonomy.
}
  \item{seas.freq}{
  the frequency of the data. In the case of seasonal models must be greater than 1.
}
  \item{persistence}{
  the persistence vector, that includes all the smoothing parameters. Must correspond to the chosen model. The maximum length is 3: level, trend and seasonal smoothing parameters. If \code{NULL}, all the values will be taken at random.
}
  \item{phi}{
  the value of damping parameter. If trend is not chosen in the model, the parameter is ignored.
}
  \item{initial}{
  the vector of initial states of level and trend. The maximum length is 2. If \code{NULL}, all the values will be taken at random.
}
  \item{initial.season}{
  the vector of initial states for seasonal coefficients. Should correspond to the \code{seas.freq} parameter If \code{NULL}, all the values will be taken at random.
}
  \item{bounds}{
  the type of bounds to use for the persistence vector. NOT IMPLEMENTED YET.
}
  \item{obs}{
  the number of observations in each generated time series.
}
  \item{nseries}{
  the number of series to generate.
}
  \item{randomizer}{
  the type of the random number generator function. The defaults are: \code{rnorm}, \code{rt}, \code{runif}, \code{rbeta}. But any function from \link[stats]{Distributions} will do the trick if the appropriate parameters are passed. For example \code{rpois} with \code{lambda=2} can be used.
}
  \item{...}{
  additional parameters passed to the chosen randomizer. All the parameters should be passed in the order they are used in the chosen function. For example, passing \code{sd=0.5} to \code{rnorm} function will lead to the call \code{rnorm(obs, mean=0.5, sd=1)}.
  ATTENTION! When generating the multiplicative errors some tuning might be needed to obtain the meaningful data.
}
}
\details{
%%  ~~ If necessary, more details than the description above ~~
}
\value{
The list of the following values is returned:
  \item{data}{The ts vector of the generated series.}
  \item{states}{The states matrix. States are in columns, time is in rows. Also includes error term in the last column.}
  \item{persistence}{The vector of smoothing parameters used in the simulation.}

}
\references{
Hyndman, R.J., Koehler, A.B., Ord, J.K., and Snyder, R.D. (2008) Forecasting with exponential smoothing: the state space approach, Springer-Verlag. \url{http://www.exponentialsmoothing.net}.
}
\author{
Ivan Svetunkov, \email{ivan@svetunkov.ru}
}

\seealso{
\code{\link[forecast]{ets}, \link[forecast]{forecast}, \link[stats]{ts}, \link[stats]{Distributions}}
}
\examples{
# Create 40 observations of quarterly data using AAA model with errors from normal distribution
sim.ets(model="AAA",seas.freq=4,obs=40,randomizer="rnorm",mean=0,sd=100)-> ETS.AAA

# Create 50 series of quarterly data using AAA model with 40 observations eachwith errors from normal distribution
sim.ets(model="AAA",seas.freq=4,obs=40,randomizer="rnorm",mean=0,sd=100,nseries=50)-> ETS.AAA

# Create 60 observations of monthly data using ANN model with errors from beta distribution
sim.ets(model="ANN",persistence=c(1.5),seas.freq=12,obs=60,randomizer="rbeta",sshape1=1.5,sshape2=1.5)-> ETS.ANN
plot(ETS.ANN$states)

# Create 60 observations of monthly data using MAM model with errors from uniform distribution
sim.ets(model="MAM",persistence=c(0.3,0.2,0.1),initial=c(2000,50),phi=0.8,seas.freq=12,obs=60,randomizer="runif",min=-0.5,max=0.5)-> ETS.MAM

# Create 80 observations of quarterly data using MMM model with predefined initial values and errors from the normal distribution
sim.ets(model="MMM",persistence=c(0.1,0.1,0.1),initial=c(2000,1),initial.seas=c(1.1,1.05,0.9,.95),seas.freq=4,obs=80,mean=0,sd=0.01)-> ETS.MMM
}

\keyword{ exponential smoothing }
\keyword{ ETS }
\keyword{ forecasting }
\keyword{ simulation }