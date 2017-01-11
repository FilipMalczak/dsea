module masters.mains.utils;

import masters.experiments;
import masters.io;

ResultFile[int][string] groupBySetupByIter(ResultsRepository repo, string problem, string dataset){
    ResultFile[int][string] grouped;
    repo.eachRun(problem, dataset, (rf) {
        if (! (rf.params.setupName in grouped)) {
            ResultFile[int] arr;
            grouped[rf.params.setupName] = arr;
        }
        if (!(rf.params.iter in grouped[rf.params.setupName])) {
            grouped[rf.params.setupName][rf.params.iter] = rf;
        } else
            throw new Exception("Duplicate: ", rf.name);
    });
    return grouped;
}

abstract class CsvReport(RowClass) {
    CsvFile!string csv;
    auto repo = ResultsRepository("./results");

    @property string separator(){
        return "\t";
    }
    abstract @property string[] header();

    abstract void feed(int idx, RowClass row);

    abstract RowClass[] extract();

    void run(string outFile){
        csv  = new CsvFile!string(outFile, header, separator);
        foreach(int i, row; extract()) {
            feed(i, row);
            csv.nl();
        }
        csv.flush();
    }
}
