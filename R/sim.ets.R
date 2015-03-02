sim.ets <- function(model="ANN",seas.freq=1,
             persistence=NULL, phi=1,
             initial=NULL, initial.season=NULL,
             bounds=c("usual","both","admissible","restricted"),
             obs=10, nseries=1,
             randomizer=c("rnorm","runif","rbeta","rt"),
             ...){
# Function generates data using ETS with Single Source of Error as a data generating process.
#    Copyright (C) 2015  Ivan Svetunkov
    
    bounds <- bounds[1];
    randomizer <- randomizer[1];

    error.type <- substring(model,1,1);
    trend.type <- substring(model,2,2);
    season.type <- substring(model,3,3);

# In the case of wrong nseries, make it natural number. The same is for obs and seas.freq.
    nseries <- abs(round(nseries,0));
    obs <- abs(round(obs,0));
    seas.freq <- abs(round(seas.freq,0));

    if(!is.null(persistence) & length(persistence)>3){
        stop("The length of persistence vector is wrong! It should not be greater than 3.",call.=FALSE);
    }

    if(phi<0 | phi>2){
        stop("Damping parameter should lie in (0, 2) region.",call.=FALSE);
    }

r.value <- function(error.type, trend.type, season.type, xt){
# Function returns the value of r for the error term for the inclusion in transition equation depending on several parameters
    if(error.type=="A"){
# AZZ
        r <- 1;
        r <- rep(r,persistence.length);
        if(season.type=="N" & trend.type=="M"){
            r <- 1 / c(1,xt[1]);
        }
        else if(season.type=="A" & trend.type=="M"){
            r <- 1 / c(1,xt[1],1);
        }
        else if(season.type=="M"){
            if(trend.type=="N"){
                r <- 1 / c(xt[2],xt[1]);
            }
            else if(trend.type=="A"){
                r <- 1 / c(xt[3],xt[3],(mat.w[1:2] %*% xt[1:2]));
            }
            else {
                r <- 1 / c(xt[3],(xt[1] * xt[3]),(exp(mat.w[1:2] %*% log(xt[1:2]))))
            }
        }        
    }
    else{
        if(trend.type!="M" & season.type!="M"){
# MNN, MAN, MNA, MAA
                r <- mat.w %*% xt;
                r <- rep(r,persistence.length);
        }
        else if((trend.type=="M" | trend.type=="N") & (season.type=="M" | season.type=="N")){
# MNN, MMN, MNM, MMM
            r <- exp(mat.F %*% log(xt));
        }
        else if(trend.type=="A" & season.type=="M"){
# MAM
            r <- mat.w[1:2] %*% xt[1:2];
            r <- c(r,r,xt[3]);
        }
        else if(trend.type=="M" & season.type=="A"){
# MMA
            r <- exp(mat.w[1:2] %*% log(xt[1:2])) + xt[3];
            r <- c(r, r/xt[1], xt[3]);
        }
    }
    return(r)
}

ry.value <- function(error.type, trend.type, season.type, xt){
# Function returns the value of r for the error term for the inclusion in measurement equation, depending on several parameters
    if(error.type=="A"){
# AZZ
        r <- 1;
    }
    else{
        if(trend.type!="M" & season.type!="M"){
# MNN, MAN, MNA, MAA
                r <- mat.w %*% xt;
        }
        else if((trend.type=="M" | trend.type=="N") & (season.type=="M" | season.type=="N")){
# MNN, MMN, MNM, MMM
            r <- exp(mat.w %*% log(xt));
        }
        else if(trend.type=="A" & season.type=="M"){
# MAM
            r <- (mat.w[1:2] %*% xt[1:2]) * xt[3];
        }
        else if(trend.type=="M" & season.type=="A"){
# MMA
            r <- exp(mat.w[1:2] %*% log(xt[1:2])) + xt[3];
        }
    }
    return(r)
}

# Check the used model and estimate the length of needed persistence vector.
    if(error.type!="A" & error.type!="M"){
        stop("Wrong error type! Should be 'A' or 'M'.",call.=FALSE);
    }
    else{
# The number of the smoothing parameters needed
        persistence.length <- 1;
# The number initial values of the state vector
        n.components <- 1;
# The lag of components (needed for the seasonal models)
        lags <- 1;
# The names of the state vector components
        component.names <- "level";
        mat.w <- 1;
# The transition matrix
        mat.F <- matrix(1,1,1);
# The matrix used for the multiplicative error models. Should contain ^yt
        mat.r <- 1;
    }

# Check the trend type of the model
    if(trend.type!="N" & trend.type!="A" & trend.type!="M"){
        stop("Wrong trend type! Should be 'N', 'A' or 'M'.",call.=FALSE);
    }
    else if(trend.type!="N"){
        persistence.length <- persistence.length + 1;
        n.components <- n.components + 1;
        lags <- c(lags,1);
        component.names <- c(component.names,"trend");
        mat.w <- c(mat.w,phi);
        mat.F <- matrix(c(1,0,phi,phi),2,2);
        trend.component=TRUE;
    }
    else{
        trend.component=FALSE;
    }

# Check the seasonaity type of the model
    if(season.type!="N" & season.type!="A" & season.type!="M"){
        stop("Wrong seasonality type! Should be 'N', 'A' or 'M'.",call.=FALSE);
    }

    if(season.type!="N" & seas.freq==1){
        stop("Cannot create the seasonal model with the data seas.freq 1!",call.=FALSE);
    }

    if(season.type!="N"){
        persistence.length <- persistence.length + 1;
# model.freq is used in the cases of seasonal models.
#   if model.freq==1 then non-seasonal data will be produced with the defined seas.freq.
        model.freq <- seas.freq;
        lags <- c(lags,seas.freq);
        component.names <- c(component.names,"seasonality");
        mat.w <- c(mat.w,1);
        seasonal.component <- TRUE;

        if(trend.component==FALSE){
            mat.F <- matrix(c(1,0,0,1),2,2);
        }
        else{
            mat.F <- matrix(c(1,0,0,phi,1,0,0,0,1),3,3);
        }
    }
    else{
        seasonal.component <- FALSE;
        model.freq <- 1;
    }

# Create the matrix of state vectors
    mat.xt <- matrix(NA,nrow=obs,ncol=persistence.length);
    colnames(mat.xt) <- component.names;

# Check the persistence vector length
    if(!is.null(persistence)){
        if(persistence.length != length(persistence)){
            print("The length of persistence vector does not correspond to the chosen model!");
            print("Falling back to random number generator in... now!");
            persistence <- NULL;
        }
    }

# Check the inital vector length
    if(!is.null(initial)){
        if(length(initial)>2){
            stop("The length of the initial value is wrong! It should not be greater than 2.",call.=FALSE);
        }
        if(n.components!=length(initial)){
            print("The length of initial state vector does not correspond to the chosen model!");
            print("Falling back to random number generator in... now!");
            initial <- NULL;
        }
    }

    if(!is.null(initial.season)){
        if(model.freq!=length(initial.season)){
            print("The length of seasonal initial states does not correspond to the chosen frequency!");
            print("Falling back to random number generator in... now!");
            initial.season <- NULL;
        }
    }

# If the seasonal model is chosen, fill in the first "seas.freq" values of seasonal component.
    if(seasonal.component==TRUE & !is.null(initial.season)){
        mat.xt[1:seas.freq,(n.components+1)] <- initial.season;
    }

    if(nseries > 1){
# The array of the components
        arr.xt <- array(NA,c(obs,(persistence.length+1),nseries));
        dimnames(arr.xt)[[2]] <- c(component.names,"error");
# The matrix of the final data
        mat.yt <- matrix(NA,obs,nseries);
# The matrix of smoothing parameters
        mat.g <- matrix(NA,nseries,persistence.length)
        colnames(mat.g) <- c(component.names);

    cat("Series simulated:  ");
    }

# If the chosen randomizer is not rnorm, rt and runif and no parameters are provided, change to rnorm.
    if(randomizer!="rnorm" & randomizer!="rt" & randomizer!="runif" & (any(names(match.call(expand.dots=FALSE)[-1]) == "...")==FALSE)){
      warning(paste0("The chosen randomizer - ",randomizer," - needs some arbitrary parameters! Changing to 'rnorm' now."),call.=FALSE);
      randomizer = "rnorm";
    }

##### Start the loop #####
for(k in 1:nseries){

# If the persistence is NULL or was of the wrong length, generate the values
    if(is.null(persistence)){
# For the case of "usual" bounds make restrictions on the generated smoothing parameters so the ETS can be "averaging" model.
        if(bounds=="usual"){
            vec.g <- runif(persistence.length,0,1);
            if(persistence.length > 1){
                vec.g[2] <- runif(1,0,vec.g[1]);
                if(persistence.length==3){
                    vec.g[3] <- runif(1,0,max(0,1-vec.g[1]));
                }
            }
        }
        else if(bounds=="restricted"){
            vec.g <- runif(persistence.length,0,0.3);            
            if(persistence.length > 1){
                vec.g[2] <- runif(1,0,vec.g[1]);
                if(persistence.length==3){
                    vec.g[3] <- runif(1,0,max(0,1-vec.g[1]));
                }
            }
        }
        else{
            vec.g <- runif(persistence.length,0,1);
        }
    }
    else{
        vec.g <- persistence;
    }

# Generate initial stated of level and trend if they were not supplied
    if(is.null(initial)){
        if(trend.type=="N"){
            mat.xt[1,1] <- runif(1,0,1000);
        }
        else if(trend.type=="A"){
            mat.xt[1,1] <- runif(1,0,5000);
            mat.xt[1,2] <- runif(1,-100,100);
        }
        else{
            mat.xt[1,1] <- runif(1,500,5000);
            mat.xt[1,2] <- 1;
        }
    }
    else{
        mat.xt[1,1:n.components] <- initial;
    }

# Generate seasonal states if they were not supplied
    if(seasonal.component==TRUE & is.null(initial.season)){
# Create and normalize seasonal components. Use geometric mean for multiplicative case
        if(season.type == "A"){
            mat.xt[1:model.freq,n.components+1] <- runif(model.freq,-500,500);
            mat.xt[1:model.freq,n.components+1] <- mat.xt[1:model.freq,n.components+1] - mean(mat.xt[1:model.freq,n.components+1]);
        }
        else{
            mat.xt[1:model.freq,n.components+1] <- runif(model.freq,0.3,1.7);
            mat.xt[1:model.freq,n.components+1] <- mat.xt[1:model.freq,n.components+1] / exp(mean(log(mat.xt[1:model.freq,n.components+1])));
        }
    }

# Create vector for the series
    y <- rep(NA,obs);

# Check if any argument was passed in dots
    if(any(names(match.call(expand.dots=FALSE)[-1]) == "...")==FALSE){
# Create vector of the errors
        if(randomizer=="rnorm" | randomizer=="runif"){
          errors <- eval(parse(text=paste0(randomizer,"(n=",obs,")")));
        }
        else if(randomizer=="rt"){
# The degrees of freedom are df = n - k.
          errors <- rt(obs,obs-(persistence.length + model.freq));
        }

# Center errors just in case
        errors <- errors - mean(errors);
# Change variance to make some sense. Errors should not be rediculously high and not too low.
        errors <- errors * sqrt(abs(mat.xt[1,1]));
# If the error is multiplicative, scale it!
        if(error.type=="M" & max(abs(errors))>0.05){
            errors <- 0.05 * errors / max(abs(errors));
        }
    }
# If arguments are passed, use them.
    else{
        errors <- eval(parse(text=paste0(randomizer,"(n=",obs,",", toString(as.character(list(...))),")")));

        if(randomizer=="rbeta"){
# Center the errors around 0.5
          errors <- errors - 0.5;
# Make a meaningful variance of data. Something resembling to var=1.
          errors <- errors / sqrt(var(errors)) * sqrt(abs(mat.xt[1,1]));
# If the error is multiplicative, scale it!
            if(error.type=="M" & max(abs(errors))>0.05){
                errors <- 0.05 * errors / max(abs(errors));
            }
        }
        else if(randomizer=="rt"){
# Make a meaningful variance of data.
          errors <- errors * sqrt(abs(mat.xt[1,1]));
# If the error is multiplicative, scale it!
            if(error.type=="M" & max(abs(errors))>0.05){
                errors <- 0.05 * errors / max(abs(errors));
            }
        }

# Center errors in case all of them are positive or negative to get rid of bias.
        if(all(errors>0) | all(errors<0)){
            errors <- errors - mean(errors);
        }
    }

##### Simulation of first model.freq observations #####
    if(season.type!="M"){
        if(season.type=="A"){
            if(error.type=="M"){
                y[1] <- mat.xt[1,1] + mat.xt[1,(n.components+1)] + errors[1] * (mat.xt[1,1] + mat.xt[1,(n.components+1)]);
            }
            else{
                y[1] <- mat.xt[1,1] + mat.xt[1,(n.components+1)] + errors[1];
            }
            j <- 2;
            if(trend.type!="M"){
### ZAA and ZNA
                while(j <= model.freq){
                    y[j] <- mat.w[1:n.components] %*% mat.xt[cbind((j-lags[1:n.components]),c(1:n.components))] + mat.xt[j,n.components+1] + errors[j] * ry.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-c(lags[1:n.components],0)),c(1:persistence.length))]);
                    mat.xt[j,1:n.components] <- mat.F[1:n.components,1:n.components] %*% mat.xt[cbind((j-lags[1:n.components]),c(1:n.components))] + vec.g[1:n.components] * errors[j] * r.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-c(lags[1:n.components],0)),c(1:persistence.length))])[1:n.components];
                    j <- j + 1;
                }
            }
            else{
### ZMA
                while(j <= model.freq){
                    y[j] <- exp(mat.w[1:n.components] %*% log(mat.xt[cbind((j-lags[1:n.components]),c(1:n.components))])) + mat.xt[j,n.components+1] + errors[j] * ry.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-c(lags[1:n.components],0)),c(1:persistence.length))]);
                    mat.xt[j,1:n.components] <- exp(mat.F[1:n.components,1:n.components] %*% log(mat.xt[cbind((j-lags[1:n.components]),c(1:n.components))])) + vec.g[1:n.components] * errors[j] * r.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-c(lags[1:n.components],0)),c(1:persistence.length))])[1:n.components];
                    j <- j + 1;
                }
            }
        }
        else{
### ZNN, ZAN, ZMN
            if(error.type=="M"){
                y[1] <- mat.xt[1,1] + errors[1] * mat.xt[1,1];
            }
            else{
                y[1] <- mat.xt[1,1] + errors[1];
            }
            j <- 2;
        }
    }
    else{
        if(error.type=="M"){
            y[1] <- mat.xt[1,1]*mat.xt[1,(n.components+1)] + errors[1] * mat.xt[1,1]*mat.xt[1,(n.components+1)];
        }
        else{
            y[1] <- mat.xt[1,1]*mat.xt[1,(n.components+1)] + errors[1];
        }
        j <- 2;
        if(trend.type!="M"){
### ZAM and ZNM
            while(j <= model.freq){
                y[j] <- mat.w[1:n.components] %*% mat.xt[cbind((j-lags[1:n.components]),c(1:n.components))] * mat.xt[j,n.components+1] + errors[j] * ry.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-c(lags[1:n.components],0)),c(1:persistence.length))])
                mat.xt[j,1:n.components] <- mat.F[1:n.components,1:n.components] %*% mat.xt[cbind((j-lags[1:n.components]),c(1:n.components))] + vec.g[1:n.components] * errors[j] * r.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-c(lags[1:n.components],0)),c(1:persistence.length))])[1:n.components];
                j <- j + 1;
            }
        }
        else{
### ZMM
            while(j <= model.freq){
                y[j] <- exp(mat.w %*% log(mat.xt[cbind((j-c(lags[1:n.components],0)),c(1:persistence.length))])) + errors[j] * ry.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-c(lags[1:n.components],0)),c(1:persistence.length))])
                mat.xt[j,1:n.components] <- exp(mat.F[1:n.components,1:n.components] %*% log(mat.xt[cbind((j-lags[1:n.components]),c(1:n.components))])) + vec.g[1:n.components] * errors[j] * r.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-c(lags[1:n.components],0)),c(1:persistence.length))])[1:n.components];
                j <- j + 1;
            }
        }
    }


