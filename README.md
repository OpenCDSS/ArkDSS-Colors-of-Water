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


## License ##

The software is licensed under GPL v3+.  See the [LICENSE.md](LICENSE.md) file.

## Contact ##

Contact Brian Macpherson, CWCB (brian.macpherson@state.co.us) or Kelley Thompson, DWR (kelley.thompson@state.co.us).
