module masters.utils;

import std.string;
import std.datetime;
import std.conv;
import std.format;

string toStr(TickDuration dur){
    with (std.conv.to!(Duration)(dur).split()) {
        return format("%02d:%02d:%02d.%3d", hours, minutes, seconds, msecs);
    }
}
