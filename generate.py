#!/usr/bin/env python3
from contextlib import contextmanager
import os
import random
import re
from subprocess import Popen, TimeoutExpired
import sys
import tarfile


DIVINE = os.path.abspath("tools/divine")
PNML2LTSSYM = os.path.abspath("tools/pnml2lts-sym")
DVE2LTSSYM = os.path.abspath("tools/dve2lts-sym")
LDD2BDD = os.path.abspath("tools/ldd2bdd")
LDD2MEDDLY = os.path.abspath("tools/ldd2meddly")
TIMEOUT = 3600


patterns = [
    (r'ARMCacheCoherence', 'none'),
    (r'AirplaneLD-pt-(\d+)', r'\3'),
    (r'angiogenesis-(\d+)', r'\3'),
    (r'afcs_(\d+)_(\w)', r'\3\4'),
    (r'BridgeAndVehicles-(V..)-(P..)-(N..)-unfolded', r'\3\4\5'),
    (r'cs_repetitions-(.)-unfolded', r'0\3'),
    (r'cs_repetitions-(..)-unfolded', r'\3'),
    (r'circadian_clock-(\d+)', r'\3'),
    (r'CircularTrain-(...)', r'\3'),
    (r'deploy_(.)_(.)', r'\3\4'),
    (r'des_(..)_(.)', r'\3\4'),
    (r'dlcsh_(.)_(.)', r'\3\4'),
    (r'dnawalk-(..)', r'\3'),
    (r'database(.)UNFOLD', r'0\3'),
    (r'database(..)UNFOLD', r'\3'),
    (r'dekker-(..)', r'0\3'),
    (r'dekker-(...)', r'\3'),
    (r'2D8_gradient_5x5_(..)', r'D05N0\3'),
    (r'2D8_gradient_5x5_(...)', r'D05N\3'),
    (r'2D8_gradient_(..)x.._(..)', r'D\3N0\4'),
    (r'2D8_gradient_(..)x.._(...)', r'D\3N\4'),
    (r'distributeur-01-unfolded-(..)', r'\3'),
    (r'erk-(\d+)', r'\3'),
    (r'echo-d(.)r(.)', r'd0\3r0\4'),
    (r'echo-d(.)r(..)', r'd0\3r\4'),
    (r'EnergyBus', r'none'),
    (r'eratosthenes-(...)', r'\3'),
    (r'FMS-(.)', r'00\3'),
    (r'FMS-(..)', r'0\3'),
    (r'FMS-(...)', r'\3'),
    (r'G-PPP-1-1',           r'C0001N0000000001'),
    (r'G-PPP-1-10',          r'C0001N0000000010'),
    (r'G-PPP-1-100',         r'C0001N0000000100'),
    (r'G-PPP-1-1000',        r'C0001N0000001000'),
    (r'G-PPP-1-10000',       r'C0001N0000010000'),
    (r'G-PPP-1-100000',      r'C0001N0000100000'),
    (r'G-PPP-10-10',         r'C0010N0000000010'),
    (r'G-PPP-10-100',        r'C0010N0000000100'),
    (r'G-PPP-10-1000000000', r'C0010N1000000000'),
    (r'G-PPP-100-10',        r'C0100N0000000010'),
    (r'G-PPP-100-100',       r'C0100N0000000100'),
    (r'G-PPP-100-1000',      r'C0100N0000001000'),
    (r'G-PPP-100-10000',     r'C0100N0000010000'),
    (r'G-PPP-100-100000',    r'C0100N0000100000'),
    (r'G-PPP-1000-10',       r'C1000N0000000010'),
    (r'G-PPP-1000-100',      r'C1000N0000000100'),
    (r'G-PPP-1000-1000',     r'C1000N0000001000'),
    (r'galloc_res-(.)', r'0\3'),
    (r'HouseConstruction-(...)', r'\3'),
    (r'hc(.)k(.)p(.)b(..)', r'C\3K\4P\5B\6'),
    (r'ht_(d.k.p.b..)', r'\3'),
    (r'IBM(\w+)', r'none'),
    (r'IOTP_c(.)m(.)p(.)d(.)', r'C0\3M0\4P0\5D0\6'),
    (r'IOTP_c(..)m(..)p(..)d(..)', r'C\3M\4P\5D\6'),
    (r'Kanban-(.)', r'000\3'),
    (r'Kanban-(..)', r'00\3'),
    (r'Kanban-(...)', r'0\3'),
    (r'Kanban-(....)', r'\3'),
    (r'lamport_fmea-(.)', r'\3'),
    (r'MAPK-(.)', r'00\3'),
    (r'MAPK-(..)', r'0\3'),
    (r'MAPK-(...)', r'\3'),
    (r'MultiwaySync', r'none'),
    (r'neoelection-(.).unf', r'\3'),
    (r'PaceMaker', r'none'),
    (r'closed_system(.)', r'\3'),
    (r'open_system_(.)', r'\3'),
    (r'parking_(.)_(.)', r'\g<3>0\4'),
    (r'parking_(.)_(..)', r'\3\4'),
    (r'unf-8x8-4stageSEN-(..)', r'\3'),
    (r'Peterson-(.)', r'\3'),
    (r'(.)-10_phaseVariation', r'D0\3CS010'),
    (r'(..)-10_phaseVariation', r'D\3CS010'),
    (r'(.)-100_phaseVariation', r'D0\3CS100'),
    (r'(..)-100_phaseVariation', r'D\3CS100'),
    (r'Philosophers-(.)', r'00000\3'),
    (r'Philosophers-(..)', r'0000\3'),
    (r'Philosophers-(...)', r'000\3'),
    (r'Philosophers-(....)', r'00\3'),
    (r'Philosophers-(.....)', r'0\3'),
    (r'philo_dyn-(.)-unfolded', r'0\3'),
    (r'philo_dyn-(..)-unfolded', r'\3'),
    (r'planning', r'none'),
    (r'PolyORB-LF-(S..)-(J..)-(T..)-unfolded', r'\3\4\5'),
    (r'PolyORB-NT-(S..)-(J..)-unfolded', r'\3\4'),
    (r'ProductionCell', r'none'),
    (r'QCertifProtocol_(..)-unfold', r'\3'),
    (r'raft_(..)', r'\3'),
    (r'railroad-(...)-pt', r'\3'),
    (r'RAS-C-(.)', r'R003C00\3'),
    (r'RAS-C-(..)', r'R003C0\3'),
    (r'RAS-C-(...)', r'R003C\3'),
    (r'RAS-R-(.)', r'R00\3C002'),
    (r'RAS-R-(..)', r'R0\3C002'),
    (r'RAS-R-(...)', r'R\3C002'),
    (r'ring', r'none'),
    (r'rwmutex-r(..)w(..)', r'r00\3w00\4'),
    (r'rwmutex-r(...)w(..)', r'r0\3w00\4'),
    (r'rwmutex-r(....)w(..)', r'r\3w00\4'),
    (r'rwmutex-r(..)w(...)', r'r00\3w0\4'),
    (r'rwmutex-r(..)w(....)', r'r00\3w\4'),
    (r'SafeBus-(..)-unfolded', r'\3'),
    (r'shared_memory-pt-(.)', r'00000\3'),
    (r'shared_memory-pt-(..)', r'0000\3'),
    (r'shared_memory-pt-(...)', r'000\3'),
    (r'simple_lbs-(.)', r'0\3'),
    (r'simple_lbs-(..)', r'\3'),
    (r'SmallOperatingSystem-(MT....DC....)', r'\3'),
    (r'soli0_square5', r'SqrNC5x5'),
    (r'soli0_counter_square5', r'SqrCT5x5'),
    (r'soli1', r'EngNC7x7'),
    (r'soli1_counter', r'EngCT7x7'),
    (r'soli2', r'FrnNC7x7'),
    (r'soli2_counter', r'FrnCT7x7'),
    (r'sg-(.)-(.)-(.)', r'0\g<3>0\g<4>0\g<5>'),
    (r'sg-(..)-(.)-(..)', r'\g<3>0\g<4>\g<5>'),
    (r'SwimmingPool-(.)', r'0\3'),
    (r'SwimmingPool-(..)', r'\3'),
    (r'tcp(.)', r'0\3'),
    (r'tcp(..)', r'\3'),
    (r'TokenRing-(.)-unfolded', r'00\3'),
    (r'TokenRing-(..)-unfolded', r'0\3'),
    (r'trg_(\d+)-(\d+)-(\d+)', r'\3\4\5'),
    (r'UtahNoC', r'none'),
    (r'Vasy2003', r'none'),
]


