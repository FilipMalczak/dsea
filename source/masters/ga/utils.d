module masters.ga.utils;

import std.datetime;
import std.stdio;
import std.conv;

import core.memory;

import masters.ga.framework;

class SingleSpecimenMutation(S): Mutation!S {
	override S[] mutate(S s) {
        return [ mutateOne(s) ];
	}

	abstract S mutateOne(S s);
}

void inheritRandomGender(S: Specimen)(S child, S[] parents){
    size_t idx = uniform(0, parents.length);
    child.gender = parents[idx].gender;
}

class Callback(S){
    Evaluator!S evaluator = null;

    void atStart(Context!S ctx){}
    void postSelect(Context!S ctx){}
    void atEnd(Context!S ctx){}
}

class UsefulCallback(S): Callback!S {
    StopWatch fullStopWatch;
    StopWatch gaStopWatch;
    bool exact;
    int k = 10000;
    int ksOfEvalsDone = -1;

    this(bool exact){
        this.exact = exact;
    }

    void logEvals(Context!S ctx){
        if (ctx.evals / k != ksOfEvalsDone){
            ksOfEvalsDone = ctx.evals/k;
            writeln(Clock.currTime.toSimpleString(),
                " At least ", k*ksOfEvalsDone, " evals (exactly ",
                ctx.evals, ") already done; ",
                "generation #", ctx.genNo
            );
        }
    }

    override void atStart(Context!S ctx){
        fullStopWatch = StopWatch();
        gaStopWatch = StopWatch();
        ksOfEvalsDone = -1;
        logEvals(ctx);
        stdout.flush();
        GC.collect();
        fullStopWatch.start();
        gaStopWatch.start();
    }

    Stat calculateStats(alias F)(S[] pop){
        Stat stat = Stat();
        foreach (elem; pop) {
            auto eval = F(elem);
            if (eval > stat.worst)
                stat.worst = eval;
            if (eval < stat.best)
                stat.best = eval;
            stat.avg += eval;
        }
        stat.avg /= pop.length;
        foreach (elem; pop)
            stat.variance += (elem.eval-stat.avg)^^2;
        stat.variance /= pop.length;
        return stat;
    }

    double justEval(S s){ return evaluator.evaluate(s); }
    double properEval(S s){ return evaluator.evaluateProperly(s); }

    override void postSelect(Context!S ctx){
        gaStopWatch.stop();
        ctx.stats ~= calculateStats!justEval(ctx.pop);
        if (exact) {
            ctx.properStats ~= calculateStats!properEval(ctx.pop);
        }
        logEvals(ctx);
        gaStopWatch.start();
    }

    override void atEnd(Context!S ctx){
        fullStopWatch.stop();
        gaStopWatch.stop();
        logEvals(ctx);
        ctx.fullDuration = fullStopWatch.peek();
        ctx.gaDuration = gaStopWatch.peek();
        fullStopWatch.reset();
        gaStopWatch.reset();
        stdout.flush();
        GC.collect();
    }
}
