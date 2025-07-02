use SST;


proc createTestCompInfo() {
  var sim = getSimulation();
  for i in 1..10 {
    var newCompInfo = new shared ComponentInfo();
    newCompInfo.linkMap = new shared LinkMap();
    newCompInfo.id = i: ComponentId;
    sim.compInfoMap!.insert(newCompInfo);
  }
}

proc testConnect() {
  writeln("testConnect...");

  var c1 = new shared Component(1);
  var c2 = new shared Component(2);

  connect(c1, "port1", 10, c2, "port2", 12);

  var map1 = c1.linkMap!;
  var map2 = c2.linkMap!;

  var l1 = map1.getLink("port1");
  var l2 = map2.getLink("port2");

  assert(l1.pairLink == l2);
  assert(l2.pairLink == l1);
  assert(l1.latency == 10);
  assert(l2.latency == 12);

  writeln("testConnect Success");
}

proc testConfigureLink() {
  writeln("testConfigureLink...");
  var c1 = new shared Component(1);
  var c2 = new shared Component(2);

  connect(c1, "port1", 10, c2, "port2", 12);

  var l1 = c1.configureLink("port1");
  var l2 = c2.configureLink("port2");

  
  var l3 = c1.configureLink("port2");
  assert(l3 == nil);


  var l4 = c2.configureLink("port1");
  assert(l4 == nil);

  writeln("testConfigureLink success");
}

proc testHeap() {
  writeln("testHeap...");
  use Heap;
  var h = new heap(int, parSafe=true);
  assert(h.size == 0);
  assert(h.isEmpty());

  h.push(3);
  assert(h.size == 1);
  assert(h.top() == 3);


  writeln("testHeap Success");
}

proc testList() {
  writeln("testList...");
  use List;
  var l = new list(int, parSafe=true);
  assert(l.size == 0);
  l.pushBack(3);
  assert(l.size == 1);

  var t = l.popBack();
  assert(t == 3);
  writeln("testList Success");
}

proc testTimeVortexPQ() {
  writeln("testTimeVortexPQ...");

  var pq1 = new shared TimeVortexPQ(threadSafe=false);
  var pq2 = new shared TimeVortexPQ(threadSafe=true);

  var e1 = new shared Event();
  e1.deliveryTime = 100;
  assert(pq1.front() == nil);
  pq1.insert(e1);
  assert(pq1.front() == e1);
  var e2 = new shared Event();
  e2.deliveryTime = 90;
  pq1.insert(e2);
  assert(pq1.front() == e2);
  assert(pq1.size() == 2);

  var first = pq1.pop();
  assert(pq1.size() == 1);

  assert(first == e2, e2, first);

  var second = pq1.pop();
  assert(pq1.size() == 0);
  assert(second == e1);

  assert(pq2.front() == nil);
  pq2.insert(e1);
  assert(pq2.front() == e1);
  pq2.insert(e2);
  assert(pq2.front() == e2);
  assert(pq2.size() == 2);
  var first2 = pq2.pop();
  assert(pq2.size() == 1);
  assert(first2 == e2);
  var second2 = pq2.pop();
  assert(pq2.size() == 0);
  assert(second2 == e1, e1, second2);
  writeln("testTimeVortexPQ Sucess");
}


proc main() {
  writeln("here.id: ", here.id);
  initSST();
  createTestCompInfo();
  testConnect();
  testConfigureLink();
  testList();
  testHeap();
  testTimeVortexPQ();

}