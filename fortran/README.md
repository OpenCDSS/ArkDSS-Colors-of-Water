#  fortran
This folder contains the fortran code, originally called j349 from the USGS, that has been further developed by the State of Colorado / ArkDSS Colors of Water (COW) project.  The compiled fortran code is utilized by the COW model engine currently called StateTL (*matlab*).
* [Background](#Background)
* [Summary of Changes](#Summary of Changes)
* [Compiling](#Compiling)

## Background
The USGS j349 model utilized for the COW project was described by Land (1977).  The model was utilized by Livingston for use in his Transit Loss Accounting Program (TLAP) and calibrated for the  Lower Arkansas River from Pueblo to John Martin Reservoir (Livingston 2008) and from John Martin Reservoir to the Kansas State Line (Livingston 2011).

*Land, L.F., 1977, Streamflow routing with losses to bank storage or wells: National Technical Information Service, Computer Contribution, PB-271535/AS, 117 p.
Livingston, R.K. 2008.  Transit Losses and Travel Times of Reservoir Releases along the Arkansas River from John Martin Reservoir to the Colorado-Kansas Stateline: Arkansas River Compact Administration.
Livingston, R.K. 2011.  Transit Losses and Travel Times of Reservoir Releases along the Arkansas River from Pueblo Reservoir to John Martin Reservoir.*

The j349 combines a streamflow-routing component (channel-storage component) with a bank-storage component (developed by Hall and Moench (1972)) to determine a total conveyance loss for a given reach.  The bank-storage component is analogous to a one-dimensional aquifer model utilizing parameters such as transmissivity, storage coefficient, and aquifer length and width. Similar to the USGS CONROUT (Doyle et al., 1983) program, the streamflow-routing uses a diffusion analogy approach using celerity and dispersion and can be operated either with single or multiple linearization.  The multiple linearization approach was described by Keefer and McQuivey (1974).

*Doyle, W.H., Shearman, J.O., Stiltner G.J., and Krug, W.R., 1983, A Digital Model For Streamflow Routing By Convolution Methods.  USGS Water-Resources Investigations Report 83-4160
Hall, F.R. and Moench, A.F. (1972), Application of the convolution equation to stream-aquifer relationships, Water Resources Research, 8(2), 487-493.
Keefer, T. N., and McQuivey, R. S., 1974, Multiple linearization flow routing model: American Society of Civil Engineers Proceedings, Journal of the Hydraulics Division, v. 100, no. HY7, p. 1031-1046.*

## Summary of Changes
The original USGS fortran code was updated to compile in the 64bit gfortran compiler and dimensioning expanded to operate for a full calendar year.  An error was fixed in the multiple linearization method and celerity/dispersion dimensioning for the method was increased from 8 to 10.  A “fast” feature was also added to reduce output to just Qds in a binary rather than text file to increase efficiency when deployed.
1. Original j349.f code from USGS
2. Code acquired from Lou Parslow, an original TLAP developer, by Jim Brannon.  This version had some arrays (originally at 1600) dimensioned to 3200 and has modified versions of RATNG and ERFC.  The dimensioning was confirmed to be needed and may be due to the bank storage URFs being of equal size as the original time series so that the array sizing needs to be double the time step. 
3. Code from Jim Brannon, as modified from the Lou Parslow code.  Fixes were primarily to get to run in 32bit gfortran.  This is a branch not committed back to master.
4. 

## Compiling