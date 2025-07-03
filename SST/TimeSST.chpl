use Sort;
use List;
use Map;

type UnitId = int;
type sstBigNum = int;
type SimTime = int;


var unitCount: UnitId = 0;
var validBaseUnits: map(string, UnitId);
var unitStrings: map(UnitId, string);
var validCompoundUnits: map(string, (Units, sstBigNum));
var siUnitMap: map(string, sstBigNum);

siUnitMap.add("a",1:int);
siUnitMap.add("f", 1:int);
siUnitMap.add("p", 1:int);
siUnitMap.add("n", 1:int);
siUnitMap.add("u", 1:int);
siUnitMap.add("m", 1:int);
siUnitMap.add("k", 1e3:int);
siUnitMap.add("K", 1e3:int);
siUnitMap.add("ki", 1024:int);
siUnitMap.add("Ki", 1024);
siUnitMap.add("Mi", 1024**2);
siUnitMap.add("M", 1e6:int);
siUnitMap.add("Gi", 1024**3);
siUnitMap.add("G", 1e9:int);
siUnitMap.add("Ti", 1024**4);
siUnitMap.add("T", 1e12:int);
siUnitMap.add("Pi", 1024**5);
siUnitMap.add("P", 1e15:int);
siUnitMap.add("Ei", 1024**6);
siUnitMap.add("E", 1e18:int);

proc registerBaseUnit(u: string) {
  if validBaseUnits.contains(u) then return;
  validBaseUnits.add(u, unitCount);
  unitStrings.add(unitCount, u);
  unitCount += 1;
  return;
}

registerBaseUnit("s");
registerBaseUnit("B");
registerBaseUnit("b");
registerBaseUnit("events");


proc registerCompoundUnit(u: string, v: string) {
  if validCompoundUnits.contains(u) then return;
  var multiplier: sstBigNum = 1;
  var unit = new Units(v, multiplier);
  validCompoundUnits.add(u, (unit, multiplier));
  return;
}
registerCompoundUnit("Hz", "1/s");
    // Yes, I know it's wrong, but other people don't always realize
    // that.
registerCompoundUnit("hz", "1/s");
registerCompoundUnit("Bps", "B/s");
registerCompoundUnit("bps", "b/s");
registerCompoundUnit("event", "events");


record Units {

  var numerator: list(UnitId),
      denominator: list(UnitId);

  proc init () {
    numerator = new list(UnitId);
    denominator = new list(UnitId);
    init this;
  }
  proc init(units: string, ref multiplier: sstBigNum) {
    init();

    var slashIndex = units.find("/"): int,
        numeratorString: string,
        denominatorString: string;
    
    if slashIndex == -1 {
      numeratorString = units;
      denominatorString = "";
    }
    else {
      numeratorString = units(0..<slashIndex);
      denominatorString = units(slashIndex+1..<units.size);
    }

    // TODO: split these into individual units, which will be separated with '-'
    for token in numeratorString.split("-") do
      addUnit(token, multiplier, false);
    
    if denominatorString != "" then
      for token in denominatorString.split("-") do
        addUnit(token, multiplier, true);
    
    this.reduceUnits();
  }

  proc ref reduceUnits() {
    sort(numerator);
    sort(denominator);

    // remove stuff that's in both
    var n = 0;
    while n < numerator.size {
      if denominator.contains(numerator[n]) {
        denominator.remove(n);
        numerator.remove(n);
      } else {
        n += 1;
      }
    }
  }
  proc ref addUnit(units: string, ref multiplier: sstBigNum, invert: bool) throws {

    //Check if the unit matches one of the registered names
    var siLength = 0;
    if !validBaseUnits.contains(units) && !validCompoundUnits.contains(units) {
      select units(0) {
        when "a", "f", "p", "n", "u", "m" {
          siLength = 1;
        }
        when "k", "K", "M", "G", "T", "P", "E" {
          if units(1) == "i" then
            siLength = 2;
          else 
            siLength = 1;
        }
        otherwise {
          siLength = 0;
        }
      }
    }

    if siLength > 0 {
      var siUnit = units(0..<siLength);
      if ! invert then 
        multiplier *= siUnitMap(siUnit);
      else 
        multiplier /= siUnitMap(siUnit);
    }

    // Check to see if the unit is valid and get its ID
    var typeStr = units(siLength..<units.size);
    if validBaseUnits.contains(typeStr) {
      if ! invert then
        numerator.pushBack(validBaseUnits(typeStr));
      else
        denominator.pushBack(validBaseUnits(typeStr));
    }
    //Check if its a compound unit
    else if validCompoundUnits.contains(typeStr) {
      var units = validCompoundUnits(typeStr);
      if !invert {
        this *= units[0];
        multiplier *= units[1];
      } else {
        this /= units[0];
        multiplier /= units[1];
      }
    }
    else if typeStr == "1" {
      return;
    } else {
      throw new Error("Invalid Unit Type: '" + typeStr + "'. Full unit: " + units);
    }
  }

}

