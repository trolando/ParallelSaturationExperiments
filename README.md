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
First extract the tarballs in the mcc and the dve directories.

Use `generate.py` as the preprocessing step to generate LDD and BDD files from the models.
The file `generate.py` can be configured with a timeout value (in the file itself).
Use `generate.py` (without parameters) to generate all files, one by one.
Use `generate.py list` to get the list of files the script generates.
Use `generate.py todo` to get the list of files not yet generated and did not timeout.
Use `generate.py <REGEXP>` to generate all files matching the given input.
You can use this to quickly generate files in parallel on a cluster.
The `generate-slurm.sh` does this, use `sbatch -N... -p... generate-slurm.sh`.

Use `exp.py` with either parameter `run` or `report` to run the experiments or to generate a report of the results.
Use `exp.py` without parameters to receive a list of valid inputs for the script.

A specialized `exp-cluster.py` runs the experiments for the cluster with 16-core machines, just the 'offline' LDD and BDD experiments. We used `sbatch -N... -p... exp-cluster-slurm.sh` to run this.

Running a Promela example
-----

To run the Promela example of the GARP protocol run the commandline `tools/prom2lts-sym Promela/garp_1b2a.prm --saturation=sat -rf`.
After approximately a minute LTSmin should output `prom2lts-sym: state space has 385000995634 states, 487405 nodes`.
