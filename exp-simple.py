#!/usr/bin/env python3
from expfw import ExperimentEngine, Experiment
from exp import LDDExperiments, BDDExperiments, MDDExperiments, PNMLExperiments
import sys

ITERATIONS = 1
TIMEOUT = 60
WORKERS = [1, 2, 4]

engine = ExperimentEngine(logdir="logs-simple", cachefile="cache-simple.json", timeout=TIMEOUT)
engine += LDDExperiments("mcc", WORKERS)
engine += BDDExperiments("mcc", WORKERS)
engine += MDDExperiments("mcc")
# engine += PNMLExperiments("mcc", WORKERS)


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def usage():
    eprint("Valid calls:")
    eprint("exp-simple.py todo           List all groups to do")
    eprint("exp-simple.py report         Report all experiments")
    eprint("exp-simple.py report <GROUP> Report all experiments in a group")
    eprint("exp-simple.py run            Run all experiments")
    eprint("exp-simple.py run <GROUP>    Run a group")
    eprint("exp-simple.py cache          Update the cache")
    eprint("exp-simple.py csv            Write the CSV of the results to stdout")


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