operator *(x: Units, y: Units) {
  var z = new Units();
  z.numerator.pushBack(x.numerator);
  z.denominator.pushBack(x.denominator);
  z.numerator.pushBack(y.numerator);
  z.denominator.pushBack(y.denominator);
  z.reduceUnits();
  return z;
}


operator /(x: Units, y: Units) {
  var z = new Units();
  z.numerator.pushBack(x.numerator);
  z.denominator.pushBack(x.denominator);
  z.numerator.pushBack(y.denominator);
  z.denominator.pushBack(y.numerator);
  z.reduceUnits();
  return z;
}

record unitAlgebra {
  var unit: Units,
      value: sstBigNum;


  proc init(u: Units, value: sstBigNum) {
    this.unit = u;
    this.value = value;
  }
  proc init(val: string) {
    var parse: string = val.strip();

    var split: int = 0;
    while parse[split].isDigit() {
      split = split+1;
    }

    
    
    var number: string = parse[0..<split];
    var units: string = parse[split..<parse.size];

    var multiplier: sstBigNum = 1;
    unit = new Units(units, multiplier);
    value = number: sstBigNum;
    value *= multiplier;
  }

  //TODO: arithmetic and logical operators 
  //TODO: invert

  proc getValue()  do return value;
  proc getRoundedValue() do return value;
  proc hasUnits(u: string) { 
    var multiplier: sstBigNum = 1;
    var checkUnits = new Units(u, multiplier);
    return unit == checkUnits;
  }

  proc invert() {
    return this;
  }
}

operator +(x: unitAlgebra, y: unitAlgebra) {
  assert(x.unit == y.unit);
  var z = new unitAlgebra(x.unit, x.value + y.value);
  return z;
}
operator -(x: unitAlgebra, y: unitAlgebra) {
  assert(x.unit == y.unit);
  var z = new unitAlgebra(x.unit, x.value - y.value);
  return z;
}
operator *(x: unitAlgebra, y: unitAlgebra) {
  var z = new unitAlgebra(x.unit * y.unit, x.value * y.value);
  return z;
}
operator /(x: unitAlgebra, y: unitAlgebra): unitAlgebra {
  var z = new unitAlgebra(x.unit / y.unit, x.value / y.value);
  return z;
}

class TimeLord {
  var initialized: bool,
      timeBaseString: string,
      tcMap: map(SimTime, shared TimeConverter),
      parseCache: map(string, shared TimeConverter),
      timeBase: unitAlgebra,
      nano: shared TimeConverter?,
      micro: shared TimeConverter?,
      milli: shared TimeConverter?;


  proc init(units: string) {
    timeBase = new unitAlgebra(units);
  }
  proc initialize(timeBaseString: string) {
    initialized = true;
    this.timeBaseString = timeBaseString;
    timeBase = new unitAlgebra(timeBaseString);
    try {
      nano = getTimeConverter("1ns");
    } catch {
      nano = nil;
    }

    try {
      micro = getTimeConverter("1us");
    } catch {
      micro = nil;
    }

    try {
      milli = getTimeConverter("1ms");
    } catch {
      milli = nil;
    }

  }

  proc getTimeConverter(ts: string) : shared TimeConverter {
    if ! parseCache.contains(ts) {
      var tc = getTimeConverter(new unitAlgebra(ts));
      parseCache.add(ts, tc);
    }
    return parseCache[ts];
  }

  proc getTimeConverter(simCycles: SimTime): shared TimeConverter {
    if ! tcMap.contains(simCycles) {
      var tc = new shared TimeConverter(simCycles);
      tcMap.add(simCycles, tc);
    }
    return tcMap[simCycles];
  }

