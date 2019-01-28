#!/usr/bin/env python3
import os
import re

# import framework
from expfw import Experiment


DIVINE = "tools/divine"
PNML2LTSSYM = "tools/pnml2lts-sym"
DVE2LTSSYM = "tools/dve2lts-sym"
LDDMC = "tools/lddmc"
BDDMC = "tools/bddmc"
MEDMC = "tools/medmc"


###
# First we have some classes implementing Experiment
# They implement:
# - <parse_log> to parse a log file into a result dictionary (or None)
# - <get_text> to obtain a textual description from a result dictionary
###

class ExpLTSmin(Experiment):
    def parse_log(self, contents):
        res = {}
        # Read required reachability time
        s = re.compile(r'reachability took ([\d\.,]+)').findall(contents)
        if len(s) != 1:
            # There was an error, find it
            if re.search('Make sure the initial marking', contents):
                return {'error': 'Initial marking does not fit integer?'}
            if re.search('Got invalid permutation from boost', contents):
                return {'error': 'invalid permutation from boost'}
            if re.search('segmentation fault', contents):
                return {'error': 'segmentation fault'}
            if re.search('MDD Unique table full', contents):
                return {'error': 'out of memory'}
            return None
        res['time'] = float(s[0])
        # Read optional state space size
        s = re.compile(r'state space has precisely ([\d\.,]+) states, ([\d\.,]+) nodes').findall(contents)
        if len(s) == 1:
            res['states'] = int(s[0][0])
            res['nodes'] = int(s[0][1])
        # Read optional size of group_next
        s = re.compile(r'group_next: ([\d\.,]+) nodes total').findall(contents)
        if len(s) == 1:
            res['nextnodes'] = int(s[0])
        return res

    def get_text(self, res):
        if 'error' in res:
            return res['error']
        return "{} seconds".format(res['time'])


class ExpBDDSatF(ExpLTSmin):
    def __init__(self, exe, name, workers, model):
        self.group = name
        self.workers = workers
        self.method = "rf-otf-bdd-sat"
        self.name = "{}-rf-otf-bdd-sat-{}".format(name, workers)
        self.call = [exe, "--when", "--precise", "-rf", "--lace-workers={}".format(workers), "--vset=sylvan", "--saturation=sat", model]


class ExpLDDSatF(ExpLTSmin):
    def __init__(self, exe, name, workers, model):
        self.group = name
        self.workers = workers
        self.method = "rf-otf-ldd-sat"
        self.name = "{}-rf-otf-ldd-sat-{}".format(name, workers)
        self.call = [exe, "--when", "--precise", "-rf", "--lace-workers={}".format(workers), "--vset=lddmc", "--saturation=sat", model]


class ExpBDDSatBS(ExpLTSmin):
    def __init__(self, exe, name, workers, model):
        self.group = name
        self.workers = workers
        self.method = "rbs-otf-bdd-sat"
        self.name = "{}-rbs-otf-bdd-sat-{}".format(name, workers)
        self.call = [exe, "--when", "--precise", "-rbs", "--lace-workers={}".format(workers), "--vset=sylvan", "--saturation=sat", model]


class ExpLDDSatBS(ExpLTSmin):
    def __init__(self, exe, name, workers, model):
        self.group = name
        self.workers = workers
        self.method = "rbs-otf-ldd-sat"
        self.name = "{}-rbs-otf-ldd-sat-{}".format(name, workers)
        self.call = [exe, "--when", "--precise", "-rbs", "--lace-workers={}".format(workers), "--vset=lddmc", "--saturation=sat", model]


class ExpLDD(Experiment):
    def __init__(self, name, workers, model):
        self.group = name
        self.workers = workers
        self.method = "ldd-sat"
        self.name = "{}-ldd-sat-{}".format(name, workers)
        self.call = [LDDMC, "-s", "sat", "-w", str(workers), str(model)]
        self.model = model

    def parse_log(self, contents):
        res = {}
        s = re.compile(r'SAT Time: ([\d\.,]+)').findall(contents)
        if len(s) != 1:
            return None
        res['time'] = float(s[0])
        s = re.compile(r'Final states: ([\d\.,]+) states').findall(contents)
        if len(s) == 1:
            res['states'] = int("".join(s[0].split(",")))
        return res

    def get_text(self, res):
        if 'states' in res:
            return "{} seconds, {} states".format(res['time'], res['states'])
        else:
            return "{} seconds".format(res['time'])

    def run_experiment(self, *args, **kwargs):
        if os.path.isfile(self.model):
            super(ExpLDD, self).run_experiments(*args, **kwargs)


