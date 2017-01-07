module masters.tsp.impl;

import std.conv;
import std.stdio;
import std.random;
import std.algorithm: reduce;
import std.algorithm.searching;
import std.algorithm.mutation;
import std.file;
import std.typecons;
import std.math;

import masters.io;
import masters.ga.framework;

/*
 * DEV NOTE: For faster computations, no sqrt() is performed - we only need to order distances
 * and sqrt is monotonic, so we can as well skip rooting.
 */

double distance(double[] p1, double[] p2){
    assert(p1.length == p2.length);
    double result = 0;
    foreach (i; 0..p1.length)
        result += (p1[i] - p2[i])^^2;
    return result;
}

unittest {
    assert(distance([1, 2, 3, 4], [1, 2, 3, 4]) == 0);
    assert(distance([1, 2], [3, 4]) == 8);
}

double[][] distances(double[][] points){
    double[][] toReturn = [];
    foreach (p1; points) {
        double[] row = [];
        foreach (p2; points)
            row ~= distance(p1, p2);
        toReturn ~= row;
    }
    return toReturn;
}

unittest {
    auto result = distances([[0, 0], [1, 1], [0, 1], [1, 0], [2, 2]]);
    foreach (i; 0..result.length) {
        assert(result[i][i] == 0);
        foreach (j; 0..(result.length-i))
            assert(result[i][j] == result[j][i]);
    }
    assert(result[0][1..$] == [2, 1, 1, 8]);
}

double[][] readProblemFile(string path){
    double[][] points = readCsvFile!(string, double)(";", 2, path);
    return distances(points);
}


class Path: Specimen {
    int[] repr;

    this(int[] repr){
        int gender = uniform(0, 2);
        this(repr, gender);
    }

    this(int[] repr, int gender){
        this.repr = repr;
        this.gender = gender;
    }

    override string toString(){
        return "Path(" ~ to!string(repr) ~ "; gender = "~to!string(gender)~"; eval = " ~ (isNaN(eval) ? "NaN" : to!string(eval)) ~ "; properEval = " ~ (isNaN(properEval) ? "NaN" : to!string(properEval)) ~ ")";
    }
}

class TspEval: Evaluator!Path {
    double[][] distances;

    this(string dataset, double[][] distances){
        this.dataset = dataset;
        this.problem = "tsp";
        this.distances = distances;
    }

    override double getEval(Path s) {
        double result = 0;
        foreach (i; 0..s.repr.length-2)
            result += distances[s.repr[i]][s.repr[i+1]];
        result += distances[s.repr[s.repr.length-2]][s.repr[s.repr.length-1]];
        result += distances[s.repr[s.repr.length-1]][s.repr[0]];
        return result;
    }

    override double getProperEval(Path s) {
        double result = 0;
        foreach (i; 0..s.repr.length-2)
            result += sqrt(distances[s.repr[i]][s.repr[i+1]]);
        result += sqrt(distances[s.repr[s.repr.length-2]][s.repr[s.repr.length-1]]);
        result += sqrt(distances[s.repr[s.repr.length-1]][s.repr[0]]);
        return result;
    }

    override @property size_t datasetSize(){
        return distances.length;
    }
}

class TspGenerator: Generator!Path {
    int size;

    this(int size){
        this.size = size;
    }

    int[] increasing(){
        int[] result = new int[size];
        foreach(int i, ref element; result)
            element = i;
        return result;
    }

    override Path generateRandom() {
        int[] repr = increasing();
        randomShuffle(repr);
        return new Path(repr);
    }
}

unittest {
    auto example = new TspGenerator(10).generateRandom();
    assert(example.repr.length == 10);
    foreach (i; 0..10)
        assert(canFind(example.repr, i));
}

class ReverseSubsequenceMutation: Mutation!Path {
    override Path[] mutate(Path s){
        auto upper = uniform(2, s.repr.length-1);
        auto lower = uniform(1, upper);
        return [ new Path(reverseSubsequence!(int)(s.repr, to!int(lower), to!int(upper))) ];
    }

    static T[] reverseSubsequence(T)(T[] original, int lower, int upper){
        auto toReverse = original[lower..upper];
        reverse(toReverse);
        return original[0..lower] ~ toReverse ~ original[upper..$];
    }

}

unittest {
    assert(ReverseSubsequenceMutation.reverseSubsequence([0, 1, 2, 3, 4, 5, 6, 7, 8], 3, 7) == [0, 1, 2, 6, 5, 4, 3, 7, 8]);
}

class SubsequenceCrossover: Crossover!Path {
    override Path[] crossOver(Path s1, Path s2) {
        int cuttingPoint = uniform(1, to!int(s1.repr.length-1));
        return [
            new Path(fill(s1.repr[0..cuttingPoint], s2.repr)),
            new Path(fill(s2.repr[0..cuttingPoint], s1.repr))
        ];
    }

    static T[] fill(T)(T[] front, T[] candidates){
        T[] result = front.dup;
        foreach (idx; 0..candidates.length) {
            auto elem = candidates[(idx+front.length) % candidates.length];
            if (!canFind(result, elem))
                result ~= elem;
        }
        return result;
    }
}

unittest {
    assert(SubsequenceCrossover.fill([1, 4], [2, 4, 5, 3, 1]) == [1, 4, 5, 3, 2]);
}

