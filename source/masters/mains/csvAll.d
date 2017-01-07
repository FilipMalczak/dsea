module masters.mains.csvAll;

import std.datetime;
import std.algorithm;
import std.stdio;

import masters.experiments;
import masters.utils;
import masters.io;
import masters.mains.utils;


struct Row {
    double totalBest = double.max;
    double totalWorst = double.min_normal;
    double bestAvg = 0.0;
    double worstAvg = 0.0;
    double score = 0.0;
    TickDuration duration;

    int iters;

    int noByBest;
    int noByAvgBest;
    int noByScore;

    Params params;
    ResultFile[] allIterations;

    @property double span(){
        return totalWorst - totalBest;
    }

    @property double avgSpan(){
        return worstAvg - bestAvg;
    }

    CsvFormatter!S feed(S)(CsvFormatter!S formatter){
        return formatter.
            _(noByBest)._(noByAvgBest)._(noByScore).
            _(params.cp).
            _(params.mp).
            _(params.popSize).
            _(params.maxEvals).
            _(params.mutation).
            _(params.crossover).
            _(params.natSel).
            _(params.genSel).
            _(totalBest)._(bestAvg).
            _(totalWorst)._(worstAvg).
            _(totalWorst-totalBest)._(worstAvg-bestAvg).
            _(score)._(toStr(duration));
    }
}

class CsvAllReport: CsvReport!Row {
    string problem;
    string dataset;

    this(string problem, string dataset){
        this.problem = problem;
        this.dataset = dataset;
    }

    override @property string[] header(){
        return [
            "noByBest", "noByAvgBest", "noByScore",
            "cp", "mp", "popSize", "maxEvals",
            "mutation", "crossover", "natSel", "genSel",
            "totalBest", "avgBest",
            "totalWorst", "avgWorst",
            "span", "avgSpan",
            "score", "duration"
        ];
    }

    override void feed(int idx, Row row){
        with(row){
            csv._(noByBest)._(noByAvgBest)._(noByScore).
                _(params.cp).
                _(params.mp).
                _(params.popSize).
                _(params.maxEvals).
                _(params.mutation).
                _(params.crossover).
                _(params.natSel).
                _(params.genSel).
                _(totalBest)._(bestAvg).
                _(totalWorst)._(worstAvg).
                _(totalWorst-totalBest)._(worstAvg-bestAvg).
                _(score)._(toStr(duration));
        }
    }

    override Row[] extract(){
        auto grouped = groupBySetupByIter(repo, problem, dataset);
        Row[] rows;
        foreach(setup, byIter; grouped){
            auto anyRf = byIter.values[0];
            Row row;
            row.allIterations = byIter.values;
            foreach(iter, rf; byIter){
                if (rf.results.properGlobalBest < row.totalBest)
                    row.totalBest = rf.results.properGlobalBest;
                if (rf.results.properGlobalWorst > row.totalWorst)
                    row.totalWorst = rf.results.properGlobalWorst;
                row.bestAvg += rf.results.properGlobalBest;
                row.worstAvg += rf.results.properGlobalWorst;
                row.score += rf.results.score(to!int(byIter.length));
                row.duration += rf.results.fullDuration;
            }

            row.bestAvg /= to!int(byIter.length);
            row.worstAvg /= to!int(byIter.length);
            row.duration /= to!int(byIter.length);

            row.iters = to!int(byIter.length);

            row.params = anyRf.params;

            rows ~= row;
        }
        int i = 0;
        foreach(ref row; sort!((x, y) => x.totalBest < y.totalBest)(rows)){
            row.noByBest = i++;
        }
        i = 0;
        foreach(ref row; sort!((x, y) => x.bestAvg < y.bestAvg)(rows)){
            row.noByAvgBest = i++;
        }
        i = 0;
        foreach(ref row; sort!((x, y) => x.score < y.score)(rows)){
            row.noByScore = i++;
        }
        writeln("Extraction finished");
        return rows;
    }
}

void run(string problem, string dataset, string outFile){
    new CsvAllReport(problem, dataset).run(outFile);
}
