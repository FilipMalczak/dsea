module masters.ga.common;

import std.random;
import std.algorithm: canFind, remove;
import std.algorithm.sorting;
import std.algorithm.iteration;
import std.string;
import std.array;
import std.conv;

import std.range;

import std.stdio;

import masters.ga.framework;


class SelectionFactory(S) {
    static Selection!S getSelection(string serialized, string separator=","){
        string[] parts = serialized.split(separator);
        switch (parts[0]) {
            case "RouletteSelect": return new RouletteSelect!S();
            case "TourneySelect": return getTourney(parts[1..$]);
            default: throw new Exception("WTF "~serialized);
        }
    }

    private static TourneySelect!S getTourney(string[] parts...){
        assert(parts.length == 1);
        return new TourneySelect!S(to!int(parts[0]));
    }
}

unittest {
    auto result = SelectionFactory!Specimen.getSelection("TourneySelect,3");
    auto tourney = to!(TourneySelect!Specimen)(result);
    assert(tourney !is null);
    assert(tourney==result);
    assert(tourney.size == 3);
}

class TourneySelect(S): Selection!S {
	int size;
	this(int size){
        this.size = size;
	}

	S[] select(S[] pop, Evaluator!S eval, size_t popSize) {
        S[] used = [];
        S[] result = [];
        while (result.length < popSize) {
        	S[] tourney = [];
            while (tourney.length < size) {
                auto candidate = pop[uniform(0, pop.length)];
                if (! used.canFind(candidate))
                    tourney ~= candidate;
            }
            S winner = tourney[0];
            foreach (s; tourney[1..$])
                if (eval.evaluate(s) < eval.evaluate(winner))
                	winner = s;
            result ~= winner;
        }
        return result;
	}

    override string toString(){
        return "TourneySelect(size: "~to!string(size)~")";
    }
}

class Sorter(S) {
        Evaluator!S eval;

        this(Evaluator!S eval){
            this.eval = eval;
        }

        bool comp(S x, S y) {
            return eval.evaluate(x) < eval.evaluate(y);
        }
    }

class RouletteSelect(S): Selection!S {

    S[] select(S[] pop, Evaluator!S eval, size_t popSize) {
        auto sorter = new Sorter!S(eval);
        auto sorted = array(sort!((a, b) => sorter.comp(a, b))(pop.dup));
        auto cumulative = repeat(0.0).take(popSize).array() ~ [double.max];
        foreach (int i, S s; sorted)
            if (i < sorted.length-1)
                foreach (ref partial; cumulative[i..sorted.length])
                    partial += eval.evaluate(s);
        S[] result = [];
        while (result.length < popSize) {
            double chosen = uniform(0, cumulative[$-2]); //next-to-last element, sum of all, last is double.max
            foreach (int i, partialSum; cumulative){
                if (chosen < partialSum)
                    result ~= sorted[i];
                    sorted = remove(sorted, i);
                    cumulative = remove(cumulative, i); //should we recalculate cumulative?
                    break;
            }
        }
        return result;
    }
}

