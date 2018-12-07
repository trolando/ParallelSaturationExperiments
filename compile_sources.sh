#!/bin/bash

# fail fast
set -e

# install Debian packages
pushd packages
echo a | sudo -S dpkg -i *.deb
popd

# install R packages
tar xf R.tgz -C"$HOME"

# compile Meddly
pushd meddly
./autogen.sh
./configure --disable-dependency-tracking --prefix=/usr/local --disable-shared
make
echo a | sudo -S make install
popd

# compile Sylvan
pushd sylvan
cmake -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DSYLVAN_BUILD_EXAMPLES=ON
make
echo a | sudo -S make install
popd

# compile LTSmin
tar xf ltsmin-3.1.0.tar.gz
pushd ltsmin-3.1.0
./configure --disable-dependency-tracking
make
echo a | sudo -S make install
popd

# copy all binaries to tools/
## copy Sylvan binaries
pushd sylvan/examples
cp bddmc ldd2bdd ldd2meddly lddmc medmc ../../tools
popd

## copy LTSmin's binaries
cp /usr/local/bin/* tools

# Sylvan requires one to overcommit memory; allow this.
echo a | sudo -S bash -c 'echo 1 > /proc/sys/vm/overcommit_memory'
# Now make this setting permanent in this VM.
echo a | sudo -S bash -c 'echo "vm.overcommit_memory = 1" > /etc/sysctl.d/99-sylvan.conf'

# run R scripts
./analyse.r
./analyse48.r

# run the running example from the paper with multi-core saturation and Force order
# among other lines this commandline should output "pnml2lts-sym: state space has 5 states, 12 nodes"
tools/pnml2lts-sym --saturation=sat -rf pnml/example.pnml

