import os
import time
import subprocess
import numpy as np
import pandas as pd
from glob import glob
from pathlib import Path
import matplotlib.pyplot as plt
from multiprocessing import Pool
from shutil import copyfile, rmtree
# from joblib import Parallel, delayed
# from mpire import WorkerPool


def run_matlab(i, par_folder):

    # Change working directory to matlab folder
    os.chdir(Path.cwd() / 'matlab')
    print(f'Starting run {i} now...')
    print(f'from folder {Path.cwd()}')
    # Name of the Matlab script
    # run_line = f'StateTL.exe -f /tests/{par_folder} -c'
    run_line = f'StateTL.exe -f \\tests\\{par_folder} -c'
    print(f'Line passing to matlab exe: {run_line}')
    # Run Matlab script on the command line
    subprocess.run(run_line)

    # prog_name = 'StateTL'
    # # Format of command line Matlab commands
    # mtext = f'matlab -batch "{prog_name}; exit"'
    # # Run Matlab script on the command line
    # subprocess.run(mtext)
    os.chdir(Path.cwd().parent)
    print(f'Run {i} has completed')
    print(f'from folder {Path.cwd()}')


def compute_RMSE(i, new_dir):
    # Location & Name of output file
    file_loc = new_dir / 'StateTL_out_calday.csv'
    print(f'Here\'s the output file location: {file_loc}')
    # Read output file of data
    df = pd.read_csv(file_loc)
    # Make list of unique WDIDs
    WDID_list = df.iloc[:, 0].unique().tolist()
    # Convert WDID integers to strings
    WDID_columns = [str(i) for i in WDID_list]
    # Create DataFrame to store RMSE values by WDID
    RMSE_df = pd.DataFrame(index=WDID_columns)
    for WDID in WDID_list:
        # print(df.iloc[:2, 0])
        # Extract Gauge & Sim data for current WDID
        gauge_data = df[(df['WDID'] == WDID) & (df['1-Gage/2-Sim'] == 1)].to_numpy().flatten()[7:]
        sim_data = df[(df['WDID'] == WDID) & (df['1-Gage/2-Sim'] == 2)].to_numpy().flatten()[7:]
        # Place RMSE for WDID in DataFrame
        RMSE_df.at[str(WDID), f'RMSE{i}'] = np.sqrt(np.mean((sim_data - gauge_data)**2))
        # RMSE_df.at[str(WDID), f'Mean_Error{i}'] = np.mean(sim_data - gauge_data)
    return RMSE_df


def obj_funct(i, par_folder, new_dir):
    # print('Inside obj_funct(x) function')
    print(f'pwd: {os.getcwd()}')

    # Run Matlab
    run_matlab(i, par_folder)

    # Compute RMSE
    RMSE = compute_RMSE(i, new_dir)
    return RMSE


# For the time being, the results are all the same
def plot_results(RMSE):
    ax = RMSE.plot(kind='line')
    ax.set_xlabel('WDID')
    ax.set_ylabel('RMSE (ft)')
    # plt.xticks = ('WDID')
    plt.show()


def controller(i):
    # Set the directory structure
    base_dir = Path.cwd()
    matlab_dir = base_dir / 'matlab'
    tests_dir = base_dir / 'tests'
    par_folder = f'par.{i}'
    new_dir = tests_dir / par_folder
    matlab_dir = base_dir / 'matlab'
    input_file = 'StateTL_inputdata.csv'
    from_file = matlab_dir / input_file
    to_file = new_dir / input_file

    # Create new data folder
    os.makedirs(new_dir, exist_ok=True)
    # Copy data to temporary folder
    print(f'Copying inputfile for instance {i}...')
    # copy_tree(from_dir, to_dir + f'/par.{i}')
    copyfile(from_file, to_file)
    print(f'Done copying for instance {i}')
    # Change directory to temporary folder
    # os.chdir(new_dir)
    # Call run_matlab function to run matlab
    # run_matlab(i)
    # Move into Objective Function function
    # print('Moving into the Objective Function')
    RMSE = obj_funct(i, par_folder, new_dir)
    # Change directory back to base directory
    os.chdir(base_dir)
    return RMSE


def main():
    # Create array of run numbers
    number_of_runs = 12
    runs = np.arange(number_of_runs)

    # Time before starting simulations
    start = time.time()

    # Change cwd to parent ('ArkDSS-colors-of-Water') folder
    os.chdir(Path.cwd().parent)
    print(Path.cwd())

    # Gather names of all folders in tests directory
    folders = glob('O:/Projects/ArkDSS/modeling/models/ArkDSS-Colors-of-Water/tests/*')

    # Delete existing folders in tests directory
    for folder in folders:
        rmtree(folder)

    # Run model using multiple cores in parallel (different options currently)
    # Joblib: set up parallel job using all cores (-1) with (i) runs
    # RMSE = Parallel(n_jobs=-1)(delayed(controller)(i) for i in range(runs))
    # RMSE = Parallel(n_jobs=-1)(delayed(controller)(i) for i in runs)
    # Python built-in multiprocessing:
    with Pool(processes=number_of_runs) as pool:
        RMSE = pool.map(controller, runs)
    # MPIRE
    # with WorkerPool(n_jobs=number_of_runs) as pool:
    #     RMSE = pool.map(controller, runs)

    # Run model using single core
    # RMSE = controller(runs)

    # Combine results into single DataFrame
    RMSE = pd.concat(RMSE, axis=1)

    # Time at end of simulations
    end = time.time()
    total_time = end - start
    print(f'Total Running time: {total_time} seconds')
    return RMSE


if __name__ == '__main__':
    print('Starting...')
    RMSE = main()
    # print simulation completed
    print('Testing scenario of running 12 parallel iterations of the Matlab executable completed!')