###### Simulate the rest of the series #####
    if(season.type=="N"){
        if(trend.type!="M"){
### ZNN and ZAN
            while(j<=obs){
                y[j] <- mat.w %*% mat.xt[cbind((j-lags),c(1:persistence.length))] + errors[j] * ry.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-lags),c(1:persistence.length))]);
                mat.xt[j,] <- mat.F %*% mat.xt[cbind((j-lags),c(1:persistence.length))] + vec.g * errors[j] * r.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-lags),c(1:persistence.length))]);
                j <- j + 1;
            }
        }
        else{
### ZMN
            while(j<=obs){
                y[j] <- exp(mat.w %*% log(mat.xt[cbind((j-lags),c(1:persistence.length))])) + errors[j] * ry.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-lags),c(1:persistence.length))]);
                mat.xt[j,] <- exp(mat.F %*% log(mat.xt[cbind((j-lags),c(1:persistence.length))])) + vec.g * errors[j] * r.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-lags),c(1:persistence.length))]);
#Failsafe for the negative components
                if(mat.xt[j,1] < 0){
                    mat.xt[j,1] <- mat.xt[j-1,1];
                }
                if(mat.xt[j,2] < 0){
                    mat.xt[j,2] <- mat.xt[j-1,2];
                }
                j <- j + 1;
            }
        }
      }
    else if(season.type=="A"){
        if(trend.type!="M"){
### ZNA and ZAA
            while(j<=obs){
                y[j] <- mat.w %*% mat.xt[cbind((j-lags),c(1:persistence.length))] + errors[j] * ry.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-lags),c(1:persistence.length))]);
                mat.xt[j,] <- mat.F %*% mat.xt[cbind((j-lags),c(1:persistence.length))] + vec.g * errors[j] * r.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-lags),c(1:persistence.length))]);
