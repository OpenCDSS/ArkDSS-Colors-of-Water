# -*- coding: utf-8 -*-

"""
Created: 11/19/2021
Modified: 01/07/2022
Created by: Rick Lyons

Description:
Run calibration for the ArkDSS Colors of Water project
There are two options for calibrators--matk parameter study and pySOT
matk is used for parameter study and later (to do) Monte Carlo analysis (more comprehensive)
(To do) pySOT is used for metaheuristic DYCORS analysis (more efficient)
Two external files are required, in the same folder, to run this script:
"StateTL_calibration_control.txt", which contains paths and options for the script
"StateTL_calibration_inputdata.csv" which contains parameter information to calibrate
"""

import os
import sys
import shutil
import subprocess
import numpy as np
import pandas as pd
import configparser
from time import time
from glob import glob
from pathlib import Path
from matk import matk, pest_io
import matplotlib.pyplot as plt
# from multiprocessing import freeze_support

# Set some pandas options
pd.set_option('expand_frame_repr', False)
# Set some matplotlib options
plt.style.use('default')


def create_template_file(matlab_dir, input_csv, output_tpl, data_dir):
    # Set data type for DataFrame
    dtype = {
        'Div': int,
        'WD': int,
        'Reach': int,
        'parameter': str,
        'symbol': str,
        'value': float,
        'minimum': float,
        'maximum': float,
        'vary': str
    }
    # Read calibration inputdata file
    df = pd.read_csv(data_dir,
                     sep='\s*[,]\s*',
                     engine='python',
                     dtype=dtype
                     )
    # Remove empty lines (NaNs) from DataFrame
    df.dropna(how='all', inplace=True)

    # Create list of unique parameter symbols
    parameter_list = df.symbol.unique().tolist()
    # Create dictionary from DataFrame
    parameters = df.to_dict('index')

    # Read Matlab input file
    inputs_df = pd.read_csv(f'{matlab_dir}/{input_csv}')
    # Create copy of csv input file
    tpl = inputs_df.copy()
    # Loop through keys in parameter dictionary
    for key in parameters.keys():
        # items created from nested dictionary
        items = parameters[key]
        # Check for -1 in 'Reach' column to give same symbol to all reaches
        if items['Reach'] == -1:
            # set template file with symbol from calibration inputdata
            tpl.loc[tpl.WD == items['WD'], items['parameter']] = f'~{items["symbol"]}~'
        # Find row in tpl DataFrame that matches the values for 'WD' and 'Reach' in nested dictionary
        # and replace value in 'parameter' cell with value from nested dictionary in 'symbol' cell
        tpl.loc[(tpl.Div == items['Div']) & (tpl.WD == items['WD']) & (tpl.Reach == items['Reach']), items['parameter']] = f'~{items["symbol"]}~'

    with open(f'{matlab_dir}/{output_tpl}', 'w') as f:
        f.write('ptf ~\n')
        tpl.to_csv(f, index=False, line_terminator='\n')
    return parameters, parameter_list


def run_extern(params, base_dir, matlab_dir, input_file, template_file, calib_dir):
    # Set the par & to_file directory path
    par_dir = Path.cwd()
    to_file = par_dir / input_file

    # Create model input file from template file
    pest_io.tpl_write(params, fr'../../matlab/{template_file}', to_file)

    # cd into matlab directory to run model
    os.chdir(matlab_dir)
    # Create command line string to run model
    run_line = f'StateTL.exe -f \\{calib_dir}\\{par_dir.name} -c'
    # print(f'Line passing to matlab exe:\n{run_line}')
    # Run model
    print(f'running StateTL from folder: {par_dir.name}')
    # ierr = subprocess.run(run_line).returncode
    subprocess.run(run_line).returncode
    # with open(f'..\\{calib_dir}\\{par_dir.name}\\calibration.out', 'w') as output:
    #     subprocess.run(run_line, stdout=output, check=True)
    print(f'{par_dir.name} run completed!')
    # print(f'{par_dir.name} ierr: {ierr}')

    # Change cwd back to current par folder
    os.chdir(par_dir)

    try:
        # Read output file of data
        results_df = pd.read_csv('StateTL_out_calday.csv')
        # Make list of unique WDIDs
        WDID_list = results_df.iloc[:, 0].unique().tolist()
        # Convert WDID integers to strings
        WDID_columns = [str(i) for i in WDID_list]
        # Create DataFrame to store RMSE values by WDID
        RMSE_df = pd.DataFrame(index=WDID_columns)
        for WDID in WDID_list:
            # Extract Gauge & Sim data for current WDID
            gauge_data = results_df[(results_df['WDID'] == WDID) & (results_df['1-Gage/2-Sim'] == 1)].to_numpy().flatten()[7:]
            sim_data = results_df[(results_df['WDID'] == WDID) & (results_df['1-Gage/2-Sim'] == 2)].to_numpy().flatten()[7:]
            # Place RMSE for WDID in DataFrame
            RMSE_df.at[str(WDID), f'RMSE{par_dir.name}'] = np.sqrt(np.mean((sim_data - gauge_data)**2))
    except Exception as err:
        print(f'StateTL_out_calday.csv was not created in {par_dir.name}\n{err}\n')
        RMSE_df = 1e999

    return RMSE_df


