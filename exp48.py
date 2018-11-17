#!/usr/bin/env python3
from expfw import ExperimentEngine, Experiment
from exp import LDDExperiments, BDDExperiments, MDDExperiments, PNMLExperiments
import re
import sys

# For the 48-core experiments

ITERATIONS = 1
TIMEOUT = 1200
WORKERS = [1, 8, 16, 24, 32, 40, 48]

MODELS = [
    "Angiogenesis-PT-10",
    "BridgeAndVehicles-PT-V20P10N10",
    "BridgeAndVehicles-PT-V20P10N20",
    "BridgeAndVehicles-PT-V20P20N10",
    "BridgeAndVehicles-PT-V20P20N20",
    "CSRepetitions-PT-04",
    "Dekker-PT-015",
    "Dekker-PT-020",
    "Kanban-PT-0050",
    "LamportFastMutEx-PT-5",
    "PhilosophersDyn-PT-10",
    "QuasiCertifProtocol-PT-06",
    "RwMutex-PT-r0010w0500",
    "RwMutex-PT-r0010w1000",
    "RwMutex-PT-r0010w2000",
    "RwMutex-PT-r0020w0010",
    "SafeBus-PT-06",
    "SmallOperatingSystem-PT-MT0128DC0064",
    "SmallOperatingSystem-PT-MT0256DC0064",
    "Solitaire-PT-EngNC7x7",
    "SwimmingPool-PT-02",
    "SwimmingPool-PT-03",
    "SwimmingPool-PT-07",
    "TCPcondis-PT-10",
]

def in_MODELS(x):
    for y in MODELS:
        if x.name.startswith(y):
            return True
    return False

def is_LDD_SAT(x):
    return x.method == "ldd-sat" or x.method == "otf-ldd-sat" or x.method == "rf-otf-ldd-sat"

engine = ExperimentEngine(logdir="logs-48", cachefile="cache-48.json", timeout=TIMEOUT)
engine += LDDExperiments("mcc", WORKERS)
engine += PNMLExperiments("mcc", WORKERS)

engine.setfilter(lambda x: in_MODELS(x) and is_LDD_SAT(x))


### The rest is pretty standard


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def uprint(*args, **kwargs):
    eprint(sys.argv[0] + " ", end="")
    print(*args, file=sys.stderr, **kwargs)


def usage():
    eprint("Valid calls:")
    uprint("todo           List all groups to do")
    uprint("report         Report all experiments")
    uprint("run            Run all experiments")
    uprint("report <GROUP> Report all experiments in a group")
    uprint("run <GROUP>    Run all experiments in a group")
    uprint("cache          Update the cache")
    uprint("csv            Write the CSV of the results to stdout")


def main():
    if len(sys.argv) > 1:
        if sys.argv[1] == 'todo':
            engine.initialize(ITERATIONS, False)
            for x in engine.todo(iterations=ITERATIONS):
                print(x)
        elif sys.argv[1] == 'report':
            engine.initialize(ITERATIONS, False)
            if len(sys.argv) > 2:
                engine.report(group=sys.argv[2], iterations=ITERATIONS)
            else:
                engine.report(iterations=ITERATIONS)
        elif sys.argv[1] == 'run':
            engine.initialize(ITERATIONS, False)
            if len(sys.argv) > 2:
                engine.run(group=sys.argv[2], iterations=ITERATIONS)
            else:
                engine.run(iterations=ITERATIONS)
        elif sys.argv[1] == 'cache':
            engine.initialize(ITERATIONS, True)
            engine.save_cache(True)
            count_done = sum([len(x) for i, x in enumerate(engine.results) if i < ITERATIONS])
            count_to = sum([1 for i, x in enumerate(engine.results) for a,b in x.items() if b[0] == Experiment.TIMEOUT and b[1] < TIMEOUT])
            print("Remaining: {} experiments not done + {} experiments rerun for higher timeout.".format(ITERATIONS*len(engine)-count_done, count_to))
        elif sys.argv[1] == 'csv':
            engine.initialize(ITERATIONS, False)
            expmap = {e.name: e for e in engine}
            for i, it in enumerate(engine.results):
                if i > ITERATIONS:
                    break
                for ename, res in it.items():
                    e = expmap[ename]
                    status, value = res
                    if status == Experiment.DONE and 'states' in value:
                        print("{}; {}; {}; {}; {}".format(e.group, e.method, e.workers, value['time'], value['states']))
                    elif status == Experiment.DONE:
                        print("{}; {}; {}; {}; 0".format(e.group, e.method, e.workers, value['time']))
                    elif status == Experiment.TIMEOUT:
                        print("{}; {}; {}; {}; -1".format(e.group, e.method, e.workers, value))
        else:
            usage()
    else:
        usage()


if __name__ == "__main__":
    main()
