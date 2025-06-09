// This file contains unit tests for the PDES data structures

use CMB;


proc testReference() {
  writeln("testReference...");
  var emptyComponent: Component = new Component(1);
  var stringEvent: event = new event();

  stringEvent.receiveTime = 10;
  stringEvent.message = "hello to the receeiver";
  stringEvent.sender = emptyComponent;
  
  stringEvent.sender!.id = 2;
  assert(emptyComponent.id == 2);
  assert(stringEvent.sender!.id == 2);
  writeln("testReference Success");
}

proc testEventPrinting() {
  writeln("testEventPrinting...");
  var e1 = new event(100, "hello", nil);
  var e1str = e1:string;
  assert(e1str == "(100, \"hello\")");
  var e2 = new event(100, "null", nil, false); //content message with string "null"
  var e2str = e2:string;
  assert(e2str == "(100, \"null\")");

  var e3 = new event(100,true);
  var e3str = e3:string;
  assert(e3str == "(100, null)");
  
  writeln("testEventPrinting Success");
}

proc testEventInsertion() {
  writeln("testEventInsertion...");
  var comp: Component = new Component(1);
  var e0: event = new event(100, "hello", comp);
  var e1: event = new event(10, "hello", comp);
  var e2: event = new event(11, "hello", comp);
  var e3: event = new event(11, "hello1", comp);
  var e4: event = new event(11, "helln", comp);

  var queue = new EventQueue();
  assert(queue.channelClock() == 0);
  queue.add(e1);
  queue.add(e0);
  assert(queue.first() == e1);
  assert(queue.last() == e0);
  assert(queue.channelClock() == 100);

  queue.add(e2);
  queue.add(e3);
  queue.add(e4);
  assert(queue.channelClock() == 100);
  var e = queue.pop();
  assert(e == e1);
  e = queue.pop();
  assert(e == e4);
  e = queue.pop();
  assert(e == e2);
  e = queue.pop();
  assert(e == e3);
  e = queue.pop();
  assert(e == e0);
  assert(queue.channelClock() == 100);
  writeln("testEventInsertion Success");
}

proc testNullInsertion() {
  writeln("testNullInsertion...");
  var q = new EventQueue();

  var e1 = new event(10, "aaa", nil,false);
  var e2 = new event(10, "aaaa", nil,false);
  var e3 = new event(10,  "aa", nil, true);
  var e4 = new event(11, "aaa", nil, false);
  var e5 = new event(11, "", nil, true);
  var e6 = new event(12, "", nil, true);
  q.add(e1);
  assert(q.first() == q.last());
  q.add(e2);
  assert(q.last() == e2);
  q.add(e3);
  assert(q.last() == e3);
  //e4 should annihilate e3
  q.add(e4);
  assert(q.size == 3);
  assert(q.last() == e4);
  
  //e5 should go in at the end
  q.add(e5);
  assert(q.last() == e5);

  //e6 should annihilate e5 even though they're both null
  q.add(e6);
  assert(q.last() == e6);
  assert(q.size == 4);
  writeln("testNullInsertion Success");
}


proc testEventRemove() {
  writeln("testEventRemove...");
  var q = new EventQueue();
  var e1 = new event(10, "aaa", nil,false);
  var e2 = new event(10, "aaaa", nil,false);
  var e3 = new event(10,  "aa", nil, true);
  q.add(e1);
  q.add(e2);
  assert(q.events.remove(e1));
  assert(q.first() == e2);
  assert(q.last() == e2);

  assert(q.size == 1);
  q.add(e3);
  assert(q.first() == e2);
  assert(q.last() == e3);
  assert(q.size == 2);
  assert(q.events.remove(e3));
  assert(q.first() == e2);
  assert(q.last() == e2);
  writeln("testEventRemove Success");
}

proc testQueuePrinting() {
  writeln("testQueuePrinting...");
  var q = new EventQueue();
  var e1 = new event(10, "aaa", nil,false);
  var e2 = new event(10, "aaaa", nil,false);
  var e3 = new event(10,  "aa", nil, true);
  q.add(e1);
  q.add(e2);
  q.add(e3);
  
  var str = q:string;
  var correct = """[(10, "aaa"), (10, "aaaa"), (10, null)]""";
  assert(str == correct);
  
  writeln("testQueuePrinting Success");
}

proc testComponentPrinting() {
  writeln("testComponentPrinting...");
  var c = new Component(1);
  var str = c:string;
  var correct = 
"""Component: 1, Clock Value: -9223372036854775808
Input Queues: []""";

  assert(str == correct);

  c.inputQueues.pushBack(new shared EventQueue());
  c.inputQueues.pushBack(new shared EventQueue());
  c.inputQueues[0].add(new event(10, "test1", c));
  c.inputQueues[1].add(new event(20, "test2", c));
  str = c:string;
  correct = """Component: 1, Clock Value: -9223372036854775808
Input Queues: [
  [(10, "test1")],
  [(20, "test2")]
]""";

  assert(str == correct);
  

  class MyComponent: Component {}
  var myComp = new MyComponent();
  correct = """Component: -1, Clock Value: -9223372036854775808
Input Queues: []""";
  str = myComp:Component:string;
  assert(str == correct);

  writeln("testComponentPrinting Success");
}

proc main() {
  testReference();
  testEventPrinting();
  testEventRemove();

  testEventInsertion();

  testNullInsertion();

  testQueuePrinting();

  testComponentPrinting();
}