module masters.io;

import std.stdio;
import std.file;
import std.conv;
import std.string;
import std.array;
import std.typecons;
import std.csv;
import std.format;
import std.algorithm.iteration;



S[] stringIt(S=string, T...)(T toStringize){
    S[] result = [];
    foreach (x; tuple(toStringize))
        result ~= to!S(x);
    return result;
}

unittest {
    assert(stringIt!string(1, "a", 3.5) == ["1", "a", "3.5"]);
}

class CsvFormatter(S = string) {
    private S _result = "";
    private S[] _header;
    private S sep;
    private bool firstInRow = true;

    this(S[] header=[], S separator=";"){
        _header = header;
        sep = separator;
        appendHeader();
    }

    this(S separator){
        this([], separator);
    }

    private void append(S s){
        _result ~= s ~ "\n";
        firstInRow = true;
    }

    private void appendHeader(){
        if (_header.length)
            append(_header.join(sep));
    }

    CsvFormatter!S _(T)(T data){
        if (!firstInRow)
            _result ~= sep;
        else
            firstInRow = false;
        _result ~= stringIt!S(data).join(sep);
        return this;
    }

    CsvFormatter!S nl(){
        _result ~= "\n";
        firstInRow = true;
        return this;
    }


    CsvFormatter!S feed(T)(T[] data...){
        foreach (d; data)
            _(d);
        nl();
        return this;
    }

    void reset(){
        _result = "";
        firstInRow = true;
        appendHeader();
    }

    @property S result(){
        return _result;
    }

}

unittest {
    auto x = new CsvFormatter!string(["a", "b", "c"], ";");
    x.feed("1", "foo", "3.5").feed("2", "bar", "8.5");
    string expected = "a;b;c\n1;foo;3.5\n2;bar;8.5\n";
    //writeln(x.result);
//    foreach (i; 0..x.result.length)
//        writeln(x.result[i], ":", expected[i]);
    assert(x.result == expected);
    x.reset();
    assert(x.result == "a;b;c\n");
    x = new CsvFormatter!string(";");
    assert(x.feed("1", "foo", "3.5").feed("2", "bar", "8.5").result == "1;foo;3.5\n2;bar;8.5\n");
    x.reset();
    assert(x.result == "");
    assert(x._(1)._("foo")._(3.5).nl()._(2)._("bar")._(8.5).nl().result == "1;foo;3.5\n2;bar;8.5\n");
}

class CsvFile(S = string): CsvFormatter!S {
    private S _path;

    this(S path, S[] header=[], S separator=";"){
        super(header, separator);
        _path = path;
    }

    this(S path, S separator){
        this(path, [], separator);
    }

    ~this(){
        flush();
    }

    @property S path() {return _path;}

    void flush(){
        std.file.write(_path, result);
    }
}

unittest {
    auto x = new CsvFile!string("./temp.csv", ["a", "b", "c"], ";");
    scope(exit) {
        std.file.remove("./temp.csv");
        assert(!exists("./temp.csv"));
    }
    //x.feed(1, "foo", 3.5).feed(2, "bar", 8.5);
    x._(1)._("foo")._(3.5).nl()._(2)._("bar")._(8.5).nl();
    x.flush();
    auto txt = readText("./temp.csv");
    assert(txt == "a;b;c\n1;foo;3.5\n2;bar;8.5\n");

}

T[][] readCsv(S = string, T)(S separator, int columns, S data){
    T[][] result = [];
    auto lines = splitLines(strip(data));
    foreach (line; lines) {
        T[] row = [];
        foreach (part; line.split(separator))
            row ~= parse!(T, S)(part);
        result ~= [row];
    }
    return result;
}

T[][] readCsvFile(S = string, T)(S separator, int columns, S path){
    return readCsv!(S, T)(separator, columns, readText(path));
}

unittest {
    assert(readCsv!(string, int)(";", 2, "1;2\n3;4") == [[1, 2], [3, 4]]);
}
