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

import warnings
warnings.filterwarnings("ignore")
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


def get_simulation_year(ctrl_file, ctrl_key):

    """
    Not using since we can control simulation year with command line argument
    :param ctrl_file: string - pointing to the StateTL_control.txt
    :return: int - simulation year
    """

    with open(ctrl_file, 'r') as f:
        ctrl = f.readlines()
    for line in ctrl:
        if ctrl_key in line.split(';')[0]:
            sim_year = int(line.split(';')[0].split('=')[1])
            break

    # put in exception error if control file is changed and there is not datestart input key
    # generalize to accomodate "may be full year or year/mo/day; mo/day will be overriden by fullyear option = 1"

    return sim_year


def str_to_bool(s):
    """

    :param s: string either 'True' or 'False'
    :return: bool True or False to work as a function argument
    """
    if s == 'True':
        return True
    elif s == 'False':
        return False
    else:
        raise ValueError('All entries for vary in the input file must be True or False.')


def get_observations(obs_file):

    """
    :param obs_file: string: observation file for a single year
    :return obs: OrderedDict: observation names and values
    """

    obs_df = pd.read_csv(obs_file)
    date_string = ['_'.join(item.split()) for item in obs_df['Date'].to_list()]

    obs_df['obs'] = obs_df['WDID'].astype(str) + '_' + date_string

    return obs_df[['obs', 'Value']]


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
    df = pd.read_csv(
        data_dir,
        sep='\s*[,]\s*',
        engine='python',
        dtype=dtype
    )
    # Remove empty lines (NaNs) from DataFrame
    df.dropna(how='all', inplace=True)

    # Create list of unique parameter symbols
    parameter_list = df['symbol'].unique().tolist()
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

    # Remove dictionaries with duplicate symbols in dictionary
    # Keep only the first entry with the symbol
    encountered_entries = set()
    key_list = []
    for k, v in parameters.items():
        if (v['symbol']) in encountered_entries:
            key_list.append(k)
        else:
            encountered_entries.add((v['symbol']))
    parameters = {k: v for k, v in parameters.items() if k not in key_list}

    return parameters, parameter_list


def run_extern(params, base_dir, matlab_dir, input_file, template_file, calib_dir, sim_year):
    # Set the par & to_file directory path
    par_dir = Path.cwd()
    to_file = par_dir / input_file

    # Create model input file from template file
    pest_io.tpl_write(params, fr'../../matlab/{template_file}', to_file)

    # cd into matlab directory to run model
    os.chdir(matlab_dir)
    # Create command line string to run model
    run_line = f'StateTL.exe -f \\{calib_dir}\\{par_dir.name} -c {sim_year}'
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

    simulation_values = get_observations('StateTL_out_calhr.csv')
    sim_values_dict = dict(zip(simulation_values['obs'].to_list(), simulation_values['Value'].to_list()))

    """
    This will change since Kelley is now providing us observations decoupled from model outputs.
    """
    # try:
    #     # Read output file of data
    #     results_df = pd.read_csv('StateTL_out_calday.csv')
    #     # Make list of unique WDIDs
    #     WDID_list = results_df.iloc[:, 0].unique().tolist()
    #     # Convert WDID integers to strings
    #     WDID_columns = [str(i) for i in WDID_list]
    #     # Create DataFrame to store RMSE values by WDID
    #     RMSE_df = pd.DataFrame(index=WDID_columns)
    #     for WDID in WDID_list:
    #         # Extract Gauge & Sim data for current WDID
    #         gauge_data = results_df[(results_df['WDID'] == WDID) & (results_df['1-Gage/2-Sim'] == 1)].to_numpy().flatten()[7:]
    #         sim_data = results_df[(results_df['WDID'] == WDID) & (results_df['1-Gage/2-Sim'] == 2)].to_numpy().flatten()[7:]
    #         # Place RMSE for WDID in DataFrame
    #         RMSE_df.at[str(WDID), f'RMSE{par_dir.name}'] = np.sqrt(np.mean((sim_data - gauge_data)**2))
    # except Exception as err:
    #     print(f'StateTL_out_calday.csv was not created in {par_dir.name}\n{err}\n')
    #     RMSE_df = 1e999

    # RMSE_df = 1e999

    return sim_values_dict