# Renormalize seasonal component
                at <- vec.g[n.components+1] / seas.freq * errors[j] * ry.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-lags),c(1:persistence.length))]);
                mat.xt[j,1] <- mat.xt[j,1] + at;
                mat.xt[(j-seas.freq+1):(j),n.components+1] <- mat.xt[(j-seas.freq+1):(j),n.components+1] - at;
                j <- j + 1;
            }
        }
        else{
### ZMA
            while(j<=obs){
                y[j] <- exp(mat.w[1:n.components] %*% log(mat.xt[cbind((j-lags[1:n.components]),c(1:n.components))])) + mat.xt[j-seas.freq,n.components+1] + errors[j] * ry.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-lags),c(1:persistence.length))]);
                mat.xt[j,] <- Re(exp(mat.F %*% log(as.complex(mat.xt[cbind((j-lags),c(1:persistence.length))])))) + vec.g * errors[j] * r.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-lags),c(1:persistence.length))]);
#Failsafe for the negative components
                if(mat.xt[j,1] < 0){
                    mat.xt[j,1] <- mat.xt[j-1,1]
                }
                if(mat.xt[j,2] < 0){
                    mat.xt[j,2] <- mat.xt[j-1,2]
                }
# Renormalize seasonal component
                at <- vec.g[n.components+1] / seas.freq * errors[j] * ry.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-lags),c(1:persistence.length))]);
                mat.xt[j,1] <- mat.xt[j,1] + at;
                mat.xt[(j-seas.freq+1):(j),n.components+1] <- mat.xt[(j-seas.freq+1):(j),n.components+1] - at;
                j <- j + 1;
            }
        }
    }
    else if(season.type=="M"){
        if(trend.type!="M"){
### ZNM and ZAM
            vec.r <- r.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-lags),c(1:persistence.length))])
            while(j<=obs){
                y[j] <- mat.w[1:n.components] %*% mat.xt[cbind((j-lags[1:n.components]),c(1:n.components))] * mat.xt[j-seas.freq,n.components+1] + errors[j] * ry.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-lags),c(1:persistence.length))]);
                mat.xt[j,1:n.components] <- mat.F[1:n.components,1:n.components] %*% mat.xt[cbind((j-lags[1:n.components]),c(1:n.components))] + vec.g[1:n.components] * errors[j] * vec.r[1:n.components];
                mat.xt[j,(n.components+1)] <- mat.xt[j-seas.freq,(n.components+1)] + vec.g[n.components+1] * errors[j] * vec.r[n.components+1];