class ExpLDDPar(Experiment):
    def __init__(self, name, workers, model):
        self.group = name
        self.workers = workers
        self.method = "ldd-par"
        self.name = "{}-ldd-par-{}".format(name, workers)
        self.call = [LDDMC, "-s", "par", "-w", str(workers), str(model)]
        self.model = model

    def parse_log(self, contents):
        res = {}
        s = re.compile(r'PAR Time: ([\d\.,]+)').findall(contents)
        if len(s) != 1:
            return None
        res['time'] = float(s[0])
        s = re.compile(r'Final states: ([\d\.,]+) states').findall(contents)
        if len(s) == 1:
            res['states'] = int("".join(s[0].split(",")))
        return res

    def get_text(self, res):
        if 'states' in res:
            return "{} seconds, {} states".format(res['time'], res['states'])
        else:
            return "{} seconds".format(res['time'])

    def run_experiment(self, *args, **kwargs):
        if os.path.isfile(self.model):
            super(ExpLDDPar, self).run_experiments(*args, **kwargs)


class ExpLDDChaining(Experiment):
    def __init__(self, name, workers, model):
        self.group = name
        self.workers = workers
        self.method = "ldd-chaining"
        self.name = "{}-ldd-chaining-{}".format(name, workers)
        self.call = [LDDMC, "-s", "chaining", "-w", str(workers), str(model)]
        self.model = model

    def parse_log(self, contents):
        res = {}
        s = re.compile(r'CHAINING Time: ([\d\.,]+)').findall(contents)
        if len(s) != 1:
            return None
        res['time'] = float(s[0])
        s = re.compile(r'Final states: ([\d\.,]+) states').findall(contents)
        if len(s) == 1:
            res['states'] = int("".join(s[0].split(",")))
        return res

    def get_text(self, res):
        if 'states' in res:
            return "{} seconds, {} states".format(res['time'], res['states'])
        else:
            return "{} seconds".format(res['time'])

    def run_experiment(self, *args, **kwargs):
        if os.path.isfile(self.model):
            super(ExpLDDChaining, self).run_experiments(*args, **kwargs)


class ExpBDD(Experiment):
    def __init__(self, name, workers, model):
        self.group = name
        self.workers = workers
        self.method = "bdd-sat"
        self.name = "{}-bdd-sat-{}".format(name, workers)
        self.call = [BDDMC, "-s", "sat", "-w", str(workers), str(model)]
        self.model = model

    def parse_log(self, contents):
        res = {}
        s = re.compile(r'SAT Time: ([\d\.,]+)').findall(contents)
        if len(s) != 1:
            return None
        res['time'] = float(s[0])
        s = re.compile(r'Final states: ([\d\.,]+) states').findall(contents)
        if len(s) == 1:
            res['states'] = int("".join(s[0].split(",")))
        return res

    def get_text(self, res):
        if 'states' in res:
            return "{} seconds, {} states".format(res['time'], res['states'])
        else:
            return "{} seconds".format(res['time'])

    def run_experiment(self, *args, **kwargs):
        if os.path.isfile(self.model):
            super(ExpBDD, self).run_experiments(*args, **kwargs)

class ExpMDD(Experiment):
    def __init__(self, name, model):
        self.group = name
        self.workers = 1
        self.method = "mdd-sat"
        self.name = "{}-mdd-sat".format(name)
        self.call = [MEDMC, str(model)]
        self.model = model

    def parse_log(self, contents):
        res = {}
        s = re.compile(r'MEDDLY Time: ([\d\.,]+)').findall(contents)
        if len(s) != 1:
            if re.search('MEDDLY error: Invalid file', contents):
                return {'error': 'invalid MDD file'}
            return None
        res['time'] = float(s[0])
        s = re.compile(r'States: ([\d\.,]+)').findall(contents)
        if len(s) == 1:
            res['states'] = int("".join(s[0].split(",")))
        return res

    def get_text(self, res):
        if 'states' in res:
            return "{} seconds, {} states".format(res['time'], res['states'])
        else:
            return "{} seconds".format(res['time'])

    def run_experiment(self, *args, **kwargs):
        if os.path.isfile(self.model):
            super(ExpMDD, self).run_experiments(*args, **kwargs)


class FileFinder(object):
    def __init__(self, directory, extensions):
        self.directory = directory
        self.extensions = extensions

    def __iter__(self):
        if not hasattr(self, 'files'):
            self.files = []
            for ext in self.extensions:
                dotext = "." + ext
                # get all files in directory ending with the extension
                files = [f[:-len(dotext)] for f in filter(lambda f: f.endswith(dotext) and os.path.isfile(self.directory+"/"+f), os.listdir(self.directory))]
                self.files.extend([(x, "{}/{}{}".format(self.directory, x, dotext)) for x in files])
        return self.files.__iter__()