def main():
    # Time at beginning of simulations
    start = time()

    # change cwd to parent ('ArkDSS-colors-of-Water') folder
    base_dir = Path.cwd().parent
    matlab_dir = base_dir / 'matlab'
    os.chdir(base_dir)
    print(f'present working directory: {Path.cwd()}')

    # Set filenames
    input_file = 'StateTL_inputdata.csv'
    template_file = 'StateTL_inputdata.tpl'
    calib_data_file = 'StateTL_calibration_inputdata.csv'
    calib_ctrl_file = 'StateTL_calibration_control.txt'

    # Set directories
    data_dir = base_dir / 'python' / calib_data_file
    ctrl_dir = base_dir / 'python' / calib_ctrl_file

    # Read calibration control file & set values
    # Set config to use 
    config = configparser.ConfigParser()
    # Keep parameters in original case
    config.optionxform = lambda option: option
    # Read config file
    config.read(ctrl_dir)

    # Create dictionary from 'Settings' group
    settings = dict(config.items('Settings'))
    # Parse values
    calib_dir = settings['calib_dir']
    results_dir = settings['results_dir']
    results_file = settings['results_file']
    log_file = settings['log_file']
    keep_previous = settings['keep_previous']
    method = settings['method']
    # Create dictionary from method
    methods = ['Parameter Sensitivity', 'Monte Carlo', 'Latin Hypercube']
    if not config.has_section(method):
        print(f'ERROR: Your method "{method}" is not valid. The available methods include {methods}. ', end='')
        print('Check your control file.')
        sys.exit(1)
    method_dict = dict(config.items(method))

    # Define model locations
    workdir_base = f'{calib_dir}/par'
    folders_to_delete = base_dir / calib_dir / '*'
    results_loc = base_dir / calib_dir / results_dir
    outfile = f'{calib_dir}/{results_dir}/{results_file}'
    logfile = f'{calib_dir}/{results_dir}/{log_file}'

    # Gather names of all folders in calib_dir directory
    if keep_previous == 'delete':
        folders = glob(str(folders_to_delete))
        # Delete existing folders in calib_dir
        for folder in folders:
            shutil.rmtree(folder)

    # Create results directory if it doesn't exist already
    if not os.path.exists(results_loc):
        os.makedirs(results_loc)

    # Create template file and return parameter dictionary
    # and number of parameters to vary
    parameters, parameter_list = create_template_file(matlab_dir, input_file,
                                                      template_file, data_dir)

    # Create MATK object
    p = matk(model=run_extern,
             model_args=(base_dir, matlab_dir, input_file, template_file, calib_dir))

    # Check method type
    methods = ['Parameter Sensitivity', 'Monte Carlo', 'Latin Hypercube Sampling']

    if method == 'Parameter Sensitivity':
        print(f'Running {method}!')
        # Create list of number of variations per parameter, by position
        nvals_list = []
        for i, item in enumerate(parameter_list):
            try:
                nvals_list.append(int(method_dict[item]))
            except Exception:
                print(f'Error: {item} in {calib_data_file}')
                print(f'       is missing in {calib_ctrl_file}')
                sys.exit(1)
        extra_symbols = [item for item in config.options(method) if item not in parameter_list]
        if extra_symbols:
            print(f"WARNING: These symbols {extra_symbols} are not being used in the {method}!")
        print(f'parameter_list: {parameter_list}')
        print(f'nvals_list: {nvals_list}')

        # Create parameters
        for key in parameters.keys():
            items = parameters[key]
            p.add_par(items['symbol'],
                      value=items['value'],
                      min=items['minimum'],
                      max=items['maximum'],
                      vary=items['vary'])

        # Create sample set from p.add_par
        s = p.parstudy(nvals=nvals_list)
        # print(f'nvals_list: {nvals_list}')
        print(f'Here are the sample values:\n{s.samples.values}')

    # Check method type
    elif method == 'Monte Carlo':
        pass

    # Check method type
    elif method == 'Latin Hypercube Sampling':
        print(f'Running {method}!')
        # Create parameters
        for key in parameters.keys():
            items = parameters[key]
            p.add_par(items['symbol'],
                      value=items['value'],
                      min=items['minimum'],
                      max=items['maximum'],
                      vary=items['vary'])
        # Create lhs sample set
        s = p.lhs(siz=int(method_dict['sample_size']))
        print(f'Here are the sample values:\n{s.samples.values}')
    else:
        print(
            f'ERROR: Your method block "[{method}]" is not valid. The available method blocks include {methods}. ',
            end=''
        )
        print('Check your control file.')
        sys.exit(1)

    # Run model with parameter samples
    s.run(cpus=os.cpu_count(),
          workdir_base=workdir_base,
          outfile=outfile,
          logfile=logfile,
          verbose=False,
          reuse_dirs=True)

    end = time()
    print(f'Total running time: {(end - start) / 60} mins')

    # # Plot results
    # plt.plot(s.samples.values, s.simvalues, 'r')
    # # plt.ylabel("Model Response")
    # plt.show()


if __name__ == '__main__':
    main()
