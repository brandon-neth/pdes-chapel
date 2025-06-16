use List;
use Heap;
use SortedSet;
use Sort;
use Map;
use CTypes;
use IO;



record event : writeSerializable {
  var receiveTime: int;
  var message: string;
  var sender: borrowed TwComponent?;
  var receiver: borrowed TwComponent?;
  var sign: bool; // is this an event (true) or an anti-event (false)

  proc init() {
    receiveTime = -1;
    message = "";
    sender = nil;
    receiver = nil;
    sign = true;
  }
  
  proc init(receiveTime: int, message: string, 
            sender: borrowed TwComponent? = nil,
            receiver: borrowed TwComponent? = nil,
            sign = true) {
    this.receiveTime = receiveTime;
    this.message = message;
    this.sender = sender;
    this.receiver = receiver;
    this.sign = sign;
  }

  proc opposite() {
    return new event(receiveTime, message, sender, receiver, !sign);
  }
}

/*
  This record is for sorting events into the event queue.
*/
record eventComparator: keyPartComparator {

  proc keyPart(elt: event, i: int) {
    var len = elt.message.numBytes;
    var section = if i < len+2 then keyPartStatus.returned 
                    else keyPartStatus.pre;
    var part =    if i == 0 then elt.receiveTime 
                  else if i == 1 then elt.sign
                    else if i < len+2 then elt.message.byte(i-2) 
                      else 0;
    return (section, part);    
  }

  proc compare(x: event, y: event) {
    if x.receiveTime < y.receiveTime then return -1;
    if x.receiveTime > y.receiveTime then return 1;
    if x.sign && !y.sign then return 1;
    if !x.sign && y.sign then return -1;
    if x.message < y.message then return -1;
    if x.message > y.message then return 1;
    return 0;
  }
}


class TwEventQueue {
  type comparatorType;
  var events : sortedSet(event, parSafe=true, comparatorType);

  proc init(type comparatorType) {
    this.comparatorType = comparatorType;
    var comparator = new comparatorType();
    events = new sortedSet(event, parSafe=true, comparator);
  }

  proc init(comparator: record) {
    this.comparatorType = comparator.type;
    events = new sortedSet(event, parSafe=true, comparator);
  }

  proc add(e: event) {
    if events.contains(e.opposite()) {
      // Annihilate the event
      events.remove(e.opposite());
    } else {
      // Add the event to the queue
      events.add(e);
    }
  }


  /* Removes the last (lowest priority) element in the queue. */
  proc pop() throws {
    if events.isEmpty() then
      throw new Error("Tried to pop from an empty TwEventQueue.");
    var event = last();
    if !events.remove(event) then
      throw new Error("Failed to remove popped event from TwEventQueue.");
    return event;
  }

  /* Removes the first (highest priority) element in the queue. */
  proc dequeue() throws {
    if events.isEmpty() then
      throw new Error("Tried to dequeue from an empty TwEventQueue.");
    var event = first();
    if !events.remove(event) then
      throw new Error("Failed to remove dequeued event from TwEventQueue.");
    return event;
  }

  proc first() throws {
    var (success,event) = events.kth(1);
    if !success then
      throw new Error("Tried to index into empty TwEventQueue.");
    return event;
  }

  proc last() throws {
    var (success,event) = events.kth(events.size);
    if !success then
      throw new Error("Tried to index into empty TwEventQueue.");
    return event;
  }

  proc size {
    return events.size;
  }
}

record savedStateComparator: keyPartComparator {
  proc keyPart(elt: (int, c_ptr(void)), i: int) {
    var section = if i == 0 then keyPartStatus.returned 
                    else keyPartStatus.pre;
    var part = if i == 0 then elt[0] else 0;
    return (section, part);
  }

  proc compare(x: (int, c_ptr(void)), y: (int, c_ptr(void))) {
    if x[0] < y[0] then return -1;
    if x[0] > y[0] then return 1;
    return 0;
  }
}

