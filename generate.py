#!/usr/bin/env python3
from contextlib import contextmanager
import os
import random
import re
from subprocess import Popen, TimeoutExpired
import sys


DIVINE = os.path.abspath("tools/divine")
PNML2LTSSYM = os.path.abspath("tools/pnml2lts-sym")
DVE2LTSSYM = os.path.abspath("tools/dve2lts-sym")
LDD2BDD = os.path.abspath("tools/ldd2bdd")
LDD2MEDDLY = os.path.abspath("tools/ldd2meddly")
TIMEOUT = 3600


@contextmanager
def cd(newdir):
    prevdir = os.getcwd()
    os.chdir(os.path.expanduser(newdir))
    try:
        yield
    finally:
        os.chdir(prevdir)


def call(*popenargs, timeout, **kwargs):
    """
    Run a call with a timeout.
    """
    with Popen(*popenargs, **kwargs) as p:
        try:
            return p.wait(timeout=timeout)
        except:
            p.terminate()
            p.wait()
            raise


def call2(*popenargs, timeout, outp):
    """
    Run a call with a timeout.
    If the call is interrupted with Ctrl-C, copy outp to outp.interrupted
    If the call times out, copy outp to outp.timeout-<TIMEOUT>
    """
    timeout_filename = "{}.timeout-{}".format(outp, timeout)
    if os.path.isfile(timeout_filename):
        print("\033[1;31mTimeout!\033[m")
        return
    try:
        call(*popenargs, timeout=timeout)
    except KeyboardInterrupt:
        if os.path.isfile(outp):
            os.rename(outp, "{}.interrupted".format(outp))
        sys.exit()
    except TimeoutExpired:
        if os.path.isfile(outp):
            os.rename(outp, timeout_filename)
        else:
            open(timeout_filename, 'a').close()
        print("\033[1;31mTimeout!\033[m")


def call3(inp, outp, the_call, cddir):
    """
    Run the prepared call with default timeout.
    """
    with cd(cddir):
        if not os.path.isfile(outp):
            print("\033[1;32mGenerating {}...\033[m".format(outp))
# try for 10 minutes
            call2(the_call, timeout=TIMEOUT, outp=outp)


def outp_exists(inp, outp, the_call, cddir):
    """
    Return true if the output file exists, false otherwise.
    """
    with cd(cddir):
        return os.path.isfile(outp)


def timeout_exists(inp, outp, the_call, cddir):
    """
    Return true if the timeout file exists, false otherwise.
    """
    with cd(cddir):
        timeout_filename = "{}.timeout-{}".format(outp, TIMEOUT)
        return os.path.isfile(timeout_filename)


def ext_files(directory, dotext, randomize=True):
    """
    Return stripped filenames in directory ending with <dotext>.
    Example: ext_files("models", ".pnml")
    """
    files = list(filter(lambda f: os.path.isfile(directory+"/"+f), os.listdir(directory)))
    files = [f[:-len(dotext)] for f in filter(lambda f: f.endswith(dotext), files)]
    if randomize:
        random.shuffle(files)
    return files


def prepare_dve2C(directory, name):
    inp = "{}.dve".format(name)
    outp = "{}.dve2C".format(name)
    return {'inp': inp, 'outp': outp, 'cddir': directory,
            'the_call': [DIVINE, "compile", "-l", inp]}


def prepare_rbs_ldd(directory, name):
    inp = "{}.pnml".format(name)
    outp = "{}.ldd".format(name)
    return {'inp': inp, 'outp': outp, 'cddir': directory,
            'the_call': [PNML2LTSSYM, "-rbs", inp, outp, "--saturation=sat", "--vset=lddmc"]}


def prepare_rf_ldd(directory, name):
    inp = "{}.pnml".format(name)
    outp = "{}-rf.ldd".format(name)
    return {'inp': inp, 'outp': outp, 'cddir': directory,
            'the_call': [PNML2LTSSYM, "-rf", inp, outp, "--saturation=sat", "--vset=lddmc"]}


def prepare_rbs_bdd(directory, name):
    inp = "{}.pnml".format(name)
    outp = "{}.bdd".format(name)
    return {'inp': inp, 'outp': outp, 'cddir': directory,
            'the_call': [PNML2LTSSYM, "-rbs", inp, outp, "--saturation=sat", "--vset=sylvan", "--sylvan-bits=1"]}


def prepare_rf_bdd(directory, name):
    inp = "{}.pnml".format(name)
    outp = "{}-rf.bdd".format(name)
    return {'inp': inp, 'outp': outp, 'cddir': directory,
            'the_call': [PNML2LTSSYM, "-rf", inp, outp, "--saturation=sat", "--vset=sylvan", "--sylvan-bits=1"]}


def prepare_ldd2bdd(directory, name):
    inp = "{}.ldd".format(name)
    outp = "{}.bdd".format(name)
    return {'inp': inp, 'outp': outp, 'cddir': directory,
            'the_call': [LDD2BDD, inp, outp]}


def prepare_ldd2meddly(directory, name):
    inp = "{}.ldd".format(name)
    outp = "{}.mdd".format(name)
    return {'inp': inp, 'outp': outp, 'cddir': directory,
            'the_call': [LDD2MEDDLY, inp, outp]}


def sanity(calls):
    # sanity check
    # for now, just check that each call has a different output file
    outp_list = [c['outp'] for c in calls]
    outp_set = set(outp_list)
    if len(outp_set) != len(calls):
        print("Sanity check failed!")
        # list offending calls
        for x in outp_set:
            if sum([1 for y in outp_list if y == x]) != 1:
                print("{} occurs multiple times as output file!".format(x))
        exit(0)


if __name__ == "__main__":
    calls = []

    # get pnml models from mcc directory
    # create LDD and BDD (1-safe) encodings using LTSmin
    for name in ext_files("mcc", ".pnml"):
        calls += [prepare_rf_ldd("mcc", name)]
        calls += [prepare_rbs_ldd("mcc", name)]

    for name in ext_files("mcc", ".ldd"):
        calls += [prepare_ldd2bdd("mcc", name)]
        calls += [prepare_ldd2meddly("mcc", name)]

    # get dve models from dve directory
    # for name in ext_files("dve", ".dve"):
    #     calls += [prepare_dve2C("dve", name)]
    #     calls += [prepare_dve2C_rf_ldd("dve", name)] .....

    sanity(calls)

    # ./generate.py list (return all files this script generates)
    # ./generate.py todo (return all files this script would generate)
    # ./generate.py <regexp> (generate all files matching regular expression)
    if len(sys.argv) > 1:
        if sys.argv[1] == 'list':
            for c in calls:
                print(c['outp'])
        elif sys.argv[1] == 'todo':
            for c in calls:
                if not outp_exists(**c) and not timeout_exists(**c):
                    print(c['outp'])
        else:
            for c in calls:
                if re.match(sys.argv[1], c['outp']):
                    call3(**c)
    else:
        todo_count = sum([1 for c in calls if not outp_exists(**c)])
        to_count = sum([1 for c in calls if timeout_exists(**c)])
        print("We have to generate {}/{} files! ({} timed out with {} seconds)".format(todo_count-to_count, len(calls), to_count, TIMEOUT))
        for c in calls:
            call3(**c)
