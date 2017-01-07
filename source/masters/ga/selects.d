module masters.ga.selects;

import std.string;
import std.stdio;
import std.typecons;
import std.algorithm;
import std.random;
import std.conv;
import std.math;

import masters.ga.framework;

S[] removeVal(S)(S[] arr, S s){
    auto idx = countUntil(arr, s);
    return remove(arr, idx);
}

interface Chooser(S) {
    S choose(S[] pop, Evaluator!S eval, S[] alreadyChosen);
}

class TourneyChooser(S): Chooser!S {
    int tourneySize;

    this(int tourneySize){
        assert(tourneySize > 1);
        this.tourneySize = tourneySize;
    }

    S choose(S[] pop, Evaluator!S eval, S[] alreadyChosen){
        S[] tourney = [];
        while (tourney.length < tourneySize) {
            auto candidate = pop[uniform(0, pop.length)];
            if (! alreadyChosen.canFind(candidate))
                tourney ~= candidate;
        }
        S winner = tourney[0];
        foreach (s; tourney[1..$])
            if (eval.evaluate(s) < eval.evaluate(winner))
                winner = s;
        return winner;
    }

    override string toString(){
        return "Tourney("~to!string(tourneySize)~")";
    }
}

class RankRouletteChooser(S): Chooser!S {

    static size_t[] cumulative(size_t size){
        size_t[] result = new size_t[size];
        foreach (size_t i, ref c; result){
            c = size-i;
            if (i)
                c += result[i-1];
        }
        return result;
    }

    static size_t chooseIdx(size_t[] cumulated, size_t chosen){
        size_t i = 0;
        while (i < cumulated.length && chosen >= cumulated[i]){
            i += 1;
        }
        if (i == cumulated.length)
            return i-1;
        return i;
    }



    S choose(S[] pop, Evaluator!S eval, S[] alreadyChosen){
        auto popSorted = sort!((x, y) => eval.getEval(x) < eval.getEval(y))(pop);
        auto cumulated = cumulative(pop.length);
        auto chosen = uniform(0, cumulated[$-1]);
        return popSorted[chooseIdx(cumulated, chosen)];

    }

    override string toString(){
        return "RankRoulette";
    }
}

class EvalRouletteChooser(S): Chooser!S {

    static double[] cumulative(S[] sorted, Evaluator!S eval){
        double[] result = new double[sorted.length];
        foreach (i, ref c; result){
            c = eval.getEval(sorted[i]);
            if (i)
                c += result[i-1];
        }
        return result;
    }

    static int chooseIdx(double[] cumulated, double chosen){
        int i = 0;
        while (i < cumulated.length && chosen >= cumulated[i]){
            i += 1;
        }
        if (i == cumulated.length)
            return i-1;
        return i;
    }



    S choose(S[] pop, Evaluator!S eval, S[] alreadyChosen){
        auto popSorted = sort!((x, y) => eval.getEval(x) < eval.getEval(y))(pop);
        auto cumulated = cumulative(pop, eval);
        auto chosen = uniform(0, cumulated[$-1]);
        return popSorted[chooseIdx(cumulated, chosen)];

    }

    override string toString(){
        return "EvalRoulette";
    }
}

//todo: refactor roulettes to share common code

unittest {
    assert(RankRouletteChooser!Specimen.cumulative(4) == [4, 7, 9, 10]);
    assert(RankRouletteChooser!Specimen.chooseIdx([4, 7, 9, 10], 0) == 0);
    assert(RankRouletteChooser!Specimen.chooseIdx([4, 7, 9, 10], 1) == 0);
    assert(RankRouletteChooser!Specimen.chooseIdx([4, 7, 9, 10], 4) == 1);
    assert(RankRouletteChooser!Specimen.chooseIdx([4, 7, 9, 10], 7) == 2);
    assert(RankRouletteChooser!Specimen.chooseIdx([4, 7, 9, 10], 9) == 3);
    assert(RankRouletteChooser!Specimen.chooseIdx([4, 7, 9, 10], 10) == 3);
}

