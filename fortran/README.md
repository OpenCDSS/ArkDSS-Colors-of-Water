#  fortran
This folder contains the fortran code, originally called j349 from the USGS, that has been further developed by the State of Colorado / ArkDSS Colors of Water (COW) project.  The compiled fortran code is utilized by the COW model engine currently called StateTL (*matlab*).
* [Background](#background)
* [Summary of Changes](#summary-of-changes)
* [Compiling](#compiling)
* [Remaining Issues](#remaining-issues)

## Background
The USGS j349 model utilized for the COW project was described by Land (1977).  The model was utilized by Livingston for use in his Transit Loss Accounting Program (TLAP) and calibrated for the  Lower Arkansas River from Pueblo to John Martin Reservoir (Livingston 2008) and from John Martin Reservoir to the Kansas State Line (Livingston 2011).

*Land, L.F., 1977, Streamflow routing with losses to bank storage or wells: National Technical Information Service, Computer Contribution, PB-271535/AS, 117 p.*

*Livingston, R.K. 2008.  Transit Losses and Travel Times of Reservoir Releases along the Arkansas River from John Martin Reservoir to the Colorado-Kansas Stateline: Arkansas River Compact Administration.*

*Livingston, R.K. 2011.  Transit Losses and Travel Times of Reservoir Releases along the Arkansas River from Pueblo Reservoir to John Martin Reservoir.*

The j349 combines a streamflow-routing component (channel-storage component) with a bank-storage component (developed by Hall and Moench (1972)) to determine a total conveyance loss for a given reach.  The bank-storage component is analogous to a one-dimensional aquifer model utilizing parameters such as transmissivity, storage coefficient, and aquifer length and width. Similar to the USGS CONROUT (Doyle et al., 1983) program, the streamflow-routing uses a diffusion analogy approach using celerity and dispersion and can be operated either with single or multiple linearization.  The multiple linearization approach was described by Keefer and McQuivey (1974).

*Doyle, W.H., Shearman, J.O., Stiltner G.J., and Krug, W.R., 1983, A Digital Model For Streamflow Routing By Convolution Methods.  USGS Water-Resources Investigations Report 83-4160*

*Hall, F.R. and Moench, A.F. (1972), Application of the convolution equation to stream-aquifer relationships, Water Resources Research, 8(2), 487-493.*

*Keefer, T. N., and McQuivey, R. S., 1974, Multiple linearization flow routing model: American Society of Civil Engineers Proceedings, Journal of the Hydraulics Division, v. 100, no. HY7, p. 1031-1046.*

## Summary of Changes
The original USGS fortran code was updated to compile in the 64bit gfortran compiler and dimensioning expanded to operate for a full calendar year.  An error was fixed in the multiple linearization method and celerity/dispersion dimensioning for the method was increased from 8 to 10.  A “fast” feature was also added to reduce output to just Qds in a binary rather than text file to increase efficiency when deployed.
1. Original j349.f code from USGS.  Fortan file dated 9/5/2018 3:46 PM (as obtained by Jim Brannon)
2. Code acquired from Lou Parslow, an original TLAP developer, by Jim Brannon.  This version had some arrays (originally at 1600) dimensioned to 3200 and has modified versions of RATNG and ERFC.  The dimensioning was confirmed to be needed and may be due to the bank storage URFs being of equal size as the original time series so that the array sizing needs to be double the time step. Fortan file dated 9/5/2018 3:50 PM (as obtained by Jim Brannon)
3. Code from Jim Brannon, as modified from the Lou Parslow code.  Fixes were primarily to get to run in 32bit gfortran.  Includes executable which is currently used by TLAP used by DWR Div2 for administration. Fortan file dated 9/10/2018 3:08 PM
4. Code modified by Kelley Thompson to run on 64bit gfortran; starting from Lou Parslow code.  Compile errors but not warnings were resolved. Fortan file dated 9/20/2021 12:41 PM
5. Increased dimensions of main arrays from 1600/3200 to 9000/18000.  Enables calendar year time step of 9000 hours which is 365 or 366 days plus 9 days spinup.  Fortan file dated 9/22/2021 10:37 AM
6. Added 'fast' option to reduce output to Qds in a binary rather than text file.  A bug in the multiple linearization method was also fixed and Q/celerity/dispersion input dimension increased from 8 to 10.  The fast option is turned on in the input text file in column C of row 3; an example input text file is included that shows fast option as well as multiple linearization input.
7. Modified code so that input and output(2) filenames are provided through command line arguments rather than through a file.  An example new command line to call the code (using fast=1) is '$ StateTL_j349 StateTL_j349input_us.dat StateTL_j349output_ds.dat StateTL_j349output_ds.bin'.  Increased dimensioning of these filenames to upto 200 characters to allow folder references from within filename.

## Compiling
Fortran code for use in COW project is being compiled with 64bit GNU gcc/gfortran (https://gcc.gnu.org/fortran/) and using the Msys2 environment.  Installation and use followed information at:https://opencdss.state.co.us/statemod/16.00.47/doc-dev/dev-env/machine/#install-mingw also looking at: https://gcc.gnu.org/wiki/GFortranUsage and https://gcc.gnu.org/onlinedocs/gfortran/ .
When compiling, .a files were included but with the compiler build used 2 dlls were still required to be supplied directly with the compiled executable.  However, this compiled version was tested to run faster than when using a -static include statement.   Therefore, currently using the following statements to compile:
```
gfortran -c j349.f
gfortran -o executable j349.o libgfortran.a libgcc_s.a libquadmath.a libwinpthread.a
```
but the following dlls are still required for deployement:
```
libgcc_s_seh-1.dll
libwinpthread-1.dll
```
For COW project, currently renaming executable as StateTL_j349.exe that is placed and ran from within the matlab folder.

## Remaining Issues
* Fast options are currently hardwired within the subroutine AQTYPE, so output from this function would not display when fast is off.
* The multiple linearization method runs well at higher river flow rates, but is causing added noise and oscillations at low flow rates (that when used in current StateTL code can potentially "create" water at low flow/release rates). 
* To increase efficiency, may also want to use binary file as input but may still need text file to trigger fast option unless OK to have binary file hardwired.