import std.conv;
import std.stdio;
import std.algorithm;
import std.string;

import masters.experiments;
import masters.mains.tsvAll: runAll = run;
import masters.mains.divergence: runDiv = run;
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
                load("nrw1379"),
                // with known optima,
                // taken from http://www.math.uwaterloo.ca/tsp/vlsi/index.html
                load("xqf131"), // optimum: 564
                load("bcl380")  // optimum: 1621
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
    foreach (iter; 0..ITERS)
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

//todo: try plain GA with gender selection instead of natural selection

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
        "DSEA with harem gen. sel.",
        0.166667, 0.166667,
        76,
        "Std=RankRoulette", "Harem=3=0.8=Tourney,5=Tourney,5=Tourney,5"
    );
}

//todo: try DSEA with other, non-harem gensel

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
            if (["tsvall", "tsv_all"].canFind(args[0])) {
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
            } else if (["div", "divergence"].canFind(args[0])) {
                runDiv();
            } else {
                foreach (arg; args) {
                    switch (arg.toLower()) {
                        case "all":
                        case "experiments":
                        case "exp": runTsp(); break;
                        case "ga":
                        case "plain": plainGA(); break;
                        case "gga": gga(); break;
                        case "sexualga":
                        case "sga": sexualGA(); break;
                        case "harem":
                        case "dsea": dseaWithHarem(); break;
                        default: throw new Exception("Unknown experiment to execute!");
                    }
                }
            }
        } else
            runTsp();
    } catch (Exception e){
        writeln("Args:");
        writeln(args);
        throw e;
    }
}