class RandomChooser(S): Chooser!S {
    S choose(S[] pop, Evaluator!S eval, S[] alreadyChosen){
        return pop[uniform(0, pop.length)];
    }

    override string toString(){
        return "Random";
    }
}

class ChooserSelection(S): Selection!S {
    Chooser!S chooser;

    this(Chooser!S chooser){
        this.chooser = chooser;
    }

    S[] select(S[] pop, Evaluator!S eval, size_t size){
        auto result = new S[size];
        auto popDup = pop.dup;
        foreach (ref chosen; result) {
            chosen = chooser.choose(popDup, eval, []);
            popDup = removeVal(popDup, chosen);
        }
        return result;
    }

    override string toString(){
        return "Std("~to!string(chooser)~")";
    }
}

class NoGender(S): GenderSelection!S {
    Chooser!S chooser;

    this(Chooser!S chooser){
        this.chooser = chooser;
    }

    Tuple!(S, S)[] select(S[] pop, Evaluator!S eval, size_t size){
        assert(size < pop.length-1);
        Tuple!(S, S)[] result = new Tuple!(S, S)[size];
        S[] popDup = pop.dup;
        foreach (ref tup; result) {
            auto s1 = chooser.choose(popDup, eval, []);
            popDup = removeVal(popDup, s1);
            auto s2 = chooser.choose(popDup, eval, [s1]);
            tup[0] = s1;
            tup[1] = s2;
        }
        return result;
    }

    override string toString(){
        return "NoGender("~to!string(chooser)~")";
    }
}

S[][] splitByGender(S)(S[] pop){
    S[] gender0 = [];
    S[] gender1 = [];
    foreach (s; pop)
        if (s.gender == 0)
            gender0 ~= s;
        else if (s.gender == 1)
            gender1 ~= s;
        else throw new Exception("Wtf? Specimen "~to!string(s)~" has gender "~to!string(s.gender)~" - how??");
    return [gender0, gender1];
}

class Gender(S): GenderSelection!S {
    Chooser!S chooser1;
    Chooser!S chooser2;

    this(Chooser!S chooser1, Chooser!S chooser2){
        this.chooser1 = chooser1;
        this.chooser2 = chooser2;
    }

    this(Chooser!S chooser){
        this(chooser, chooser);
    }

    Tuple!(S, S)[] select(S[] pop, Evaluator!S eval, size_t size){
        Tuple!(S, S)[] result = new Tuple!(S, S)[size];
        S[][] genders = splitByGender(pop);
        foreach (ref tup; result) {
            tup[0] = chooser1.choose(genders[0], eval, []);
            tup[1] = chooser2.choose(genders[1], eval, []);
        }
        return result;
    }
}

class GGA(S): GenderSelection!S{
    Chooser!S chooser1;
    Chooser!S chooser2;

    this(Chooser!S chooser1, Chooser!S chooser2){
        this.chooser1 = chooser1;
        this.chooser2 = chooser2;
    }

    this(Chooser!S chooser){
        this(chooser, chooser);
    }

    Tuple!(S, S)[] select(S[] pop, Evaluator!S eval, size_t size){
        S[] gender0 = [];
        S[] gender1 = [];
        auto flag = true;
        foreach (s; sort!((x, y) => eval.getEval(x) < eval.getEval(y))(pop)) {
            if (flag)
                gender0 ~= s;
            else
                gender1 ~= s;
            flag = !flag;
        }
        Tuple!(S, S)[] result = new Tuple!(S, S)[size];
        foreach (ref tup; result) {
            tup[0] = chooser1.choose(gender0, eval, []);
            tup[1] = chooser2.choose(gender1, eval, []);
        }
        return result;
    }
}

class Harem(S): GenderSelection!S{
    int alfaCount;
    double betaFactor;
    Chooser!S chooserAlfa;
    Chooser!S chooserBeta;
    Chooser!S chooserOther;

