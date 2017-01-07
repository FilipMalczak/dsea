module masters.experiments;

import std.path;
import std.file: exists, mkdirRecurse, readFile = read, writeFile = write,
        DirEntry, dirEntries, SpanMode;
import std.string;
import std.format;
import std.datetime;
import std.stdio;
import std.conv;
import std.typecons;
import std.array;
import std.math;

import msgpack;

import masters.ga.framework;
public import masters.ga.framework: Results;
import masters.ga.selects;
import masters.ga.utils;

import masters.tsp.impl;

struct Dataset(S) {
    string name;
    Evaluator!S evaluator;
    Generator!S generator;
}



struct ExperimentSetup(S) {
    Dataset!S[] datasets;

    double cp;
    double mp;

    size_t popSize;
    int maxEvals;

    string mutation;
    string crossover;

    string natSel;
    string genSel;

    Callback!S callback = new UsefulCallback!S(true);

    @property string name(){
        return format(
            "%s_%s_%s_%s_%s_%s_%s_%s",
            cp, mp,
            popSize, maxEvals,
            mutation, crossover,
            natSel, genSel
        );
    }

    string getPath(string root, string dataset){
        return buildPath(root, name, dataset);
    }

    ExperimentSetup!S copy(){
        return ExperimentSetup!S(datasets, cp, mp, popSize, maxEvals, mutation, crossover, natSel, genSel);
    }

    ExperimentSetup!S withValue(string name, double val){
        switch (name)
        {
            default: throw new Exception("Only cp and mp are doubles! Got "~name~" instead!");
            case "cp": {
                auto result = copy();
                result.cp = val;
                return result;
            }
            case "mp": {
                auto result = copy();
                result.mp = val;
                return result;
            }
        }
    }

    ExperimentSetup!S withValue(string name, size_t val){
        switch (name)
        {
            default: throw new Exception("Only popSize is size_t! Got "~name~" instead!");
            case "popSize": {
                auto result = copy();
                result.popSize = val;
                return result;
            }
        }
    }

    ExperimentSetup!S withValue(string name, int val){
        switch (name)
        {
            default: throw new Exception("Only popSize and maxEvals are ints! Got "~name~" instead!");
            case "popSize": {
                auto result = copy();
                result.popSize = val;
                return result;
            }
            case "maxEvals": {
                auto result = copy();
                result.maxEvals = val;
                return result;
            }
        }
    }

    ExperimentSetup!S withValue(string name, string val){
        switch (name)
        {
            default: throw new Exception("Only crossover, mutation, natSel and genSel are strings! Got "~name~" instead!");
            case "mutation": {
                auto result = copy();
                result.mutation = val;
                return result;
            }
            case "crossover": {
                auto result = copy();
                result.crossover = val;
                return result;
            }
            case "natSel": {
                auto result = copy();
                result.natSel = val;
                return result;
            }
            case "genSel": {
                auto result = copy();
                result.genSel = val;
                return result;
            }
        }
    }

    protected Dataset!S getDataset(string name){
        foreach (d; datasets)
            if (d.name == name)
                return d;
        throw new Exception("Dataset "~name~" not found!");
    }

    ExperimentRun!S build(Dataset!S dataset, int iter=0){
        ExperimentRun!S result;
        result.iter = iter;
        result.gaConfig.cp = cp;
        result.gaConfig.mp = mp;
        result.gaConfig.popSize = popSize;
        result.gaConfig.maxEvals = maxEvals;
        result.gaConfig.select = buildNatSel(natSel);
        result.gaConfig.genSel = buildGenSel(genSel);

        result.problemConfig.cross = buildCrossover(crossover);
        result.problemConfig.mut = buildMutation(mutation);
        result.problemConfig.generator = dataset.generator;
        result.problemConfig.evaluator = dataset.evaluator;

        result.callback = callback;

        return result;
    }

    ExperimentRun!(S)[] build(int iter=0){
        ExperimentRun!(S)[] result = [];
        foreach(dataset; datasets) {
            result ~= build(dataset, iter);
        }
        return result;
    }


    private Selection!S buildNatSel(string name){
        return SelectionFactory!S.getSelection(name);
    }

