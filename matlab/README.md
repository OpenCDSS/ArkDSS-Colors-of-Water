#  matlab
This folder contains the matlab based model engine code developed by the State of Colorado / ArkDSS Colors of Water (COW) project.  The COW StateTL model engine code manages inputs, outputs, methods used, and transit loss and routing calculations.
* [Background](#background)
* [Other Files Needed](#other-files-needed)
* [Summary of Changes](#summary-of-changes)
* [Primary Processes Built](#primary-processes-built)
* [Usage Notes](#usage-notes)
* [Compiling](#compiling)

## Background
The StateTL model engine code manages runs and performs transit loss and routing calculations to estimate river flows and portions of that river flow (ie colors of water) originating from releases from reservoirs and other structures (ie water classes) at both river gage and intermediate structure locations between gages (ie ditch headgates or other inflow/outflow locations). StateTL was initially designed to run similarly to the spreadsheet based Transit Loss Accounting Program (TLAP) developed by R.K. Livingston and calibrated for the Lower Arkansas River from Pueblo to John Martin Reservoir (Livingston 2008) and from John Martin Reservoir to the Kansas State Line (Livingston 2011).  The model calls a modified version of the USGS j349 program (Land 1977) that is a compiled fortran program to perform streamflow routing and bank storage calculations, although other methodologies can now also be used.  

*Land, L.F., 1977, Streamflow routing with losses to bank storage or wells: National Technical Information Service, Computer Contribution, PB-271535/AS, 117 p.*

*Livingston, R.K. 2008.  Transit Losses and Travel Times of Reservoir Releases along the Arkansas River from John Martin Reservoir to the Colorado-Kansas Stateline: Arkansas River Compact Administration.*

*Livingston, R.K. 2011.  Transit Losses and Travel Times of Reservoir Releases along the Arkansas River from Pueblo Reservoir to John Martin Reservoir.*

StateTL runs streamflow routing and transit losses on a channel subreach that is defined by an upstream and downstream WDID (structure or inflow/outflow location).  The stream network and channel and aquifer parameters for stream subreaches are defined by an input table that is specified in the run control file (*StateTL_control.txt*).  The network is currently defined by the following general rules:
1. Division (D) - primary river basin (ie Arkansas River Basin is Division 2)
1. Water District (WD): larger river reach for tributaries and between on-stream reservoirs
	1. Upstream terminus: structure or gage on tributary or primary on-stream reservoir
	1. Downstream terminus: confluence point (when WD is the tributary), primary on-stream
reservoir, or final structure at or beyond stateline (currently not a gage)
	1. Naming Convention:
		1. primary reach as primary administrative water district (ie 67)
		1. Tributaries can relate to primary reach (ie 671)
1. Reach (R ): river reach generally between two gages or top/bottom of WD
	1. Upstream terminus: top of WD (top of trib or on-stream reservoir) or gage
	1. Downstream terminus: bottom of WD (confluence pt, reservoir, or stateline) or gage
	1. Naming Convention: Currently need to be integer in order from top to bottom (ie 1-7)
1. Subreach (SR): river subreach between two structures
	1. Consists of: upstream WDID, downstream WDID, river reach (with length)
	1. Naming Convention: Currently need to be integer in order from top to bottom (ie 1-7)


## Other Files Needed
For repository storage size and security reasons, several other files are needed to initially run StateTL including a large file that contains the ET/evaporation data for Division 2 and the compiled StateTL and j349 fortran codes and associated dlls .  These files can be downloaded from the COW shared drive (Discovery > 4. Model Engine > StateTLfiles_notingit).

When StateTL runs it builds a number of binary files that are saved.  If indicated in the StateTL_control.txt file, when the program is ran again these binary files can be used directly rather than rebuilding (ie for files that pull from REST services or rebuild evaporation) as long as changes aren't made (ie adding WDID's) that would require new files.  So files such as the ET/evaporation file may not be needed if processed binaries are already produced or are shared instead.

## Summary of Major Changes
The original model engine code was functional in 2019.  This code (as slightly modified in 2020) was stored as the original base in github.  Significant advancement on this code occurred in May through October 2021 but versioning was not maintained in git (versions were stored locally and on the COW shared drive in the discover folder).  The progression of locally stored versions was added into git in October 2021 just in case some element of previous versions may be needed (additional intermediate versions not added to git are available on the COW shared drive).  The last of these versions was dated 10/6/2021; and from this point forward versioning will be managed within git and will follow CDSS recommended methods for versioning including relating development to issues in git.  The following describes some larger changes.
1. 2019/2020 (TLAP.m) version - Original code operates similarly to TLAP but with non-steady rather than state-state river conditions.  Loops for river and water class flows were fully separate. 
2. May 2021 - renamed StateTL and significant development by DWR staff
3. June 2021 - To attempt to deal with inadvertent diversion issue, river and water class loops were integrated/nested loop and operated reach by reach so that could iterate back on river flows based on sum of water classes releases (ie when negative native flows were found)
4. late July 2021 - To improve efficiency for calibration, nested loops were re-separated so that the river flow loop could operate without the water class loop (which is the most time consuming but not needed for calibration).  This broke the action to increase intermediate (between gage) river flows when intermediate negative native flows were encountered, but the initial/current perspective of the COW team was that we should allow potentially negative native flows due to both inaccuracies in calculations and a common practice in Div2 to exchange on reservoir releases.  Loops still operate on a reach basis for all water classes rather than running a complete analysis for each water class as originally done.
5. October 2021 - initiation of version management using github and recommended CDSS practices
6. November 2021 - enable data folders and command line arguments

## Primary Processes Built
Primary processes and components that have so-far been built include:
* pull gage and diversion (release - Type 7) records using REST services
* QC hourly telemetry data using daily 'improved' data
* fill missing station (gage and telemetry) data and extending data into future
* routing - from branch above (ie upper Ark above Pueblo Res) and mid-branch (ie Fountain Creek into main branch)
* methods - j349 and muskingum (%TL + muskingum routing)
* processing loops
* gage/total river amounts (determines gain/loss amounts)
* water class / releases from reservoirs and other structures (ie aug. stations)
* exchanges in “reverse” in separate loop from releases
* simulation/calibration - simulate river flows without intermediate gage amounts
* capture - reduce amounts to what can be captured at headgates (10% rule)
* inadvertent diversion measures (let water by, reduce wc at gage, increase internal flows)
* simulation loop to use in calibration
* log file vs editor display
* Output - currently 22 files (11 hourly / 11 daily) oriented as matrices
* Utilizes new statewide ET dataset (different evap for every subreach based on loc/elev)
* j349 64bit gfortran exe with dimensions up to 1 year (366 days plus 9 day spinup)
* options for single or multiple linearization method and “fast” binary file output
* filling routine to fill missing telemetry data or extend data into future
* enable command line arguments to control data folder, calibration, and other options

## Usage Notes
An initial set of command line arguments have been enabled to control the StateTL model engine that will override equivalent lines in the control file.  Command line option arguments include `-f -c -b -r -s -d -nd -w -nw` to trigger folder, calibration, build base files, save, display, and write options.  For the first four of these commands, additional arguments can be defined that must follow the given '-' command.  Example usage includes:

folder `-f` command to use data folder for input/output - options/examples:

`StateTL -f \calibration\Par.1` - create folder at same level as code folder (ie matlab and calibration folders same level)

`StateTL -f calibration\Par.1` - otherwise folder will be placed within code folder (ie matlab\calibration\Par.1 folder)

calibration `-c` command full (year,startmo,startday,endmo,endday,water district (must start with 'WD') and partial argument examples:

`StateTL -c 2018,03,15,11,15,WD17`

`StateTL -c` `StateTL -c 2018` `StateTL -c 2018,03,15,11,15` `StateTL -c WD17` `StateTL -c 2018,WD17` 


build `-b` command to build base binary files without rebuilding evaporation or long term station data (ie to work with a new year but river network has not been altered)

`StateTL -b 2018` `StateTL -b 2018,03,15,11,15`

rebuild `-r` command to rebuild base files including evaporation and long term station data (ie after river network has been altered)

`StateTL -r 2018` `StateTL -r 2018,03,15,11,15`

save `-s` command saves final mat files from calibration or control loops (currently used for plotting)

plot `-p` command plots several calibration related plots (only when runcalibloop=1)

music `-m` command produces a short sound clip when StateTL finishes

example expected command line arguments for calibration:

`StateTL -b 2018` - build new binary base files for full year 2018

`StateTL -f \calibration\Par.1 -c 2018,WD17` - calibrate year 2018 for WD17 with input/output into Par.1 folder



## Compiling
For initial deployment testing, DWR is compiling StateTL to an executable currently using Matlab version 2021b.  To run the executable directly, the free Matlab MCR version 2021b must be installed from the following location.  In the future, the executable may be compiled in a newer version (ie 2022a) but this progression may be stopped after final deployment.

https://www.mathworks.com/products/compiler/matlab-runtime.html

