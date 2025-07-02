class Base {
  proc execute() {
    writeln("Base.execute");
  }
}

class Derived: Base {
  override proc execute() {
    writeln("General Derived.execute");
  }
}
override proc (shared Derived).execute() {
  writeln("(shared Derived).execute");
}

var b: Base = new shared Base();
b.execute();

var dOwned = new owned Derived();
dOwned.execute();

var dShared = new shared Derived();
dShared.execute();


use List;
var l: list(shared Base);

l.pushBack(b);
l.pushBack(dShared);

for t in l do t.execute();