# Failsafe mechanism for the cases with negative multiplicative seasonals
                if(mat.xt[j,(n.components+1)] < 0){
                    mat.xt[j,(n.components+1)] <- mat.xt[j-seas.freq,(n.components+1)];
                }
# Renormalize seasonal component. It is done differently comparing with Hyndman et. al. 2008!
                mat.xt[(j-seas.freq+1):(j),n.components+1] <- mat.xt[(j-seas.freq+1):(j),n.components+1] / exp(mean(log(mat.xt[(j-seas.freq+1):(j),n.components+1])));
                j <- j + 1;
            }
        }
        else{
### ZMM
            while(j<=obs){
                y[j] <- exp(mat.w %*% log(mat.xt[cbind((j-lags),c(1:persistence.length))])) + errors[j] * ry.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-lags),c(1:persistence.length))]);
                mat.xt[j,] <- Re(exp(mat.F %*% log(as.complex(mat.xt[cbind((j-lags),c(1:persistence.length))])))) + vec.g * errors[j] * r.value(error.type=error.type, trend.type=trend.type, season.type=season.type, xt=mat.xt[cbind((j-lags),c(1:persistence.length))]);
# Failsafe mechanism for the cases with negative components
                if(mat.xt[j,1] < 0){
                    mat.xt[j,1] <- mat.xt[j-1,1]
                }
                if(mat.xt[j,2] < 0){
                    mat.xt[j,2] <- mat.xt[j-1,2]
                }
                if(mat.xt[j,3] < 0){
                    mat.xt[j,3] <- mat.xt[j-seas.freq,3];
                }
