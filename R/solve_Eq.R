##########################################################################################
#  Function to solve the model and get the trace matrix, TRE, Eq, deltaEq and eigenvalue
##########################################################################################

solve_Eq <- function(func = model_fm, # = model
                    ENV1a, # = to get state at T0 ou y
                    ENV1b, # temperature
                    growth = 'linear', # patern of climate change increase [stepwise, linear, exponential]
                    management = c(0, 0, 0, 0), # intensity of management (in % [0-1]) order: plantation, harvest, thinning, enrichmenet
                    plotLimit = 200, # limit to repeat the loast eq to avoid empty plot
                    maxsteps = 10000) #maxsteps = 10000
{
  library(rootSolve)

  # get equilibrium for initial condition (ENV1a)
  init <- get_eq(get_pars(ENV1 = ENV1a, ENV2 = 0, params, int = 5))[[1]]
  # In the case T + M are inexistent, add a really small amount of them so the model can reach the real equilibrium
  if(all(init[c('T', 'M')] <= 5e-5)) init[c('T', 'M')] <- 5e-5
  
  # get pars depending on the growth mode
  envDiff <- ENV1b - ENV1a
  if(growth == 'stepwise') {
    pars <- get_pars(ENV1 = ENV1b, ENV2 = 0, params, int = 5)
  }else if(growth == 'linear') {
    gwt <- 1:20 * envDiff/20 + ENV1a
    envGrowth <- c(ENV1a, gwt, rep(gwt[20], maxsteps))
  }else if(growth == 'exponential') {
    gwt <- ENV1a * ((ENV1b/ENV1a)^(1/20*1:20))
    envGrowth <- c(ENV1a, gwt, rep(gwt[20], maxsteps))
  }

  nochange = 0

  trace.mat = matrix(NA, ncol  = length(init), nrow = maxsteps+1)
  trace.mat[1,] = c(init)
  state = init
  #plot(0, state[2], ylim = c(0,1), xlim = c(0, maxsteps), cex = .2)
  for (i in 1:maxsteps)
  {
    # because calculate the parameters many times get the app to be slow
    # I try and save some time here removing the parameters calculation if
    # growth is == stepwise (may optimize in a cleaner way)
    if(growth == 'stepwise') {
      di = func(t = 1, state, pars, management)
    }else {
      pars <- get_pars(ENV1 = envGrowth[i], ENV2 = 0, params, int = 5)
      di = func(t = 1, state, pars, management)
    }
    state = state + di[[1]]
    # correct proportions out of the [0 - 1]
    state[state > 1] <- 1
    state[state < 0] <- 0
    
    trace.mat[i+1,] = state

    if(sum(abs(trace.mat[i, ] - trace.mat[i-1, ])) < 1e-7) nochange = nochange+1

    if(nochange >= 10) break;
    #points(i,state[2], cex=.2)
  }
  trace.mat = trace.mat[1:i,]

  # Time to reach equilibrium
  deltaTime = i - 10

  # Cumulative changes in state
  integral <- sum(abs(sweep(trace.mat, 2, state, "-")))

  # repeat the last eq so the plot is not empty after reaching equilibrium
  if(dim(trace.mat)[1] < plotLimit) {
    missing <- plotLimit - dim(trace.mat)[1]
    trace.missing <- matrix(rep(trace.mat[dim(trace.mat)[1], ], missing), ncol = dim(trace.mat)[2], byrow = T)
    trace.mat <- rbind(trace.mat, trace.missing)
  }

  # Compute the Jacobian
  J = jacobian.full(y = state, func = model_fm, parms = pars, management = management)

  # Asymptotic resilience (local stability)
  R_inf = max(Re(eigen(J)$values)) #in case of complex eigenvalue, using Re to get the real part

  # Initial resilience (reactivity)
  M = (J + t(J))/2
  R_init = max(eigen(M)$values)

  # Euclidean distance between initial and final state proportion
  deltaState <- dist(rbind(init, state))

  return(list(eq = state, mat = trace.mat, R_inf = R_inf, deltaState = deltaState, deltaTime = deltaTime, R_init = R_init, integral = integral))
}
