# ArkDSS-Colors-of-Water
Colorado's Decision Support Systems (CDSS) ArkDSS Colors of Water Model Engine code

This repository contains the source code for the ArkDSS Colors of Water Model Engine,
which is part of [Colorado's Decision Support Systems (CDSS)](https://www.colorado.gov/cdss).

See the following sections in this page:

* [Colors of Water Repository Folder Structure](#colors-of-water-repository-folder-structure)
* [License](#license)
* [Contact](#contact)

-----

## Colors of Water Repository Folder Structure ##

The following are folders in the repository.
1. matlab - This folder contains the StateTL matlab based model engine code for the Colors of Water (COW) tool.  The StateTL manages inputs, outputs, stream network routing, and transit loss and routing calculations given options in a control file.
1. fortran - This folder contains the fortran code modified from the original USGS j349 code that performs dynamic streamflow routing and bank storage calculations that can be called from the matlab StateTL code for a given stream subreach.
1. python - This folder contains the python script to perform calibration using the ArkDSS matlab StateTL executable.
1. tests - This folder is empty, but is used to hold output folders for the calibration runs.

-----

## Python/Anaconda setup ##

To ensure you have the proper python libraries installed in your python setup use the following commands, using the command line, **before** the first time the python script is run.
(Make sure you are in the directory of the requirements.txt or environment.yml file)
- Python using pip: (This will import the necessary packages into the current python environment (recommended to use a virtual environment))
  - pip install -r requirements.txt
- To update Python with the newly included packages using pip:
  - pip install -I -r requirements.txt
- Anaconda using Anaconda Prompt: (This will create a new Anaconda environment with necessary python version and python packages)
  - conda env create -n **environmentname** -f /**path/to/dir**/environment.yml
- To update Anaconda with the newly included packages using the Anaconda Prompt:
  - conda env update -f /**path/to/dir**/environment.yml

-----

## Initial run of Matlab executable ##

The Matlab runtime v911 must be installed and available on the local machine to run the Matlab executable (available from mathworks)

Before running the python script for the first time it is necessary to run the matlab executable to build essential .mat binary files that are read by Matlab for subsequent runs.
From the command line, run the following code from the matlab directory:
- StateTL -r 2018

-----

## Running Calibration ##

From the command line, navigate to the 'python' directory under the ArkDSS-Colors-of-Water directory and run the following line of code:
- python StateTL_calibration.py

The program will take at least several minutes to run. A simple statement saying, 'This test has completed. ' indicates the script has successfully completed running.

-----

## License ##

The software is licensed under GPL v3+.  See the [LICENSE.md](LICENSE.md) file.

## Contact ##

Contact Brian Macpherson, CWCB (brian.macpherson@state.co.us) or Kelley Thompson, DWR (kelley.thompson@state.co.us).