# Renormalize seasonal component. It is done differently comparing with Hyndman et. al. 2008!
                mat.xt[(j-seas.freq+1):(j),3] <- mat.xt[(j-seas.freq+1):(j),3] / exp(mean(log(mat.xt[(j-seas.freq+1):(j),3])));
                j <- j + 1;
            }
        }
    }

    if(nseries > 1){
        mat.yt[,k] <- y;
        arr.xt[,,k] <- cbind(mat.xt,errors);
        mat.g[k,] <- vec.g;

# Print the number of processed series
        if(k<=10){
            cat("\b");
        }
        else if(k>10 & k<=100){
            cat("\b");
            cat("\b");
        }
        else if(k>100 & k<=1000){
            cat("\b");
            cat("\b");
            cat("\b");
        }
        else if(k>1000 & k<=10000){
            cat("\b");
            cat("\b");
            cat("\b");
            cat("\b");
        }
        else if(k>10000 & k<=100000){
            cat("\b");
            cat("\b");
            cat("\b");
            cat("\b");
            cat("\b");
        }
        else{
            cat("\b");
            cat("\b");
            cat("\b");
            cat("\b");
            cat("\b");
            cat("\b");            
        }
        cat(k);
    }
}

    if(nseries==1){
        y <- ts(y,frequency=seas.freq);
        errors <- ts(errors,frequency=seas.freq);
        mat.xt <- cbind(mat.xt,errors);
        mat.xt <- ts(mat.xt,frequency=seas.freq);
        colnames(mat.xt) <- c(component.names,"error");
    
        return(list(data=y,states=mat.xt,persistence=vec.g));
    }
    else{
        mat.yt <- ts(mat.yt,frequency=seas.freq);
        return(list(data=mat.yt,states=arr.xt,persistence=mat.g));
    }
}