def apply_patterns(n):
    for p,q in patterns:
        n = re.sub(r'^(\w+)/(\w+)/{}.pnml$'.format(p), r'\1-\2-{}.pnml'.format(q), n)
    return n


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
    outp = "{}-rbs.ldd".format(name)
    return {'inp': inp, 'outp': outp, 'cddir': directory,
            'the_call': [PNML2LTSSYM, "-rbs", inp, outp, "--saturation=sat", "--vset=lddmc", "--lace-workers=4", "--when"]}


def prepare_rf_ldd(directory, name):
    inp = "{}.pnml".format(name)
    outp = "{}-rf.ldd".format(name)
    return {'inp': inp, 'outp': outp, 'cddir': directory,
            'the_call': [PNML2LTSSYM, "-rf", inp, outp, "--saturation=sat", "--vset=lddmc", "--lace-workers=4", "--when"]}


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
        if sys.argv[1] == 'download':
            from bs4 import BeautifulSoup
            import requests
            import wget

            BASEURL = "https://mcc.lip6.fr/2016/archives/"
            soup = BeautifulSoup(requests.get(BASEURL).text, features='html5lib')
            links = [l.get('href') for l in soup.find_all('a')]
            tgz = filter(lambda s: 'pnml' in s, links)

            for f in filter(lambda f: not os.path.isfile('mcc/'+f), tgz):
                wget.download(BASEURL+f, 'mcc/'+f)
        elif sys.argv[1] == 'pnml':
            # first prepare the pnml models
            for name in ext_files("mcc", ".tar.gz"):
                tar = tarfile.open('mcc/'+name+'.tar.gz', "r:gz")
                for n in filter(lambda n: 'pnml' in n and 'PT' in n, tar.getnames()):
                    # apply patterns to get correct filename
                    pnmlfile = apply_patterns(n)
                    if not os.path.isfile('mcc/'+pnmlfile):
                        print("Extracting {}...".format(pnmlfile))
                        with open("mcc/"+pnmlfile, "wb") as out:
                            f = tar.extractfile(n)
                            out.write(f.read())
        elif sys.argv[1] == 'list':
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