  proc getTimeConverter(ts: unitAlgebra) : shared TimeConverter throws{
    if !initialized then 
      throw new Error("Time Lord has not yet been initialized");
    
    var simCycles: SimTime,
        period: unitAlgebra = ts,
        uaFactor: unitAlgebra;
    
    if period.hasUnits("s") {
      uaFactor = period / timeBase;
    } else if period.hasUnits("Hz") {
      var temp = timeBase;
      uaFactor = temp.invert() / period;
    } else {
      throw new Error("TimeConverter creation requires a time unit.");
    }

    // TODO: check for overflow

    if uaFactor.getValue() < 1 && uaFactor.getValue() != 0 {
      throw new Error("Attempting to get TimeConverter for a time with \
      too small of a period to be represented by the timebase.");

    }
    simCycles = uaFactor.getRoundedValue();
    var tc = getTimeConverter(simCycles);
    return tc;
  }

  proc getTimeBase() do return timeBase;
  proc getNano() do return nano;
  proc getMicro() do return micro;
  proc getMilli() do return milli;

  proc getSimCycles(timeString: string, whereString: string) {

  }

}

class TimeConverter {
  var factor: int;

  proc convertToCoreTime(time: SimTime) do return time * factor;

  proc convertFromCoreTime(time: SimTime) do return time / factor;

  proc getFactor() do return factor;

}
proc testTimeLord() {
  writeln("testTimeLord...");

  var tl = new TimeLord("1ks");
  tl.initialize("1ks");

  var tc1 = tl.getTimeConverter("3ks");
  assert(tc1.getFactor() == 3, tc1.getFactor());
  assert(tc1.convertToCoreTime(5) == 15);
  assert(tc1.convertFromCoreTime(9) == 3);

  var tc2 = tl.getTimeConverter("1Ms");
  assert(tc2.getFactor() == 1000);
  assert(tc2.convertToCoreTime(3) == 3000);
  assert(tc2.convertFromCoreTime(2000) == 2);

  var tc3 = tl.getTimeConverter("1uhz");
  assert(tc3.getFactor() == 1000);
  assert(tc3.convertToCoreTime(5) == 5000);
  assert(tc3.convertFromCoreTime(2000) == 2);

  writeln("testTimeLord Success");
}


proc testUnitAlgebra() {
  //From test_unitAlgebra.py
  writeln("testUnitAlgebra...");
  var ua1 = new unitAlgebra("15ks");
  var ua2 = new unitAlgebra("10ks");

  var ua3: unitAlgebra;
  
  ua3 = ua1 + ua2;
  
  assert(ua3.value == 25000, ua3.value);
  assert(ua3.hasUnits("s"), ua3.unit);

  ua3 = ua1 - ua2;
  
  assert(ua3.value == 5000);
  assert(ua3.hasUnits("s"));

  ua3 = ua1*ua2;
  assert(ua3.value == 15000*10000);
  assert(ua3.hasUnits("s-s"), ua3.unit);
  //TODO: check

  ua3 = ua3 / ua2;
  assert(ua3.value == 15000, ua3.value);
  assert(ua3.hasUnits("s"));


  writeln("testUnitAlgebra Success");
}

proc testUnitReduce() {
  writeln("testUnitReduce...");

  var multiplier: sstBigNum = 1;
  var units = new Units("s/b", multiplier);
  assert(units.numerator.contains(validBaseUnits("s")), units.numerator);
  assert(units.denominator.contains(validBaseUnits("b")));

  multiplier = 1;
  units = new Units("s/s", multiplier);
  assert(units.numerator.isEmpty());
  assert(units.denominator.isEmpty());


  multiplier = 1;
  units = new Units("s/s-b", multiplier);
  assert(units.numerator.isEmpty());
  assert(units.denominator.contains(validBaseUnits("b")));

  multiplier = 1;
  units = new Units("Es/Pb", multiplier);
  assert(units.numerator.contains(validBaseUnits("s")));
  assert(units.denominator.contains(validBaseUnits("b")));
  assert(multiplier == 1000, multiplier);
  writeln("testUnitReduce Success");
}
proc main() {
  testUnitReduce();
  testUnitAlgebra();
  testTimeLord();
}