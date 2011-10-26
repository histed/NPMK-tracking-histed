function testOpenNsx

ds = directories;

ns3 = openNSx(ds.ns31, 'read');;

%load saved
savedMatName = fullfile(ds.compDir, [strrep(ns3.MetaTags.Filename, '.', '_') '.mat']);
savedDs = load(savedMatName);
savedNs3 = savedDs.ns3;

assertTrue(isequalwithequalnans(ns3, savedNs3));



return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%% used this code to save as mat

%% open
ds = directories;
ns3 = openNSx(ds.ns31, 'read');

%% save
outName = fullfile(ds.compDir, [strrep(ns3.MetaTags.Filename, '.', '_') '.mat']);
save(outName, 'ns3', '-v7.3');