    private GenderSelection!S buildGenSel(string name){
        return GenSelFactory!S.getGenSel(name);
    }

    private Mutation!S buildMutation(string name){
        switch (name) {
            default: throw new Exception("WTF "~name);
            //static if (typeof(S)==Path) {
                case "reverseSubsequence": return new ReverseSubsequenceMutation();
            //}
        }
    }

    private Crossover!S buildCrossover(string name){
        switch (name) {
            default: throw new Exception("WTF "~name);
            //static if (typeof(S)==Path) {
                case "subsequence": return new SubsequenceCrossover();
            //}
        }
    }

    Results[] ensureExecution(string root, int iter=0){
        return ensureExecution(ResultsRepository(root), iter);
    }

    Results[] ensureExecution(ResultsRepository repo, int iter=0){
        Results[] result = [];
        foreach (exp; build(iter)) {
            auto name = this.name;
            auto problem = exp.problemConfig.evaluator.problem;
            auto dataset = exp.problemConfig.evaluator.dataset;
            Results lastResult;
            if (repo.has(problem, dataset, name, iter)) {
                lastResult = repo.read(problem, dataset, name, iter);
                string fullTime;
                with (std.conv.to!(Duration)(lastResult.fullDuration).split()) {
                    fullTime = format("%02d:%02d:%02d.%3d", hours, minutes, seconds, msecs);
                }
                writefln("Just saved you %s", fullTime);
            } else {
                auto expResult = exp.run();
                repo.write(problem, dataset, name, iter, expResult.results);
                lastResult = expResult.results;
            }
            result ~= lastResult;
        }
        return result;
    }

    void summarize(alias write=writeln)(ResultsRepository repo, int iter=0, string prefix="", string sep="---"){
        foreach (res; ensureExecution(repo, iter)){
            foreach (line; split(res.metadata, "\n")) {
                write(prefix ~ line);
            }
            write(prefix ~ sep);
        }
    }

    double score(ResultsRepository repo, int iters=1){
        assert(iters > 0);
        double result = 0.0;
        Results[] results = [];
        foreach (i; 0..iters){
            results ~= ensureExecution(repo, i);
        }

        foreach (r; results){
            auto scorePart = r.score(iters);
            if (isNaN(scorePart))
                throw new Exception("Score part is NaN! result: "~to!string(r));
            writeln("Result "~to!string(r)~" scored "~to!string(r.properGlobalBest)~" changing setup score by "~to!string(scorePart));
            result += scorePart;
        }
        return result;
    }

    @property string[string] params(){
        return [
            "cp": to!string(cp),
            "mp": to!string(mp),
            "popSize": to!string(popSize),
            "maxEvals": to!string(maxEvals),
            "mutation": mutation,
            "crossover": crossover,
            "natSel": natSel,
            "genSel": genSel
        ];
    }
}

struct ExperimentRun(S) {
    int iter;
    GAConfig!S gaConfig;
    ProblemConfig!S problemConfig;

    Callback!S callback;

    Context!S run(){
        auto ga = new GA!S(gaConfig, problemConfig, callback);
        writeln(Clock.currTime.toSimpleString()~" Running with "~to!string(gaConfig)~" / "~to!string(problemConfig));
        ga.run();
        ga.ctx.results.iter = iter;
        string fullTime;
        string gaTime;
        with (std.conv.to!(Duration)(ga.ctx.fullDuration).split()) {
            fullTime = format("%02d:%02d:%02d.%3d", hours, minutes, seconds, msecs);
        }
        with (std.conv.to!(Duration)(ga.ctx.gaDuration).split()) {
            gaTime = format("%02d:%02d:%02d.%3d", hours, minutes, seconds, msecs);
        }
        writeln("It took "~ fullTime ~ " altogether ("~ gaTime ~" of that was GA)");
        return ga.ctx;
    }
}

struct Params {
    string problem;
    string dataset;

    double cp;
    double mp;

    size_t popSize;
    int maxEvals;

    string mutation;
    string crossover;

    string natSel;
    string genSel;

    int iter;

     @property string setupName(){
        return format(
            "%s_%s_%s_%s_%s_%s_%s_%s",
            cp, mp,
            popSize, maxEvals,
            mutation, crossover,
            natSel, genSel
        );
    }
}