    this(int alfaCount, double betaFactor, Chooser!S chooserAlfa, Chooser!S chooserBeta, Chooser!S chooserOther){
        this.alfaCount = alfaCount;
        this.betaFactor = betaFactor;
        this.chooserAlfa = chooserAlfa;
        this.chooserBeta = chooserBeta;
        this.chooserOther = chooserOther;
    }

    Tuple!(S, S)[] select(S[] pop, Evaluator!S eval, size_t size){
        Tuple!(S, S)[] result = [];
        size_t perAlfa = to!size_t(ceil((1.0-betaFactor) * size / alfaCount));
        S[][] genders = splitByGender(pop);
        S[] alfas = [];
        foreach (i; 0..alfaCount) {
            S alfa;
            //why the crap did I give that 3rd param?
            while (alfas.canFind((alfa = chooserAlfa.choose(genders[0], eval, [])))){}
            foreach (j; 0..perAlfa) {
                Tuple!(S, S) t;
                t[0] = alfa;
                t[1] = chooserOther.choose(genders[1], eval, []);
                result ~= t;
            }
        }
        while (result.length < size) {
            Tuple!(S, S) t;
            t[0] = chooserBeta.choose(genders[0], eval, []);
            if (alfas.canFind(t[0]))
                continue;
            t[1] = chooserOther.choose(genders[1], eval, []);
            result ~= t;
        }

        return result;
    }
}

class ChooserFactory(S) {
    static Chooser!S getChooser(string[] parts){
        switch (parts[0]){
            case "Tourney": return getTourney(parts[1..$]);
            case "RankRoulette": return new RankRouletteChooser!S();
            case "EvalRoulette": return new EvalRouletteChooser!S();
            case "Random": return new RandomChooser!S();
            default: throw new Exception("Unknown chooser: "~parts[0]);
        }
    }

    private static Chooser!S getTourney(string[] parts...){
        assert(parts.length == 1);
        return new TourneyChooser!S(to!int(parts[0]));
    }
}

class SelectionFactory(S) {
    static Selection!S getSelection(string serialized){
        string[] parts = serialized.split("=");
        switch (parts[0]) {
            case "Std": return new ChooserSelection!S(
                ChooserFactory!S.getChooser(parts[1].split(","))
            );
            default: throw new Exception("Unknown selection "~parts[0]);
        }
    }
}

class GenSelFactory(S){
    static GenderSelection!S getGenSel(string serialized){
        string[] parts = serialized.split("=");
        switch(parts[0]){
            case "NoGender": return new NoGender!S(
                ChooserFactory!S.getChooser(parts[1].split(","))
            );
			case "Gender":
                if (parts.length == 2)
                    return new Gender!S(
                        ChooserFactory!S.getChooser(parts[1].split(",")),
                    );
                else if (parts.length == 3)
                    return new Gender!S(
                        ChooserFactory!S.getChooser(parts[1].split(",")),
                        ChooserFactory!S.getChooser(parts[2].split(",")),
                    );
                else goto default;
            case "GGA":
                if (parts.length == 2)
                    return new GGA!S(
                        ChooserFactory!S.getChooser(parts[1].split(",")),
                    );
                else if (parts.length == 3)
                    return new GGA!S(
                        ChooserFactory!S.getChooser(parts[1].split(",")),
                        ChooserFactory!S.getChooser(parts[2].split(",")),
                    );
                else goto default;
            case "Harem":
                if (parts.length == 6) {
                    return new Harem!S(
                        to!int(parts[1]),
                        to!double(parts[2]),
                        ChooserFactory!S.getChooser(parts[3].split(",")),
                        ChooserFactory!S.getChooser(parts[4].split(",")),
                        ChooserFactory!S.getChooser(parts[5].split(","))
                    );
                } else goto default;
            default: throw new Exception("No genSel named "~parts[0]~" instantiable with "~to!string(parts[1..$]));
        }
    }
}


