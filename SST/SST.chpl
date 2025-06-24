use Map;
use List;

type ComponentId = int;
type SimTime = int;
type uIntPtrT = int;
type LinkType = int;
type LinkMode = int;
type LinkId = int;
type SimulatorHeartbeat = int;


class SimulationImpl {
  // most of these are simulation_impl.h starting line 410
  //TODO: factory
  //TODO: barriers, mutexes, locks,
  var crossThreadLinks: map(LinkId, Link?);
  var timeVortex: shared TimeVortex;
  var currentActivity: borrowed Activity;
  var minPart: SimTime;
  
  // var minPartTC : TimeConverter?;
  var interThreadLatencies: list(SimTime),
      interThreadMinLatency: SimTime,
      syncManager: shared SyncManager,
      compInfoMap: shared ComponentInfoMap,
      clockMap: shared ClockMap,
      heartbeat: SimulatorHeartbeat?,
      timeLord: shared TimeLord?,
      currentSimCycle: SimTime,
      currentPriority: int,
      endSimCycle: SimTime,
      endSim: bool;
  /* Not including:
    oneShotMap, exit, checkpoint_*, untimed*, 
    independent*, signal*, *interactive*, sim_output, stat_engin, profile*
  */

  proc run() {
    var timeFault = false;
    while !endSim && ! timeFault {
      var currentActivity = timeVortex.pop();
      var eventTime: SimTime = currentActivity.getDeliveryTime();
      timeFault = eventTime < currentSimCycle;
      currentSimCycle = eventTime;
      currentPriority = currentActivity.getPriority();
      currentActivity.execute();

      /* TODO: Signal handling */
    }
  }
}

class ComponentInfo {
  //var id: ComponentId;
  //var parentInfo: borrowed ComponentInfo?;
  //var name: string;
  //var linkMap: LinkMap;
  //var component: borrowed BaseComponent?;
}

class BaseComponent {
  var myInfo : borrowed ComponentInfo?;
  var sim : borrowed SimulationImpl?;
}

class Component : BaseComponent {
  // No additional fields
}

class LinkMap {
  var linkMap: map(string, Link);
  var selfPorts: list(string);
}

class Link {
  var sendQueue : ActivityQueue?;
  var deliveryInfo : uIntPtrT;
  var defaultTimeBase : SimTime;
  var latency : SimTime;
  var pairLink : Link?;

  var currentTime: SimTime;
  var myType : LinkType;
  var mode : LinkMode;
  var tag : LinkId;

  proc send(delay: SimTime, event: shared Event?) {
    /* TODO: Convert to core time */

    var deliveryTime = currentTime + delay + latency;
    if event == nil then event = new NullEvent();
    event.deliverTime = deliveryTime;
    event.deliveryInfo = deliveryInfo;
    sendQueue.insert(event);
  }
}

class NullEvent : Event {

  override proc execute() {
    // noop
  }
}


class Activity {
  var deliveryTime: SimTime,
      priorityOrder: int,
      queueOrder: int;

  proc execute() {}
}

class Action : Activity {

}

class Event : Activity {
  var deliveryInfo : borrowed DeliveryInfo?;
  override proc execute() {
    if deliveryInfo == nil then return;
    deliveryInfo!(this);
  }

  proc getDeliveryLink() {}


}

class ActivityQueue {

  proc empty(){}
  proc size(){}
  proc pop(){}
  proc insert(activity: Activity) {activity;}
  proc front() {}
}


class TimeVortex : ActivityQueue{
  var maxDepth: int, 
      sim: SimulationImpl;

  proc getCurrentDepth() {}
  proc fixup() {}
}





class SyncManager {}

class ComponentInfoMap{
  var dataById : map(ComponentId, ComponentInfo?);
  proc insert(info: ComponentInfo?) {info;}
  proc getbyId(key) {key;}
  proc empty() {}
  proc clear() {}
  proc size() {}
}

class ClockMap {}

class TimeLord {}

class DeliveryInfo {
  var recipient: borrowed Component?;

  proc this(event: shared Event) {
    if recipient == nil then return;
    recipient.handleEvent(event);
  }
}