class ResultFile {
    const DirEntry dirEntry;

    protected string _name;
    protected Results _results;
    protected Params _params;

    protected bool _nameLoaded = false;
    protected bool _resultsLoaded = false;
    protected bool _paramsParsed = false;

    this(string problem, string dataset, DirEntry entry){
        dirEntry = entry;
        _params.problem = problem;
        _params.dataset = dataset;
    }

    @property string name() {
        if (!_nameLoaded) {
            foreach (part; pathSplitter(dirEntry.name))
                _name = part;
            _nameLoaded = true;
        }
        return _name;
    }

    @property Results results(){
        if (!_resultsLoaded) {
            _results = ResultsRepository.read(dirEntry.name);
            _resultsLoaded = true;
        }
        return _results;
    }

    protected void parseParams(){
        auto nameNoExt = name[0..$-4];
        auto paramsStrs = nameNoExt.split("_");
        _params.cp = to!double(paramsStrs[0]);
        _params.mp = to!double(paramsStrs[1]);
        _params.popSize = to!size_t(paramsStrs[2]);
        _params.maxEvals = to!int(paramsStrs[3]);
        _params.mutation = paramsStrs[4];
        _params.crossover = paramsStrs[5];
        _params.natSel = paramsStrs[6];
        _params.genSel = paramsStrs[7];
        _params.iter = to!int(paramsStrs[8]);
    }

    @property Params params(){
        if (!_paramsParsed) {
            parseParams();
            _paramsParsed = true;
        }
        return _params;
    }
}

struct ResultsRepository {
    string root;

    protected string path(string problem, string dataset, string name, int iter){
        return buildPath(root, problem, dataset, name~"_"~to!string(iter)~".dat");
    }

    protected string path(string problem, string dataset){
        return buildPath(root, problem, dataset);
    }

    protected string path(string problem){
        return buildPath(root, problem);
    }

    protected void ensure(string problem, string dataset){
        auto p = buildPath(root, problem, dataset);
        if (!exists(p))
            mkdirRecurse(p);
    }

    bool has(string problem, string dataset, string name, int iter){
        return exists(path(problem, dataset, name, iter));
    }

    void write(string problem, string dataset, string name, int iter, Results results){
        ubyte[] inData = pack(results);
        ensure(problem, dataset);
        writeln("Saving file "~path(problem, dataset, name, iter));
        writeFile(path(problem, dataset, name, iter), inData);
    }

    Results read(string problem, string dataset, string name, int iter){
        return read(path(problem, dataset, name, iter));
    }

    Results read(string problem, string dataset, string fileName){
        return read(buildPath(path(problem, dataset), fileName));
    }

    static Results read(string p){
        writeln("Reading file "~p);
        ubyte[] outData = cast(ubyte[])readFile(p);
        Results target = outData.unpack!Results();
        return target;
    }

    protected void each(string path, void delegate(string, DirEntry) callback,
                    bool delegate(DirEntry) predicate){
        foreach (DirEntry entry; dirEntries(path, SpanMode.shallow))
            if (predicate(entry)) {
                string name;
                foreach (part; pathSplitter(entry.name))
                    name = part;
                callback(name, entry);
            }
    }

    void eachProblem(void delegate(string, DirEntry) callback){
        each(root, callback, (entry) { return entry.isDir(); });
    }

    void eachDataset(string problem, void delegate(string, DirEntry) callback){
        each(path(problem), callback, delegate (entry) { return entry.isDir(); });
    }

    protected string ext(string path){
        return path.split(".")[$-1];
    }

    void eachRun(string problem, string dataset, void delegate(ResultFile) callback){
        each(
            path(problem, dataset),
            delegate (name, entry) {
                callback(new ResultFile(problem, dataset, entry));
            },
            delegate (entry) {
                return entry.isFile();
            }
       );
    }
}
/*
unittest {
    ResultsRepository repo = ResultsRepository("./repo");
    repo.eachDataset("tsp", delegate (name, entry) {
        writeln("name:", name, "entry", entry);
    });
    repo.eachRun("tsp", "qatar", delegate (rf) {
        writeln("results ", rf);
    });
}
*/
