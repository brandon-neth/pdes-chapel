// This file contains the Event and EventQueue data structures

use List;
use Heap;
use SortedSet;
use Sort;
use Map;
use IO;

record event {
  var receiveTime: int;
  var message: string;
  var sender: borrowed Component?;

  proc init() {
    receiveTime = -1;
    message = "";
    sender = nil;
  }
  
  proc init(receiveTime: int, message: string) {
    this.receiveTime = receiveTime;
    this.message = message;
    this.sender = nil;
  }

  proc init(receiveTime: int, message: string, sender: borrowed Component?) {
    this.receiveTime = receiveTime;
    this.message = message;
    this.sender = sender;
  }
}

record eventComparator: keyPartComparator {

  proc keyPart(elt: event, i: int) {
    var len = elt.message.numBytes;
    var section = if i <= len then keyPartStatus.returned 
                    else keyPartStatus.pre;
    var part =    if i == 0 then elt.receiveTime 
                    else if i <= len then elt.message.byte(i-1) 
                      else 0;
    return (section, part);    
  }

  proc compare(x: event, y: event) {
    if x.receiveTime < y.receiveTime then return -1;
    if x.receiveTime > y.receiveTime then return 1;
    if x.message < y.message then return -1;
    if x.message > y.message then return 1;
    return 0;
  }
}

class EventQueue : writeSerializable {
  var events : sortedSet(event, parSafe=false, eventComparator);

  // This variable holds a persistent copy of the channel clock
  // time. This is so that if all the events in a queue are 
  // processed, the channel clock value doesn't regress to -inf.
  // It is updated when events are removed.
  var maxPoppedReceiveTime: int;

  proc init() {
    events = new sortedSet(event, parSafe=false, eventComparator);
    maxPoppedReceiveTime = 0;
  }

  override proc serialize(writer: fileWriter(locking=false, ?),
                 ref serializer: ?st) {
    
    var strs = forall event in events do 
      "(" + event.receiveTime:string + ", '" + event.message + "')";
    var content = ", ".join(strs);
    writer.write("[" + content + "]");
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
     Pops the highest priority event from the queue
  */
  proc pop() throws {
    var event = first();
    if !events.remove(event) {
      throw new Error("failed to remove popped event.");
    }
    maxPoppedReceiveTime = event.receiveTime;
    return event;
  }

  proc add(e: event) {
    events.add(e);
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

class Component {

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

  proc handleEvent(e: event) {
    writeln("Base component event handler called. Content: ", e.message);
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
      writeln("updated clock value to ", clockValue);
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


  proc step(lookahead: int = 0) {
    var updated = updateClockValue();
    while hasEventToProcess() {
      var e = nextEvent();
      writeln("Handling event: ", e.message, ", ", e.receiveTime);
      handleEvent(e);
    }
    if updated {
      for queue in outputQueues {
        var e = new event(clockValue + lookahead, "null", this);
        queue.add(e);
      }
    }
  }
}