class TwComponent {
      /* Received events that are not yet proccessed. Stored in
         ascending order by receiveTime. 
      */
  var futureEvents: shared TwEventQueue(eventComparator),

      /* Received events that have bene processed but not yet 
         fossil collected. Stored in decending order by recieveTime.
         This means that the front of this list is the most recently sent
         message and the rear is the oldest message sent that still is
         recorded.
      */
      pastEvents: shared TwEventQueue(reverseComparator(eventComparator)),

      /* Anti-message copies of sent messages. These are used to
         annihilate messages that have been sent in the case of rollback.
         They are sorted most recent to least recent. Thus, when rewinding,
         we send the messages from the front of the queue until it equals the
         rewind timestamp. 
      */
      sentEvents: shared TwEventQueue(reverseComparator(eventComparator)),

      /* Saved states of the component contents. Used to restore the state 
         in case of rollback. Important to ensure that this is a tuple of 
         a timestamp and a c_ptr(void) to the saved state. I do this to 
         allow different components to have different contents.
         NOTE: An entry of (x,data) is the state of the component AFTER
         processing all events up to AND INCLUDING timestamp x.
      */
      savedStates: sortedSet((int, c_ptr(void)), parSafe=true, savedStateComparator);
  var lvt: int;
  proc init() {
    futureEvents = new shared TwEventQueue(new eventComparator());
    var revComp = new reverseComparator(new eventComparator());
    pastEvents = new shared TwEventQueue(revComp);
    sentEvents = new shared TwEventQueue(revComp);
    savedStates = new sortedSet((int, c_ptr(void)), parSafe=true, savedStateComparator);
    lvt = 0;
  }

  proc localVirtualTime {
    return lvt;
  }
  proc addEvent(e: event) {
    if e.receiveTime <= lvt {
      rollback(e.receiveTime);
    }
    futureEvents.add(e);
  }

  proc empty() {
    return futureEvents.size == 0;
  }
  proc rollback(timestamp: int) {

    // First, restore the state of the component and get the timestamp that 
    // we restore to. This will determine what time we rewind the queues 
    // to, because we may have to go further back in the past than the
    // timestamp passed as an argument

    var rewindTime = loadState(timestamp);

    // Now, roll back the event queue to the time we restored to.
    while pastEvents.size != 0 && pastEvents.first().receiveTime > rewindTime {
      var e = pastEvents.dequeue();
      futureEvents.add(e);
    }

    // Then, send the anti-events to cancel out erroneously sent messages
    while sentEvents.size != 0 && sentEvents.first().receiveTime > rewindTime {
      var e = sentEvents.dequeue();
      this.sendEvent(e);
    }

    // Last, set the local virtual time to the new timestamp
    lvt = rewindTime;
  }

  proc fossilCollect(timestamp: int) {
    // Remove past events older than the timestamp
    while pastEvents.size != 0 && pastEvents.last().receiveTime < timestamp {
      pastEvents.pop();
    }
    // Remove sent events older than the timestamp
    while sentEvents.size != 0 && sentEvents.last().receiveTime < timestamp {
      sentEvents.pop();
    }

    // Remove saved states older than the timestamp, always ensuring 
    // that there's at least one older than the timestamp
    
    // `s` will be the first saved state that is newer than the timestamp
    var (success1, s) = savedStates.upperBound((timestamp, nil: c_ptr(void)));
    
    if !success1 {
      // No saved states newer than the timestamp, remove all but the last
      while savedStates.size > 1 {
        var (success11, stateToRemove) = savedStates.kth(1);
        savedStates.remove(stateToRemove);
        freeSavedState(stateToRemove[1]);
      }
    } else {
      var (success2, stateToKeep) = savedStates.predecessor(s);
      assert(success2, "Component does not have a saved \
      state older than the fossil collection timestamp");

      var (success, stateToRemove) = savedStates.kth(1);
      while success && stateToRemove[0] < stateToKeep[0] {
        savedStates.remove(stateToRemove);
        (success, stateToRemove) = savedStates.kth(1);
      }
    }
  }

