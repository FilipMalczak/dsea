module masters.ga.framework;

import std.math: isNaN, sqrt;
import std.algorithm.comparison;
import std.algorithm.iteration;
import std.random;
import std.stdio;
import std.conv;
import std.datetime;
import std.format;
import std.array;

import std.typecons;

import masters.io;
import masters.utils;
public import masters.ga.utils;

struct Stat {
    double best = double.max;
    double worst = double.min_normal;
    double avg = 0;
    double variance = 0;

    @property double stdDev(){
        return sqrt(variance);
    }

    string toString(){
        return format("Stat(best = %f, worst = %f, avg = %f, variance = %f)", best, worst, avg, variance);
    }


}

/**
 * Used to enlarge resolution of the score
 */
const double MULITPLIER = 100.0;

struct Results {
    int genNo;
    int evals;
    size_t datasetSize;
    Stat[] stats;
    Stat[] properStats;
    TickDuration fullDuration;
    TickDuration gaDuration;

    int iter;

    @property string formattedDuration(){
        return toStr(fullDuration);
    }

    @property string metadata(){
        return format("Dataset size: %d\n" ~
                        "Generations: %d\nEvaluations: %d\n" ~
                        "All ticks: %d\nFull duration: %s\n" ~
                        "GA ticks: %d\nGA duration: %s\n" ~
                        "Global best: %f\n" ~
                        "Proper eval of global best: %f\n" ~
                        "Iteration: %d\n",
                        datasetSize,
                        genNo, evals,
                        fullDuration.length, toStr(fullDuration),
                        gaDuration.length, toStr(gaDuration),
                        globalBest, properGlobalBest,
                        iter
                    );
    }

    static double best(Stat[] theStats){
        double result = double.max;
        foreach (stat; theStats)
            if (stat.best < result)
                result = stat.best;
        return result;
    }

    static double worst(Stat[] theStats){
        double result = double.min_normal;
        foreach (stat; theStats)
            if (stat.worst > result)
                result = stat.worst;
        return result;
    }

    @property double globalBest(){
        return best(stats);
    }

    @property double properGlobalBest(){
        return best(properStats);
    }

    @property double globalWorst(){
        return worst(stats);
    }

    @property double properGlobalWorst(){
        return worst(properStats);
    }

    string toString(){
        return metadata;
    }



    @property double score(int iters=1){
        //sum of averages of (best/optimum) for each dataset
        return properGlobalBest / iters;
    }
}

class Context(S){
    int genNo=0;
    int evals=0;
    S[] pop = [];
    Stat[] stats = [];
    Stat[] properStats = [];
    TickDuration fullDuration;
    TickDuration gaDuration;
    size_t datasetSize;


    @property string metadata(){
        return results.metadata;
    }

    @property double globalBest(){
        return results.globalBest;
    }

    @property double properGlobalBest(){
        return results.properGlobalBest;
    }

    void saveStats(S)(CsvFormatter!S csv){
        foreach (stat; stats)
            with (stat) {
                string formatDouble(double x){
                    return format("%f", x);
                }
                csv.feed!string(array(map!formatDouble([best, worst, avg, stdDev, variance])));
            }
    }

    Results results(){
        return Results(genNo, evals, datasetSize, stats, properStats, fullDuration, gaDuration);
    }
}

class Specimen {
    double eval = double.nan;
    double properEval = double.nan;

    int gender = 0;
}

class Evaluator(S) {
    Context!S ctx;

    public string problem;
    public string dataset;
    abstract @property size_t datasetSize();

    double evaluate(S s){
        if (isNaN(s.eval)) {
        	auto e = getEval(s);
        	s.eval=e;
            ++ctx.evals;
        }
        return s.eval;
    }
    abstract double getEval(S s);

    double evaluateProperly(S s){
        if (isNaN(s.properEval)) {
            auto e = getProperEval(s);
            s.properEval=e;
        }
        return s.properEval;
    }

    double getProperEval(S s) {
        return evaluate(s);
    }

    override string toString(){
        return format("%s(problem: %s, dataset: %s, datasetSize: %d)",
                        this.classinfo.name,
                        problem,
                        dataset,
                        datasetSize
        );
    }
}

interface Generator(S){
    S generateRandom();

    final S[] generateMany(size_t size){
        S[] result = new S[size];
        foreach (ref s; result)
            s = generateRandom();
        return result;
    }
}



interface Mutation(S) {
    S[] mutate(S s);
}



interface Crossover(S) {
    S[] crossOver(S s1, S s2);
}

interface Selection(S) {
    S[] select(S[] pop, Evaluator!S eval, size_t size);
}

interface GenderSelection(S) {
    Tuple!(S, S)[] select(S[] pop, Evaluator!S eval, size_t size);
}

struct GAConfig(S) {
    size_t popSize;
    float cp;
    float mp;
    int maxEvals;
    Selection!S select;
    GenderSelection!S genSel;
}

struct ProblemConfig(S) {
    Generator!S generator;
    Evaluator!S evaluator;
    Mutation!S mut;
    Crossover!S cross;
}

class GA(S) {
	Context!S ctx;

    size_t popSize;
    float cp;
    float mp;
    int maxEvals;

    Evaluator!S evaluator;
    Mutation!S mut;
    Crossover!S cross;
    Selection!S select;
    GenderSelection!S genSel;

    Callback!S callback;

    this(GAConfig!S ga, ProblemConfig!S problem, Callback!S callback=null){
        this(ga.popSize, ga.cp, ga.mp, ga.maxEvals, problem.generator,
            problem.evaluator, problem.mut, problem.cross,
            ga.select, ga.genSel, callback);
    }

    this(size_t popSize, float cp, float mp, int maxEvals,
        Generator!S generator, Evaluator!S eval, Mutation!S mut,
        Crossover!S cross, Selection!S select, GenderSelection!S genSel,
        Callback!S callback = null) {
        this.ctx = new Context!S;
    	this.popSize = popSize;
        this.cp = cp;
        this.mp = mp;
        this.maxEvals = maxEvals;

    	ctx.pop = generator.generateMany(popSize);

		this.evaluator = eval;
        eval.ctx = ctx;
        this.ctx.datasetSize = evaluator.datasetSize;
        this.mut = mut;
        this.cross = cross;
        this.select = select;
        this.genSel = genSel;

        this.callback = callback;
        if (this.callback)
            this.callback.evaluator = eval;
    }

    S[] generateInitialPop(Generator!S generator){
    	S[] pop = new S[popSize];
        foreach (ref s; pop)
        	s = generator.generateRandom();
		return pop;
    }

    void run(){
        if (callback) callback.atStart(ctx);
        int genNo;
        while (ctx.evals < maxEvals){
            auto pop = ctx.pop;
            auto newPop = pop.dup;
            auto parentsCount = to!int(cp * popSize);
            if (parentsCount < 1)
                parentsCount = 1;
            auto parents = genSel.select(newPop, evaluator, parentsCount);
            S[] children = [];
            foreach(parentPair; parents)
                children ~= cross.crossOver(parentPair.expand);
            newPop ~= children;
            S[] mutants = [];
            foreach (s; newPop)
                if (uniform01()<mp)
                    mutants ~= mut.mutate(s);
            ctx.pop = select.select(newPop, evaluator, popSize);
            if (callback) callback.postSelect(ctx);
            ++ctx.genNo;
        }
        if (callback) callback.atEnd(ctx);
    }
}
