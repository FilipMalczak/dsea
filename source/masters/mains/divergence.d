module masters.mains.divergence;

import std.stdio;
import std.conv;
import std.algorithm;

import masters.experiments;
import masters.utils;
import masters.io;
import masters.mains.utils;
import masters.ga.framework;


size_t[] iterationsUntilEvals(Stat[] stats, double[] evals){
    size_t evalIdx = 0;
    double searchedEval = evals[evalIdx];
    size_t[] result = [];
    foreach (genIdx, stat; stats){
        while (stat.best < searchedEval) {
            result ~= genIdx;
            evalIdx++;
            if (evalIdx >= evals.length)
                break;
            searchedEval = evals[evalIdx];
        }
    }
    while (result.length < evals.length)
        result ~= stats.length;
    return result;
}

size_t[][] iterationsUntilOptimumFactors(ResultFile[] allIterations, double[] factors, double optimum){
    double[] evals = [];
    foreach (factor; factors)
        evals ~= optimum*factor;
    size_t[][] result = [];
    foreach (iter; allIterations)
        result ~= iterationsUntilEvals(iter.results.properStats, evals);
    return result;
}

void run(){
    auto optima = [
        "xqf131": 564,
        "bcl380": 1621
    ];
    auto methodOrder = [
        "Plain GA (selection for survival)",
        "Plain GA (selection for breeding)",
        "GGA",
        "SexualGA",
        "DSEA with Harem"
    ];
    auto methods = [
        methodOrder[0]: "0.3_0.1_100_250000_reverseSubsequence_subsequence_Std=RankRoulette_NoGender=Random",
        methodOrder[1]: "0.1_0.1_100_250000_reverseSubsequence_subsequence_Std=Random_NoGender=Tourney,5",
        methodOrder[2]: "0.1_0.0333333_76_250000_reverseSubsequence_subsequence_Std=RankRoulette_GGA=Random",
        methodOrder[3]: "0.166667_0.1_76_250000_reverseSubsequence_subsequence_Std=Random_Gender=Tourney,5=Tourney,5",
        methodOrder[4]: "0.166667_0.166667_76_250000_reverseSubsequence_subsequence_Std=RankRoulette_Harem=3=0.8=Tourney,5=Tourney,5=Tourney,5"
    ];

    double[] factors = [
        10.0, 5.0, 3.0, 2.5, 2.0,
        1.7, 1.5, 1.4, 1.3, 1.2,
        1.19, 1.18, 1.17, 1.16, 1.15,
        1.14, 1.13, 1.12, 1.11, 1.1,
        1.0
    ];
    double[] zeros = [];
    string[] strFactors = [];
    foreach (factor; factors) {
        strFactors ~= to!string(factor);
        zeros ~= 0.0;
    }

    auto headerPerIter = ["dataset", "method", "iter"] ~ strFactors;
    auto headerAvg = ["dataset", "method"] ~ strFactors;
    auto perIter = new CsvFile!string("./summaries/divergence_per_iter.tsv", headerPerIter, "\t");
    auto avg = new CsvFile!string("./summaries/divergence_avg.tsv", headerAvg, "\t");

    foreach(dataset, optimum; optima) {
        double[] evals = [];
        foreach (factor; factors)
            evals ~= factor*optimum;
        auto grouped = groupBySetupByIter(ResultsRepository("./results"), "tsp", dataset);
        foreach (method; methodOrder) {
            auto setup = methods[method];
            auto fileMap = grouped[setup];
            avg._(dataset)._(method);
            auto sums = zeros.dup;
            foreach(iter; sort(fileMap.keys())) {
                perIter._(dataset)._(method)._(iter);
                auto resultFile = fileMap[iter];
                auto stats = resultFile.results.properStats;
                auto itersUntilEvals = iterationsUntilEvals(stats, evals);
                foreach (i, iters; itersUntilEvals) {
                    auto relative = 1.0*iters/stats.length;
                    perIter._(relative);
                    sums[i] += relative;
                }
                perIter.nl();
            }
            foreach (sum; sums) {
                avg._(sum/fileMap.length);
            }
            avg.nl();
        }
        writeln("---------------------");
    }
};
