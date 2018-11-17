#!/bin/bash

for g in `./generate.py todo`
do
    # echo $g
    srun -N1 -n1 -c16 --exclusive -o job%J.out ./generate.py "$g" &
done

wait
