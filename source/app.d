import std.conv;
import std.stdio;
import std.algorithm;

import masters.experiments;
import masters.mains.csvAll: runAll = run;
import masters.tsp.impl;

struct Tsp {
    static Dataset!Path load(string name){
        auto fileContent = readProblemFile("./data/"~name~".csv");
        return Dataset!Path(name, new TspEval(name, fileContent), new TspGenerator(to!int(fileContent.length)));
    }

    static Dataset!(Path)[] _datasets = [];

    static @property Dataset!(Path)[] datasets(){
        /* datasets are taken from here:
         * http://elib.zib.de/pub/mp-testdata/tsp/tsplib/tsp/
         * TSPLIB files were manually converted to CSV by copying data section
         * to Excel, splitting text to columns and saving as CSV.
         */
        if (_datasets.length == 0) {
            _datasets = [
                load("eil76"),
                load("a280"),
                load("ali535"),
                load("rat783"),
                load("nrw1739")
            ];
        }
        return _datasets;
    }
}

int ITERS = 10;
int EVALS = 250000;
//int EVALS = 10000;

void exec(string title, double cp, double mp, size_t popSize, string natSel, string genSel){
    writeln("===== "~title~" =====");
    foreach (iter; 0..ITERS-1)
        ExperimentSetup!Path(
            Tsp.datasets,
            cp, mp,
            popSize, EVALS,
            "reverseSubsequence", "subsequence",
            natSel, genSel
        ).ensureExecution(ResultsRepository("./results"), iter);
    writeln("---------------------");
}

/*
 * Following parameters were found in greedy search process.
 *
 * Code used for that search has been refactored and used here.
 * It was quite ugly, so it's not published here.
*/

void plainGA(){
    exec(
        "Plain GA",
        0.3, 0.1,
        100,
        "Std=RankRoulette", "NoGender=Random"
    );
}

void gga(){
    exec(
        "GGA",
        0.1, 0.0333333,
        76,
        "Std=RankRoulette", "GGA=Random"
    );
}

void sexualGA(){
    exec(
        "SexualGA",
        0.166667, 0.1,
        76,
        "Std=Random", "Gender=Tourney,5=Tourney,5"
    );
}

void dseaWithHarem(){
    exec(
        "GGA",
        0.166667, 0.166667,
        76,
        "Std=RankRoulette", "Harem=3=0.8=Tourney,5=Tourney,5=Tourney,5"
    );
}

void runTsp(){
    plainGA();
    gga();
    sexualGA();
    dseaWithHarem();
}

void main(string[] args) {
    try {
        args = args[1..$];
        if (args.length > 0){
            if (["csvall", "csv_all"].canFind(args[0])) {
                if (args.length == 3)
                    runAll(
                        "tsp",
                        args[1],
                        args[2]
                    );
                else if (args.length > 3)
                    runAll(
                        args[1],
                        args[2],
                        args[3]
                    );
                else
                    throw new Exception("Specify dataset and outFile for csv_all target!");
            }
        } else
            runTsp();
    } catch (Exception e){
        writeln("Args:");
        writeln(args);
        throw e;
    }
}