def main():
    # Time at beginning of simulations
    start = time()

    # change cwd to parent ('ArkDSS-colors-of-Water') folder
    base_dir = Path.cwd().parent
    matlab_dir = base_dir / 'matlab'
    os.chdir(base_dir)
    print(f'Working directory: {Path.cwd()}')

    # Set filenames
    input_file = 'StateTL_inputdata.csv'
    template_file = 'StateTL_inputdata.tpl'
    calib_data_file = 'StateTL_calibration_inputdata.csv'
    calib_ctrl_file = 'StateTL_calibration_control.txt'

    # Set directories
    data_dir = base_dir / 'python' / calib_data_file
    ctrl_dir = base_dir / 'python' / calib_ctrl_file

    # matlab_ctrl_file = 'matlab/StateTL_control.txt'
    # # Read MATLAB control file to get simulation year for setting up observations for the correct year
    # simulation_year = get_simulation_year(matlab_ctrl_file, 'datestart')
    # observation_file = f'matlab/StateTL_out_Y{simulation_year}gagehr.csv'

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
    simulation_year = settings['simulation_year']
    keep_previous = settings['keep_previous']
    method = settings['method']
    cpus = int(settings['cpus'])
    # Create dictionary from method
    methods = ['Parameter Sensitivity', 'Latin Hypercube']
    if not config.has_section(method):
        print(f'ERROR: Your method "{method}" is not valid. The available methods include {methods}. ', end='')
        print('Check your control file.')
        sys.exit(1)
    method_dict = dict(config.items(method))

    observation_file = f'matlab/StateTL_out_Y{simulation_year}gagehr.csv'

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
    parameters, parameter_list = create_template_file(
        matlab_dir,
        input_file,
        template_file,
        data_dir
    )
    print(f'There are {len(parameter_list)} parameters in your calibration.')
    # Create MATK object
    p = matk(
        model=run_extern,
        model_args=(
            base_dir,
            matlab_dir,
            input_file,
            template_file,
            calib_dir,
            simulation_year,
        )
    )

    """
    Add observations
    """
    observations = get_observations(observation_file)
    num_observations = observations.shape[0]
    for obs, val in zip(observations['obs'].to_list(), observations['Value'].to_list()):
        p.add_obs(name=obs, value=val)

    if method == 'Parameter Sensitivity':
        print(f'Running {method}!')
        # Create list of number of variations per parameter, by position
        nvals_list = []
        for i, item in enumerate(parameter_list):
            """
            ToDo: the following breaks if parameter is not defined in control and vary=False. 
                  Also the input file is not skipping # lines when read.
            """
            try:
                nvals_list.append(int(method_dict[item]))
            except Exception:
                print(f'Error: {item} in {calib_data_file}', end=' ')
                print(f'is missing in {calib_ctrl_file}')
                sys.exit(1)
        extra_symbols = [item for item in config.options(method) if item not in parameter_list]
        if extra_symbols:
            print(f"WARNING: These symbols {extra_symbols} are not being used in the {method}!")
        print(f'parameter_list: {parameter_list}')
        print(f'nvals_list: {nvals_list}')

        # Create parameters
        for key in parameters.keys():
            items = parameters[key]
            p.add_par(
                items['symbol'],
                value=items['value'],
                min=items['minimum'],
                max=items['maximum'],
                vary=str_to_bool(items['vary'])
            )

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
            p.add_par(
                items['symbol'],
                value=items['value'],
                min=items['minimum'],
                max=items['maximum'],
                vary=str_to_bool(items['vary'])
            )
        # Ensure sample size is great than the number of parameters
        if int(method_dict['sample_size']) <= len(parameters.keys()):
            print('ERROR: The sample_size for Latin Hypercube sampling must be greater', end=' ')
            print('than or equal the number of calibration parameters.')
            sys.exit(1)
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
    s.run(cpus=cpus,
          workdir_base=workdir_base,
          outfile=outfile,
          logfile=logfile,
          verbose=False,
          reuse_dirs=True)

    end = time()
    print(f'Total running time: {(end - start) / 60} mins')

    df = pd.DataFrame(index=list(range(len(s.indices))))
    df['simulation'] = [f'par.{x}' for x in s.indices]
    df['sse'] = s.sse()
    df['rmse'] = (s.sse()/num_observations)**0.5

    df.to_csv(f'{calib_dir}/{results_dir}/calibration_residual_statistics.csv')

    print('Doh!')

    # # Plot results
    # plt.plot(s.samples.values, s.simvalues, 'r')
    # # plt.ylabel("Model Response")
    # plt.show()


if __name__ == '__main__':
    main()