class LDDExperiments(object):
    def __init__(self, directory, workers):
        self.files = FileFinder(directory, ["pnml"])
        self.workers = workers

    def dicts(self):
        dicts = []
        for w in self.workers:
            dicts.append("s_" + str(w))
            dicts.append("c_" + str(w))
            dicts.append("p_" + str(w))
        return dicts

    def prepare(self):
        for d in self.dicts():
            setattr(self, d, {})
        self.grouped = {}
        for name, filename in self.files:
            # with -rf
            for w in self.workers:
                getattr(self, "s_"+str(w))[name+"-rf"] = ExpLDD(name+"-rf", w, filename[:-5]+"-rf")
                getattr(self, "c_"+str(w))[name+"-rf"] = ExpLDDChaining(name+"-rf", w, filename[:-5]+"-rf")
                getattr(self, "p_"+str(w))[name+"-rf"] = ExpLDDPar(name+"-rf", w, filename[:-5]+"-rf")
            self.grouped[name+"-rf"] = [getattr(self, d)[name+"-rf"] for d in self.dicts()]
            # with -rbs
            for w in self.workers:
                getattr(self, "s_"+str(w))[name+"-rbs"] = ExpLDD(name+"-rbs", w, filename[:-5]+"-rbs")
                getattr(self, "c_"+str(w))[name+"-rbs"] = ExpLDDChaining(name+"-rbs", w, filename[:-5]+"-rbs")
                getattr(self, "p_"+str(w))[name+"-rbs"] = ExpLDDPar(name+"-rbs", w, filename[:-5]+"-rbs")
            self.grouped[name+"-rbs"] = [getattr(self, d)[name+"-rbs"] for d in self.dicts()]

    def __iter__(self):
        if not hasattr(self, 'grouped'):
            self.prepare()
        return self.grouped.values().__iter__()


class BDDExperiments(object):
    def __init__(self, directory, workers):
        self.files = FileFinder(directory, ["pnml"])
        self.workers = workers

    def dicts(self):
        dicts = []
        for w in self.workers:
            dicts.append("s_" + str(w))
        return dicts

    def prepare(self):
        for d in self.dicts():
            setattr(self, d, {})
        self.grouped = {}
        for name, filename in self.files:
            # with -rf
            for w in self.workers:
                getattr(self, "s_"+str(w))[name+"-rf"] = ExpBDD(name+"-rf", w, filename[:-5]+"-rf.bdd")
            self.grouped[name+"-rf"] = [getattr(self, d)[name+"-rf"] for d in self.dicts()]
            # with -rbs
            for w in self.workers:
                getattr(self, "s_"+str(w))[name+"-rbs"] = ExpBDD(name+"-rbs", w, filename[:-5]+"-rbs.bdd")
            self.grouped[name+"-rbs"] = [getattr(self, d)[name+"-rbs"] for d in self.dicts()]

    def __iter__(self):
        if not hasattr(self, 'grouped'):
            self.prepare()
        return self.grouped.values().__iter__()


class MDDExperiments(object):
    def __init__(self, directory):
        self.files = FileFinder(directory, ["pnml"])

    def dicts(self):
        return ["s"]

    def prepare(self):
        self.s = {}
        self.grouped = {}
        for name, filename in self.files:
            # one with -rf, one with -rbs
            self.s[name+"-rf"] = ExpMDD(name+"-rf", filename[:-5]+"-rf.mdd")
            self.grouped[name+"-rf"] = [getattr(self, d)[name+"-rf"] for d in self.dicts()]
            self.s[name+"-rbs"] = ExpMDD(name+"-rbs", filename[:-5]+"-rbs.mdd")
            self.grouped[name+"-rbs"] = [getattr(self, d)[name+"-rbs"] for d in self.dicts()]

    def __iter__(self):
        if not hasattr(self, 'grouped'):
            self.prepare()
        return self.grouped.values().__iter__()


class PNMLExperiments(object):
    def __init__(self, directory, workers):
        self.files = FileFinder(directory, ["pnml"])
        self.workers = workers

    def dicts(self):
        dicts = []
        for w in self.workers:
            dicts.append("lf_" + str(w))
            dicts.append("ls_" + str(w))
        return dicts

    def prepare(self):
        for d in self.dicts():
            setattr(self, d, {})
        self.grouped = {}
        for name, filename in self.files:
            for w in self.workers:
                getattr(self, "lf_"+str(w))[name] = ExpLDDSatF(PNML2LTSSYM, name, w, filename)
                getattr(self, "ls_"+str(w))[name] = ExpLDDSatBS(PNML2LTSSYM, name, w, filename)
            self.grouped[name] = [getattr(self, d)[name] for d in self.dicts()]

    def __iter__(self):
        if not hasattr(self, 'grouped'):
            self.prepare()
        return self.grouped.values().__iter__()
