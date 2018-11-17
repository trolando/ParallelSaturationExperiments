Multi-core saturation experiments
===============================
This repository hosts the experimental scripts for multi-core saturation.

You can contact the main author of this work at <t.vandijk@jku.at>.

Information on the experiments are found in the submitted paper.

Compiling the sources
-----
Installing the Debian packages and compiling the necessary sources is done by running `./compile_sources.sh`.
The script will compile and install *Meddly*, *Sylvan* and *LTSmin*.
Running the compile script ensures that all binaries that are built end up in the `tools` directory.
Ultimately the script will run multi-core saturation with the force order on the Petri net running example presented in the paper.
I.e. the commandline that is automatically run is `tools/pnml2lts-sym --saturation=sat -rf pnml/example.pnml`.
This means the last few lines that are shown when running `./compile_sources.sh` contain `pnml2lts-sym: state space has 5 states, 12 nodes`.
When this output is visible the compilation step has been completed successfully.

Reproducing the experiments
-----
First extract the tarballs in the mcc directory using `tar Jxf models.tar.xz`.

Use `generate.py` as the preprocessing step to generate LDD and BDD files from the models.
The file `generate.py` can be configured with a timeout value (in the file itself).
Use `generate.py` (without parameters) to generate all files, one by one.
Use `generate.py list` to get the list of files the script generates.
Use `generate.py todo` to get the list of files not yet generated and did not timeout.
Use `generate.py <REGEXP>` to generate all files matching the given input.
You can use this to quickly generate files in parallel on a cluster.
The `generate-slurm.sh` does this, use `sbatch -N... -p... generate-slurm.sh`.

The scripts `exp-cluster.py` and `exp48.py` are configured to run on 16-core machines and 48-core machines respectively.

For a simple small example, you can generate some LDD files with `generate.py` and then use `exp-simple.py run` to run "simple" experiments.

With `exp-simple.py cache` you can populate a cache file but this is optional.
With `exp-simple.py report` you get a report of the status of all experiments.
With `exp-simple.py csv` you get a CSV file of the results.

The log files of the 16-core machine cluster are in logs-cluster.tar.gz and the log files of the 48-core machine experiments are in logs-48.tar.gz.
The generated CSV files are in results.csv (for the 16-core cluster) and results48.csv

To analyse these results we used R and have provided two R scripts `analyse.r` and `analyse48.r`. (Unfortunately these are not part of the artifact, R wants internet to install packages.)
The R scripts generate the tables and numbers that we used in the empirical evaluation.

Running a Promela example
-----

To run the Promela example of the GARP protocol run the commandline `tools/prom2lts-sym Promela/garp_1b2a.prm --saturation=sat -rf`.
After approximately a minute LTSmin should output `prom2lts-sym: state space has 385000995634 states, 487405 nodes`.
