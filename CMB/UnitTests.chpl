// This file contains unit tests for the PDES data structures

use PDES;


proc testEvents() {
  writeln("Testing Events");
  var emptyComponent: Component = new Component(1);
  var stringEvent: event = new event();

  stringEvent.receiveTime = 10;
  stringEvent.message = "hello to the receeiver";
  stringEvent.sender = emptyComponent;
  
  stringEvent.sender!.id = 2;
  writeln("id through component: ", emptyComponent.id);
  writeln("id through event: ", stringEvent.sender!.id);
}

proc testEventInsertion() {
  writeln("Testing event insertion");
  var comp: Component = new Component(1);
  var e0: event = new event(100, "hello", comp);
  var e1: event = new event(10, "hello", comp);
  var e2: event = new event(11, "hello", comp);
  var e3: event = new event(11, "hello1", comp);
  var e4: event = new event(11, "helln", comp);

  var queue = new EventQueue();
  assert(queue.channelClock() == min(int));
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
  writeln("Success");
}


proc main() {
  testEvents();

  testEventInsertion();


  
}