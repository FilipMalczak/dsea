module masters.html;

import std.string;
import std.algorithm.iteration;

interface Node {
    string toHtml();
}

class Raw: Node {
    string content;

    this(string content){
        this.content = content;
    }

    override string toHtml(){
        return content;
    }
}

class Tag: Node {
    string name;
    string[string] attrs;

    Node[] children = [];

    this(string name, string[string] attrs, Node[] children=[]){
        this.name=name;
        this.attrs=attrs;
        this.children=children;
    }

    override string toHtml(){
        string[] attrEntries = [];
        foreach(k, v; attrs)
            attrEntries ~= k~"='"~v~"'";
        auto opening = "<"~(( [ name ] ~ attrEntries).join(" "))~">";
        auto closing = "</"~name~">";
        string content = "";
        foreach (c; children) {
            auto htmlLines = c.toHtml().split("\n");
            foreach(line; htmlLines)
                content ~= "\t"~line~"\n";
        }
        return opening~"\n"~content~closing;
    }
}

class HtmlBuilder {
    Node _(string txt){
        return new Raw(txt);
    }

    Node _(string name)(string[string] attrs, Node[] children=[]){
        return new Tag(name, attrs, children);
    }

/*
    Node _body(string[string] attrs, Node[] children=[]){
        return new Tag("body", attrs, children);
    }
*/
    Node _(string name)(string[string] attrs, string child){
        return new Tag(name, attrs, [ new Raw(child) ]);
    }
/*
    Node _body(string[string] attrs, string child=null){
        return new Tag("body", attrs, [ new Raw(child) ]);
    }
*/
    static string[string] emptyMap;

    Node _(string name)(Node[] children=[]){
        return new Tag(name, emptyMap, children);
    }
/*
    Node _body(Node[] children=[]){
        return new Tag("body", emptyMap, children);
    }*/

    Node _(string name)(string child){
        return new Tag(name, emptyMap, [ new Raw(child) ]);
    }
/*
    Node _body(string child=null){
        return new Tag("body", emptyMap, [ new Raw(child) ]);
    }*/
}

Node htmlBoilerplate(string title, string[] scripts, string[] styles, Node[] content){
    with(new HtmlBuilder()){
        Node[] headNodes = [];
        foreach (s; styles)
            headNodes ~= _!"link"(["href": s, "rel": "stylesheet"]);
        foreach (s; scripts)
            headNodes ~= _!"script"(["src": s, "type": "text/javascript"]);
        return _!"html"([
            _!"head"([
                _!"title"(title),
                _!"meta"(["name": "viewport", "content": "width=device-width, initial-scale=1"])
            ] ~ headNodes),
            _!"body"([
                _!"div"(
                    ["class": "container-fluid"],
                    [
                        _!"h1"(title)
                    ] ~ content
                )
            ])
        ]);
    }
}

Node bootstrapped(string title, Node[] content){
    return bootstrapped(title, [], [], content);
}

Node bootstrapped(string title, string[] scripts, string[] styles, Node[] content){
    return htmlBoilerplate(
        title,
        scripts ~ [
            "https://ajax.googleapis.com/ajax/libs/jquery/1.12.4/jquery.min.js",
            //"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js",
            "https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.3.7/js/bootstrap.js",
            "https://cdnjs.cloudflare.com/ajax/libs/jquery-timeago/1.5.3/jquery.timeago.js"
        ],
        styles ~[
            //"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css",
            "https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.3.7/css/bootstrap.css",
            //"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap-theme.min.css",
            "https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.3.7/css/bootstrap-theme.css",
            //"https://maxcdn.bootstrapcdn.com/font-awesome/4.6.3/css/font-awesome.min.css"
            "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.css"
        ],
        content
    );
}
