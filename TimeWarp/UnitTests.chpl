use TimeWarp;
use CTypes;


class QuietComponent: TwComponent {
  /* This is a component that just silently handles events.
     It's for testing */

  proc init() {
    super.init();
    init this;
    saveState();
  }
  override proc handleEvent(e: event) {
    return;
  }
  override proc store(): c_ptr(void) {
    // No state to store
    var contents = (0,);
    return c_ptrTo(contents): c_ptr(void);
  }
  override proc restore(contents: c_ptr(void)) {
    // No state to restore
    contents;
  }
}

proc testReverseComparator() {
  writeln("testReverseComparator...");
  var c = new shared QuietComponent();
  var e1 = new event(1, "a", nil, c, true);
  var e2 = new event(1, "b", nil, c, true);
  var e3 = new event(2, "a", nil, c, true);
  var e4 = new event(2, "a", nil, c, false);
  var e5 = new event(2, "a", c, c, true);

  c.futureEvents.add(e1);
  c.pastEvents.add(e1);
  assert(c.futureEvents.first() == c.pastEvents.last());
  assert(c.futureEvents.last() == c.pastEvents.first());
  c.futureEvents.add(e2);
  c.pastEvents.add(e2);
  assert(c.futureEvents.first() == c.pastEvents.last());
  assert(c.futureEvents.last() == c.pastEvents.first());
  c.futureEvents.add(e3);
  c.pastEvents.add(e3);
  assert(c.futureEvents.first() == c.pastEvents.last());
  assert(c.futureEvents.last() == c.pastEvents.first());
  c.futureEvents.add(e4);
  c.pastEvents.add(e4);
  assert(c.futureEvents.first() == c.pastEvents.last());
  assert(c.futureEvents.last() == c.pastEvents.first());
  c.futureEvents.add(e5);
  c.pastEvents.add(e5);
  assert(c.futureEvents.first() == c.pastEvents.last());
  assert(c.futureEvents.last() == c.pastEvents.first());
  writeln("testReverseComparator Success");
}

proc testAnnihilation() {
  writeln("testAnnihilation...");
  var c = new shared QuietComponent();
  var e1 = new event(1, "a", nil, c, true);
  var e2 = new event(1, "b", nil, c, true);
  var e3 = new event(2, "a", nil, c, true);
  var e4 = new event(2, "a", nil, c, false);
  var e5 = new event(2, "a", c, c, true);

  c.addEvent(e1);
  assert(c.futureEvents.first() == e1);
  c.addEvent(e2);
  assert(c.futureEvents.first() == e1);
  assert(c.futureEvents.last() == e2);

  c.addEvent(e3);
  assert(c.futureEvents.first() == e1);
  assert(c.futureEvents.last() == e3);
  c.addEvent(e4);
  assert(c.futureEvents.first() == e1);
  assert(c.futureEvents.last() == e2);
  assert(c.futureEvents.size == 2);
  c.addEvent(e5);
  assert(c.futureEvents.first() == e1);
  assert(c.futureEvents.last() == e5);


  writeln("testAnnihilation Success");
}

proc testRollback() {
  writeln("testRollback...");
  var c = new shared QuietComponent();
  var e1 = new event(1, "a", nil, c, true);
  var e2 = new event(2, "a", nil, c, true);
  var e3 = new event(3, "a", nil, c, true);
  var e4 = new event(4, "a", nil, c, true);
  var e5 = new event(5, "a", c, c, true);

  c.pastEvents.add(e2);
  c.pastEvents.add(e3);
  c.futureEvents.add(e5);
  c.futureEvents.add(e4);

  c.lvt = 2;
  // Now, adding e1 should cause a rollback that adds back e2 and e3
  c.addEvent(e1);
  assert(c.futureEvents.first() == e1);
  assert(c.futureEvents.last() == e5);
  assert(c.pastEvents.size == 0);
  assert(c.futureEvents.size == 5);
  writeln("testRollback Success");
}

proc testFossilCollectPast() {
  writeln("testFossilCollectPast...");
  var c = new shared QuietComponent();
  var e1 = new event(1, "a", nil, c, true);
  var e2 = new event(2, "a", nil, c, true);
  var e3 = new event(3, "a", nil, c, true);
  var e4 = new event(4, "a", nil, c, true);
  var e5 = new event(5, "a", c, c, true);

  c.pastEvents.add(e2);
  c.pastEvents.add(e3);
  c.pastEvents.add(e4);
  c.pastEvents.add(e1);
  c.fossilCollect(3);
  assert(c.pastEvents.size == 2);
  assert(c.pastEvents.first() == e4);
  assert(c.pastEvents.last() == e3);

  writeln("testFossilCollectPast Success");
}


