use List;
use Heap;
use SortedSet;
use Sort;
use Map;
use IO;



record event : writeSerializable{
  var receiveTime: int;
  var message: string;
  var sender: borrowed Component?;
  var sign: bool; // is this an event or an anti-event

  proc init() {
    receiveTime = -1;
    message = "";
    sender = nil;
    sign = true;
  }
  
  proc init(receiveTime: int, message: string, 
            sender: borrowed Component? = nil, sign = true) {
    this.receiveTime = receiveTime;
    this.message = message;
    this.sender = sender;
    this.sign = sign;
  }

  // For creating null messages
  proc init(receiveTime: int, null: bool, 
            sender: borrowed Component? = nil) {
    this.receiveTime = receiveTime;
    this.message = "";
    this.sender = sender; 
    this.sign = true;
  }

  proc isNull() {
    return null;
  }
  
  proc serialize(writer: fileWriter(locking=false, ?),
                 ref serializer: ?st) {
    writer.write(this:string);              
  }
}

operator :(from: event, type toType: string) {
   var message:string = "(";
   message += (from.receiveTime):string;
   message += ", " ;
   message += (if from.null then "null" else "\"" + from.message + "\"");
   message += ")";
   return message;
}

record eventComparator: keyPartComparator {

  proc keyPart(elt: event, i: int) {
    var len = elt.message.numBytes;
    var section = if i < len+2 then keyPartStatus.returned 
                    else keyPartStatus.pre;
    var part =    if i == 0 then elt.receiveTime 
                  else if i == 1 then !elt.null
                    else if i < len+2 then elt.message.byte(i-2) 
                      else 0;
    return (section, part);    
  }

  proc compare(x: event, y: event) {
    if x.receiveTime < y.receiveTime then return -1;
    if x.receiveTime > y.receiveTime then return 1;
    if x.isNull() && !y.isNull() then return 1;
    if !x.isNull() && y.isNull() then return -1;
    if x.message < y.message then return -1;
    if x.message > y.message then return 1;
    return 0;
  }
}


/*
  What data structure is right for an time warp event queue?

  Needs:
  - fossil collection / commiting
  - insertion with annihilation
  - popping
  - rollback?
  
  whats different from the CMB data structures?
  - single, shared input event queue per component

  I want a sortedSet and an iterator for the current head? 

*/

class TwEventQueue {
  
}

class TwComponent {
  var futureEvents, 
      pastEvents: EventQueue, 
      sentEvents: EventQueue;

  
}

class EventQueue : writeSerializable {
  var events : sortedSet(event, parSafe=true, eventComparator);

  // This variable holds a persistent copy of the channel clock
  // time. This is so that if all the events in a queue are 
  // processed, the channel clock value doesn't regress to -inf.
  // It is updated when events are removed.
  var maxPoppedReceiveTime: int;

  var lock: sync bool;
  proc init() {
    events = new sortedSet(event, parSafe=true, eventComparator);
    maxPoppedReceiveTime = 0;
  }

  override proc serialize(writer: fileWriter(locking=false, ?),
                 ref serializer: ?st) {
    writer.write(this:string);
  }
  /*
     Returns the first (highest priority) event in the queue.
     Does *not* remove the event  from the queue.
  */
  proc first() throws {
    var (success,event) = events.kth(1);
    if !success then
      throw new Error("tried to index into empty EventQueue.");
    return event;
  }

  /*
     Returns the last (lowest priority) event in the queue.
     Does *not* remove the event  from the queue.
  */
  proc last() throws {
    var (success,event) = events.kth(events.size);
    if !success then
      throw new Error("tried to index into empty EventQueue.");
    return event;
  }

  /*
    Returns how many events are in the channel
  */
  proc size {
    return events.size;
  }

  /*
     Pops the highest priority event from the queue
  */
  proc pop() throws {
    lock.writeEF(true);
    var event = first();
    if !events.remove(event) {
      lock.readFE();
      throw new Error("failed to remove popped event.");
    }
    lock.readFE();
    maxPoppedReceiveTime = event.receiveTime;
    return event;
  }

  proc add(e: event) {
    lock.writeEF(true);
    // Any message put in the buffer after a null message
    // annihilates any null message ahead of it in the buffer
    try {
      while last().isNull() {
        events.remove(last());
      }
    } catch {}
    events.add(e);
    lock.readFE();
  }


  /* 
     Returns the channel clock value of this queue. This is
     the largest receive timestamp on an event in the queue
  */
  proc channelClock() {
    try {
      var lastEvent = last();
      return lastEvent.receiveTime;
    } catch {
      return maxPoppedReceiveTime;
    }
  }
}


operator :(from: EventQueue, type toType: string) {
  var strs = forall event in from.events do event:string;
  var content = ", ".join(strs);
  return "[" + content + "]";
}

class Component : writeSerializable {

  var id: int;
  var inputQueues : list(shared EventQueue, parSafe = false);
  var outputQueues : list(shared EventQueue, parSafe = false);
  var clockValue: int;

  proc init() {
    this.id = -1;
    inputQueues = new list(shared EventQueue, parSafe = false);
    outputQueues = new list(shared EventQueue, parSafe = false);
    clockValue = min(int);
  }

  proc init(id: int) {
    this.init();
    this.id = id;
  }

  override proc serialize(writer: fileWriter(locking=false, ?),
                          ref serializer: ?st) throws {
    writer.write(this:string);
  }

  proc handleEvent(e: event) {
    writeln("Warning: Base component event handler called. Content: ", e.message);
  }

  proc nextEvent(): event throws {
    var minQueueIdx = -1;
    var minTime = max(int);
    for i in 0..<inputQueues.size {
      var queue = inputQueues[i];
      try {
        var nextEvent = queue.first();
        if nextEvent.receiveTime < minTime {
          minTime = nextEvent.receiveTime;
          minQueueIdx = i;
        }
      } catch {}
    }

    if minQueueIdx == -1 {
      throw new Error("No more events for this component");
    }
    ref queue = inputQueues[minQueueIdx];
    var nextEvent = queue.pop();
    return nextEvent;
  }

  proc updateClockValue() {
    var lowestClock = max(int);
    for queue in inputQueues {
      lowestClock = min(lowestClock, queue.channelClock());
    }
    if lowestClock > clockValue {
      clockValue = lowestClock;
      return true;
    }
    return false;
  }

  proc hasEventToProcess() {
    for queue in inputQueues {
      try{
      if queue.first().receiveTime < clockValue then
        return true;
      } catch {}
    }
    return false;
  }

  proc lookahead() {
    return 0;
  }

  proc sendNulls() {
    for queue in outputQueues do
      queue.add(new event(clockValue + lookahead(), true, this));
  }

  proc step() {
    var updated = updateClockValue();
    while hasEventToProcess() {
      var e = nextEvent();
      handleEvent(e);
    }
    if updated {
      sendNulls();
    }
  }
}

operator :(from: Component, type toType: string) {
  var str = "";
  str += ("Component: " + from.id:string + ", ");
  str += ("Clock Value: " + from.clockValue:string);
  str += ("\nInput Queues: [");
  var queues = for q in from.inputQueues do q:string;
  var qStr = ",\n  ".join(queues);
  if queues.size > 0 {
    str += "\n  ";
  }
  str += qStr;
  if queues.size > 0 {
    str += "\n";
  }
  str += ("]");
  return str;
}