  proc sendEvent(e: event) {
    // Add the anti message to the sent events queue
    sentEvents.add(e.opposite());
    // Send the message onwards
    e.receiver!.addEvent(e);
  }

  /* 
    This is a placeholder for handling events. It is only responsible
    for processing positive, standard events. Anti-events moving events
    from the future to the past queue are done by the stepping procedure
    below.
  */
  proc handleEvent(e: event) {
    writeln("Warning: TwComponent.handleEvent has been run. \
    Consider overriding this method in your subclass.");
    e;
  }

  proc step() {
    // If there are no future events, we are done
    if futureEvents.size == 0 then return;

    var nextEvent: event = futureEvents.dequeue();

    // If we are increasing the local virtual time, we need to 
    // save the state
    if nextEvent.receiveTime > lvt {
      saveState(lvt);
    }

    // Treat anti-events as no-ops, when the corresponding event arrives,
    // it will cause a rollback and the anti-event will be removed.
    if nextEvent.sign then handleEvent(nextEvent);

    // Add it to the past event queue in case of later rollback
    pastEvents.add(nextEvent);

    lvt = nextEvent.receiveTime;
  }

  proc store(): c_ptr(void) {
    writeln("Warning: TwComponent.store has been called. \
    Consider overriding this method in your subclass. ");
    var contents = (-42,);
    return c_ptrTo(contents): c_ptr(void);
  }

  proc restore(contents: c_ptr(void)) {
    writeln("Warning: TwComponent.restore has been called. \
    Consider overriding this method in your subclass.");
    contents;
  }

  proc freeSavedState(contents: c_ptr(void)) {
    // Free the saved state contents
    writeln("Warning: TwComponent.freeSavedState has been called. \
    Consider overriding this method in your subclass.");
    contents;
  }

  proc saveState(timestamp: int = -1) {
    var contents = this.store();
    var state = (timestamp, contents);
    savedStates.add(state);
  }

  proc removeOutdatedSavedStates(timestamp: int) {
    // Remove all saved states new than the timestamp.
    // This is to "restore" the saved state queue
    var (success, stateToRemove) = savedStates.kth(savedStates.size);
    while success && stateToRemove[0] > timestamp {
      savedStates.remove(stateToRemove);
      freeSavedState(stateToRemove[1]);
      (success, stateToRemove) = savedStates.kth(savedStates.size);
    }
  }

  proc loadState(timestamp: int) throws {
    //TODO: need to remove the saved states that we don't use when restoring

    var (success, state) = savedStates.upperBound((timestamp, nil: c_ptr(void)));
    if ! success {
      // No saved state newer than the timestamp,
      // so just use the most recent one
      var (success1, stateToRestore) = savedStates.kth(savedStates.size);
      if !success1 {
        throw new Error("No saved state to restore from.");
      }
      this.restore(stateToRestore[1]);
      removeOutdatedSavedStates(stateToRestore[0]);
      return stateToRestore[0];
    }

    var (success2, stateToRestore) = savedStates.predecessor(state);
    if success2 {
      this.restore(stateToRestore[1]);
      removeOutdatedSavedStates(stateToRestore[0]);
      return stateToRestore[0];
    } 
    else {
      throw new Error("No saved state to restore from.");
    }
  }
}

proc gvt(components: [shared TwComponent]) {
  assert(components.size > 0,
         "Cannot calculate GVT of an empty set of components.");
  // Calculate the global virtual time of the system
  var gvt = components[0].localVirtualTime;
  for c in components {
    if c.localVirtualTime < gvt then
      gvt = c.localVirtualTime;
  }
  for c in components {
    c.fossilCollect(gvt);
  }
  return gvt;
}



class QuietComponent: TwComponent {
  /* This is a component that just silently handles events. */

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

  override proc freeSavedState(contents: c_ptr(void)) {
    // No state to free
    contents;
  }
}
