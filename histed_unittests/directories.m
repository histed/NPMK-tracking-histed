function ds = directories

ds.nevDir = '~/data-local/nev-data-testcases';
ds.compDir = '~/data-local/nev-data-testcases/FilesToCompare';
ds.nev1 = fullfile(ds.nevDir, 'i005-110930-002.nev'); 

ds.ns31 = strrep(ds.nev1, '.nev', '.ns3');