proc testMessageHandling1() {
  // Original message arrives, but hasn't been processed. 
  // Negative message arrives, with a timestamp equal to the next 
  // event in the queue (the corresponding positive event)

  writeln("testMessageHandling1...");
  var c = new shared QuietComponent();
  var e1 = new event(1, "a", nil, c, true);
  var e2 = new event(2, "b", nil, c, true);
  var e3 = new event(2, "b", nil, c, false);

  c.addEvent(e1);
  c.addEvent(e2);

  c.step();
  assert(c.pastEvents.first() == e1);
  assert(c.futureEvents.size == 1);
  assert(c.futureEvents.first() == e2);
  c.addEvent(e3);
  assert(c.futureEvents.size == 0, c.futureEvents.size);

  writeln("testMessageHandling1 Success");
}

proc testMessageHandling2() {
  // Original positive message in the past (already run)
  // negative message arrives, should cause rollback and annihilation
  writeln("testMessageHandling2...");
  var c = new shared QuietComponent();

  var e2 = new event(2, "b", nil, c, true);
  var e3 = new event(2, "b", nil, c, false);

  c.addEvent(e2);
  c.step();
  assert(c.pastEvents.first() == e2);
  assert(c.futureEvents.size == 0);
  assert(c.lvt == 2, c.lvt);
  c.addEvent(e3);
  assert(c.pastEvents.size == 0);
  assert(c.futureEvents.size == 0);
  writeln("testMessageHandling2 Success");
}

proc testMessageHandling3() {
  // Negative message arrives first. Positive message arriving
  // causes rollback and annihilation
  writeln("testMessageHandling3...");
  var c = new shared QuietComponent();

  var e2 = new event(2, "b", nil, c, true);
  var e3 = new event(2, "b", nil, c, false);

  c.addEvent(e3);
  c.step();
  assert(c.pastEvents.first() == e3);
  assert(c.futureEvents.size == 0);
  assert(c.localVirtualTime == 2);
  c.addEvent(e2);
  assert(c.pastEvents.size == 0);
  assert(c.futureEvents.size == 0);
  writeln("testMessageHandling3 Success");
}

class CounterClass1 : TwComponent {
  var counter: int;

    
  class SavedState {
      var counter: int;
  }

  proc init() {
    super.init();
    init this;
    this.counter = 0;
    this.saveState();
  }

  override proc handleEvent(e: event) {
    counter += 1;
  }

  override proc store() {
    var curState = new unmanaged SavedState(counter);
    return c_ptrTo(curState): c_ptr(void);
  }

  override proc restore(contents: c_ptr(void)) {
    var curState: unmanaged SavedState = (contents: unmanaged SavedState?)!;
    counter = curState.counter;
  }

  override proc freeSavedState(contents: c_ptr(void)) {
    var state: unmanaged SavedState = (contents: unmanaged SavedState?)!;
    delete state;
  }
}

proc testRestore1() {
  writeln("testRestore1...");
  var c = new shared CounterClass1();
  var e1 = new event(2, "a", nil, c, true);
  var e2 = new event(3, "b", nil, c, true);
  var e3 = new event(1, "a", nil, c, true);

  assert(c.savedStates.size == 1, c.savedStates.size);
  c.addEvent(e1);
  assert(c.savedStates.size == 1);
  c.addEvent(e2);
  assert(c.savedStates.size == 1);
  assert(c.lvt == 0, c.lvt);
  c.step();
  assert(c.counter == 1);
  assert(c.savedStates.size == 2);
  assert(c.futureEvents.size == 1);
  assert(c.futureEvents.first() == e2);
  assert(c.pastEvents.size == 1);
  assert(c.pastEvents.first() == e1);
  c.step();
  assert(c.counter == 2);
  assert(c.futureEvents.size == 0);
  assert(c.pastEvents.size == 2);
  assert(c.pastEvents.last() == e1);
  assert(c.pastEvents.first() == e2);
  assert(c.savedStates.size == 3, c.savedStates.size);
  // Add an event that will be rolled back
  c.addEvent(e3);
  assert(c.counter == 0);
  
  
  writeln("testRestore1 Success");
}

proc main() {
  testReverseComparator();
  testAnnihilation();
  testRollback();
  testFossilCollectPast();
  testMessageHandling1();
  testMessageHandling2();
  testMessageHandling3();
  testRestore1();
}