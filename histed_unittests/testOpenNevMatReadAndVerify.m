function test_suite = testOpenNevMatReadAndVerify
initTestSuite;

%%%%%%%%%%%%%%%%

function testReadNoCache
ds = directories;
ns = openNEV(ds.nev1, 'read', 'nomat', 'nosave');

function testReadAndSave(ns)

ds = directories;

ns = openNEV(ds.nev1);
mt = ns.MetaTags;
matName = fullfile(mt.FilePath, [mt.Filename, '.mat']);
if exist(matName, 'file');
    delete(matName);
end

ns = openNEV(ds.nev1, 'read');

assertEqual(exist(matName, 'file'), 2);

function testVerifyMat
ds = directories;

ns = openNEV(ds.nev1, 'read');

mt = ns.MetaTags;
matName = fullfile(mt.FilePath, [mt.Filename, '.mat']);

savedMatName = fullfile(ds.nevDir, 'FilesToCompare', [mt.Filename '.mat']);
savedDs = load(savedMatName);
savedNs = savedDs.NEV;

assertTrue(isequalwithequalnans(ns, savedNs))

