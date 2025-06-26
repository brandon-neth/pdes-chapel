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

  try {
    var l3 = c1.configureLink("port2");
    assert(false);
  } catch {}

  try {
    var l4 = c2.configureLink("port1");
    assert(false);
  } catch {}

  writeln("testConfigureLink success");
}

proc main() {
  writeln("here.id: ", here.id);
  initSST();
  createTestCompInfo();
  testConnect();
  testConfigureLink();
}