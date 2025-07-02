

class Units {

}
class UnitAlgebra {
  var unit: shared Units,
      value: sstBigNum;

  proc init(val: string) {
    var parse: string = val.trim();

    var split: int = 0;
    for i in 0..<parse.size {
      if parse[i].isDigit() {
        split = i+1;
        break;
      }
    }
    
    var number: string = parse[0..<split];
    var units: string = parse[split..<parse.size];

    var multiplier: sstBigNum = 1;
    unit = new shared Units(units, multiplier);
    value = number: sstBigNumber;
    value *= multiplier;
  }

  //TODO: arithmetic and logical operators 
  //TODO: invert

  proc hasUnits(u: string) { 
    u; 
    return false;
  }

  operator =(v: string) {
    //TODO
  }

  operator *=(v: shared UnitAlgebra) {
    //TODO
  }
  operator /=(v: shared UnitAlgebra) {
    //TODO
  }
  operator +=(v: shared UnitAlgebra) {
    //TODO
  }
  operator -=(v: shared UnitAlgebra) {
    //TODO
  }

  operator>(v: shared UnitAlgebra) {
    //TODO
  }
  operator>=(v: shared UnitAlgebra) {
    //TODO
  }
  operator<(v: shared UnitAlgebra) {
    //TODO
  }
  operator<=(v: shared UnitAlgebra) {
    //TODO
  }

  operator==(v: shared UnitAlgebra) {
    //TODO
  }
  operator!=(v: shared UnitAlgebra) {
    //TODO
  }

  proc invert() {}
}

class TimeLord {
  var initialized: bool,
      timeBaseString: string,
      tcMap: map(SimTime, shared TimeConverter),
      parseCache: map(string, shared TimeConverter),
      timeBase: shared UnitAlgebra,
      nano: shared TimeConverter?,
      micro: shared TimeConverter?,
      milli: shared TimeConverter?;


  proc initialize(timeBaseString: string) {
    initialized = true;
    this.timeBaseString = timeBaseString;
    timeBase = new shared UnitAlgebra(timeBaseString);
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
      var tc = getTimeConverter(new UnitAlgebra(ts));
      parseCache.add(ts, tc);
    }
    return parseCache[ts];
  }

  proc getTimeConverter(simCycles: SimTime): shared TimeConverter {
    if ! tcMap.contains(simCycles) {
      var tc = new TimeConverter(simCycles);
      tcMap.add(simCycles, tc);
    }
    return tcMap[simCycles];
  }

  proc getTimeConverter(ts: shared UnitAlgebra) : shared TimeConverter throws{
    if !initialized then 
      throw new Error("Time Lord has not yet been initialized");
    
    var simCycles: SimTime,
        period: shared UnitAlgebra = ts,
        uaFactor: shared UnitAlgebra;
    
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
    simCycles = uaFator.getRoundedValue();
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



proc testUnitAlgebra() {
  //From test_UnitAlgebra.py
  writeln("testUnitAlgebra...");
  var ua1 = new shared UnitAlgebra("15ns");
  var ua2 = new shared UnitAlgebra("10ns");

  var ua3: UnitAlgebra;
  
  ua3 = ua1 + ua2;
  
  //TODO: check

  ua3 = ua1 - ua2;
  //TODO: check

  ua3 = ua1*ua2;
  //TODO: check

  ua3 = ua1 / ua2;
  //TODO: check

  //TODO: in place operators

  //TODO: comparisons

  //TODO: check comparison errors correctly for respective types


  //TODO: math and comparison operators with mismatch units throws the right errors



  writeln("testUnitAlgebra Success");
}